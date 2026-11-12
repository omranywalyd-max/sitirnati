import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The bridge to the one piece of this app that cannot be written in Dart: a
/// full-screen alert drawn by Android itself, on top of whatever is on screen.
///
/// Why native at all: a Flutter dialog can only appear inside the Flutter
/// window, so a customer whose phone is locked, or who is in another app, would
/// never see it. Android's "display over other apps" permission exists exactly
/// for this, and it is the only way to make the alert reliable without a push
/// notification service.
///
/// Every method is best-effort: if the channel is missing (a non-Android host,
/// or a build without the plugin registration) the call resolves to `false`
/// instead of throwing, so the order flow never breaks because of the overlay.
abstract final class OverlayService {
  static const _channel = MethodChannel('com.sitirnati.app/overlay');

  /// Whether Android will let this app draw over other apps.
  ///
  /// `false` on any failure, which is the safe answer: it makes the caller show
  /// the explanation instead of silently assuming the alert will work.
  static Future<bool> hasPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return granted ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('OverlayService.hasPermission: ${error.message}');
      return false;
    }
  }

  /// Opens the system screen where the permission is granted.
  ///
  /// Android has no API to grant this from inside an app, so the only thing we
  /// can do is take the customer to the right switch. Resolves to whether the
  /// screen was opened, not whether the permission was granted — that is
  /// re-checked with [hasPermission] the next time it matters.
  static Future<bool> requestPermission() async {
    try {
      final opened =
          await _channel.invokeMethod<bool>('requestOverlayPermission');
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('OverlayService.requestPermission: ${error.message}');
      return false;
    }
  }

  /// Raises the full-screen "the driver is near" alert.
  ///
  /// [driverName] and [placeName] are written into the native screen as-is;
  /// [phone] powers its call button, so the customer can reach the driver
  /// without unlocking the app first.
  static Future<bool> showArrival({
    required String driverName,
    required String placeName,
    required String phone,
  }) async {
    try {
      final shown = await _channel.invokeMethod<bool>(
        'showArrival',
        <String, Object?>{
          'driverName': driverName,
          'placeName': placeName,
          'phone': phone,
        },
      );
      return shown ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('OverlayService.showArrival: ${error.message}');
      return false;
    }
  }
}
