import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

/// The driver's Firebase Auth session.
///
/// One app, one account, one uid. The session is persisted by the SDK itself
/// (Android Keystore-backed storage), so closing and reopening the app lands
/// straight on the home screen — [restored] is what the splash waits on.
abstract final class DriverAuth {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static GoogleSignIn? _google;
  static bool _googleReady = false;

  /// The signed-in driver, or `null`.
  static User? get user => _auth.currentUser;

  /// Emits on every sign-in and sign-out.
  static Stream<User?> get changes => _auth.authStateChanges();

  /// Resolves with the persisted session on a cold start, without a network
  /// round-trip: Firebase Auth restores the user from disk first.
  static Future<User?> restored() async {
    try {
      return await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 6),
        onTimeout: () => _auth.currentUser,
      );
    } catch (error) {
      debugPrint('DriverAuth.restored: $error');
      return _auth.currentUser;
    }
  }

  /// Signs in with email and password.
  static Future<User> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const DriverAuthFailure('ما قدرناش ندخلوك. عاود المحاولة.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw DriverAuthFailure(messageFor(error));
    }
  }

  /// Creates the account. The profile document is written by [DriverStore]
  /// right after, because it needs the uid the server assigns.
  static Future<User> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const DriverAuthFailure('ما قدرناش ننشئو الحساب. عاود المحاولة.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      throw DriverAuthFailure(messageFor(error));
    }
  }

  /// Signs in with the Google account already on the phone.
  ///
  /// Uses Credential Manager through `google_sign_in` 7, which mints an ID
  /// token from the *Android* OAuth client — the one identified by the package
  /// name plus the signing SHA-1 registered in the Firebase console. No Web
  /// client secret is involved and the user never leaves the app.
  static Future<User> signInWithGoogle() async {
    final google = await _googleInstance();
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const DriverAuthFailure(
          'Google ما رجعش رمز الدخول. تحقق من اتصال الإنترنت وعاود.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw const DriverAuthFailure('ما قدرناش ندخلوك بحساب Google.');
      }
      return user;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const DriverAuthFailure('لغيت الدخول بحساب Google.');
      }
      throw DriverAuthFailure(_googleMessageFor(error));
    } on FirebaseAuthException catch (error) {
      throw DriverAuthFailure(messageFor(error));
    }
  }

  static Future<GoogleSignIn> _googleInstance() async {
    final existing = _google;
    if (existing != null) return existing;
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      // `initialize` throws if it is called twice; the flag keeps a hot restart
      // from tripping over it.
      await google.initialize();
      _googleReady = true;
    }
    _google = google;
    return google;
  }

  /// Ends the session.
  static Future<void> signOut() async {
    try {
      final google = _google;
      if (google != null && google.supportsAuthenticate()) {
        await google.signOut();
      }
    } catch (error) {
      debugPrint('DriverAuth: Google sign-out skipped: $error');
    }
    await _auth.signOut();
  }

  /// Arabic copy for the auth errors a driver can actually hit.
  static String messageFor(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-credential' ||
      'invalid-email' ||
      'user-not-found' ||
      'wrong-password' =>
        'الإيميل ولا كلمة السر غالطة. عاود جرّب.',
      'email-already-in-use' =>
        'هذا الإيميل مستعمل من قبل. دخل بيه ولا بدّل إيميل آخر.',
      'weak-password' => 'كلمة السر ضعيفة: 6 حروف ولا أكثر.',
      'user-disabled' => 'هذا الحساب مسدود. اتصل بالمشغّل.',
      'too-many-requests' =>
        'محاولات كثيرة في وقت قصير. استنى شوية وعاود.',
      'network-request-failed' =>
        'ما كاينش اتصال بالإنترنت. تحقق من الشبكة وعاود.',
      'operation-not-allowed' =>
        'هذا النوع من الدخول ماشي مفعّل في المشروع. اتصل بالمشغّل.',
      'account-exists-with-different-credential' =>
        'هذا الإيميل مسجل بطريقة دخول أخرى. دخل بالإيميل وكلمة السر.',
      _ => 'صار مشكل في الدخول. عاود المحاولة.',
    };
  }

  static String _googleMessageFor(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'لغيت الدخول بحساب Google.',
      GoogleSignInExceptionCode.interrupted ||
      GoogleSignInExceptionCode.uiUnavailable =>
        'ما قدرناش نفتحو شاشة Google. عاود المحاولة.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'إعدادات Google ماشي كاملة في هذا الإصدار. دخل بالإيميل وكلمة السر.',
      _ => 'ما قدرناش ندخلوك بحساب Google. جرّب بالإيميل.',
    };
  }
}

/// A sign-in failure with copy that is safe to show as-is.
class DriverAuthFailure implements Exception {
  /// Creates the failure with the message shown under the form.
  const DriverAuthFailure(this.message);

  /// Arabic message for the driver.
  final String message;

  @override
  String toString() => message;
}
