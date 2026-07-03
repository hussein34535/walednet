package com.waled.net

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

/**
 * WaledVpnService v6 - DNS-over-TCP
 *
 * v5 مشكلة: dartssh2 مبيعملش support UDP ASSOCIATE
 * v6 حل: UDP DNS (53) → TCP DNS عبر SOCKS5 (RFC 1035)
 *
 * التوجيه:
 *   TCP → SOCKS5 → SSH tunnel ✅
 *   UDP 53 → DoT → SOCKS5 → SSH tunnel ✅  (جديد)
 *   UDP أخرى → direct (protect)
 */
class WaledVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.waled.net.START"
        const val ACTION_STOP = "com.waled.net.STOP"
        const val EXTRA_SOCKS_PORT = "socks_port"
        const val EXTRA_SOCKS_HOST = "socks_host"
        const val EXTRA_DNS_SERVER = "dns_server"

        private const val TAG = "WaledVpn"
        private const val CHANNEL_ID = "waled_vpn"
        private const val UDP_TIMEOUT_MS = 5000
        private const val DNS_PORT = 53
        private const val TCP_DNS_TIMEOUT_MS = 15000
    }

    private var tunFd: ParcelFileDescriptor? = null
    private var tunInput: FileInputStream? = null
    private var tunOutput: FileOutputStream? = null
    @Volatile private var running = false
    private var socksHost = "127.0.0.1"
    private var socksPort = 10808
    private var dnsServer = "1.1.1.1"
    private val sessions = ConcurrentHashMap<Int, TcpSession>()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        try {
            startForeground(1, buildNotification("جارٍ إعداد الاتصال..."))
            Log.i(TAG, "startForeground called")
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent?.action) {
            ACTION_START -> {
                socksHost = intent.getStringExtra(EXTRA_SOCKS_HOST) ?: "127.0.0.1"
                socksPort = intent.getIntExtra(EXTRA_SOCKS_PORT, 10808)
                dnsServer = intent.getStringExtra(EXTRA_DNS_SERVER) ?: "1.1.1.1"
                startVpn()
            }
            ACTION_STOP -> stopVpn()
        }
        return START_STICKY
    }

    override fun onRevoke() { Log.w(TAG, "onRevoke called by system"); stopVpn() }

    private fun startVpn() {
        val builder = Builder()
        builder.setSession("WaledNet")
        builder.setMtu(1500)
        builder.addAddress("10.0.0.1", 24)
        builder.addRoute("0.0.0.0", 0)
        builder.addRoute("::", 0)
        builder.addDnsServer(dnsServer)
        builder.addDnsServer("8.8.8.8")
        builder.addDisallowedApplication(packageName)

        try {
            tunFd = builder.establish()
            if (tunFd == null) { Log.e(TAG, "TUN fd is null"); stopVpn(); return }
            Log.i(TAG, "TUN established, fd=${tunFd!!.fd}")

            tunInput = FileInputStream(tunFd!!.fileDescriptor)
            tunOutput = FileOutputStream(tunFd!!.fileDescriptor)

            running = true
            Log.i(TAG, "VPN started → $socksHost:$socksPort, DNS=$dnsServer (DoT)")
            thread(name = "TunRead") { readLoop() }
            startForeground(1, buildNotification("WaledNet VPN متصل"))
        } catch (e: Exception) {
            Log.e(TAG, "startVpn failed: ${e.message}")
            stopVpn()
        }
    }

    private fun readLoop() {
        val buf = ByteArray(32767)
        var total = 0L
        Log.i(TAG, "TUN reader loop started")
        while (running) {
            try {
                val n = tunInput!!.read(buf)
                if (n == 0) { Thread.sleep(10); continue }
                if (n < 0) { Log.i(TAG, "TUN EOF"); break }
                total += n
                processPacket(buf.copyOfRange(0, n))
            } catch (e: java.io.InterruptedIOException) { if (!running) break }
            catch (e: Exception) { if (!running) break; Thread.sleep(10) }
        }
        Log.i(TAG, "TUN reader stopped, total: $total bytes")
        cleanup()
    }

    private fun processPacket(data: ByteArray) {
        if (data.size < 20) return
        val ver = (data[0].toInt() shr 4) and 0x0F
        if (ver != 4) return
        val ihl = (data[0].toInt() and 0x0F) * 4
        if (ihl < 20 || data.size < ihl + 4) return
        val proto = data[9].toInt() and 0xFF
        val totalLen = u16(data, 2)
        when (proto) {
            6 -> onTcp(data, ihl, minOf(totalLen, data.size))
            17 -> onUdp(data, ihl, minOf(totalLen, data.size))
        }
    }

    private fun onTcp(data: ByteArray, ipHdr: Int, totalLen: Int) {
        if (data.size < ipHdr + 20) return
        val tcpHdrLen = ((data[ipHdr + 12].toInt() shr 4) and 0x0F) * 4
        if (tcpHdrLen < 20) return
        val flags = data[ipHdr + 13].toInt() and 0xFF
        val srcPort = u16(data, ipHdr)
        val dstPort = u16(data, ipHdr + 2)
        val srcIp = readI32(data, 12)
        val dstIp = readI32(data, 16)
        val isSyn = (flags and 0x02) != 0 && (flags and 0x10) == 0
        val key = srcIp xor srcPort
        val seq = readU32(data, ipHdr + 4)
        val ack = readU32(data, ipHdr + 8)
        val payLen = totalLen - ipHdr - tcpHdrLen

        when {
            isSyn -> {
                Log.i(TAG, "TCP SYN ${ipStrFromInt(dstIp)}:$dstPort")
                val session = TcpSession(srcIp, srcPort, dstIp, dstPort, seq)
                sessions[key] = session
                thread(name = "SOC-$srcPort") { session.run() }
            }
            (flags and 0x04) != 0 -> sessions.remove(key)?.close()
            (flags and 0x01) != 0 -> sessions[key]?.handleFin(seq, ack)
            else -> sessions[key]?.let { s -> s.handleData(data, ipHdr, tcpHdrLen, payLen, seq, ack, flags) }
        }
    }

    /**
     * ★ v6: UDP 53 → DNS-over-TCP عبر SOCKS5
     * باقي UDP → direct (protect)
     */
    private fun onUdp(data: ByteArray, ipHdr: Int, totalLen: Int) {
        if (data.size < ipHdr + 8) return
        val srcPort = u16(data, ipHdr)
        val dstPort = u16(data, ipHdr + 2)
        val udpLen = u16(data, ipHdr + 4)
        val payOff = ipHdr + 8
        val payLen = minOf(udpLen - 8, data.size - payOff)
        if (payLen <= 0) return
        val dstIp = ipStr(data, 16)
        val srcIpInt = readI32(data, 12)
        val dstIpInt = readI32(data, 16)

        if (dstPort == DNS_PORT) {
            Log.i(TAG, "DNS query $dstIp:$dstPort (${payLen}B) → DoT")
            thread(name = "DNS-$srcPort") {
                handleDnsOverTcp(data, payOff, payLen, srcIpInt, dstIpInt, srcPort, dstPort, dstIp)
            }
            return
        }

        thread(name = "UDP-$srcPort") {
            try {
                val sock = DatagramSocket()
                protect(sock)
                sock.soTimeout = UDP_TIMEOUT_MS
                sock.send(DatagramPacket(data.copyOfRange(payOff, payOff + payLen), payLen,
                    InetAddress.getByName(dstIp), dstPort))
                val rbuf = ByteArray(4096)
                val rp = DatagramPacket(rbuf, rbuf.size)
                sock.receive(rp)
                sock.close()
                if (rp.length > 0) {
                    val out = buildUdpPacket(srcIpInt, dstIpInt, srcPort.toShort(), dstPort.toShort(),
                        rp.data, rp.offset, rp.length)
                    writeTun(out)
                }
            } catch (_: Exception) {}
        }
    }

    /**
     * ★ DNS-over-TCP: UDP DNS → 2-byte length prefix + TCP → SOCKS5 → SSH
     */
    private fun handleDnsOverTcp(
        data: ByteArray, payOff: Int, payLen: Int,
        srcIpInt: Int, dstIpInt: Int, srcPort: Int, dstPort: Int, dstIp: String
    ) {
        var socks: Socket? = null
        try {
            socks = Socket()
            protect(socks)
            socks.connect(InetSocketAddress(socksHost, socksPort), 3000)
            socks.soTimeout = TCP_DNS_TIMEOUT_MS
            val out = socks.getOutputStream()
            val inp = socks.getInputStream()

            out.write(byteArrayOf(0x05, 0x01, 0x00)); out.flush()
            val gbuf = ByteArray(2); readExact(inp, gbuf)
            if (gbuf[0] != 0x05.toByte() || gbuf[1] != 0x00.toByte()) return

            val dB = dstIp.toByteArray()
            val req = byteArrayOf(0x05, 0x01, 0x00, 0x03, dB.size.toByte()) +
                dB + byteArrayOf((dstPort shr 8).toByte(), dstPort.toByte())
            out.write(req); out.flush()

            val rbuf = ByteArray(256); val rn = inp.read(rbuf)
            if (rn < 4 || rbuf[0] != 0x05.toByte() || rbuf[1] != 0x00.toByte()) return

            val dnsQuery = data.copyOfRange(payOff, payOff + payLen)
            val tcpQuery = ByteArray(2 + dnsQuery.size)
            tcpQuery[0] = ((dnsQuery.size shr 8) and 0xFF).toByte()
            tcpQuery[1] = (dnsQuery.size and 0xFF).toByte()
            System.arraycopy(dnsQuery, 0, tcpQuery, 2, dnsQuery.size)
            out.write(tcpQuery); out.flush()

            val lenBuf = ByteArray(2); readExact(inp, lenBuf)
            val respLen = ((lenBuf[0].toInt() and 0xFF) shl 8) or (lenBuf[1].toInt() and 0xFF)
            if (respLen <= 0 || respLen > 4096) return
            val respBuf = ByteArray(respLen); readExact(inp, respBuf)

            val udpResponse = buildUdpPacket(srcIpInt, dstIpInt, srcPort.toShort(), dstPort.toShort(),
                respBuf, 0, respLen)
            writeTun(udpResponse)
            Log.i(TAG, "DoT: ✅ ${respLen}B from $dstIp")
        } catch (e: Exception) {
            Log.w(TAG, "DoT: $dstIp error: ${e.message}")
        } finally {
            try { socks?.close() } catch (_: Exception) {}
        }
    }

    inner class TcpSession(
        val srcIp: Int, val srcPort: Int,
        val dstIp: Int, val dstPort: Int,
        synSeq: Long
    ) {
        @Volatile private var closed = false
        private var state = 0
        private var srvSeq = (Math.random() * 0xFFFFFFFFL).toLong() and 0xFFFFFFFFL
        private var srvAck = (synSeq + 1) and 0xFFFFFFFFL
        private var socks: Socket? = null
        private var socksOut: java.io.OutputStream? = null
        private var socksIn: java.io.InputStream? = null

        fun run() {
            val dstStr = ipStrFromInt(dstIp)
            try {
                val s = Socket()
                protect(s)
                s.connect(InetSocketAddress(socksHost, socksPort), 3000)
                s.tcpNoDelay = true
                socks = s; socksOut = s.getOutputStream(); socksIn = s.getInputStream()

                socksOut!!.write(byteArrayOf(0x05, 0x01, 0x00)); socksOut!!.flush()
                val gbuf = ByteArray(2); readExact(socksIn!!, gbuf)
                if (gbuf[0] != 0x05.toByte() || gbuf[1] != 0x00.toByte()) return

                val dB = dstStr.toByteArray()
                socksOut!!.write(byteArrayOf(0x05, 0x01, 0x00, 0x03, dB.size.toByte()) +
                    dB + byteArrayOf((dstPort shr 8).toByte(), dstPort.toByte())); socksOut!!.flush()

                val rbuf = ByteArray(256); val rn = socksIn!!.read(rbuf)
                if (rn < 4 || rbuf[0] != 0x05.toByte() || rbuf[1] != 0x00.toByte()) return

                val synAck = buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(),
                    srvSeq, srvAck, 0x12, 0, includeMss = true)
                writeTun(synAck)
                srvSeq = (srvSeq + 1) and 0xFFFFFFFFL
                Log.i(TAG, "SYN-ACK $dstStr:$dstPort")

                readSocksLoop()
            } catch (e: Exception) {
                Log.e(TAG, "Session $srcPort -> $dstStr:$dstPort error: ${e.message}")
            } finally { close() }
        }

        fun handleData(data: ByteArray, ipHdr: Int, tcpHdrLen: Int, payLen: Int,
                       seq: Long, ack: Long, flags: Int) {
            if (closed || socksOut == null) return
            if (state == 0 && (flags and 0x10) != 0 && payLen == 0) { state = 1; return }
            if (payLen > 0) {
                if (seq != srvAck) {
                    writeTun(buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(),
                        srvSeq, srvAck, 0x10, 0))
                    return
                }
                try {
                    socksOut!!.write(data, ipHdr + tcpHdrLen, payLen)
                    socksOut!!.flush()
                    srvAck = (srvAck + payLen) and 0xFFFFFFFFL
                    writeTun(buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(),
                        srvSeq, srvAck, 0x10, 0))
                } catch (_: Exception) { close() }
            }
        }

        fun handleFin(seq: Long, ack: Long) {
            if (seq == srvAck) srvAck = (srvAck + 1) and 0xFFFFFFFFL
            writeTun(buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(), srvSeq, srvAck, 0x10, 0))
            try { socksOut?.close() } catch (_: Exception) {}
            writeTun(buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(), srvSeq, srvAck, 0x01, 0))
            srvSeq = (srvSeq + 1) and 0xFFFFFFFFL
            close()
        }

        private fun readSocksLoop() {
            val buf = ByteArray(65535)
            while (running && !closed) {
                try {
                    val n = socksIn!!.read(buf)
                    if (n <= 0) {
                        writeTun(buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(),
                            srvSeq, srvAck, 0x01, 0))
                        srvSeq = (srvSeq + 1) and 0xFFFFFFFFL
                        break
                    }
                    writeTun(buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(),
                        srvSeq, srvAck, 0x18, n, buf))
                    srvSeq = (srvSeq + n) and 0xFFFFFFFFL
                } catch (_: Exception) { break }
            }
        }

        fun close() {
            if (closed) return; closed = true
            try { socks?.close() } catch (_: Exception) {}
            sessions.remove(srcIp xor srcPort)
        }

        private fun readExact(inp: java.io.InputStream, buf: ByteArray) {
            var off = 0
            while (off < buf.size) { val n = inp.read(buf, off, buf.size - off)
                if (n <= 0) throw Exception("EOF"); off += n }
        }
    }

    private fun buildTcp(srcIp: Int, dstIp: Int, srcP: Short, dstP: Short,
                         seq: Long, ack: Long, flags: Int, dataLen: Int,
                         payload: ByteArray? = null, includeMss: Boolean = false): ByteArray {
        val opts = if (includeMss) 4 else 0; val tcpHdrLen = 20 + opts
        val total = 20 + tcpHdrLen + dataLen; val p = ByteArray(total)
        p[0] = 0x45; u16w(p, 2, total); p[6] = 0x40.toByte(); p[8] = 64.toByte(); p[9] = 6
        i32w(p, 12, srcIp); i32w(p, 16, dstIp)
        u16w(p, 20, srcP.toInt() and 0xFFFF); u16w(p, 22, dstP.toInt() and 0xFFFF)
        u32w(p, 24, seq); u32w(p, 28, ack)
        p[32] = ((tcpHdrLen / 4) shl 4).toByte(); p[33] = flags.toByte()
        u16w(p, 34, 65535); u16w(p, 36, 0); u16w(p, 38, 0)
        if (includeMss) { p[40] = 2; p[41] = 4; u16w(p, 42, 1460) }
        if (dataLen > 0 && payload != null) System.arraycopy(payload, 0, p, 20 + tcpHdrLen, dataLen)
        u16w(p, 10, 0); u16w(p, 10, ipCsum(p, 0, 20))
        u16w(p, 36, tcpCsum(p, 20, tcpHdrLen + dataLen, p, 12, p, 16))
        return p
    }

    private fun buildUdpPacket(srcIp: Int, dstIp: Int, srcP: Short, dstP: Short,
                               data: ByteArray, dataOff: Int, dataLen: Int): ByteArray {
        val total = 20 + 8 + dataLen; val p = ByteArray(total)
        p[0] = 0x45; u16w(p, 2, total); p[6] = 0x40.toByte(); p[8] = 64.toByte(); p[9] = 17
        i32w(p, 12, srcIp); i32w(p, 16, dstIp)
        u16w(p, 20, srcP.toInt() and 0xFFFF); u16w(p, 22, dstP.toInt() and 0xFFFF)
        u16w(p, 24, 8 + dataLen); u16w(p, 26, 0)
        System.arraycopy(data, dataOff, p, 28, dataLen)
        u16w(p, 10, ipCsum(p, 0, 20)); u16w(p, 26, udpCsum(p, 20, 8 + dataLen, p, 12, p, 16))
        return p
    }

    private fun writeTun(data: ByteArray) {
        if (!running) return
        try { synchronized(tunOutput!!) { tunOutput!!.write(data); tunOutput!!.flush() } } catch (_: Exception) {}
    }

    private fun ipCsum(d: ByteArray, off: Int, len: Int): Int {
        var s = 0; var i = off
        while (i < off + len - 1) { s += ((d[i].toInt() and 0xFF) shl 8) or (d[i + 1].toInt() and 0xFF); i += 2 }
        if (i < off + len) s += (d[i].toInt() and 0xFF) shl 8
        while (s > 0xFFFF) s = (s and 0xFFFF) + (s shr 16)
        return s.inv() and 0xFFFF
    }

    private fun tcpCsum(d: ByteArray, off: Int, len: Int, sa: ByteArray, so: Int, da: ByteArray, dO: Int): Int {
        val pl = 12 + len; val odd = pl % 2; val buf = ByteArray(if (odd != 0) pl + 1 else pl)
        System.arraycopy(sa, so, buf, 0, 4); System.arraycopy(da, dO, buf, 4, 4)
        buf[8] = 0; buf[9] = 6; u16w(buf, 10, len)
        System.arraycopy(d, off, buf, 12, len); var s = 0; var i = 0
        while (i < buf.size - 1) { s += ((buf[i].toInt() and 0xFF) shl 8) or (buf[i + 1].toInt() and 0xFF); i += 2 }
        while (s > 0xFFFF) s = (s and 0xFFFF) + (s shr 16)
        return s.inv() and 0xFFFF
    }

    private fun udpCsum(d: ByteArray, off: Int, len: Int, sa: ByteArray, so: Int, da: ByteArray, dO: Int): Int {
        val pl = 12 + len; val odd = pl % 2; val buf = ByteArray(if (odd != 0) pl + 1 else pl)
        System.arraycopy(sa, so, buf, 0, 4); System.arraycopy(da, dO, buf, 4, 4)
        buf[8] = 0; buf[9] = 17; u16w(buf, 10, len)
        System.arraycopy(d, off, buf, 12, len); var s = 0; var i = 0
        while (i < buf.size - 1) { s += ((buf[i].toInt() and 0xFF) shl 8) or (buf[i + 1].toInt() and 0xFF); i += 2 }
        while (s > 0xFFFF) s = (s and 0xFFFF) + (s shr 16)
        return if (s == 0) 0xFFFF else s.inv() and 0xFFFF
    }

    private fun readExact(inp: java.io.InputStream, buf: ByteArray) {
        var off = 0
        while (off < buf.size) { val n = inp.read(buf, off, buf.size - off)
            if (n <= 0) throw Exception("EOF"); off += n }
    }

    private fun u16(d: ByteArray, o: Int) = ((d[o].toInt() and 0xFF) shl 8) or (d[o + 1].toInt() and 0xFF)
    private fun u16w(d: ByteArray, o: Int, v: Int) { d[o] = ((v shr 8) and 0xFF).toByte(); d[o + 1] = (v and 0xFF).toByte() }
    private fun readU32(d: ByteArray, o: Int) = ((d[o].toLong() and 0xFF) shl 24) or ((d[o + 1].toLong() and 0xFF) shl 16) or ((d[o + 2].toLong() and 0xFF) shl 8) or (d[o + 3].toLong() and 0xFF)
    private fun u32w(d: ByteArray, o: Int, v: Long) { d[o] = ((v shr 24) and 0xFF).toByte(); d[o + 1] = ((v shr 16) and 0xFF).toByte(); d[o + 2] = ((v shr 8) and 0xFF).toByte(); d[o + 3] = (v and 0xFF).toByte() }
    private fun readI32(d: ByteArray, o: Int) = ((d[o].toInt() and 0xFF) shl 24) or ((d[o + 1].toInt() and 0xFF) shl 16) or ((d[o + 2].toInt() and 0xFF) shl 8) or (d[o + 3].toInt() and 0xFF)
    private fun i32w(d: ByteArray, o: Int, v: Int) { d[o] = ((v shr 24) and 0xFF).toByte(); d[o + 1] = ((v shr 16) and 0xFF).toByte(); d[o + 2] = ((v shr 8) and 0xFF).toByte(); d[o + 3] = (v and 0xFF).toByte() }
    private fun ipStr(d: ByteArray, o: Int) = "${d[o].toInt() and 0xFF}.${d[o + 1].toInt() and 0xFF}.${d[o + 2].toInt() and 0xFF}.${d[o + 3].toInt() and 0xFF}"
    private fun ipStrFromInt(v: Int) = "${(v shr 24) and 0xFF}.${(v shr 16) and 0xFF}.${(v shr 8) and 0xFF}.${v and 0xFF}"

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val c = NotificationChannel(CHANNEL_ID, "WaledNet VPN", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(NotificationManager::class.java)).createNotificationChannel(c)
        }
    }

    private fun buildNotification(text: String): Notification {
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        return b.setSmallIcon(android.R.drawable.ic_lock_lock).setContentTitle("WaledNet")
            .setContentText(text).setOngoing(true).setPriority(Notification.PRIORITY_MIN)
            .setCategory(Notification.CATEGORY_SERVICE).build()
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping VPN"); running = false
        try { stopForeground(true) } catch (_: Exception) {}
        cleanup(); try { stopSelf() } catch (_: Exception) {}
    }

    private fun cleanup() {
        sessions.values.forEach { it.close() }; sessions.clear()
        try { tunInput?.close() } catch (_: Exception) {}
        try { tunOutput?.close() } catch (_: Exception) {}
        try { tunFd?.close() } catch (_: Exception) {}
        tunInput = null; tunOutput = null; tunFd = null
    }
}
