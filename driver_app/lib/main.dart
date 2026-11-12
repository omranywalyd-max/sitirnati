import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'firebase_options.dart';
import 'models/driver_profile.dart';
import 'pages/auth_page.dart';
import 'pages/home_shell.dart';
import 'pages/sign_up_page.dart';
import 'pages/splash_page.dart';
import 'services/driver_auth.dart';
import 'services/driver_store.dart';
import 'theme/app_theme.dart';
import 'widgets/app_buttons.dart';

/// Transparent system bars with light icons over the dark canvas.
const _overlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Full-bleed canvas: the gradient runs under the status and navigation bars,
  // and the pages keep their own SafeArea padding.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(_overlay);

  // Every liquid-glass surface is drawn as lite glass: a real backdrop frost, a
  // tint and a painted rim, with no fragment-shader pass. This device family
  // returns opaque pixels from the Impeller glass shader, and lite glass is also
  // the cheapest path.
  LiquidGlassEngine.liteGlassOnSkia = true;
  LiquidGlassEngine.liteGlassOnImpeller = true;

  runApp(const SitirnatiDriverApp());
}

/// Sitirnati Driver: sign in, go available, accept water orders, deliver them.
class SitirnatiDriverApp extends StatelessWidget {
  /// Creates the app.
  const SitirnatiDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سيترنتي للسائق',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Arabic only: the whole product, including its numerals and dates, is
      // written for an Algerian driver.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.6,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const _Boot(),
    );
  }
}

/// Splash, then Firebase, then the session gate.
///
/// Firebase is started **here**, not before `runApp`, so the splash animation
/// covers the initialisation instead of a black frame. A failed boot is a real
/// screen with a retry, never a silent empty app: without a backend this app
/// cannot do anything at all.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool _splashDone = false;
  bool _backendReady = false;
  Object? _backendError;

  @override
  void initState() {
    super.initState();
    _startBackend();
  }

  Future<void> _startBackend() async {
    if (mounted) {
      setState(() {
        _backendReady = false;
        _backendError = null;
      });
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (!mounted) return;
      setState(() => _backendReady = true);
    } catch (error) {
      debugPrint('Firebase boot failed: $error');
      if (!mounted) return;
      setState(() => _backendError = error);
    }
  }

  void _finishSplash() {
    if (!mounted || _splashDone) return;
    setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_splashDone) {
      child = SplashPage(
        key: const ValueKey('splash'),
        onDone: _finishSplash,
      );
    } else if (_backendError != null) {
      child = _BackendErrorPage(
        key: const ValueKey('backend-error'),
        onRetry: _startBackend,
      );
    } else if (!_backendReady) {
      child = const _Booting(key: ValueKey('booting'));
    } else {
      child = const _SessionGate(key: ValueKey('session'));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: AnimatedSwitcher(
        duration: AppMotion.entrance,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: child,
      ),
    );
  }
}

/// Whether there is a session, and whether that session has a profile.
///
/// Two questions, two streams, one screen at a time: signed out → the sign-in
/// page; signed in without a profile → the completion form; otherwise the home
/// shell. Every write the app makes is gated on this, which is why the screens
/// themselves never ask "am I logged in".
class _SessionGate extends StatelessWidget {
  const _SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: DriverAuth.changes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Booting();
        }

        final user = snapshot.data;
        if (user == null) return const AuthPage();

        return _ProfileGate(
          key: ValueKey('profile-${user.uid}'),
          user: user,
        );
      },
    );
  }
}

/// Watches `drivers/{uid}` and decides between the completion form and home.
class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key, required this.user});

  final User user;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  /// Bumped by the retry button; the key change resubscribes the stream.
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return StreamBuilder<DriverProfile?>(
      key: ValueKey('profile-stream-$_attempt'),
      stream: DriverStore.watchProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BackendErrorPage(
            title: 'ما قدرناش نقراو معلومات حسابك',
            message: 'تحقق من اتصال الإنترنت و عاود.',
            onRetry: () => setState(() => _attempt++),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Booting();
        }

        final profile = snapshot.data;
        if (profile == null) {
          final displayName = (user.displayName ?? '').trim();
          final parts = displayName.split(RegExp(r'\s+'));
          return SignUpPage.complete(
            uid: user.uid,
            initialEmail: user.email ?? '',
            initialFirstName: parts.isEmpty ? '' : parts.first,
            initialLastName: parts.length > 1 ? parts.skip(1).join(' ') : '',
          );
        }

        return HomeShell(profile: profile);
      },
    );
  }
}

/// A quiet centred spinner on the brand canvas, used only while a stream has
/// not produced its first value yet.
class _Booting extends StatelessWidget {
  const _Booting({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Semantics(
            label: 'جاري التحميل',
            child: const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The screen shown when the backend cannot be reached at all.
class _BackendErrorPage extends StatelessWidget {
  const _BackendErrorPage({
    super.key,
    this.title = 'ما قدرناش نشعلو الخدمة',
    this.message = 'التطبيق يحتاج اتصال بالإنترنت باش يخدم. '
        'تحقق من الشبكة و عاود.',
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GradientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: AppColors.textFaint,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    PrimaryButton(
                      label: 'عاود المحاولة',
                      icon: Icons.refresh_rounded,
                      onPressed: onRetry,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
