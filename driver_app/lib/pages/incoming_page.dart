import 'package:flutter/material.dart';

import '../models/driver_profile.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import '../widgets/glass_surface.dart';
import '../widgets/order_card.dart';
import '../widgets/status_toggle.dart';

/// The first tab: who is available, and the orders waiting for a driver.
///
/// The card order is deliberate. Availability first, because it is the one
/// switch that decides whether work exists at all; then the list, because that
/// is what the driver opened the app for. When the switch is off the list is
/// replaced by an explanation instead of silently going empty — an empty list
/// with no reason reads as a bug.
class IncomingPage extends StatelessWidget {
  /// Creates the incoming-orders tab.
  const IncomingPage({
    super.key,
    required this.profile,
    required this.orders,
    required this.loading,
    required this.active,
    required this.activeBusy,
    required this.busyId,
    required this.onToggleActive,
    required this.onAccept,
    required this.onReject,
    required this.onShowMap,
  });

  /// The signed-in driver.
  final DriverProfile profile;

  /// Unclaimed orders, newest first.
  final List<DriverOrder> orders;

  /// Whether the first snapshot is still on its way.
  final bool loading;

  /// Whether the driver is accepting orders.
  final bool active;

  /// Whether the availability write is in flight.
  final bool activeBusy;

  /// Order id with a write in flight, if any.
  final String? busyId;

  /// Called with the requested availability.
  final ValueChanged<bool> onToggleActive;

  /// Claims an order.
  final ValueChanged<DriverOrder> onAccept;

  /// Hides an order from this phone.
  final ValueChanged<DriverOrder> onReject;

  /// Opens the delivery pin in Google Maps.
  final ValueChanged<DriverOrder> onShowMap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.pageBottom,
      ),
      children: [
        AvailabilityCard(
          active: active,
          busy: activeBusy,
          onChanged: onToggleActive,
        ),
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            Expanded(
              child: Text('الطلبات الجديدة', style: text.titleLarge),
            ),
            if (orders.isNotEmpty && active)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm + 2,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(color: const Color(0x665FD3E8)),
                ),
                child: Text(
                  '${orders.length}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          active
              ? 'طلبات الزبائن لي ما زال ما قبلهمش حتى سائق.'
              : 'ولّي نشط باش توصلك الطلبات.',
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpace.lg),
        if (!active)
          const OrdersEmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'راك غير نشط',
            message: 'كي تكون غير نشط، الزبائن ما يشوفوكش في اللائحة و ما '
                'توصلكش طلبات جديدة. شغّل الزر لفوق باش تبدا.',
          )
        else if (loading && orders.isEmpty)
          const _LoadingCard()
        else if (orders.isEmpty)
          const OrdersEmptyState(
            icon: Icons.inbox_rounded,
            title: 'ما كاينش طلبات دابا',
            message: 'كي يطلب زبون صهريج، الطلب يبان هنا في الحين مع المسافة '
                'بيناتك و بينو. خلّي التطبيق مفتوح.',
          )
        else
          for (final order in orders) ...[
            OrderCard(
              order: order,
              mode: OrderCardMode.pool,
              distanceMetres: driverDistance(profile, order),
              busy: busyId == order.id,
              onAccept: () => onAccept(order),
              onReject: () => onReject(order),
              onShowMap: () => onShowMap(order),
            ),
            const SizedBox(height: AppSpace.md),
          ],
      ],
    );
  }
}

/// The first-snapshot placeholder: one panel, not a wall of spinners.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

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
            'نجيبو في الطلبات…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A panel used when a tab has no orders of its own.
class OrdersEmptyState extends StatelessWidget {
  /// Creates an empty state panel.
  const OrdersEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  /// Glyph shown in the disc.
  final IconData icon;

  /// Short headline.
  final String title;

  /// The explanation underneath.
  final String message;

  /// Optional action under the copy.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x0FFFFFFF),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(icon, size: 24, color: AppColors.textFaint),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(title, textAlign: TextAlign.center, style: text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(height: 1.6),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpace.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
