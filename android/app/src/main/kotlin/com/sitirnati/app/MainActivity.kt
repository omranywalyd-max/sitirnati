package com.sitirnati.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The Flutter host, plus the one bridge that cannot live in Dart.
 *
 * The bridge is deliberately tiny: it answers whether Android will let this app
 * draw over other apps, opens the screen that grants it, and launches the
 * full-screen arrival alert. Everything else in the product is Flutter.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.sitirnati.app/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkOverlayPermission" -> result.success(canDrawOverlays())

                    "requestOverlayPermission" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("overlay_settings", error.message, null)
                        }
                    }

                    "showArrival" -> {
                        try {
                            val intent = Intent(this, DriverArrivalActivity::class.java).apply {
                                putExtra(
                                    DriverArrivalActivity.EXTRA_DRIVER_NAME,
                                    call.argument<String>("driverName").orEmpty()
                                )
                                putExtra(
                                    DriverArrivalActivity.EXTRA_PLACE_NAME,
                                    call.argument<String>("placeName").orEmpty()
                                )
                                putExtra(
                                    DriverArrivalActivity.EXTRA_PHONE,
                                    call.argument<String>("phone").orEmpty()
                                )
                                addFlags(
                                    Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                                )
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("show_arrival", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Whether the app may draw over other apps.
     *
     * On Android 6 and newer this is a per-app user decision, so it is read from
     * the system every time instead of being cached: the customer can flip it in
     * Settings while the app is in the background, and the next check must see
     * the new answer.
     */
    private fun canDrawOverlays(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return Settings.canDrawOverlays(this)
    }
}
