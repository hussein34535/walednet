package com.waled.net

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.util.Log
import java.io.FileDescriptor
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

class WaledVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.waled.net.START"
        const val ACTION_STOP = "com.waled.net.STOP"
        const val EXTRA_SOCKS_PORT = "socks_port"
    }

    private val TAG = "WaledVpn"
    private var tunFd: ParcelFileDescriptor? = null
    private var tunDesc: FileDescriptor? = null
    @Volatile private var running = false
    private var socksPort = 10808
    private val sessions = ConcurrentHashMap<Int, TcpSession>()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                socksPort = intent.getIntExtra(EXTRA_SOCKS_PORT, 10808)
                startVpn()
            }
            ACTION_STOP -> stopVpn()
        }
        return START_STICKY
    }

    override fun onRevoke() {
        Log.w(TAG, "onRevoke called by system")
        stopVpn()
    }

    private fun startVpn() {
        val builder = Builder()
        builder.setSession("WaledNet")
        builder.setMtu(1500)
        builder.addAddress("10.0.0.1", 24)
        builder.addRoute("0.0.0.0", 0)
        builder.addRoute("::", 0)
        builder.addDnsServer("1.1.1.1")
        builder.addDnsServer("8.8.8.8")
        builder.addDisallowedApplication(packageName)

        try {
            tunFd = builder.establish()
            Log.i(TAG, "TUN interface established")
        } catch (e: Exception) {
            Log.e(TAG, "TUN establish failed: $e")
            stopVpn()
            return
        }
        if (tunFd == null) { Log.e(TAG, "TUN fd is null"); stopVpn(); return }

        tunDesc = tunFd!!.fileDescriptor
        Log.i(TAG, "TUN fd ready fd=${tunFd!!.getFd()}")

        createChannel()
        startForeground(1, buildNotif())

        running = true
        Log.i(TAG, "VPN started, SOCKS target: 127.0.0.1:$socksPort")
        thread(name = "TunRead") { readLoop() }
    }

    private fun readLoop() {
        val buf = ByteArray(65535)
        var total = 0L
        while (running) {
            try {
                val n = Os.read(tunDesc!!, buf, 0, buf.size)
                if (n > 0) {
                    total += n
                    processPacket(buf.copyOfRange(0, n))
                } else {
                    Thread.sleep(10)
                }
            } catch (e: android.system.ErrnoException) {
                if (e.errno == android.system.OsConstants.EAGAIN) {
                    Thread.sleep(10)
                    continue
                }
                Log.e(TAG, "TUN read error: errno=${e.errno} ${e.message}")
                break
            } catch (e: Exception) {
                Log.e(TAG, "TUN read error: ${e.message}")
                break
            }
        }
        Log.i(TAG, "TUN reader stopped, total bytes read: $total")
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
        val len = minOf(totalLen, data.size)
        when (proto) {
            6 -> onTcp(data, ihl, len)
            17 -> onUdp(data, ihl, len)
        }
    }

    private fun onTcp(data: ByteArray, ipHdr: Int, totalLen: Int) {
        if (data.size < ipHdr + 20) return
        val tcpHdr = ((data[ipHdr + 12].toInt() shr 4) and 0x0F) * 4
        if (tcpHdr < 20) return
        val flags = data[ipHdr + 13].toInt() and 0xFF
        val srcPort = u16(data, ipHdr)
        val dstPort = u16(data, ipHdr + 2)
        val srcIp = readI32(data, 12)
        val dstIp = readI32(data, 16)
        val isSyn = (flags and 0x02) != 0 && (flags and 0x10) == 0
        val isRst = (flags and 0x04) != 0
        val isFin = (flags and 0x01) != 0
        val key = srcIp xor srcPort
        val dstStr = ipStrFromInt(dstIp)

        when {
            isSyn && !isRst -> {
                Log.i(TAG, "TCP SYN $dstStr:$dstPort (session size=${sessions.size})")
                val seq = readU32(data, ipHdr + 4)
                val session = TcpSession(srcIp, srcPort, dstIp, dstPort, seq)
                sessions[key] = session
                thread(name = "SOC-$srcPort") { session.run() }
            }
            isRst || isFin -> {
                Log.i(TAG, "TCP RST/FIN $dstStr:$dstPort")
                sessions.remove(key)?.close()
            }
            else -> {
                sessions[key]?.let { s -> s.handleData(data, ipHdr, tcpHdr, totalLen, flags) }
                    ?: Log.w(TAG, "No session for ${ipStrFromInt(srcIp)}:$srcPort -> $dstStr:$dstPort")
            }
        }
    }

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

        thread(name = "UDP") {
            try {
                val sock = DatagramSocket()
                protect(sock)
                val p = DatagramPacket(data.copyOfRange(payOff, payOff + payLen), payLen,
                    InetAddress.getByName(dstIp), dstPort)
                sock.send(p)
                val rbuf = ByteArray(4096)
                sock.soTimeout = 5000
                val rp = DatagramPacket(rbuf, rbuf.size)
                sock.receive(rp)
                sock.close()
                val rlen = rp.length
                if (rlen <= 0) return@thread

                val out = buildUdpPacket(srcIpInt, dstIpInt, srcPort.toShort(), dstPort.toShort(),
                    rp.data, rp.offset, rlen)
                writeTun(out)
            } catch (_: Exception) {}
        }
    }

    inner class TcpSession(
        val srcIp: Int, val srcPort: Int,
        val dstIp: Int, val dstPort: Int,
        synSeq: Long
    ) {
        @Volatile private var closed = false
        private var state = 0
        private var appSeq = synSeq
        private var appAck = 0L
        private var srvSeq = (Math.random() * 0xFFFFFFFFL).toLong() and 0xFFFFFFFFL
        private var srvAck = (synSeq + 1) and 0xFFFFFFFFL
        private var socks: Socket? = null
        private var socksOut: java.io.OutputStream? = null
        private var socksIn: java.io.InputStream? = null

        fun run() {
            val dstStr = ipStrFromInt(dstIp)
            Log.i(TAG, "Session $srcPort -> $dstStr:$dstPort starting")
            try {
                val s = Socket()
                protect(s)
                s.connect(InetSocketAddress("127.0.0.1", socksPort), 3000)
                socks = s; socksOut = s.getOutputStream(); socksIn = s.getInputStream()
                Log.i(TAG, "Session $srcPort -> $dstStr:$dstPort connected to SOCKS5")

                // SOCKS5 greeting
                socksOut!!.write(byteArrayOf(0x05, 0x01, 0x00)); socksOut!!.flush()
                val gbuf = ByteArray(2); readExact(gbuf)
                if (gbuf[0] != 0x05.toByte() || gbuf[1] != 0x00.toByte()) {
                    Log.e(TAG, "SOCKS5 greeting failed for $dstStr:$dstPort: ${gbuf[1]}")
                    return
                }

                // SOCKS5 CONNECT
                val dB = dstStr.toByteArray()
                val req = byteArrayOf(0x05, 0x01, 0x00, 0x03, dB.size.toByte()) +
                    dB + byteArrayOf((dstPort shr 8).toByte(), dstPort.toByte())
                socksOut!!.write(req); socksOut!!.flush()

                // Read SOCKS5 response (variable length)
                val rbuf = ByteArray(256); val rn = socksIn!!.read(rbuf)
                if (rn < 4 || rbuf[0] != 0x05.toByte() || rbuf[1] != 0x00.toByte()) {
                    val code = if (rn >= 2) rbuf[1].toInt() and 0xFF else -1
                    Log.e(TAG, "SOCKS5 CONNECT failed for $dstStr:$dstPort: code=$code")
                    return
                }
                Log.i(TAG, "SOCKS5 CONNECT OK $dstStr:$dstPort")

                // Connection established, send SYN-ACK to app
                state = 1
                val synAck = buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(),
                    srvSeq, srvAck, 0x12, 0)
                writeTun(synAck)
                srvSeq = (srvSeq + 1) and 0xFFFFFFFFL
                Log.i(TAG, "SYN-ACK sent for $dstStr:$dstPort")

                // Read SOCKS5 response data and send to TUN
                readSocksLoop()
            } catch (e: Exception) {
                Log.e(TAG, "Session $srcPort -> $dstStr:$dstPort error: ${e.message}")
            }
            finally { close() }
        }

        private fun readSocksLoop() {
            val buf = ByteArray(65535)
            var total = 0L
            while (running && !closed) {
                try {
                    val n = socksIn!!.read(buf)
                    if (n <= 0) break
                    total += n
                    val out = buildTcp(dstIp, srcIp, dstPort.toShort(), srcPort.toShort(),
                        srvSeq, appSeq and 0xFFFFFFFFL, 0x18, n, buf)
                    writeTun(out)
                    srvSeq = (srvSeq + n) and 0xFFFFFFFFL
                } catch (_: Exception) { break }
            }
            if (total > 0) Log.i(TAG, "SOCKS->TUN relay done for ${ipStrFromInt(dstIp)}:$dstPort, $total bytes")
        }

        fun handleData(data: ByteArray, ipHdr: Int, tcpHdr: Int, totalLen: Int, flags: Int) {
            if (closed || socksOut == null) return
            val payLen = totalLen - ipHdr - tcpHdr
            val seq = readU32(data, ipHdr + 4)
            val ack = readU32(data, ipHdr + 8)

            // Update tracked seq/ack from app
            if (state == 0 && (flags and 0x10) != 0) {
                state = 1
                appSeq = (seq) and 0xFFFFFFFFL
                appAck = ack
            }

            if (payLen > 0) {
                try {
                    socksOut!!.write(data, ipHdr + tcpHdr, payLen)
                    socksOut!!.flush()
                    appSeq = (seq + payLen) and 0xFFFFFFFFL
                    appAck = ack
                } catch (e: Exception) {
                    Log.e(TAG, "TUN->SOCKS write error for ${ipStrFromInt(dstIp)}:$dstPort: ${e.message}")
                    close()
                }
            }
        }

        fun close() {
            if (closed) return
            closed = true
            Log.i(TAG, "Closing session ${ipStrFromInt(srcIp)}:$srcPort -> ${ipStrFromInt(dstIp)}:$dstPort")
            try { socks?.close() } catch (_: Exception) {}
            sessions.remove(srcIp xor srcPort)
        }

        private fun readExact(buf: ByteArray) {
            var off = 0
            while (off < buf.size) {
                val n = socksIn!!.read(buf, off, buf.size - off)
                if (n <= 0) throw Exception("EOF")
                off += n
            }
        }

    }

    private fun buildTcp(srcIp: Int, dstIp: Int, srcP: Short, dstP: Short,
                         seq: Long, ack: Long, flags: Int, dataLen: Int, payload: ByteArray? = null): ByteArray {
        val hdrLen = 20
        val total = 20 + hdrLen + dataLen
        val p = ByteArray(total)

        // IP header
        p[0] = 0x45
        u16w(p, 2, total)
        p[6] = 0x40.toByte()
        p[8] = 64.toByte()
        p[9] = 6
        i32w(p, 12, srcIp)
        i32w(p, 16, dstIp)

        // TCP header
        u16w(p, 20, srcP.toInt() and 0xFFFF)
        u16w(p, 22, dstP.toInt() and 0xFFFF)
        u32w(p, 24, seq)
        u32w(p, 28, ack)
        p[32] = 0x50.toByte()
        p[33] = flags.toByte()
        u16w(p, 34, 65535)
        u16w(p, 36, 0)
        u16w(p, 38, 0)

        // Payload
        if (dataLen > 0 && payload != null) {
            System.arraycopy(payload, 0, p, 40, dataLen)
        }

        // IP checksum
        u16w(p, 10, 0)
        u16w(p, 10, ipCsum(p, 0, 20))

        // TCP checksum
        u16w(p, 36, tcpCsum(p, 20, hdrLen + dataLen, p, 12, p, 16))

        return p
    }

    private fun buildUdpPacket(srcIp: Int, dstIp: Int, srcP: Short, dstP: Short,
                                 data: ByteArray, dataOff: Int, dataLen: Int): ByteArray {
        val total = 20 + 8 + dataLen
        val p = ByteArray(total)
        p[0] = 0x45
        u16w(p, 2, total)
        p[6] = 0x40.toByte()
        p[8] = 64.toByte()
        p[9] = 17
        i32w(p, 12, srcIp)
        i32w(p, 16, dstIp)
        u16w(p, 20, srcP.toInt() and 0xFFFF)
        u16w(p, 22, dstP.toInt() and 0xFFFF)
        u16w(p, 24, 8 + dataLen)
        u16w(p, 26, 0)
        System.arraycopy(data, dataOff, p, 28, dataLen)

        u16w(p, 10, ipCsum(p, 0, 20))
        u16w(p, 26, udpCsum(p, 20, 8 + dataLen, p, 12, p, 16))
        return p
    }

    private fun writeTun(data: ByteArray) {
        if (!running) return
        try {
            synchronized(tunDesc!!) { Os.write(tunDesc!!, data, 0, data.size) }
        } catch (e: Exception) {
            Log.w(TAG, "TUN write error: ${e.message}")
        }
    }

    private fun ipCsum(d: ByteArray, off: Int, len: Int): Int {
        var s = 0
        var i = off
        while (i < off + len - 1) { s += ((d[i].toInt() and 0xFF) shl 8) or (d[i + 1].toInt() and 0xFF); i += 2 }
        if (i < off + len) s += (d[i].toInt() and 0xFF) shl 8
        while (s > 0xFFFF) s = (s and 0xFFFF) + (s shr 16)
        return s.inv() and 0xFFFF
    }

    private fun tcpCsum(d: ByteArray, off: Int, len: Int, sa: ByteArray, so: Int, da: ByteArray, dO: Int): Int {
        val pl = 12 + len; val odd = pl % 2
        val buf = ByteArray(if (odd != 0) pl + 1 else pl)
        System.arraycopy(sa, so, buf, 0, 4)
        System.arraycopy(da, dO, buf, 4, 4)
        buf[8] = 0; buf[9] = 6; u16w(buf, 10, len)
        System.arraycopy(d, off, buf, 12, len)
        var s = 0
        var i = 0
        while (i < buf.size - 1) { s += ((buf[i].toInt() and 0xFF) shl 8) or (buf[i + 1].toInt() and 0xFF); i += 2 }
        while (s > 0xFFFF) s = (s and 0xFFFF) + (s shr 16)
        return s.inv() and 0xFFFF
    }

    private fun udpCsum(d: ByteArray, off: Int, len: Int, sa: ByteArray, saOff: Int, da: ByteArray, daOff: Int): Int {
        val pl = 12 + len; val odd = pl % 2
        val buf = ByteArray(if (odd != 0) pl + 1 else pl)
        System.arraycopy(sa, saOff, buf, 0, 4)
        System.arraycopy(da, daOff, buf, 4, 4)
        buf[8] = 0; buf[9] = 17; u16w(buf, 10, len)
        System.arraycopy(d, off, buf, 12, len)
        var s = 0
        var i = 0
        while (i < buf.size - 1) { s += ((buf[i].toInt() and 0xFF) shl 8) or (buf[i + 1].toInt() and 0xFF); i += 2 }
        while (s > 0xFFFF) s = (s and 0xFFFF) + (s shr 16)
        return if (s == 0) 0xFFFF else s.inv() and 0xFFFF
    }

    private fun u16(d: ByteArray, o: Int): Int = ((d[o].toInt() and 0xFF) shl 8) or (d[o + 1].toInt() and 0xFF)
    private fun u16w(d: ByteArray, o: Int, v: Int) { d[o] = ((v shr 8) and 0xFF).toByte(); d[o + 1] = (v and 0xFF).toByte() }
    private fun readU32(d: ByteArray, o: Int): Long = ((d[o].toLong() and 0xFF) shl 24) or ((d[o + 1].toLong() and 0xFF) shl 16) or ((d[o + 2].toLong() and 0xFF) shl 8) or (d[o + 3].toLong() and 0xFF)
    private fun u32w(d: ByteArray, o: Int, v: Long) { d[o] = ((v shr 24) and 0xFF).toByte(); d[o + 1] = ((v shr 16) and 0xFF).toByte(); d[o + 2] = ((v shr 8) and 0xFF).toByte(); d[o + 3] = (v and 0xFF).toByte() }
    private fun readI32(d: ByteArray, o: Int): Int = ((d[o].toInt() and 0xFF) shl 24) or ((d[o + 1].toInt() and 0xFF) shl 16) or ((d[o + 2].toInt() and 0xFF) shl 8) or (d[o + 3].toInt() and 0xFF)
    private fun i32w(d: ByteArray, o: Int, v: Int) { d[o] = ((v shr 24) and 0xFF).toByte(); d[o + 1] = ((v shr 16) and 0xFF).toByte(); d[o + 2] = ((v shr 8) and 0xFF).toByte(); d[o + 3] = (v and 0xFF).toByte() }
    private fun ipStr(d: ByteArray, o: Int) = "${d[o].toInt() and 0xFF}.${d[o + 1].toInt() and 0xFF}.${d[o + 2].toInt() and 0xFF}.${d[o + 3].toInt() and 0xFF}"
    private fun ipStrFromInt(v: Int) = "${(v shr 24) and 0xFF}.${(v shr 16) and 0xFF}.${(v shr 8) and 0xFF}.${v and 0xFF}"

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val c = NotificationChannel("waled_vpn", "WaledNet VPN", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(NotificationManager::class.java)).createNotificationChannel(c)
        }
    }

    private fun buildNotif(): Notification {
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, "waled_vpn") else Notification.Builder(this)
        return b.setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("WaledNet")
            .setContentText("VPN active")
            .setOngoing(true).setPriority(Notification.PRIORITY_MIN).build()
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping VPN")
        running = false
        try { stopForeground(true) } catch (_: Exception) {}
        cleanup()
        try { stopSelf() } catch (_: Exception) {}
    }

    private fun cleanup() {
        Log.i(TAG, "Cleanup: closing ${sessions.size} sessions")
        sessions.values.forEach { it.close() }
        sessions.clear()
        try { tunFd?.close() } catch (_: Exception) {}
        tunDesc = null; tunFd = null
    }
}
