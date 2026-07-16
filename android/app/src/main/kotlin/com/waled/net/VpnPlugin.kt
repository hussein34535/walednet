package com.waled.net

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    io.flutter.plugin.common.PluginRegistry.ActivityResultListener {

    companion object {
        private const val TAG = "WaledPlugin"
        private const val METHOD_CHANNEL = "waled_net/vpn"
        private const val STATUS_EVENT_CHANNEL = "waled_net/status"
        private const val TRAFFIC_EVENT_CHANNEL = "waled_net/traffic"
        private const val LOG_EVENT_CHANNEL = "waled_net/logs"
        private const val VPN_PREPARE_REQUEST = 9001
    }

    private var context: Context? = null
    private var activity: Activity? = null
    private var methodChannel: MethodChannel? = null
    private var statusEventChannel: EventChannel? = null
    private var trafficEventChannel: EventChannel? = null
    private var logEventChannel: EventChannel? = null
    private var pendingPrepareResult: MethodChannel.Result? = null

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        Log.i(TAG, "Activity attached to VpnPlugin")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PREPARE_REQUEST) {
            val granted = resultCode == Activity.RESULT_OK
            Log.i(TAG, "VPN prepare result: granted=$granted")
            pendingPrepareResult?.success(granted)
            pendingPrepareResult = null
            return true
        }
        return false
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(this@VpnPlugin)
        }
        statusEventChannel = EventChannel(binding.binaryMessenger, STATUS_EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    sink.success(BoxService.lastStatus)
                    BoxService.statusListener = { msg ->
                        try { sink.success(msg) } catch (_: Exception) {}
                    }
                }
                override fun onCancel(args: Any?) {
                    BoxService.statusListener = null
                }
            })
        }
        trafficEventChannel = EventChannel(binding.binaryMessenger, TRAFFIC_EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    BoxService.trafficListener = { uplink, downlink ->
                        try {
                            sink.success(mapOf("uplink" to uplink, "downlink" to downlink))
                        } catch (_: Exception) {}
                    }
                }
                override fun onCancel(args: Any?) {
                    BoxService.trafficListener = null
                }
            })
        }
        logEventChannel = EventChannel(binding.binaryMessenger, LOG_EVENT_CHANNEL).apply {
            setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    BoxService.logListener = { logLine ->
                        try { sink.success(logLine) } catch (_: Exception) {}
                    }
                }
                override fun onCancel(args: Any?) {
                    BoxService.logListener = null
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
                if (intent != null) {
                    // Launch the VPN permission intent and wait for result
                    val act = activity ?: run {
                        result.success(false); return
                    }
                    try {
                        pendingPrepareResult = result
                        act.startActivityForResult(intent, VPN_PREPARE_REQUEST)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to launch VPN prepare intent: ${e.message}")
                        pendingPrepareResult = null
                        result.success(false)
                    }
                } else {
                    result.success(true)
                }
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
                result.success(BoxService.instance != null)
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

            val intent = Intent(ctx, BoxService::class.java).apply {
                action = BoxService.ACTION_START
                putExtra(BoxService.EXTRA_CONFIG, config)
            }
            ctx.startForegroundService(intent)
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
        BoxService.logListener = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        statusEventChannel?.setStreamHandler(null)
        statusEventChannel = null
        trafficEventChannel?.setStreamHandler(null)
        trafficEventChannel = null
        logEventChannel?.setStreamHandler(null)
        logEventChannel = null
        context = null
        activity = null
        Log.i(TAG, "VpnPlugin detached")
    }
}
