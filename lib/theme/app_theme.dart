import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Sitirnati design tokens: a dark water-delivery theme.
///
/// Every surface in the app references these instead of raw values, so the
/// whole product re-skins from this one file. Three tiers, in practice:
/// primitives live in [AppColors], semantic roles are the named getters, and
/// components consume the semantic names (for example a card uses
/// `AppColors.surfaceGlass`, never `Color(0x8A0C0C0F)`).
///
/// Contrast of every text/background pair shipped here was measured, not
/// eyeballed: see `tool/contrast_check.mjs`.
abstract final class AppColors {
  // ---- Canvas: black easing into graphite gray. ----
  static const bgTop = Color(0xFF050506);
  static const bgMid = Color(0xFF0A0A0B);
  static const bgDeep = Color(0xFF121214);
  static const bgLow = Color(0xFF1E1E22);
  static const bgBottom = Color(0xFF2A2A2F);

  /// Smoke drawn behind the glass: soft gray clouds, deliberately dim so text
  /// stays legible on every part of the canvas.
  static const cloud = Color(0x8C5A5A64);

  // ---- Water cyan accent. One accent only; neutrals carry the weight. ----
  static const accent = Color(0xFF5FD3E8);
  static const accentDeep = Color(0xFF2A9FB4);
  static const accentSoft = Color(0x335FD3E8);
  static const onAccent = Color(0xFF04262B);

  // ---- Text. ----
  static const textPrimary = Color(0xFFF3F3F5);
  static const textSecondary = Color(0xFFC4C4CD);
  static const textFaint = Color(0xFFA9A9B3);

  // ---- Surfaces. ----
  /// Card / panel tint: smoked glass at 54%, so the blurred clouds behind the
  /// card stay visible and every text pair still clears 4.5:1 over the
  /// brightest cloud region. Measured in `tool/contrast_check.mjs`.
  static const surfaceGlass = Color(0x8A0C0C0F);

  /// Heavier fill for sheets and dialogs, which sit over live content and hold
  /// form fields.
  static const surfaceSheet = Color(0xE60D0D10);

  /// Field fill inside a card or sheet.
  static const surfaceField = Color(0x14FFFFFF);

  /// Hairline rim on glass panels.
  static const glassBorder = Color(0x33FFFFFF);

  /// Rim on form fields: bright enough to identify the control on its own
  /// (>= 3:1 against the surface it sits on).
  static const fieldBorder = Color(0x73FFFFFF);

  static const divider = Color(0x1FFFFFFF);

  // ---- Bottom bar. Faint blue selection, never a white pill. ----
  /// Selection capsule: the accent at 26%. On the bar's smoked glass this reads
  /// as a soft blue capsule, not as a white chip, and the label on top of it
  /// still clears 4.5:1.
  static const barPill = Color(0x425FD3E8);

  /// Selected icon and label: light cyan, 6.9:1 on the capsule and 12.3:1 on
  /// the bar itself.
  static const barSelected = Color(0xFFB7ECF5);

  /// Unselected icon and label: white at 85%, 12.2:1 on the bar.
  static const barIdle = Color(0xD9FFFFFF);

  // ---- Status. ----
  static const success = Color(0xFF7BE495);
  static const warning = Color(0xFFFFC46B);
  static const danger = Color(0xFFFF8A8A);
  static const dangerSoft = Color(0x33FF8A8A);
}

/// The one glass recipe, shared by every surface in the app.
///
/// It is the bottom bar's own recipe — a clipped [BackdropFilter] that blurs
/// *and* saturates the content behind it, a translucent tint, a top sheen and
/// a hairline rim — so a card, a button and the bar read as the same material.
/// Only the tint and the blur radius change with the surface.
abstract final class AppGlass {
  /// Blur sigma for cards and list rows: **none**.
  ///
  /// A card sits on the canvas, and the canvas is already soft (a baked,
  /// blurred cloud field). Blurring a blur is invisible on screen but is paid
  /// for on every frame of every scroll, per card — this was the main cause of
  /// the scroll jank. The smoked tint, the sheen and the rim carry the material;
  /// the frost is kept only where content actually moves behind the glass.
  static const cardBlur = 0.0;

  /// Blur sigma for sheets, dialogs and the floating panels on the map: these
  /// really do float over scrolling content, so the frost is the point.
  static const sheetBlur = 14.0;

  /// Blur sigma for buttons: none, same reasoning as [cardBlur].
  static const buttonBlur = 0.0;

  /// Saturation boost applied with the blur: frosted glass brightens what it
  /// covers instead of washing it to grey.
  static const saturation = 1.35;

  /// Accent-tinted glass, used by the primary action.
  static const buttonTint = Color(0xCC5FD3E8);

  /// Neutral glass, used by secondary actions and icon buttons.
  static const controlTint = Color(0x1FFFFFFF);

