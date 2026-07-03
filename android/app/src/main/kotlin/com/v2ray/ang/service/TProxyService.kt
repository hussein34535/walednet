package com.v2ray.ang.service

class TProxyService {
    companion object {
        @JvmStatic private external fun TProxyStartService(configPath: String, fd: Int)
        @JvmStatic private external fun TProxyStopService()
        @JvmStatic private external fun TProxyGetStats(): LongArray?

        init {
            System.loadLibrary("hev-socks5-tunnel")
        }

        fun startService(configPath: String, tunFd: Int) { TProxyStartService(configPath, tunFd) }
        fun stopService() { TProxyStopService() }
        fun getStats(): LongArray? = try { TProxyGetStats() } catch (_: Exception) { null }
    }
}
