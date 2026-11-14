package br.com.desperrengue.app

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var flagSecureActive: Boolean = false
    private var bypassExpiresAtEpochMs: Long = 0L

    private val relockRunnable = Runnable {
        applyFlagSecureProtection(enable = true)
    }

    private val isFounderCeoBuild: Boolean
        get() = applicationContext.packageName.endsWith(".founder")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFounderCeoBuild) {
            applyFlagSecureProtection(enable = true)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!isFounderCeoBuild) return

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.desperrengue.app.founder/security"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getScreenProtectionStatus" -> {
                    result.success(
                        mapOf(
                            "flagSecureActive" to flagSecureActive,
                            "bypassExpiresAtEpochMs" to bypassExpiresAtEpochMs
                        )
                    )
                }
                "setTemporaryCaptureAllowed" -> {
                    val allow = call.argument<Boolean>("allow") ?: false
                    val minutes = (call.argument<Int>("minutes") ?: 5).coerceIn(1, 5)
                    mainHandler.removeCallbacks(relockRunnable)
                    if (allow) {
                        val durationMs = minutes * 60_000L
                        bypassExpiresAtEpochMs = System.currentTimeMillis() + durationMs
                        applyFlagSecureProtection(enable = false)
                        mainHandler.postDelayed(relockRunnable, durationMs)
                    } else {
                        bypassExpiresAtEpochMs = 0L
                        applyFlagSecureProtection(enable = true)
                    }
                    result.success(
                        mapOf(
                            "flagSecureActive" to flagSecureActive,
                            "bypassExpiresAtEpochMs" to bypassExpiresAtEpochMs
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(relockRunnable)
        super.onDestroy()
    }

    private fun applyFlagSecureProtection(enable: Boolean) {
        if (enable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                setRecentsScreenshotEnabled(false)
            }
            flagSecureActive = true
            bypassExpiresAtEpochMs = 0L
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                setRecentsScreenshotEnabled(true)
            }
            flagSecureActive = false
        }
    }
}
