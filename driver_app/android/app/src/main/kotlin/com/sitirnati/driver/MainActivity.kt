package com.sitirnati.driver

import io.flutter.embedding.android.FlutterActivity

/**
 * Plain Flutter host for the driver app.
 *
 * Nothing here needs a platform channel: the driver only reads and writes
 * Firestore, opens Google Maps through url_launcher, and places calls through
 * the system dialler. The customer app is the one that owns the full-screen
 * "driver is near" overlay, because the customer is the side that has to be
 * woken up.
 */
class MainActivity : FlutterActivity()
