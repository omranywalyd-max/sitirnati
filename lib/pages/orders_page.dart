import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_buttons.dart';
import '../widgets/glass_surface.dart';

/// Tab two: everything the customer has ordered, newest first, stored on the
/// device.
class OrdersPage extends StatelessWidget {
  /// Creates the orders tab.
  const OrdersPage({
    super.key,
    required this.orders,
    required this.loading,
    required this.onDelete,
    required this.onBrowse,
  });

  /// Cached orders, newest first.
  final List<Order> orders;

  /// Whether the cache is still being read.
  final bool loading;

  /// Removes one order.
  final ValueChanged<Order> onDelete;

  /// Switches to the browse tab.
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('طلبياتي', style: text.displaySmall),
                        const SizedBox(height: 6),
                        Text(
                          orders.isEmpty
                              ? 'كل طلبية تبعتها تتخزن في هذا الهاتف.'
                              : '${orders.length} طلبية محفوظة في هذا الهاتف.',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 60),
                  const SizedBox(height: 52),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.pageBottom,
            ),
            sliver: SliverToBoxAdapter(
              child: loading
                  ? const _LoadingOrders()
                  : orders.isEmpty
                      ? _EmptyOrders(onBrowse: onBrowse)
                      : Column(
                          children: [
                            for (final order in orders) ...[
                              _OrderCard(
                                order: order,
                                onDelete: () => onDelete(order),
                              ),
                              const SizedBox(height: AppSpace.md),
                            ],
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton rows while the cache is read. Faster than a spinner and it does not
/// shift the layout when the real rows arrive.
class _LoadingOrders extends StatelessWidget {
  const _LoadingOrders();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(120, 16),
                  const SizedBox(height: AppSpace.md),
                  _bar(double.infinity, 12),
                  const SizedBox(height: AppSpace.sm),
                  _bar(180, 12),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _bar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// The empty state: says what will appear here and gives the one next action.
class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.onBrowse});

  final VoidCallback onBrowse;

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
          Container(
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
              Icons.receipt_long_rounded,
              size: 32,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'ما عندك حتى طلبية دابا',
            style: text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'اختار سائق من التبويب الأول، حدد مكانك على الخريطة، '
            'والطلبية تبان هنا بحالتها.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xl),
          PrimaryButton(
            label: 'اطلب ماء الآن',
            icon: Icons.water_drop_outlined,
            onPressed: onBrowse,
          ),
        ],
      ),
    );
  }
}

/// One order, with its state spelled out in words and an icon, never colour
/// alone.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onDelete});

  final Order order;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.driverName, style: text.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      '${order.waterType} · ${formatVolume(order.volumeM3)}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              _StatusBadge(status: order.status),
              const SizedBox(width: AppSpace.xs),
              GlassIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'حذف الطلبية',
                size: 36,
                tone: AppColors.danger,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpace.md),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: order.customerName,
          ),
          const SizedBox(height: AppSpace.sm),
          _DetailRow(
            icon: Icons.place_outlined,
            label: order.placeName,
          ),
          const SizedBox(height: AppSpace.sm),
          _DetailRow(
            icon: Icons.my_location_rounded,
            label: formatLatLng(order.lat, order.lng),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.textFaint,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${formatRelativeDay(order.createdAt)} · '
                  '${formatOrderDate(order.createdAt)}',
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${formatDzd(order.price)} دج',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status pill: icon plus Arabic word, tinted by state.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (status) {
      OrderStatus.sent => (Icons.send_rounded, AppColors.warning),
      OrderStatus.accepted => (Icons.local_shipping_rounded, AppColors.accent),
      OrderStatus.delivered => (Icons.check_circle_rounded, AppColors.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tone.withValues(alpha: 0.14),
          const Color(0x00000000),
        ),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tone,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of order detail: glyph plus value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textFaint),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
