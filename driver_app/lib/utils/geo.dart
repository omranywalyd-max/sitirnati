import 'package:geolocator/geolocator.dart';

import '../models/driver_profile.dart';
import '../models/order.dart';

/// Straight-line distance from the driver's base to the order's delivery point,
/// in metres.
///
/// Returns `null` when either side has no usable coordinates — showing `0 م`
/// would be a lie, and the card falls back to the order's status pill instead.
///
/// This is the crow-flies distance, not a routed one: it needs no network, no
/// API key and no billing, and for "is this job worth taking?" it is the number
/// a driver actually uses.
double? driverDistance(DriverProfile? profile, DriverOrder order) {
  if (profile == null || !profile.hasBase) return null;
  if (order.lat == 0 && order.lng == 0) return null;
  return Geolocator.distanceBetween(
    profile.lat,
    profile.lng,
    order.lat,
    order.lng,
  );
}
