import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'pages/home_shell.dart';
import 'pages/splash_page.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full-bleed canvas: the gradient runs under the status and navigation bars,
  // and the pages keep their own SafeArea padding.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(_overlay);

  // Every liquid-glass surface is drawn as lite glass: a real backdrop frost,
  // a tint and a painted rim, with no fragment-shader pass. This device family
  // returns opaque pixels from the Impeller glass shader, and lite glass is
  // also the cheapest path, so the glass stays transparent and smooth on both
  // the Skia and the Impeller backend.
  LiquidGlassEngine.liteGlassOnSkia = true;
  LiquidGlassEngine.liteGlassOnImpeller = true;

  runApp(const SitirnatiApp());
}

/// Transparent system bars with light icons over the dark canvas.
const _overlay = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// Sitirnati: order a water tanker, pin the drop point, send the request.
class SitirnatiApp extends StatelessWidget {
  /// Creates the app.
  const SitirnatiApp({super.key, this.showSplash = true});

  /// Whether the animated splash plays before the shell.
  ///
  /// Tests pass `false`: the splash owns a 1.2 s controller, and every test
  /// would otherwise screenshot it instead of the screen under test.
  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سيترنتي',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Arabic only: the whole product, including its numerals and dates, is
      // written for an Algerian customer.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // The canvas is dark on every screen: force the light-on-dark text
        // scaling metrics and keep the text direction Arabic everywhere.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.6,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: showSplash ? const _Boot() : const HomeShell(),
    );
  }
}

/// Splash, then the shell, cross-faded.
///
/// The shell is built only after the splash is done, so its first layout (the
/// cards, the bar, the glass) does not compete with the splash animation for
/// the first frames.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool _ready = false;

  void _finish() {
    if (!mounted || _ready) return;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: AnimatedSwitcher(
        duration: AppMotion.entrance,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: _ready
            ? const HomeShell(key: ValueKey('shell'))
            : SplashPage(key: const ValueKey('splash'), onDone: _finish),
      ),
    );
  }
}
