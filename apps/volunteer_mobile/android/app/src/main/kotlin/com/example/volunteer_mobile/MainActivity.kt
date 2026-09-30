package com.example.volunteer_mobile

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "spatially/haptic"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibratePattern" -> {
                    val patternList = call.argument<List<Number>>("pattern")
                    if (patternList != null) {
                        val timings = patternList.map { it.toLong() }.toLongArray()
                        vibrateWithPattern(timings)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Pattern cannot be null", null)
                    }
                }
                "cancel" -> {
                    cancelVibration()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getVibrator(): Vibrator {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    private fun vibrateWithPattern(timings: LongArray) {
        val vibrator = getVibrator()
        if (vibrator.hasVibrator()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Waveform: -1 means do not repeat
                val effect = VibrationEffect.createWaveform(timings, -1)
                vibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(timings, -1)
            }
        }
    }

    private fun cancelVibration() {
        val vibrator = getVibrator()
        vibrator.cancel()
    }
}
