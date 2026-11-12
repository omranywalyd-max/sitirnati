package com.sitirnati.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import java.util.Locale

/**
 * The full-screen "the driver is near" alert.
 *
 * This is a native Activity on purpose. A Flutter dialog can only appear inside
 * the Flutter window, so a customer whose phone is locked, or who is in another
 * app, would never see it. This screen turns the display on, shows itself over
 * the keyguard and whatever else is running, and offers the two things a waiting
 * customer needs at that moment: ring the driver, or acknowledge and go back.
 *
 * It closes itself after [AUTO_CLOSE_SECONDS] so a phone left on a table does not
 * stay awake all night, and it keeps the screen on while it is up.
 */
class DriverArrivalActivity : Activity() {

    companion object {
        const val EXTRA_DRIVER_NAME = "driverName"
        const val EXTRA_PLACE_NAME = "placeName"
        const val EXTRA_PHONE = "phone"

        private const val AUTO_CLOSE_SECONDS = 60
    }

    private val handler = Handler(Looper.getMainLooper())
    private var secondsLeft = AUTO_CLOSE_SECONDS
    private var countdown: TextView? = null

    private val tick = object : Runnable {
        override fun run() {
            secondsLeft--
            countdown?.text = String.format(Locale.US, "يتسد وحدو بعد %d ثانية", secondsLeft)
            if (secondsLeft > 0) {
                handler.postDelayed(this, 1000L)
            } else {
                dismiss()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over the lock screen and turn the display on: the whole point of
        // this screen is that it reaches the customer without them unlocking.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguard?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(R.layout.activity_driver_arrival)

        val driverName = intent.getStringExtra(EXTRA_DRIVER_NAME)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: "السائق"
        val placeName = intent.getStringExtra(EXTRA_PLACE_NAME).orEmpty().trim()
        val phone = intent.getStringExtra(EXTRA_PHONE).orEmpty().trim()

        findViewById<TextView>(R.id.tvDriverName).text = driverName
        findViewById<TextView>(R.id.tvPlace).text = if (placeName.isEmpty()) {
            "وصل لموقعك. إذا ما لقيتوش، عيّطله."
        } else {
            "وصل لـ$placeName. إذا ما لقيتوش، عيّطله."
        }

        val callButton = findViewById<Button>(R.id.btnCall)
        if (phone.isEmpty()) {
            // No number means no call action at all: a button that does nothing
            // is worse than no button.
            callButton.visibility = View.GONE
        } else {
            callButton.setOnClickListener { dial(phone) }
        }

        countdown = findViewById(R.id.tvCountdown)
        findViewById<Button>(R.id.btnDismiss).setOnClickListener { dismiss() }

        buzz()
        handler.postDelayed(tick, 1000L)
    }

    /** Opens the dialer with the driver's number filled in. */
    private fun dial(phone: String) {
        try {
            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone"))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (_: Exception) {
            // No dialer on the device: the number is on screen and copyable.
        }
    }

    /** A short double buzz — enough to notice a phone face-down, not a ringtone. */
    private fun buzz() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
            if (!vibrator.hasVibrator()) return
            val pattern = longArrayOf(0, 220, 120, 220)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (_: Exception) {
            // Vibration is a courtesy; never let it stop the alert.
        }
    }

    private fun dismiss() {
        handler.removeCallbacks(tick)
        finish()
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        countdown = null
        super.onDestroy()
    }
}
