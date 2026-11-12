import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_buttons.dart';
import 'glass_surface.dart';

/// Which set of actions an order card offers.
enum OrderCardMode {
  /// Still in the pool: accept, reject, or look at the pin.
  pool,

  /// Claimed and running: call, navigate, say "I am near", close it.
  running,

  /// Delivered or cancelled: read-only history.
  closed,
}

/// One order, as a driver reads it.
///
/// The card leads with *who and how far*, because that is the question a driver
/// answers before anything else; the price and the load follow, and the actions
/// sit at the bottom where the thumb already is.
class OrderCard extends StatelessWidget {
  /// Creates an order card.
  const OrderCard({
    super.key,
    required this.order,
    required this.mode,
    this.distanceMetres,
    this.onAccept,
    this.onReject,
    this.onShowMap,
    this.onCall,
    this.onNear,
    this.onDelivered,
    this.busy = false,
  });

  /// The order rendered by the card.
  final DriverOrder order;

  /// Which actions to show.
  final OrderCardMode mode;

  /// Straight-line distance from the driver's base, in metres.
  final double? distanceMetres;

  /// Claims the order.
  final VoidCallback? onAccept;

  /// Hides the order from this phone's pool.
  final VoidCallback? onReject;

  /// Opens the delivery pin in Google Maps.
  final VoidCallback? onShowMap;

  /// Dials the customer.
  final VoidCallback? onCall;

  /// Raises the customer's full-screen "driver is near" alert.
  final VoidCallback? onNear;

  /// Closes the order as delivered.
  final VoidCallback? onDelivered;

  /// Whether a write for this card is in flight.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final closed = mode == OrderCardMode.closed;
    final distance = distanceMetres;

    return GlassSurface(
      padding: const EdgeInsets.all(AppSpace.lg),
      rim: mode == OrderCardMode.running
          ? const Color(0x665FD3E8)
          : AppColors.glassBorder,
      child: Opacity(
        opacity: closed ? 0.78 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CustomerBadge(name: order.customerName),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName.isEmpty
                            ? 'زبون بلا اسم'
                            : order.customerName,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: AppColors.textFaint,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              formatAgo(order.createdAt),
                              style: text.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                if (distance != null && mode != OrderCardMode.closed)
                  _DistanceTag(metres: distance)
                else
                  _StatusTag(status: order.status),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            // Where. The one line the driver needs to judge the trip.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.placeName.isEmpty
                        ? formatLatLng(order.lat, order.lng)
                        : order.placeName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.35,
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
                MetaChip(
                  icon: Icons.water_drop_outlined,
                  label: order.waterType.isEmpty
                      ? 'ماء بلا نوع'
                      : order.waterType,
                  tint: AppColors.accent,
                ),
                MetaChip(
                  icon: Icons.straighten_rounded,
                  label: formatCubicMetresAsLitres(order.volumeM3),
                ),
                MetaChip(
                  icon: Icons.payments_outlined,
                  label: '${formatDzd(order.price)} دج',
                ),
              ],
            ),

            if (mode == OrderCardMode.running && order.nearAt != null) ...[
              const SizedBox(height: AppSpace.md),
              _NearNote(at: order.nearAt!),
            ],

            const SizedBox(height: AppSpace.lg),
            ..._actions(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    switch (mode) {
      case OrderCardMode.closed:
        return const [];

      case OrderCardMode.pool:
        return [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: PrimaryButton(
                  label: 'اقبل الطلب',
                  icon: Icons.check_rounded,
                  busy: busy,
                  onPressed: busy ? null : onAccept,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              GlassIconButton(
                icon: Icons.map_outlined,
                tooltip: 'ورّي الموقع على الخريطة',
                onPressed: onShowMap,
              ),
              const SizedBox(width: AppSpace.sm),
              GlassIconButton(
                icon: Icons.close_rounded,
                tooltip: 'ارفض الطلب',
                tone: AppColors.textSecondary,
                onPressed: busy ? null : onReject,
              ),
            ],
          ),
        ];

      case OrderCardMode.running:
        return [
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'اتصل',
                  icon: Icons.call_rounded,
                  expand: true,
                  onPressed: onCall,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: SecondaryButton(
                  label: 'الموقع',
                  icon: Icons.navigation_rounded,
                  expand: true,
                  onPressed: onShowMap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          SecondaryButton(
            label: order.nearAt == null ? 'أنا قريب — بلّغ الزبون' : 'عاود بلّغ الزبون',
            icon: Icons.campaign_rounded,
            tone: AppColors.accent,
            onPressed: busy ? null : onNear,
          ),
          const SizedBox(height: AppSpace.sm),
          PrimaryButton(
            label: 'تم إيصال الطلب',
            icon: Icons.local_shipping_rounded,
            busy: busy,
            onPressed: busy ? null : onDelivered,
          ),
        ];
    }
  }
}

/// Round initials disc at the head of the card.
class _CustomerBadge extends StatelessWidget {
  const _CustomerBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '؟' : trimmed[0];

    return ExcludeSemantics(
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.field),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accentSoft, Color(0x0D5FD3E8)],
          ),
          border: Border.all(color: const Color(0x4D5FD3E8)),
        ),
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

/// The distance chip: the second thing the eye should find on a pool card.
class _DistanceTag extends StatelessWidget {
  const _DistanceTag({required this.metres});

  final double metres;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: const Color(0x665FD3E8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.near_me_rounded,
            size: 13,
            color: AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            formatDistance(metres),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill for running and closed orders.
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      OrderStatus.sent => (AppColors.warning, const Color(0x33FFC46B)),
      OrderStatus.accepted => (AppColors.accent, AppColors.accentSoft),
      OrderStatus.delivered => (AppColors.success, const Color(0x337BE495)),
      OrderStatus.cancelled => (AppColors.danger, AppColors.dangerSoft),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Confirmation that the customer has already been alerted.
class _NearNote extends StatelessWidget {
  const _NearNote({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 15,
          color: AppColors.success,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'بلّغت الزبون بلي راك قريب · ${formatAgo(at)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.success,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
