import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// The customer's identity.
///
/// The customer is an **anonymous** Firebase user created on first launch.
/// There is no sign-up screen and no password: the uid exists only so the
/// security rules can answer "is this your order?" and so the same phone keeps
/// its history across reinstalls of the app data.
///
/// The driver has their own app and their own real account, so nothing here
/// touches a driver session any more — the two halves of the product never share
/// a Firebase Auth state.
abstract final class AuthService {
  static Future<User>? _customerBoot;

  /// Starts the anonymous customer session exactly once.
  ///
  /// Called from `main()` but deliberately **not awaited**: the splash plays
  /// while the sign-in happens, and [customerUidOrEmpty] is what the orders
  /// stream waits on. A cold start with no network still ends with a user when
  /// a session was already persisted, because Firebase Auth restores it from
  /// disk before it talks to the network.
  ///
  /// A **failed** boot is not remembered. The first launch on a phone with no
  /// data would otherwise inherit a dead future for the rest of the process —
  /// every write would then be rejected for the whole session, even after the
  /// network came back. Clearing it makes the next caller try again.
  static Future<User> bootCustomer() {
    final pending = _customerBoot;
    if (pending != null) return pending;

    return _customerBoot = _signInCustomer().then(
      (user) => user,
      onError: (Object error, StackTrace stack) {
        _customerBoot = null;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  static Future<User> _signInCustomer() async {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current != null) return current;
    final credential = await auth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous sign-in returned no user.');
    }
    return user;
  }

  /// The customer uid once the session exists, or `''` if it cannot be made.
  ///
  /// Never throws: an offline first launch degrades to the on-device cache
  /// instead of an error screen, and the next call — not just the next launch —
  /// tries the sign-in again.
  static Future<String> customerUidOrEmpty() async {
    try {
      return (await bootCustomer()).uid;
    } catch (error) {
      debugPrint('AuthService: customer sign-in failed: $error');
      return '';
    }
  }

  /// The uid of the signed-in customer, or an empty string before boot.
  static String get customerUid => FirebaseAuth.instance.currentUser?.uid ?? '';
}
