import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../theme/app_theme.dart';

/// One row of the morphing glass menu.
class GlassMenuItem {
  /// Creates a menu entry.
  const GlassMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  /// Leading glyph.
  final IconData icon;

  /// Arabic label.
  final String label;

  /// What the entry does. The menu closes before it runs.
  final VoidCallback onTap;
}

/// A circular glass button that flows into a glass menu and back.
///
/// Place it as the last child of a page-level [Stack]: it fills the stack, so
/// while it is closed it only swallows taps on the button itself. While open it
/// paints a full-page barrier, which closes the menu on an outside tap, on an
/// item tap, and on the system back gesture.
///
/// The glass is drawn as *lite* glass (frost, tint, painted rim) because this
/// device family returns opaque pixels from the Impeller shader; the morph then
/// runs on a single spring, which is what a lite surface can render honestly.
class GlassMorphMenu extends StatefulWidget {
  /// Creates the morphing menu layer.
  const GlassMorphMenu({
    super.key,
    required this.items,
    this.icon = Icons.menu_rounded,
    this.anchor = Alignment.topLeft,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.buttonSize = 52,
    this.menuWidth = 232,
    this.rowHeight = 52,
    this.contentColor = AppColors.textPrimary,
    this.motion,
  });

  /// Menu entries, top to bottom.
  final List<GlassMenuItem> items;

  /// Glyph shown on the closed button.
  final IconData icon;

  /// Corner the button is pinned to and the menu grows from.
  final Alignment anchor;

  /// Padding around the button inside the safe area.
  final EdgeInsets padding;

  /// Diameter of the closed button. Kept at 52 for a comfortable target.
  final double buttonSize;

  /// Width of the open menu.
  final double menuWidth;

  /// Height of one menu row.
  final double rowHeight;

  /// Glyph and label colour.
  final Color contentColor;

  /// Motion preset; `null` uses [LiquidGlassMorphMotion.anchoredPop].
  final LiquidGlassMorphMotion? motion;

  @override
  State<GlassMorphMenu> createState() => _GlassMorphMenuState();
}

class _GlassMorphMenuState extends State<GlassMorphMenu> {
  static const double _verticalPadding = 8;

  bool _open = false;

  /// One immutable style for the whole lifetime of the widget: rebuilding it
  /// per frame would invalidate the lens every time.
  static const LiquidGlassStyle _style = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 26),
    specular: LiquidGlassLight.specular(thickness: 1.3, intensity: 0.9),
    glow: LiquidGlassLight.glow(intensity: 0.45),
    color: Color(0x2EFFFFFF),
    saturation: 1.05,
    blur: AppGlass.sheetBlur,
    refractionIndex: 1.45,
    refractionWidth: 20,
    dispersion: 0.6,
  );

  void _setOpen(bool value) {
    if (_open == value) return;
    HapticFeedback.selectionClick();
    setState(() => _open = value);
  }

  void _pick(GlassMenuItem item) {
    _setOpen(false);
    item.onTap();
  }

  Widget _buildButton() {
    return SizedBox(
      key: const ValueKey('glass-menu-button'),
      width: widget.buttonSize,
      height: widget.buttonSize,
      child: Semantics(
        button: true,
        label: 'القائمة',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setOpen(true),
          child: Center(
            child: Icon(
              widget.icon,
              color: widget.contentColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    const textStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    return SizedBox(
      key: const ValueKey('glass-menu-content'),
      width: widget.menuWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in widget.items)
              SizedBox(
                height: widget.rowHeight,
                child: Semantics(
                  button: true,
                  label: item.label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pick(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.lg,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: widget.contentColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuHeight =
        widget.items.length * widget.rowHeight + _verticalPadding * 2;
    final boxWidth = math.max(widget.menuWidth, widget.buttonSize);
    final boxHeight = math.max(menuHeight, widget.buttonSize);

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setOpen(false);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_open)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setOpen(false),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: widget.padding,
              child: Align(
                alignment: widget.anchor,
                child: SizedBox(
                  width: boxWidth,
                  height: boxHeight,
                  child: LiquidGlassMorph(
                    alignment: widget.anchor,
                    motion: widget.motion ?? LiquidGlassMorphMotion.anchoredPop,
                    style: _style,
                    child: _open ? _buildMenu() : _buildButton(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
