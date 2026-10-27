package com.wisplit.app

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.accessibility.AccessibilityEvent
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Customizable Hardware Trigger Detection Service.
 *
 * Supported Gestures:
 * 1. BACK_DOUBLE_TAP (Default): Two quick jolts on phone back
 * 2. BACK_TRIPLE_TAP: Three quick jolts on phone back
 * 3. SHAKE: Physical phone shake gesture
 * 4. POWER_TRIPLE_TAP: Three rapid power button presses (screen on/off transitions)
 *
 * Sensitivity Adjustment:
 * - LOW: Higher threshold, avoids accidental triggers
 * - MEDIUM: Balanced everyday threshold
 * - HIGH: Sensitive, triggers with minimal force
 */
class BackTapService : AccessibilityService(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var vibrator: Vibrator? = null

    // Double & Triple-tap timing and thresholds
    private var tapThreshold = 5.2f
    private val minTapIntervalMs = 120L
    private val maxTapIntervalMs = 600L

    private var lastZ = 0.0f
    private var lastTapTimestamp = 0L
    private var tapCount = 0

    // Shake detection
    private var shakeThreshold = 14.0f
    private var lastShakeTimestamp = 0L

    // Power button triple press tracking
    private val screenTransitions = mutableListOf<Long>()

    companion object {
        var tapListener: (() -> Unit)? = null
        var currentGesture = "BACK_DOUBLE_TAP"
        var currentSensitivity = "MEDIUM"

        fun updateConfig(gesture: String, sensitivity: String) {
            currentGesture = gesture
            currentSensitivity = sensitivity
        }
    }

    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val now = System.currentTimeMillis()

            if (currentGesture == "POWER_TRIPLE_TAP") {
                if (intent?.action == Intent.ACTION_SCREEN_ON || intent?.action == Intent.ACTION_SCREEN_OFF) {
                    screenTransitions.add(now)
                    // Keep only transitions in the last 1800 ms
                    while (screenTransitions.isNotEmpty() && (now - screenTransitions.first()) > 1800L) {
                        screenTransitions.removeAt(0)
                    }
                    if (screenTransitions.size >= 3) {
                        screenTransitions.clear()
                        onTriggerDetected("POWER_TRIPLE_TAP")
                    }
                }
            }

            when (intent?.action) {
                Intent.ACTION_SCREEN_ON -> registerSensor()
                Intent.ACTION_SCREEN_OFF -> {
                    if (currentGesture != "POWER_TRIPLE_TAP") {
                        unregisterSensor()
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
            ?: sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

        applySensitivity(currentSensitivity)

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(screenStateReceiver, filter)
        registerSensor()
    }

    private fun applySensitivity(sensitivity: String) {
        when (sensitivity.uppercase()) {
            "LOW" -> {
                tapThreshold = 7.6f
                shakeThreshold = 18.0f
            }
            "HIGH" -> {
                tapThreshold = 3.4f
                shakeThreshold = 10.0f
            }
            else -> { // MEDIUM
                tapThreshold = 5.2f
                shakeThreshold = 14.0f
            }
        }
    }

    private fun registerSensor() {
        accelerometer?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun unregisterSensor() {
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        applySensitivity(currentSensitivity)

        val now = System.currentTimeMillis()
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        // 1. Shake detection
        if (currentGesture == "SHAKE") {
            val netAccel = sqrt((x * x + y * y + z * z).toDouble()).toFloat()
            if (netAccel > shakeThreshold && (now - lastShakeTimestamp) > 1200L) {
                lastShakeTimestamp = now
                onTriggerDetected("SHAKE")
            }
            return
        }

        // 2. Back Tap detection (Z-axis delta)
        val deltaZ = abs(z - lastZ)
        lastZ = z

        if (deltaZ > tapThreshold) {
            val interval = now - lastTapTimestamp

            if (currentGesture == "BACK_DOUBLE_TAP") {
                if (interval in minTapIntervalMs..maxTapIntervalMs) {
                    tapCount = 0
                    lastTapTimestamp = 0L
                    onTriggerDetected("BACK_DOUBLE_TAP")
                } else if (interval > maxTapIntervalMs) {
                    tapCount = 1
                    lastTapTimestamp = now
                }
            } else if (currentGesture == "BACK_TRIPLE_TAP") {
                if (interval in minTapIntervalMs..maxTapIntervalMs) {
                    tapCount++
                    lastTapTimestamp = now
                    if (tapCount >= 3) {
                        tapCount = 0
                        lastTapTimestamp = 0L
                        onTriggerDetected("BACK_TRIPLE_TAP")
                    }
                } else if (interval > maxTapIntervalMs) {
                    tapCount = 1
                    lastTapTimestamp = now
                }
            }
        }
    }

    private fun onTriggerDetected(source: String) {
        // Haptic feedback
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createOneShot(45, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(45)
        }

        // Dispatch to Flutter MethodChannel
        tapListener?.invoke() ?: run {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("TRIGGER_SOURCE", source)
            }
            startActivity(launchIntent)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        unregisterSensor()
        unregisterReceiver(screenStateReceiver)
        tapListener = null
    }
}
