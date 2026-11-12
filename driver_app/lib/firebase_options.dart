import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for the `sitirnati` project, driver app registration.
///
/// These values are the public client identifiers of the Firebase project; they
/// are the same ones `android/app/google-services.json` carries, and they ship
/// inside every APK anyway. They are not secrets — access is controlled by
/// `firestore.rules` and by the Firebase Auth providers, not by this file.
abstract final class DefaultFirebaseOptions {
  /// Options for the running platform.
  ///
  /// The product ships on Android only; every other target uses the same
  /// project so a desktop debug run still works.
  static FirebaseOptions get currentPlatform => android;

  /// The `sitirnati` driver app registration (`com.sitirnati.driver`).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVVinqJTl_zlfaW9_-pbY8oYPsIR9AMHA',
    appId: '1:370377524340:android:f47b367068ea19feb0fd21',
    messagingSenderId: '370377524340',
    projectId: 'sitirnati',
    storageBucket: 'sitirnati.firebasestorage.app',
  );
}
