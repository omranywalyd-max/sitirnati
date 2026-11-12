import 'dart:async';
import 'dart:convert';

// `hide Order`: cloud_firestore exports a class of that name (an index
// definition), and this file's `Order` is the app's own model. Without the
// hide, every mention of `Order` here is ambiguous.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import 'auth_service.dart';

/// The one place the customer's orders are read and written.
///
/// Orders live in Cloud Firestore, at `orders/{id}`. The device keeps the last
/// list it saw in [SharedPreferences] so the orders tab paints from disk on a
/// cold start instead of showing an empty screen while the network answers.
///
/// One query, one collection: the customer streams the orders where
/// `customerUid == their uid`. The driver side runs in a different app, so
/// nothing here ever writes a driver field — the claim is the driver's write.
///
/// No server-side `orderBy`: a `where` plus an `orderBy` on another field needs
/// a composite index, and this list is a handful of rows — sorting in Dart is
/// free and keeps the project index-free.
abstract final class OrdersStore {
  static const _cacheKey = 'sitirnati_orders_v2';

  static CollectionReference<Map<String, dynamic>> get _orders =>
      FirebaseFirestore.instance.collection('orders');

  /// The last list written to this device, newest first.
  static Future<List<Order>> cached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      // A corrupted cache is dropped instead of crashing the app.
      await prefs.remove(_cacheKey);
      return const [];
    }
  }

  static Future<void> _writeCache(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(orders.map((o) => o.toJson()).toList()),
    );
  }

  /// Live customer orders, newest first.
  ///
  /// The stream waits for the anonymous session before it subscribes, so the
  /// query is never built with an empty uid (which would match nothing and then
  /// never retry). If the session cannot be created at all the stream falls
  /// back to the on-device cache, so an offline first launch still shows what
  /// this phone knows.
  static Stream<List<Order>> watchCustomer() async* {
    final uid = await AuthService.customerUidOrEmpty();
    if (uid.isEmpty) {
      yield await cached();
      return;
    }

    yield* _orders.where('customerUid', isEqualTo: uid).snapshots().map(
      (snapshot) {
        final orders = snapshot.docs
            .map((doc) => Order.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        unawaited(_writeCache(orders));
        return orders;
      },
    );
  }

  /// Writes a new order and seeds the on-device cache with it.
  ///
  /// With no network the write stays queued in Firestore's local queue and the
  /// document already appears in the local snapshot, so the customer sees their
  /// order immediately either way.
  static Future<void> place(Order order) async {
    final previous = await cached();
    await _writeCache(<Order>[order, ...previous]);
    await _orders.doc(order.id).set(order.toFirestore());
  }

  /// Cancels an order the customer no longer wants.
  ///
  /// The document stays: the driver who already accepted it needs to see that
  /// the job was called off, and a deleted row would leave them driving to an
  /// address nobody wants water at. Only the status changes.
  static Future<void> cancel(Order order) async {
    final next = order.withStatus(OrderStatus.cancelled);
    final previous = await cached();
    await _writeCache([
      for (final cachedOrder in previous)
        if (cachedOrder.id == order.id) next else cachedOrder,
    ]);
    await _orders.doc(order.id).update({
      'status': OrderStatus.cancelled.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Deletes one of the customer's own orders from their history.
  static Future<void> delete(Order order) async {
    final previous = await cached();
    await _writeCache(
      previous.where((o) => o.id != order.id).toList(growable: false),
    );
    await _orders.doc(order.id).delete();
  }

  /// Deletes every order this customer placed.
  static Future<void> clearMine() async {
    final uid = await AuthService.customerUidOrEmpty();
    await _writeCache(const []);
    if (uid.isEmpty) return;
    final snapshot = await _orders.where('customerUid', isEqualTo: uid).get();
    if (snapshot.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
