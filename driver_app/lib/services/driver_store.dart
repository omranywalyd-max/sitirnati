import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/driver_profile.dart';
import '../models/order.dart';

/// Every Firestore read and write the driver app performs.
///
/// Two collections, one rule: `drivers/{uid}` is owned by its own user, and
/// `orders/{id}` is readable by the customer who placed it, by the driver who
/// claimed it, and — while it is still unclaimed — by any registered driver.
///
/// No query sorts on the server: an `orderBy` next to a `where` needs a
/// composite index, and these lists are a handful of rows, so sorting in Dart
/// keeps the project index-free.
abstract final class DriverStore {
  static const _dismissedKey = 'sitirnati_driver_dismissed_v1';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _drivers =>
      _db.collection('drivers');

  static CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');

  // ---------------------------------------------------------------- profile --

  /// Live profile for [uid]; emits `null` while the document does not exist.
  static Stream<DriverProfile?> watchProfile(String uid) {
    return _drivers.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return DriverProfile.fromFirestore(uid, data);
    });
  }

  /// One-shot profile read, used right after sign-in.
  static Future<DriverProfile?> fetchProfile(String uid) async {
    final snapshot = await _drivers.doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return DriverProfile.fromFirestore(uid, data);
  }

  /// Writes the whole profile, creating it on first save.
  static Future<void> saveProfile(DriverProfile profile) async {
    await _drivers.doc(profile.uid).set(
          profile.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Flips the availability switch.
  static Future<void> setActive(String uid, bool active) async {
    await _drivers.doc(uid).set({
      'active': active,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  // ----------------------------------------------------------------- orders --

  /// Orders nobody has claimed yet — the pool every active driver sees.
  static Stream<List<DriverOrder>> watchPool() {
    return _orders
        .where('driverUid', isEqualTo: '')
        .snapshots()
        .map(_toList);
  }

  /// Orders this driver claimed, newest first.
  static Stream<List<DriverOrder>> watchMine(String uid) {
    return _orders
        .where('driverUid', isEqualTo: uid)
        .snapshots()
        .map(_toList);
  }

  static List<DriverOrder> _toList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final orders = snapshot.docs
        .map((doc) => DriverOrder.fromFirestore(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  /// Claims an order. The write is the claim: the rules only let it through
  /// while `driverUid` is still empty, so two drivers racing for the same order
  /// end with one winner and one rejected write.
  static Future<void> accept(DriverOrder order, DriverProfile driver) async {
    await _orders.doc(order.id).update({
      'driverUid': driver.uid,
      'driverName': driver.fullName,
      'driverPhone': driver.phone,
      'waterType': driver.waterType,
      'volumeM3': driver.volumeM3,
      'price': driver.price,
      'status': OrderStatus.accepted.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Tells the customer app the driver is close. That app watches `nearAt` and
  /// raises its full-screen alert the moment it turns non-null.
  static Future<void> markNear(String orderId) async {
    await _orders.doc(orderId).update({
      'nearAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Closes the order as delivered.
  static Future<void> markDelivered(String orderId) async {
    await _orders.doc(orderId).update({
      'status': OrderStatus.delivered.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Moves an order along its lifecycle, used by the running-orders actions.
  static Future<void> setStatus(String orderId, OrderStatus status) async {
    await _orders.doc(orderId).update({
      'status': status.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // -------------------------------------------------------------- dismissed --

  /// Orders this driver swiped away locally.
  ///
  /// "Reject" is deliberately a local decision: the order stays in the pool for
  /// every other driver, and this phone simply stops showing it. Writing a
  /// global cancel from one driver would take work away from the others.
  static Future<Set<String>> dismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_dismissedKey) ?? const <String>[]).toSet();
  }

  /// Remembers that this driver dismissed [orderId].
  static Future<void> dismiss(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_dismissedKey) ?? const <String>[]).toSet()
      ..add(orderId);
    await prefs.setStringList(_dismissedKey, ids.toList(growable: false));
  }

  /// Forgets every dismissal, so the pool shows everything again.
  static Future<void> clearDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
  }

  /// Best-effort seed: the admin contact line shown in the menu.
  static const adminPhone = '0550123456';

  /// Logs the profile write failures that would otherwise be silent.
  static void logError(String where, Object error) =>
      debugPrint('DriverStore.$where: $error');
}

/// One-shot read of a stream's first value, used by the sign-in flow.
extension FirstValue<T> on Stream<T> {
  /// The first element, or `null` if the stream closes empty.
  Future<T?> firstValue() async {
    await for (final value in this) {
      return value;
    }
    return null;
  }
}
