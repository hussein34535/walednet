package com.waled.net

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.nekohasekai.libbox.CommandClient
import io.nekohasekai.libbox.CommandClientHandler
import io.nekohasekai.libbox.CommandClientOptions
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.Notification as LibboxNotification
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.SetupOptions
import io.nekohasekai.libbox.StatusMessage
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.SystemProxyStatus
import java.io.File

class BoxService : Service() {

    companion object {
        private const val TAG = "WaledBox"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "waled_vpn"

        const val ACTION_START = "com.waled.net.START"
        const val ACTION_STOP = "com.waled.net.STOP"
        const val EXTRA_CONFIG = "config"

        @Volatile
        var instance: BoxService? = null
            private set

        @Volatile
        var lastStatus: String = "disconnected"
            private set

        @Volatile
        var lastUplink: Long = 0
            private set

        @Volatile
        var lastDownlink: Long = 0
            private set

        var statusListener: ((String) -> Unit)? = null
        var trafficListener: ((Long, Long) -> Unit)? = null
        var logListener: ((String) -> Unit)? = null
    }

    private var commandServer: CommandServer? = null
    private var commandClient: CommandClient? = null
    private var isRunning = false

    private val serverHandler = object : CommandServerHandler {
        override fun serviceStop() {
            Log.i(TAG, "serviceStop called by Go runtime")
            stopVPN()
        }

        override fun serviceReload() {
            Log.i(TAG, "serviceReload called by Go runtime")
        }

        override fun getSystemProxyStatus(): SystemProxyStatus {
            return SystemProxyStatus().apply {
                enabled = false
                available = false
            }
        }

        override fun setSystemProxyEnabled(enabled: Boolean) {
            Log.i(TAG, "setSystemProxyEnabled($enabled)")
        }

        override fun triggerNativeCrash() {
            Log.w(TAG, "triggerNativeCrash called")
        }

        override fun writeDebugMessage(message: String) {
            Log.d(TAG, "debug: $message")
        }

        override fun connectSSHAgent(): Int {
            return -1
        }
    }

    private val clientHandler = object : CommandClientHandler {
        override fun connected() {
            Log.i(TAG, "CommandClient connected")
        }

        override fun disconnected(message: String) {
            Log.i(TAG, "CommandClient disconnected: $message")
        }

        override fun writeStatus(status: StatusMessage) {
            val text = buildString {
                append("↑ ${Libbox.formatBitrate(status.uplink)}")
                append(" ↓ ${Libbox.formatBitrate(status.downlink)}")
                append(" | ${status.connectionsIn}/${status.connectionsOut}")
            }
            lastStatus = text
            lastUplink = status.uplink
            lastDownlink = status.downlink
            statusListener?.invoke(text)
            trafficListener?.invoke(status.uplink, status.downlink)
        }

        override fun writeLogs(it: io.nekohasekai.libbox.LogIterator) {
            while (it.hasNext()) {
                val entry = it.next() ?: continue
                logListener?.invoke(entry.message)
            }
        }

        override fun writeOutbounds(it: io.nekohasekai.libbox.OutboundGroupItemIterator) {}
        override fun writeGroups(it: io.nekohasekai.libbox.OutboundGroupIterator) {}
        override fun writeConnectionEvents(it: io.nekohasekai.libbox.ConnectionEvents) {}
        override fun initializeClashMode(it: StringIterator, current: String) {}
        override fun updateClashMode(mode: String) {}
        override fun clearLogs() {}
        override fun setDefaultLogLevel(level: Int) {}
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        Log.i(TAG, "BoxService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: ""
                if (config.isNotEmpty()) {
                    startForeground(NOTIFICATION_ID, buildNotification("Starting..."))
                    startVPN(config)
                }
            }
            ACTION_STOP -> {
                stopVPN()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVPN()
        instance = null
        Log.i(TAG, "BoxService destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startVPN(configJson: String) {
        if (isRunning) {
            Log.w(TAG, "Already running, reloading config...")
            try {
                commandServer?.startOrReloadService(configJson, OverrideOptions())
            } catch (e: Exception) {
                Log.e(TAG, "reload failed: ${e.message}")
            }
            return
        }

        try {
            val basePath = File(filesDir, "libbox").also { it.mkdirs() }.absolutePath

            Libbox.setup(SetupOptions().apply {
                this.basePath = basePath
                this.workingPath = filesDir.absolutePath
                this.tempPath = cacheDir.absolutePath
                this.fixAndroidStack = true
                this.debug = true
                this.logMaxLines = 1000
            })

            val platformInterface = VPNService.instance
            if (platformInterface == null) {
                Log.e(TAG, "VPNService not ready")
                stopSelf()
                return
            }

            commandServer = Libbox.newCommandServer(serverHandler, platformInterface)
            commandServer!!.start()
            commandServer!!.startOrReloadService(configJson, OverrideOptions())

            isRunning = true
            Log.i(TAG, "sing-box started successfully")

            commandClient = Libbox.newCommandClient(
                clientHandler,
                CommandClientOptions().apply {
                    statusInterval = 1000
                    addCommand(Libbox.CommandStatus)
                    addCommand(Libbox.CommandLog)
                }
            )
            commandClient!!.connect()

            updateNotification("VPN Connected")

        } catch (e: Exception) {
            Log.e(TAG, "startVPN failed: ${e.message}", e)
            isRunning = false
            stopForeground(true)
            stopSelf()
        }
    }

    fun stopVPN() {
        if (!isRunning) return
        isRunning = false
        lastStatus = "disconnected"

        try { commandClient?.disconnect() } catch (_: Exception) {}
        commandClient = null

        try { commandServer?.closeService() } catch (_: Exception) {}
        try { commandServer?.close() } catch (_: Exception) {}
        commandServer = null

        Log.i(TAG, "sing-box stopped")
    }

    fun updateNotification(text: String) {
        lastStatus = text
        if (isRunning) {
            startForeground(NOTIFICATION_ID, buildNotification(text))
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "WaledNet VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN connection status"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val pendingIntent = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("WaledNet VPN")
            .setContentText(text)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_MIN)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .build()
    }
}
