package com.waled.net

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import com.v2ray.ang.service.TProxyService
import java.io.File

class WaledVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.waled.net.START"
        const val ACTION_STOP = "com.waled.net.STOP"
        const val EXTRA_SOCKS_PORT = "socks_port"
        const val EXTRA_SOCKS_HOST = "socks_host"
        const val EXTRA_DNS_SERVER = "dns_server"

        private const val TAG = "WaledVpn"
        private const val CHANNEL_ID = "waled_vpn"
    }

    private var tunFd: ParcelFileDescriptor? = null
    @Volatile private var running = false
    private var socksHost = "127.0.0.1"
    private var socksPort = 10808
    private var dnsServer = "1.1.1.1"
    private var configFile: File? = null

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

            configFile = writeHevConfig(socksHost, socksPort)
            if (configFile == null) { Log.e(TAG, "Failed to write config"); stopVpn(); return }

            running = true
            TProxyService.startService(configFile!!.absolutePath, tunFd!!.fd)
            Log.i(TAG, "hev-socks5-tunnel started → $socksHost:$socksPort")
            startForeground(1, buildNotification("WaledNet VPN متصل"))
        } catch (e: Exception) {
            Log.e(TAG, "startVpn failed: ${e.message}")
            stopVpn()
        }
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping VPN")
        running = false
        try { TProxyService.stopService() } catch (e: Exception) { Log.e(TAG, "stopService: ${e.message}") }
        try { stopForeground(true) } catch (_: Exception) {}
        try { tunFd?.close() } catch (_: Exception) {}
        tunFd = null
        try { configFile?.delete() } catch (_: Exception) {}
        try { stopSelf() } catch (_: Exception) {}
    }

    private fun writeHevConfig(host: String, port: Int): File? {
        return try {
            val dir = filesDir
            val file = File(dir, "hev-config.yaml")
            file.writeText(
                "socks5:\n" +
                "  address: \"$host\"\n" +
                "  port: $port\n" +
                "misc:\n" +
                "  log-level: \"info\"\n"
            )
            Log.i(TAG, "Config written: ${file.absolutePath}")
            file
        } catch (e: Exception) {
            Log.e(TAG, "writeHevConfig: ${e.message}")
            null
        }
    }

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
}
