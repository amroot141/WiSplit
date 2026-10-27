package com.wisplit.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL_NAME = "com.wisplit/hardware_trigger"
    private var methodChannel: MethodChannel? = null
    private var pendingTrigger = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateTriggerConfig" -> {
                    val gesture = call.argument<String>("gesture") ?: "BACK_DOUBLE_TAP"
                    val sensitivity = call.argument<String>("sensitivity") ?: "MEDIUM"
                    BackTapService.updateConfig(gesture, sensitivity)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Register callback with BackTapService
        BackTapService.tapListener = {
            runOnUiThread {
                sendTriggerEvent()
            }
        }

        // Deliver any trigger that occurred while bringing Activity to front
        if (pendingTrigger) {
            sendTriggerEvent()
            pendingTrigger = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkIntentForTrigger(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkIntentForTrigger(intent)
    }

    private fun checkIntentForTrigger(intent: Intent?) {
        if (intent?.hasExtra("TRIGGER_SOURCE") == true) {
            if (methodChannel != null) {
                sendTriggerEvent()
            } else {
                pendingTrigger = true
            }
        }
    }

    private fun sendTriggerEvent() {
        methodChannel?.invokeMethod("onHardwareTrigger", null)
    }

    override fun onDestroy() {
        BackTapService.tapListener = null
        super.onDestroy()
    }
}
