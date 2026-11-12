import 'package:flutter/material.dart';

import '../models/driver_offer.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/driver_card.dart';
import '../widgets/glass_surface.dart';

/// Tab one: the drivers who are on shift right now.
///
/// One leading element (the display title), then the water-type filter, then the
/// cards. Nothing competes with the title for the first look.
///
/// The list is live: it is a stream of `drivers` documents whose `active` flag
/// is on, so a driver who goes off shift disappears from here within a second,
/// and one who comes on shift appears without a refresh.
class BrowsePage extends StatefulWidget {
  /// Creates the browse tab.
  const BrowsePage({
    super.key,
    required this.offers,
    required this.loading,
    required this.onOrder,
  });

  /// Available drivers, cheapest first.
  final List<DriverOffer> offers;

  /// Whether the first snapshot is still on its way.
  final bool loading;

  /// Called with the offer whose card was tapped.
  final ValueChanged<DriverOffer> onOrder;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const _all = 'الكل';

  String _filter = _all;

  /// The water grades actually present right now.
  ///
  /// Built from the live list, not from a constant: a filter chip that matches
  /// nothing is a dead end, and a grade nobody carries should not be offered.
  List<String> get _waterTypes {
    final types = <String>[];
    for (final offer in widget.offers) {
      if (offer.waterType.isNotEmpty && !types.contains(offer.waterType)) {
        types.add(offer.waterType);
      }
    }
    return types;
  }

  List<DriverOffer> _visible(String filter) {
    if (filter == _all) return widget.offers;
    return widget.offers
        .where((offer) => offer.waterType == filter)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final types = _waterTypes;

    // A filter whose grade no longer exists (the only driver carrying it went
    // off shift) would leave the customer staring at an empty list with a chip
    // they cannot explain, so the selection falls back to "all" — computed here
    // rather than written into the state, because `build` must stay pure.
    final filter = _filter != _all && !types.contains(_filter) ? _all : _filter;
    final offers = _visible(filter);

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
                              'ماء يوصلك لباب الدار. شوف السواقين المتوفرين '
                              'دابا، حدد مكانك بالخريطة، وابعث الطلب.',
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
                          '${widget.offers.length}',
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
                  if (types.length > 1) ...[
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        for (final type in [_all, ...types])
                          _FilterChip(
                            label: type,
                            selected: filter == type,
                            onTap: () => setState(() => _filter = type),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                  ] else
                    const SizedBox(height: AppSpace.xs),
                ],
              ),
            ),
          ),
          if (widget.loading && widget.offers.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.pageBottom,
              ),
              sliver: SliverToBoxAdapter(child: _LoadingDrivers()),
            )
          else if (widget.offers.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.pageBottom,
              ),
              sliver: const SliverToBoxAdapter(child: _NoDrivers()),
            )
          else if (offers.isEmpty)
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
                itemCount: offers.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  return _Reveal(
                    index: index,
                    child: DriverCard(
                      offer: offer,
                      onOrder: () => widget.onOrder(offer),
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

/// Shown when the water-type filter matches nothing.
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

/// Shown when nobody is on shift at all — a different problem from a filter that
/// matches nothing, so it says what actually happened and what to do about it.
class _NoDrivers extends StatelessWidget {
  const _NoDrivers();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.huge,
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accentSoft, Color(0x0D5FD3E8)],
                ),
                border: Border.all(color: const Color(0x4D5FD3E8)),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 30,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'ما كاينش سائق متوفر دابا',
            style: text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'السواقين كيظهرو هنا كي يشعلو «نشط» في تطبيقهم. عاود شوف بعد '
            'شوية — اللائحة تتبدل وحدها بلا ما تعاود تفتح التطبيق.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The first-snapshot placeholder: one panel, not a wall of spinners.
class _LoadingDrivers extends StatelessWidget {
  const _LoadingDrivers();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.huge),
      child: Column(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'نجيبو في السواقين المتوفرين…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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

  late final int _delayMs = widget.index.clamp(0, 6) * _stepDelay;

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
