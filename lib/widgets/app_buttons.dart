import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// Height of every primary touch target in the app: 52dp, above the 48dp
/// Android minimum so the target stays comfortable inside a sheet.
const kButtonHeight = 52.0;

/// The primary action, as accent-tinted glass.
///
/// It keeps the strongest visual weight on the screen (it is the only filled
/// accent surface) while belonging to the same material family as the bottom
/// bar: frosted backdrop, translucent tint, top sheen, bright rim. The label
/// stays the dark [AppColors.onAccent], measured at 6.49:1 on the tint.
class PrimaryButton extends StatelessWidget {
  /// Creates a primary action button.
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
  });

  /// Button label, always a verb phrase.
  final String label;

  /// Tap handler. `null` disables the button.
  final VoidCallback? onPressed;

  /// Optional leading glyph.
  final IconData? icon;

  /// Replaces the label with a spinner and blocks taps.
  final bool busy;

  /// Whether the button fills the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    final content = SizedBox(
      height: kButtonHeight,
      child: Center(
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.onAccent),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: AppColors.onAccent),
                    const SizedBox(width: AppSpace.sm),
                  ],
                  // Flexible keeps a long label on one line inside a narrow
                  // button (a card CTA, or a large text-scale setting).
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onAccent,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: busy ? '$label، جاري الإرسال' : label,
      child: GlassSurface(
        radius: AppRadius.field,
        padding: EdgeInsets.zero,
        tint: enabled ? AppGlass.buttonTint : const Color(0x14FFFFFF),
        rim: enabled ? AppGlass.rimStrong : AppColors.glassBorder,
        blur: AppGlass.buttonBlur,
        shadow: enabled,
        onTap: enabled ? onPressed : null,
        splashColor: const Color(0x33FFFFFF),
        highlightColor: const Color(0x1FFFFFFF),
        child: enabled
            ? content
            : Opacity(
                opacity: 0.55,
                child: IconTheme.merge(
                  data: const IconThemeData(color: AppColors.textFaint),
                  child: content,
                ),
              ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The secondary action: neutral glass, the same material as the bottom bar.
class SecondaryButton extends StatelessWidget {
  /// Creates a secondary action button.
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.tone = AppColors.textPrimary,
  });

  /// Button label.
  final String label;

  /// Tap handler. `null` disables the button.
  final VoidCallback? onPressed;

  /// Optional leading glyph.
  final IconData? icon;

  /// Whether the button fills the available width.
  final bool expand;

  /// Label and glyph colour, so destructive actions can wear the danger token.
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    final content = SizedBox(
      height: kButtonHeight,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: enabled ? tone : AppColors.textFaint),
              const SizedBox(width: AppSpace.sm),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? tone : AppColors.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final button = GlassSurface(
      radius: AppRadius.field,
      padding: EdgeInsets.zero,
      tint: AppGlass.controlTint,
      rim: AppColors.glassBorder,
      blur: AppGlass.buttonBlur,
      shadow: false,
      onTap: onPressed,
      child: content,
    );

    return SizedBox(width: expand ? double.infinity : null, child: button);
  }
}

/// A square glass icon button with a tooltip, used for back, close and delete.
class GlassIconButton extends StatelessWidget {
  /// Creates a glass icon button.
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.tone = AppColors.textPrimary,
  });

  /// Glyph to draw.
  final IconData icon;

  /// Tooltip and screen-reader label.
  final String tooltip;

  /// Tap handler.
  final VoidCallback? onPressed;

  /// Side length of the square target.
  final double size;

  /// Glyph colour.
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassSurface(
        radius: size / 2,
        padding: EdgeInsets.zero,
        tint: AppGlass.controlTint,
        rim: AppColors.glassBorder,
        blur: AppGlass.buttonBlur,
        shadow: false,
        onTap: onPressed,
        semanticLabel: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.48,
            color: onPressed == null ? AppColors.textFaint : tone,
          ),
        ),
      ),
    );
  }
}
