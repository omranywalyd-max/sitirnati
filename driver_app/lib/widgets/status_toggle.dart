import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// The availability switch: the first thing on the driver's home screen.
///
/// It is a real switch (a 48dp target with a checked state a screen reader can
/// read), not a chip that happens to look on. When it is off the driver stops
/// appearing in the customer's list and the pool below is covered with an
/// explanation instead of silently going empty.
class AvailabilityCard extends StatelessWidget {
  /// Creates the availability card.
  const AvailabilityCard({
    super.key,
    required this.active,
    required this.busy,
    required this.onChanged,
  });

  /// Whether the driver is accepting orders.
  final bool active;

  /// Whether a write is in flight; the switch is locked while it is.
  final bool busy;

  /// Called with the requested value.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      rim: active ? const Color(0x665FD3E8) : AppColors.glassBorder,
      child: Row(
        children: [
          // A single status dot, so the state is legible before the label is
          // read: filled accent when on, hollow grey when off.
          ExcludeSemantics(
            child: AnimatedContainer(
              duration: AppMotion.standard,
              curve: AppMotion.enter,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.accentSoft : const Color(0x0FFFFFFF),
                border: Border.all(
                  color: active ? AppColors.accent : AppColors.glassBorder,
                  width: active ? 1.6 : 1,
                ),
              ),
              child: Icon(
                active
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                size: 22,
                color: active ? AppColors.accent : AppColors.textFaint,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'أنت نشط' : 'أنت غير نشط',
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  active
                      ? 'الطلبات الجديدة تبانلك هنا، و الزبائن يشوفوك في اللائحة.'
                      : 'الزبائن ما يشوفوكش، و ما توصلكش طلبات جديدة.',
                  style: text.bodySmall,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Switch(
            value: active,
            onChanged: busy
                ? null
                : (value) {
                    HapticFeedback.selectionClick();
                    onChanged(value);
                  },
          ),
        ],
      ),
    );
  }
}
