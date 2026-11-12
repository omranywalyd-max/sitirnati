import 'package:flutter/material.dart';

import '../data/sample_trucks.dart';
import '../models/truck.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/glass_surface.dart';
import '../widgets/truck_card.dart';

/// Tab one: the driver directory.
///
/// One leading element (the display title), then a water-type filter, then the
/// cards. Nothing competes with the title for the first look.
class BrowsePage extends StatefulWidget {
  /// Creates the browse tab.
  const BrowsePage({super.key, required this.onOrderTruck});

  /// Called with the truck whose card was tapped.
  final ValueChanged<Truck> onOrderTruck;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const _all = 'الكل';

  String _filter = _all;

  List<String> get _waterTypes {
    final types = <String>[];
    for (final truck in sampleTrucks) {
      if (!types.contains(truck.waterType)) types.add(truck.waterType);
    }
    return types;
  }

  List<Truck> get _visible {
    if (_filter == _all) return sampleTrucks;
    return sampleTrucks.where((t) => t.waterType == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trucks = _visible;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.md,
              AppSpace.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The morph menu button floats over the empty slot at the
                  // end of this row.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('سيترنتي', style: text.displaySmall),
                            const SizedBox(height: 6),
                            Text(
                              'ماء يوصلك لباب الدار. اختار السائق، '
                              'حدد مكانك بالخريطة، وابعث الطلب.',
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 60),
                      const SizedBox(height: 52),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Row(
                    children: [
                      // Flexible + ellipsis: a long Arabic section title at a
                      // large text scale shortens instead of overflowing.
                      Flexible(
                        child: Text(
                          'السائقون المتوفرون',
                          style: text.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Text(
                          '${trucks.length}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final type in [_all, ..._waterTypes])
                        _FilterChip(
                          label: type,
                          selected: _filter == type,
                          onTap: () => setState(() => _filter = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                ],
              ),
            ),
          ),
          if (trucks.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.pageBottom,
              ),
              sliver: SliverToBoxAdapter(
                child: _NoResults(
                  onReset: () => setState(() => _filter = _all),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.pageBottom,
              ),
              sliver: SliverList.separated(
                itemCount: trucks.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                itemBuilder: (context, index) {
                  final truck = trucks[index];
                  return _Reveal(
                    index: index,
                    child: TruckCard(
                      truck: truck,
                      onOrder: () => widget.onOrderTruck(truck),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A single-select filter chip drawn as glass, with the selected state carrying
/// both a fill change and a check mark so colour is never the only signal.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          splashColor: AppColors.accentSoft,
          child: AnimatedContainer(
            duration: AppMotion.micro,
            curve: AppMotion.enter,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.accentSoft : const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.glassBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the filter matches nothing.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.xxl,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 40,
            color: AppColors.textFaint,
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'ما لقيناش سائق في هذا النوع',
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'جرّب نوع ماء آخر، ولا ورّي كل السائقين.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.lg),
          SecondaryButton(label: 'ورّيني الكل', onPressed: onReset),
        ],
      ),
    );
  }
}

/// Fades and lifts a card into place once, staggered by its position.
///
/// Honours the platform's "remove animations" setting: with animations
/// disabled the child is shown immediately, never animated.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal>
    with SingleTickerProviderStateMixin {
  static const _baseDuration = 420;
  static const _stepDelay = 55;

  late final int _delayMs =
      widget.index.clamp(0, 6) * _stepDelay;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _baseDuration + _delayMs),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    // The stagger is an interval on one controller rather than a timer, so the
    // widget never leaves a pending timer behind when it is disposed.
    curve: Interval(
      _delayMs / (_baseDuration + _delayMs),
      1,
      curve: AppMotion.enter,
    ),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
