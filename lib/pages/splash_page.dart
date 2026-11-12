import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The first frame of the app: the mark, the name and one breath of motion.
///
/// It is not a loading screen — there is nothing to load. It is the brand
/// moment that covers the engine's first frame, so the app opens on something
/// composed instead of on a half-painted list.
///
/// One controller drives the whole sequence, so the parts read as a single
/// gesture: the mark settles, a halo breathes out of it, the name rises, and a
/// hairline fills up to say "we are about to be there". It always ends on its
/// own; it never waits for a network.
class SplashPage extends StatefulWidget {
  /// Creates the splash.
  const SplashPage({super.key, required this.onDone});

  /// Called once the sequence is finished (or skipped, under reduced motion).
  final VoidCallback onDone;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1200);

  /// How long the finished frame is held when animations are switched off, so
  /// the brand does not flash past in one frame.
  static const _reducedHold = Duration(milliseconds: 500);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  late final Animation<double> _markScale = Tween<double>(begin: 0.84, end: 1)
      .animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.4, curve: Curves.easeOutBack),
        ),
      );

  late final Animation<double> _markFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.24, curve: AppMotion.enter),
  );

  late final Animation<double> _halo = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.08, 0.62, curve: Curves.easeOut),
  );

  late final Animation<double> _name = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.18, 0.58, curve: AppMotion.enter),
  );

  late final Animation<double> _tagline = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 0.7, curve: AppMotion.enter),
  );

  late final Animation<double> _line = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.05, 0.95, curve: AppMotion.enter),
  );

  Timer? _holdTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onDone();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // "Remove animations" is honoured literally: land on the finished frame and
    // hold it for a beat instead of playing the sequence. The completion
    // listener is detached first so the jump to 1 does not also fire `onDone`.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.removeStatusListener(_onStatus);
      _controller.value = 1;
      _holdTimer = Timer(_reducedHold, widget.onDone);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GradientBackdrop(
      // The canvas comes from the backdrop; the scaffold is here for Material
      // (text metrics, the default text style) and nothing else.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Semantics(
          container: true,
          label: 'سيترنتي',
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Mark(scale: _markScale, fade: _markFade, halo: _halo),
                const SizedBox(height: AppSpace.xxl),
                _RiseIn(
                  animation: _name,
                  child: Text(
                    'سيترنتي',
                    textAlign: TextAlign.center,
                    style: text.displaySmall?.copyWith(
                      fontSize: 34,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                _RiseIn(
                  animation: _tagline,
                  child: Text(
                    'ماء يوصلك لباب الدار',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textFaint,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.huge),
                _ProgressLine(progress: _line),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app mark: a glass tile with the water glyph, and the halo that breathes
/// out of it once.
class _Mark extends StatelessWidget {
  const _Mark({required this.scale, required this.fade, required this.halo});

  final Animation<double> scale;
  final Animation<double> fade;
  final Animation<double> halo;

  static const _box = 148.0;
  static const _tile = 96.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: _box,
        height: _box,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo: a thin accent ring that expands past the tile and fades.
            FadeTransition(
              opacity: Tween<double>(begin: 0.55, end: 0).animate(halo),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.72, end: 1).animate(halo),
                child: Container(
                  width: _box,
                  height: _box,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.6),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            // A second, softer glow so the tile is not floating on nothing.
            FadeTransition(
              opacity: fade,
              child: Container(
                width: _box * 0.86,
                height: _box * 0.86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.18),
                      AppColors.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            ScaleTransition(
              scale: scale,
              child: FadeTransition(
                opacity: fade,
                child: Container(
                  width: _tile,
                  height: _tile,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x4D5FD3E8), Color(0x0D5FD3E8)],
                    ),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.45),
                      width: 1.3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x665FD3E8),
                        blurRadius: 34,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    size: 46,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades a child in while it rises a few pixels.
class _RiseIn extends StatelessWidget {
  const _RiseIn({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.22),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

/// A hairline that fills from the right (the reading direction) as the app
/// settles.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final Animation<double> progress;

  static const _width = 132.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: _width,
        height: 3,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x1FFFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox.expand(),
            ),
            AnimatedBuilder(
              animation: progress,
              builder: (context, _) {
                final value = progress.value.clamp(0.0, 1.0);
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [AppColors.accentDeep, AppColors.accent],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
