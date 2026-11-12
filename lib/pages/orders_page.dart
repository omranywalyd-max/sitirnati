import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_buttons.dart';
import '../widgets/glass_surface.dart';

/// Tab two: everything the customer has ordered, newest first.
///
/// Each card answers the three questions a waiting customer actually has: who
/// is coming (or that nobody has taken it yet), how far along it is, and what it
/// costs. The state is written in words and an icon, never colour alone.
class OrdersPage extends StatelessWidget {
  /// Creates the orders tab.
  const OrdersPage({
    super.key,
    required this.orders,
    required this.loading,
    required this.onCancel,
    required this.onDelete,
    required this.onCall,
    required this.onBrowse,
  });

  /// The customer's orders, newest first.
  final List<Order> orders;

  /// Whether the first snapshot is still on its way.
  final bool loading;

  /// Calls off an order that is still running.
  final ValueChanged<Order> onCancel;

  /// Removes a finished order from the history.
  final ValueChanged<Order> onDelete;

  /// Dials the driver who claimed the order.
  final ValueChanged<Order> onCall;

  /// Switches to the browse tab.
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final running = orders.where((order) => !order.status.isClosed).length;

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
                              ? 'كل طلبية تبعتها تبان هنا بحالتها.'
                              : running > 0
                                  ? '$running طلبية جارية · الحالة تتبدل وحدها '
                                      'كي يرد السائق.'
                                  : '${orders.length} طلبية · كلشي منتهي.',
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
                                onCancel: () => onCancel(order),
                                onDelete: () => onDelete(order),
                                onCall: () => onCall(order),
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
            'شوف السواقين المتوفرين، حدد مكانك على الخريطة، '
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

/// One order, with its state spelled out in words and an icon.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onCancel,
    required this.onDelete,
    required this.onCall,
  });

  final Order order;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final waiting = order.status.isWaiting;

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
                    // Who is coming, or the honest truth that nobody has taken
                    // the order yet. Two different sentences, not one grey
                    // placeholder.
                    Text(
                      order.hasDriver ? order.driverName : 'في انتظار سائق',
                      style: text.titleMedium?.copyWith(
                        color: order.hasDriver
                            ? AppColors.textPrimary
                            : AppColors.warning,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${order.waterType} · ${formatVolume(order.volumeM3)}',
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              _StatusBadge(status: order.status),
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
          if (order.nearAt != null && order.status == OrderStatus.accepted) ...[
            const SizedBox(height: AppSpace.sm),
            _DetailRow(
              icon: Icons.notifications_active_outlined,
              label: 'السائق بلّغك بلي قريب منك',
              tone: AppColors.accent,
            ),
          ],
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
          const SizedBox(height: AppSpace.sm),
          // Actions follow the state: a running order can be called off, and
          // once a driver has claimed it the customer can ring that driver
          // directly. A finished order only offers to leave the history.
          // Showing "delete" on a job a driver is already driving to would
          // invite stranding them.
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: [
              if (order.status == OrderStatus.accepted &&
                  order.driverPhone.isNotEmpty)
                _CardAction(
                  icon: Icons.call_rounded,
                  label: 'اتصل بالسائق',
                  tone: AppColors.accent,
                  onPressed: onCall,
                ),
              if (order.canCancel)
                _CardAction(
                  icon: Icons.cancel_outlined,
                  label: 'إلغاء الطلب',
                  tone: AppColors.danger,
                  onPressed: onCancel,
                )
              else
                _CardAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'امسح من السجل',
                  tone: AppColors.textSecondary,
                  onPressed: onDelete,
                ),
            ],
          ),
          if (waiting) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'الطلب عند السواقين المتوفرين. أول واحد يقبلو راح يبان اسمه هنا.',
              style: text.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// A quiet text action at the bottom of an order card.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: tone),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: tone,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: tone,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: 6,
        ),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.padded,
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
      OrderStatus.sent => (Icons.hourglass_top_rounded, AppColors.warning),
      OrderStatus.accepted => (Icons.local_shipping_rounded, AppColors.accent),
      OrderStatus.delivered => (Icons.check_circle_rounded, AppColors.success),
      OrderStatus.cancelled => (Icons.cancel_rounded, AppColors.danger),
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
  const _DetailRow({
    required this.icon,
    required this.label,
    this.tone = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textFaint),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: tone,
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