  /// The bottom bar's own tint: the card tint at 60%, a touch heavier because
  /// the bar floats over whatever scrolls behind it. A lighter tint let the bar
  /// pick up the colour of the content underneath (it went teal over a card),
  /// which made a faint blue selection impossible to see.
  static const barTint = Color(0x990C0C10);

  /// Rim on a filled accent control.
  static const rimStrong = Color(0x73FFFFFF);

  /// Top sheen: a 10% white wash that fades out, painted over the frost.
  static const sheen = Color(0x1AFFFFFF);

  /// Contact shadow under a floating panel.
  ///
  /// Kept tight (18 / 8): a wide soft shadow under every card is one more blur
  /// per card per frame, and the canvas is dark enough that a tight shadow
  /// separates the panel just as well.
  static const List<BoxShadow> shadow = [
    BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

/// 4pt spacing rhythm. Named so a layout reads as intent, not arithmetic.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const huge = 32.0;

  /// Bottom breathing room under a scrolling page so the floating bar never
  /// covers the last card.
  static const pageBottom = 132.0;
}

/// Corner radii. The bar is a capsule, panels are 24, inner chips are 12.
abstract final class AppRadius {
  static const chip = 12.0;
  static const field = 16.0;
  static const panel = 22.0;
  static const sheet = 28.0;
}

/// Motion tokens: micro feedback is fast, entrances are slower, everything
/// uses one of two curves so the app feels like one hand made it.
abstract final class AppMotion {
  static const micro = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 240);
  static const entrance = Duration(milliseconds: 420);

  static const enter = Cubic(0.16, 1.0, 0.3, 1.0);
  static const exit = Cubic(0.4, 0.0, 1.0, 1.0);
}

/// The black-to-gray gradient canvas behind every screen: a vertical ramp, soft
/// gray clouds, and a smoked sheet over them, so the glass surfaces above
/// always have something uneven to sit on.
///
/// ## Why this is cheap
///
/// The canvas never changes, so it is painted **once**. It used to draw twelve
/// radial blobs every frame inside a full-screen [ImageFiltered] with a
/// 70-sigma blur — a screen-sized blur re-rasterised on every frame of every
/// scroll and every tab switch. That was the single most expensive thing in the
/// app. Now:
///
/// * the ramp is one GPU gradient fill (free, and no banding);
/// * the blurred clouds are baked once into a small image ([_CloudBake]), and
///   every later frame is one textured rectangle;
/// * the whole static stack sits in a [RepaintBoundary], so the scrolling
///   content above it never invalidates it.
///
/// The look is unchanged: the bake uses the same blob geometry, the same
/// gradient stops and the same blur sigma as the live version it replaced,
/// which is still there as a fallback.
class GradientBackdrop extends StatelessWidget {
  /// Creates the gradient backdrop around [child].
  const GradientBackdrop({super.key, required this.child});

  /// Screen content drawn above the gradient.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: RepaintBoundary(child: _StaticCanvas())),
        child,
      ],
    );
  }
}

/// The three static layers of the canvas, cached as one layer.
class _StaticCanvas extends StatelessWidget {
  const _StaticCanvas();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        // 1. The vertical ramp: black easing into graphite gray.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _rampColors,
              stops: _rampStops,
            ),
          ),
        ),
        // 2. The clouds.
        _Clouds(),
        // 3. A smoked sheet over the clouds: the gray reads as something blurred
        //    *under* a dark surface rather than painted on top of it.
        ColoredBox(color: Color(0x3D000000)),
      ],
    );
  }
}

const _rampColors = <Color>[
  AppColors.bgTop,
  AppColors.bgMid,
  AppColors.bgDeep,
  AppColors.bgLow,
  AppColors.bgBottom,
];
const _rampStops = <double>[0.0, 0.28, 0.55, 0.82, 1.0];

/// The cloud field: the baked image when the engine can bake, the live
/// [ImageFiltered] version otherwise.
class _Clouds extends StatelessWidget {
  const _Clouds();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
        final baked = _CloudBake.imageFor(size);
        if (baked != null) {
          return CustomPaint(
            size: size,
            isComplex: true,
            painter: _BakedClouds(baked),
          );
        }
        return _LiveClouds(size: size);
      },
    );
  }
}

/// Draws the baked cloud field stretched over the canvas.
class _BakedClouds extends CustomPainter {
  const _BakedClouds(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_BakedClouds oldDelegate) => oldDelegate.image != image;
}

/// The original live implementation, kept as the fallback: twelve blobs inside
/// one 70-sigma blur. Identical pixels to the bake, far more expensive.
class _LiveClouds extends StatelessWidget {
  const _LiveClouds({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (fx, fy, fd) in _scatter)
            Positioned(
              left: fx * size.width - (fd * size.width) / 2,
              top: fy * size.height - (fd * size.width) / 2,
              width: fd * size.width,
              height: fd * size.width,
              child: const _GrayBlob(),
            ),
        ],
      ),
    );
  }
}

