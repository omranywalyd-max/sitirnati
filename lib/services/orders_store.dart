import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';

/// Local, offline-first order cache backed by [SharedPreferences].
///
/// The app has no accounts and no server yet: every order is stored on the
/// device as JSON and survives restarts.
abstract final class OrdersStore {
  static const _key = 'sitirnati_orders_v1';

  /// Loads the cached orders, newest first.
  static Future<List<Order>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final orders = decoded
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (_) {
      // Corrupted cache: drop it instead of crashing the app.
      await prefs.remove(_key);
      return const [];
    }
  }

  /// Persists [orders] as the full cache contents.
  static Future<void> save(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(orders.map((o) => o.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  /// Clears the whole order cache.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
