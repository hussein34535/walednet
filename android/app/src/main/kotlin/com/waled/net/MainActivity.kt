package com.waled.net

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.waled.net/vpn_tunnel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "v2ray_notification_channel"
            val channelName = "V2Ray VPN Service"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(channelId, channelName, importance)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTunnel" -> {
                    val socksPort = call.argument<Int>("socksPort") ?: 10808
                    val socksHost = call.argument<String>("socksHost") ?: "127.0.0.1"
                    val dnsServer = call.argument<String>("dnsServer") ?: "1.1.1.1"
                    val intent = Intent(this, WaledVpnService::class.java).apply {
                        action = WaledVpnService.ACTION_START
                        putExtra(WaledVpnService.EXTRA_SOCKS_PORT, socksPort)
                        putExtra(WaledVpnService.EXTRA_SOCKS_HOST, socksHost)
                        putExtra(WaledVpnService.EXTRA_DNS_SERVER, dnsServer)
                    }
                    startService(intent)
                    result.success(true)
                }
                "stopTunnel" -> {
                    val intent = Intent(this, WaledVpnService::class.java).apply {
                        action = WaledVpnService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