/// Bakes the blurred cloud field once, at a fraction of the screen size.
///
/// The canvas is a smooth, low-contrast gradient, so a third of the resolution
/// upscaled with bilinear filtering is indistinguishable from the full-size
/// version — and it is ~150 KB instead of a per-frame blur. One image is kept
/// per window size; a resize (rotation, split screen) simply bakes again and
/// lets the previous image go, which is bounded and tiny.
abstract final class _CloudBake {
  /// Baked resolution relative to the logical size.
  static const _scale = 0.34;

  /// Sigma of the group blur, in logical pixels (the old live value).
  static const _sigma = 70.0;

  static ui.Image? _image;
  static Size? _size;
  static bool _unavailable = false;

  /// The baked field for [size], or `null` if this engine cannot bake.
  static ui.Image? imageFor(Size size) {
    if (_unavailable) return null;
    final cached = _image;
    if (cached != null && _size == size) return cached;
    try {
      final baked = _bake(size);
      _image = baked;
      _size = size;
      return baked;
    } catch (_) {
      // Baking is an optimisation, never a requirement: fall back to the live
      // filter and stop retrying.
      _unavailable = true;
      return null;
    }
  }

  static ui.Image _bake(Size size) {
    final w = math.max(1, (size.width * _scale).round());
    final h = math.max(1, (size.height * _scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    // Everything is drawn in logical pixels; the matrix shrinks the drawing —
    // the blur sigma included — into the small bitmap, so the result matches
    // the live filter.
    canvas.scale(w / size.width, h / size.height);
    final rect = Offset.zero & size;

    // The blobs are blurred as one group, exactly like the live filter. The
    // layer is inflated by 3 sigma so clouds bleeding off an edge still feed
    // the blur.
    canvas.saveLayer(
      rect.inflate(_sigma * 3),
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _sigma,
          sigmaY: _sigma,
          tileMode: ui.TileMode.decal,
        ),
    );
    for (final (fx, fy, fd) in _scatter) {
      final center = Offset(fx * size.width, fy * size.height);
      final radius = fd * size.width / 2;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            _cloudColors,
            _cloudStops,
          ),
      );
    }
    canvas.restore();

    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }
}

/// Where the gray clouds sit: `(x, y, diameter)` as canvas fractions. Values
/// outside 0..1 bleed off the edge; the diameter is relative to the canvas
/// width so the clouds keep their shape on any screen.
const _scatter = <(double, double, double)>[
  (1.02, -0.01, 0.88),
  (0.78, 0.05, 0.64),
  (1.16, 0.14, 0.70),
  (0.62, -0.06, 0.48),
  (0.50, 0.45, 0.74),
  (0.30, 0.55, 0.56),
  (0.72, 0.60, 0.62),
  (0.55, 0.34, 0.46),
  (-0.04, 1.03, 0.94),
  (0.20, 0.90, 0.64),
  (-0.18, 0.78, 0.70),
  (0.36, 1.08, 0.48),
];

/// One cloud puff. No solid core, no hard rim: alpha falls across the whole
/// radius and lands on zero exactly at the edge.
///
/// The same colours and stops feed the bake ([_CloudBake]), so both paths draw
/// the identical field.
class _GrayBlob extends StatelessWidget {
  const _GrayBlob();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: _cloudColors, stops: _cloudStops),
      ),
    );
  }
}

/// Cloud colour ramp, dimmed on purpose so text stays legible everywhere.
const _cloudColors = <Color>[
  AppColors.cloud,
  Color(0x7A53535C),
  Color(0x5E4A4A52),
  Color(0x3D3C3C44),
  Color(0x1F2C2C33),
  Color(0x001F1F25),
];
const _cloudStops = <double>[0.0, 0.28, 0.5, 0.7, 0.88, 1.0];

/// The app theme: dark, Tajawal, one cyan accent, no Material purple anywhere.
ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.accent,
        onSecondary: AppColors.onAccent,
        surface: AppColors.bgDeep,
        onSurface: AppColors.textPrimary,
        surfaceContainerHigh: AppColors.surfaceSheet,
        error: AppColors.danger,
        onError: AppColors.bgTop,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: AppColors.bgTop,
    canvasColor: AppColors.bgTop,
    // InkRipple is a plain canvas ripple. InkSparkle is a fragment shader that
    // compiles on the first tap (a visible stutter) and costs more on every
    // card it lands on.
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      // Display: 2.4x the body size, short, one per screen.
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.35,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textFaint,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceField,
      hintStyle: const TextStyle(
        color: AppColors.textFaint,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      floatingLabelStyle: const TextStyle(
        color: AppColors.accent,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
      ),
      errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12.5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF16161A),
      contentTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'Tajawal',
        fontSize: 14,
        height: 1.4,
      ),
      actionTextColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      insetPadding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.pageBottom,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceSheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
    ),
  );
}
