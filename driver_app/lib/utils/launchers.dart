import 'package:flutter/foundation.dart' show debugPrint;
import 'package:url_launcher/url_launcher.dart';

import 'formatters.dart';

/// Hands a coordinate pair to Google Maps.
///
/// The `geo:` intent is what opens the installed Maps app directly, with the
/// pin already dropped; the `https://` URL is the fallback for a phone that has
/// no Maps app (or a tablet with the browser only). Both carry the place name
/// when there is one, because "وصلني لسيترنتي" is easier to read back than two
/// decimals.
///
/// Returns `false` when neither target could be opened, so the caller can tell
/// the driver instead of leaving the tap with no feedback.
Future<bool> openInMaps({
  required double lat,
  required double lng,
  String? label,
}) async {
  final name = (label ?? '').trim();
  final geo = Uri.parse(
    name.isEmpty
        ? 'geo:$lat,$lng?q=$lat,$lng'
        : 'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})',
  );
  final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

  try {
    if (await canLaunchUrl(geo)) {
      return await launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    return await launchUrl(web, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('openInMaps: $error');
    return false;
  }
}

/// Opens the dialler on [phone], which is stored digits-only.
///
/// The number is normalised first: a driver may have typed `+213 550 12 34 56`
/// when registering, and `tel:` needs a single run of digits (plus an optional
/// leading `+`).
Future<bool> callPhone(String phone) async {
  final digits = digitsOnly(phone);
  if (digits.isEmpty) return false;
  final uri = Uri(scheme: 'tel', path: digits);
  try {
    if (!await canLaunchUrl(uri)) return false;
    return await launchUrl(uri);
  } catch (error) {
    debugPrint('callPhone: $error');
    return false;
  }
}
