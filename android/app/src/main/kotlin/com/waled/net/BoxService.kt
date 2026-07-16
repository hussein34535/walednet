package com.waled.net

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import libbox.CommandClient
import libbox.CommandClientHandler
import libbox.CommandClientOptions
import libbox.CommandServer
import libbox.CommandServerHandler
import libbox.Libbox
import libbox.Notification as LibboxNotification
import libbox.OverrideOptions
import libbox.SetupOptions
import libbox.StatusMessage
import libbox.StringIterator
import libbox.SystemProxyStatus
import libbox.TunOptions
import libbox.PlatformInterface
import libbox.ConnectionOwner
import libbox.InterfaceUpdateListener
import libbox.LocalDNSTransport
import libbox.NeighborUpdateListener
import libbox.NetworkInterfaceIterator
import libbox.WIFIState
import java.io.File

class BoxService : VpnService(), PlatformInterface {

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
    private var tunFd: ParcelFileDescriptor? = null
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

        override fun setSystemProxyEnabled(enabled: Boolean) {}

        override fun triggerNativeCrash() {}

        override fun writeDebugMessage(message: String) {
            Log.d(TAG, "debug: $message")
        }
    }

    private val clientHandler = object : CommandClientHandler {
        override fun connected() {
            Log.i(TAG, "CommandClient connected")
            lastStatus = "connected"
            statusListener?.invoke("connected")
        }

        override fun disconnected(message: String) {
            Log.i(TAG, "CommandClient disconnected: $message")
            lastStatus = "disconnected"
            statusListener?.invoke("disconnected")
        }

        override fun writeStatus(status: StatusMessage) {
            val text = "↑ ${Libbox.formatBitrate(status.uplink)} ↓ ${Libbox.formatBitrate(status.downlink)}"
            lastStatus = text
            lastUplink = status.uplink
            lastDownlink = status.downlink
            statusListener?.invoke(text)
            trafficListener?.invoke(status.uplink, status.downlink)
        }

        override fun writeLogs(it: libbox.LogIterator) {
            try {
                while (it.hasNext()) {
                    val entry = it.next() ?: continue
                    Log.i(TAG, "[Core] ${entry.message}")
                    logListener?.invoke(entry.message)
                }
            } catch (e: Exception) {
                Log.w(TAG, "writeLogs error: ${e.message}")
            }
        }

        override fun writeOutbounds(it: libbox.OutboundGroupItemIterator) {}
        override fun writeGroups(it: libbox.OutboundGroupIterator) {}
        override fun writeConnectionEvents(it: libbox.ConnectionEvents) {}
        override fun initializeClashMode(it: StringIterator, current: String) {}
        override fun updateClashMode(mode: String) {}
        override fun clearLogs() {}
        override fun setDefaultLogLevel(level: Int) {}
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        Log.i(TAG, "BoxService (VpnService) created")
        try {
            startForegroundCompat(buildNotification("Initializing..."))
        } catch (e: Exception) {
            Log.e(TAG, "startForeground in onCreate failed: ${e.message}", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand: action=${intent?.action}")

        try {
            startForegroundCompat(buildNotification("Starting..."))
        } catch (e: Exception) {
            Log.e(TAG, "startForeground in onStartCommand failed: ${e.message}", e)
        }

        when (intent?.action) {
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: ""
                if (config.isNotEmpty()) {
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

    override fun onRevoke() {
        Log.w(TAG, "onRevoke - VPN revoked by system")
        stopVPN()
        stopForeground(true)
        stopSelf()
    }

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

            Log.i(TAG, "Setting up libbox...")
            Libbox.setup(SetupOptions().apply {
                this.basePath = basePath
                this.workingPath = filesDir.absolutePath
                this.tempPath = cacheDir.absolutePath
                this.fixAndroidStack = true
                this.debug = true
                this.logMaxLines = 1000
            })

            Log.i(TAG, "Creating CommandServer (PlatformInterface=this)")
            commandServer = Libbox.newCommandServer(serverHandler, this)
            commandServer!!.start()

            Log.i(TAG, "Starting sing-box service...")
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
        if (!isRunning && commandServer == null) return
        isRunning = false
        lastStatus = "disconnected"

        try { commandClient?.disconnect() } catch (_: Exception) {}
        commandClient = null

        try { commandServer?.closeService() } catch (_: Exception) {}
        try { commandServer?.close() } catch (_: Exception) {}
        commandServer = null

        try { tunFd?.close() } catch (_: Exception) {}
        tunFd = null

        Log.i(TAG, "sing-box stopped")
        statusListener?.invoke("disconnected")
    }

    override fun openTun(options: TunOptions): Int {
        Log.i(TAG, "openTun() called by libbox")
        Log.i(TAG, "  MTU: ${options.mtu}")

        try {
            val builder = Builder()
            builder.setSession("WaledNet")
            builder.setMtu(options.mtu)

            val inet4 = options.inet4Address
            if (inet4.hasNext()) {
                val first = inet4.next()
                builder.addAddress(first.address(), first.prefix())
            }

            val inet4route = options.inet4RouteAddress
            var hasGlobalRoute = false
            while (inet4route.hasNext()) {
                val r = inet4route.next()
                builder.addRoute(r.address(), r.prefix())
                Log.d(TAG, "  Route: ${r.address()}/${r.prefix()}")
                if (r.address() == "0.0.0.0" && r.prefix() == 0) {
                    hasGlobalRoute = true
                }
            }

            // Force add global IPv4 route if not present
            if (!hasGlobalRoute) {
                try {
                    builder.addRoute("0.0.0.0", 0)
                    Log.i(TAG, "  Forced default IPv4 Route: 0.0.0.0/0")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to add forced default IPv4 route: ${e.message}")
                }
            }

            // Add default global IPv6 route as well for completeness
            try {
                builder.addRoute("::", 0)
                Log.i(TAG, "  Added default IPv6 Route: ::/0")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to add default IPv6 route: ${e.message}")
            }

            val dnsServer = options.dnsServerAddress
            if (dnsServer != null) {
                val dns = dnsServer.value
                if (!dns.isNullOrEmpty()) {
                    builder.addDnsServer(dns)
                    Log.d(TAG, "  DNS: $dns")
                }
            }

            builder.addDisallowedApplication(packageName)
            Log.i(TAG, "  Excluded self: $packageName")

            val excludePkg = options.excludePackage
            while (excludePkg.hasNext()) {
                val pkg = excludePkg.next()
                if (pkg != packageName) {
                    builder.addDisallowedApplication(pkg)
                }
            }

            val includePkg = options.includePackage
            while (includePkg.hasNext()) {
                val pkg = includePkg.next()
                if (pkg != packageName) {
                    builder.addAllowedApplication(pkg)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            tunFd = builder.establish()
            if (tunFd == null) {
                Log.e(TAG, "Builder.establish() returned null!")
                return -1
            }

            Log.i(TAG, "TUN established, fd=${tunFd!!.fd}")
            return tunFd!!.fd

        } catch (e: Exception) {
            Log.e(TAG, "openTun failed: ${e.message}", e)
            return -1
        }
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        val result = protect(fd)
        Log.d(TAG, "protect(fd=$fd) -> $result")
    }

    override fun sendNotification(notification: LibboxNotification) {
        val text = notification.body ?: notification.title ?: "VPN Active"
        updateNotification(text)
    }

    override fun clearDNSCache() {}
    override fun useProcFS(): Boolean = false
    override fun underNetworkExtension(): Boolean = false
    override fun includeAllNetworks(): Boolean = false
    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true
    override fun getInterfaces(): NetworkInterfaceIterator? = null
    override fun readWIFIState(): WIFIState? = null

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destAddress: String,
        destPort: Int
    ): ConnectionOwner = ConnectionOwner()

    override fun localDNSTransport(): LocalDNSTransport? = null
    override fun registerMyInterface(name: String) {}
    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {}
    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {}
    override fun startNeighborMonitor(listener: NeighborUpdateListener) {}
    override fun closeNeighborMonitor(listener: NeighborUpdateListener) {}
    override fun systemCertificates(): StringIterator? = null

    fun updateNotification(text: String) {
        lastStatus = text
        if (isRunning) {
            try {
                startForegroundCompat(buildNotification(text))
            } catch (_: Exception) {}
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
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
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
