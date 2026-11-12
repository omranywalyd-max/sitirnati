import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's glass panel.
///
/// This is deliberately the *same* recipe the bottom bar uses
/// (`FallbackGlassLayer` in the nav package): a clipped [BackdropFilter] that
/// blurs **and** saturates what is behind it, a translucent tint over that, a
/// top sheen, and a hairline rim painted on top. A card, a button, a sheet and
/// the bar therefore read as one material; only the tint and the blur radius
/// change.
///
/// ## Why it stays smooth
///
/// * **The blur is off by default** (`AppGlass.cardBlur == 0`). A card sits on
///   the canvas, and the canvas is already soft — a baked, blurred cloud field.
///   Blurring a blur is invisible on screen, yet it was being paid for on every
///   frame of every scroll, once per card. That was the scroll jank. With
///   `blur: 0` the [BackdropFilter] is not built at all: the panel is a tint,
///   a sheen and a rim, which is what the eye reads anyway.
/// * The frost is kept where content actually moves behind the glass — sheets,
///   dialogs, the floating map panels — because there the blur *is* the point.
/// * Small surfaces never blur. A chip inside a card has nothing new to sample.
/// * Blur is dropped when the platform asks for reduced motion / transparency.
class GlassSurface extends StatelessWidget {
  /// Creates a glass panel around [child].
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.panel,
    this.borderRadius,
    this.tint = AppColors.surfaceGlass,
    this.rim = AppColors.glassBorder,
    this.blur = AppGlass.cardBlur,
    this.saturation = AppGlass.saturation,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.splashColor,
    this.highlightColor,
    this.shadow = true,
    this.sheen = true,
  });

  /// Panel content.
  final Widget child;

  /// Corner radius, ignored when [borderRadius] is given.
  final double radius;

  /// Explicit corner radii, used for sheets with square bottom corners.
  final BorderRadius? borderRadius;

  /// Translucent fill painted over the frosted backdrop.
  final Color tint;

  /// Hairline rim colour.
  final Color rim;

  /// Backdrop blur sigma. `0` skips the [BackdropFilter] entirely.
  final double blur;

  /// Saturation boost applied together with the blur.
  final double saturation;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// When set, the whole panel becomes a tappable surface with a ripple, a
  /// focus ring and button semantics.
  final VoidCallback? onTap;

  /// Long-press handler for tappable panels.
  final VoidCallback? onLongPress;

  /// Screen-reader description of the panel when it is a control.
  final String? semanticLabel;

  /// Ink colour for a tap.
  final Color? splashColor;

  /// Ink colour held while pressed.
  final Color? highlightColor;

  /// Whether the panel casts a contact shadow.
  final bool shadow;

  /// Whether the 10% white top sheen is painted.
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final corners = borderRadius ?? BorderRadius.circular(radius);
    // "Remove animations" is the closest signal Flutter exposes for a user who
    // does not want heavy visual effects; honour it and drop the frost.
    final reduceEffects = MediaQuery.disableAnimationsOf(context);
    final sigma = reduceEffects ? 0.0 : blur;

    Widget panel = ClipRRect(
      borderRadius: corners,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // 1. The frost itself, plus the tint laid over the blurred backdrop.
          if (sigma > 0)
            Positioned.fill(
              child: _Frost(tint: tint, sigma: sigma, saturation: saturation),
            )
          else
            Positioned.fill(child: ColoredBox(color: tint)),
          // 2. Sheen: light landing on the top edge of the sheet.
          if (sheen)
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppGlass.sheen, Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
          // 3. Content.
          Padding(padding: padding, child: child),
          // 4. Rim last, so the frost never paints over the edge highlight.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: corners,
                  border: Border.all(color: rim),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (shadow) {
      panel = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corners,
          boxShadow: AppGlass.shadow,
        ),
        child: panel,
      );
    }

    if (onTap == null && onLongPress == null) return panel;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: corners,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: corners,
          splashColor: splashColor ?? AppColors.accentSoft,
          highlightColor: highlightColor ?? const Color(0x0DFFFFFF),
          focusColor: AppColors.accentSoft,
          child: panel,
        ),
      ),
    );
  }
}

/// The frosted layer: blur + saturation of the backdrop, then the tint.
///
/// Uses [BackdropFilter.grouped] when a [BackdropGroup] is in scope so the
/// engine performs a single backdrop pass for every panel in the group.
class _Frost extends StatelessWidget {
  const _Frost({
    required this.tint,
    required this.sigma,
    required this.saturation,
  });

  final Color tint;
  final double sigma;
  final double saturation;

  @override
  Widget build(BuildContext context) {
    final filter = ImageFilter.compose(
      outer: ColorFilter.matrix(_saturationMatrix(saturation)),
      inner: ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.mirror,
      ),
    );
    final tinted = ColoredBox(color: tint);

    if (BackdropGroup.of(context) != null) {
      return BackdropFilter.grouped(filter: filter, child: tinted);
    }
    return BackdropFilter(filter: filter, child: tinted);
  }

  /// Standard luminance-preserving saturation matrix (4x5, row-major), the
  /// same one the bottom bar uses.
  static List<double> _saturationMatrix(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final sr = (1 - s) * lr;
    final sg = (1 - s) * lg;
    final sb = (1 - s) * lb;
    return <double>[
      sr + s, sg, sb, 0, 0, //
      sr, sg + s, sb, 0, 0, //
      sr, sg, sb + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }
}

/// A small rounded label with an icon, used for water type and volume.
///
/// No blur: it lives inside an already-frosted card, so there is nothing new
/// behind it to sample — the tint and the rim are enough.
class MetaChip extends StatelessWidget {
  /// Creates a meta chip.
  const MetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.tint = AppColors.textSecondary,
  });

  /// Leading glyph.
  final IconData icon;

  /// Chip text.
  final String label;

  /// Glyph and text colour.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          // The chip sits in a Wrap, so it can be handed a narrow width (small
          // phone, big text scale). The label truncates rather than pushing the
          // chip past its container.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: tint,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
