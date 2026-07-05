package com.waled.net

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "WaledPlugin"
        private const val METHOD_CHANNEL = "waled_net/vpn"
        private const val STATUS_EVENT_CHANNEL = "waled_net/status"
        private const val TRAFFIC_EVENT_CHANNEL = "waled_net/traffic"
    }

    private var context: Context? = null
    private var methodChannel: MethodChannel? = null
    private var statusEventChannel: EventChannel? = null
    private var trafficEventChannel: EventChannel? = null
    private var statusSink: EventChannel.EventSink? = null
    private var trafficSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@VpnPlugin)
        }
        statusEventChannel = EventChannel(binding.binaryMessenger, STATUS_EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    statusSink = sink
                    sink.success(BoxService.lastStatus)
                    BoxService.statusListener = { msg -> sink.success(msg) }
                }

                override fun onCancel(args: Any?) {
                    BoxService.statusListener = null
                    statusSink = null
                }
            })
        }
        trafficEventChannel = EventChannel(binding.binaryMessenger, TRAFFIC_EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    trafficSink = sink
                    BoxService.trafficListener = { uplink, downlink ->
                        sink.success(mapOf("uplink" to uplink, "downlink" to downlink))
                    }
                }

                override fun onCancel(args: Any?) {
                    BoxService.trafficListener = null
                    trafficSink = null
                }
            })
        }
        Log.i(TAG, "VpnPlugin attached")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> {
                val ctx = context ?: run {
                    result.error("NO_CONTEXT", "Context is null", null); return
                }
                val intent = VpnService.prepare(ctx)
                result.success(intent == null)
            }
            "start" -> {
                val config = call.argument<String>("config") ?: run {
                    result.error("NO_CONFIG", "Config is null", null); return
                }
                startVPN(config, result)
            }
            "stop" -> {
                stopVPN()
                result.success(true)
            }
            "isConnected" -> {
                result.success(BoxService.instance != null && BoxService.lastStatus != "disconnected")
            }
            else -> result.notImplemented()
        }
    }

    private fun startVPN(config: String, result: MethodChannel.Result) {
        try {
            val ctx = context ?: run {
                result.error("NO_CONTEXT", "Context is null", null); return
            }
            if (VpnService.prepare(ctx) != null) {
                result.error("NO_PERMISSION", "VPN permission not granted", null)
                return
            }
            val intent = Intent(ctx, VPNService::class.java)
            ctx.startService(intent)

            val boxIntent = Intent(ctx, BoxService::class.java).apply {
                action = BoxService.ACTION_START
                putExtra(BoxService.EXTRA_CONFIG, config)
            }
            ctx.startForegroundService(boxIntent)
            Log.i(TAG, "BoxService started")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "startVPN failed: ${e.message}", e)
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun stopVPN() {
        try {
            val ctx = context ?: return
            val intent = Intent(ctx, BoxService::class.java).apply {
                action = BoxService.ACTION_STOP
            }
            ctx.startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "stopVPN failed: ${e.message}", e)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        BoxService.statusListener = null
        BoxService.trafficListener = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        statusEventChannel?.setStreamHandler(null)
        statusEventChannel = null
        trafficEventChannel?.setStreamHandler(null)
        trafficEventChannel = null
        statusSink = null
        trafficSink = null
        context = null
        Log.i(TAG, "VpnPlugin detached")
    }
}
