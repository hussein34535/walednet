package com.waled.net

import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.PlatformUser
import io.nekohasekai.libbox.RoutePrefix
import io.nekohasekai.libbox.RoutePrefixIterator
import io.nekohasekai.libbox.ShellSession
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState

class VPNService : VpnService(), PlatformInterface {

    companion object {
        private const val TAG = "WaledVPN"

        @Volatile
        var instance: VPNService? = null
            private set
    }

    private var tunFd: ParcelFileDescriptor? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "VPNService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        Log.i(TAG, "VPNService destroyed")
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN revoked by system")
        BoxService.instance?.let {
            it.stopVPN()
            it.stopForeground(true)
            it.stopSelf()
        }
    }

    override fun openTun(options: TunOptions): Int {
        Log.i(TAG, "openTun called")

        try {
            val builder = Builder()
            builder.setSession("WaledNet")
            builder.setMtu(options.mtu)

            val inet4 = options.inet4Address
            if (inet4.hasNext()) {
                val first = inet4.next()
                builder.addAddress(first.address(), first.prefix())
                while (inet4.hasNext()) {
                    val r = inet4.next()
                    builder.addRoute(r.address(), r.prefix())
                }
            }

            val inet4route = options.inet4RouteAddress
            while (inet4route.hasNext()) {
                val r = inet4route.next()
                builder.addRoute(r.address(), r.prefix())
            }

            val dnsServers = options.dnsServerAddress
            while (dnsServers.hasNext()) {
                builder.addDnsServer(dnsServers.next())
            }

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
                Log.e(TAG, "establish() returned null")
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
        protect(fd)
    }

    override fun sendNotification(notification: Notification) {
        BoxService.instance?.updateNotification(notification.body ?: notification.title ?: "VPN Active")
    }

    override fun clearDNSCache() {}

    override fun useProcFS(): Boolean = false

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun usePlatformShell(): Boolean = false

    override fun checkPlatformShell() {}

    override fun getInterfaces(): NetworkInterfaceIterator? = null

    override fun readWIFIState(): WIFIState? = null

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destAddress: String,
        destPort: Int
    ): ConnectionOwner? = null

    override fun localDNSTransport(): LocalDNSTransport? = null

    override fun registerMyInterface(name: String) {}

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {}

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {}

    override fun startNeighborMonitor(listener: NeighborUpdateListener) {}

    override fun closeNeighborMonitor(listener: NeighborUpdateListener) {}

    override fun lookupUser(username: String): PlatformUser? = null

    override fun openShellSession(
        user: PlatformUser,
        command: String,
        args: StringIterator,
        term: String,
        rows: Int,
        cols: Int
    ): ShellSession? = null

    override fun lookupSFTPServer(): String = ""

    override fun readSystemSSHHostKey(): String = ""

    override fun tailscaleHostname(): String = ""

    fun closeTun() {
        try { tunFd?.close() } catch (_: Exception) {}
        tunFd = null
    }
}
