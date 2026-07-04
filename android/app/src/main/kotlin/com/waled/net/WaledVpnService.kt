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
        const val EXTRA_TUN_MTU = "tun_mtu"
        const val EXTRA_TUN_ADDRESS = "tun_address"
        const val EXTRA_DNS_SERVER = "dns_server"

        private const val TAG = "WaledVpn"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "waled_vpn"
    }

    private var tunFd: ParcelFileDescriptor? = null
    @Volatile private var running = false
    private var socksHost = "127.0.0.1"
    private var socksPort = 10808

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand: action=${intent?.action}")

        createChannel()
        try {
            startForeground(NOTIFICATION_ID, buildNotification("جارٍ إعداد الاتصال..."))
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
                val mtu = intent.getIntExtra(EXTRA_TUN_MTU, 1500)
                val tunAddr = intent.getStringExtra(EXTRA_TUN_ADDRESS) ?: "10.0.0.1"
                val dns = intent.getStringExtra(EXTRA_DNS_SERVER) ?: "1.1.1.1"

                startVpn(mtu, tunAddr, dns)
            }
            ACTION_STOP -> stopVpn()
        }
        return START_STICKY
    }

    override fun onRevoke() {
        Log.w(TAG, "onRevoke called by system")
        stopVpn()
    }

    private fun startVpn(mtu: Int, tunAddress: String, dnsServer: String) {
        try {
            val builder = Builder()
            builder.setSession("WaledNet")
            builder.setMtu(mtu)
            builder.addAddress(tunAddress, 24)
            builder.addRoute("0.0.0.0", 0)
            builder.addRoute("::", 0)
            builder.addDnsServer(dnsServer)
            builder.addDnsServer("8.8.8.8")
            builder.addDnsServer("1.1.1.1")
            builder.addRoute("1.1.1.1", 32)
            builder.addRoute("8.8.8.8", 32)
            builder.addDisallowedApplication(packageName)

            tunFd = builder.establish()
            if (tunFd == null) {
                Log.e(TAG, "TUN fd is null")
                stopVpn()
                return
            }
            Log.i(TAG, "TUN established, fd=${tunFd!!.fd}")

            val configFile = File(filesDir, "hev-config.yaml")
            val yaml = buildYamlConfig(mtu, tunAddress, dnsServer)
            configFile.writeText(yaml)
            Log.i(TAG, "YAML config written")
            Log.d(TAG, "YAML:\n$yaml")

            running = true
            TProxyService.startService(configFile.absolutePath, tunFd!!.fd)
            Log.i(TAG, "hev-socks5-tunnel started -> $socksHost:$socksPort")

            startForeground(NOTIFICATION_ID, buildNotification("WaledNet VPN متصل"))

            Thread {
                while (running) {
                    try {
                        Thread.sleep(30000)
                        if (!running) break
                        val stats = TProxyService.getStats()
                        if (stats != null && stats.size >= 4) {
                            Log.i(TAG, "TX: ${stats[0]} pkts / ${stats[1]} bytes | RX: ${stats[2]} pkts / ${stats[3]} bytes")
                        }
                    } catch (_: InterruptedException) { break }
                    catch (e: Exception) { Log.w(TAG, "Stats error: ${e.message}") }
                }
            }.start()

        } catch (e: Exception) {
            Log.e(TAG, "startVpn failed: ${e.message}", e)
            stopVpn()
        }
    }

    private fun buildYamlConfig(mtu: Int, tunAddress: String, dnsServer: String): String {
        return """
            tunnel:
              mtu: $mtu
              ipv4: $tunAddress
              ipv6: null

            socks5:
              port: $socksPort
              address: $socksHost
              username: null
              password: null
              udp: udp

            misc:
              task-stack-size: 4194304
              connect-timeout: 5000
              read-timeout: 30000
              udp-timeout: 30
              log-level: info
              pid-file: null
              resource-limit: 65535
        """.trimIndent()
    }

    private fun stopVpn() {
        Log.i(TAG, "Stopping VPN")
        running = false
        try { TProxyService.stopService() } catch (e: Exception) { Log.w(TAG, "Stop hev error: ${e.message}") }
        try { tunFd?.close() } catch (_: Exception) {}
        tunFd = null
        try { stopForeground(true) } catch (_: Exception) {}
        try { stopSelf() } catch (_: Exception) {}
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "WaledNet VPN", NotificationManager.IMPORTANCE_LOW).apply {
                description = "VPN connection notifications"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, CHANNEL_ID) else Notification.Builder(this)
        return builder
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("WaledNet VPN")
            .setContentText(text)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_MIN)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }
}
