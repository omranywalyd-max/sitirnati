import 'package:flutter/material.dart';

import '../models/driver_profile.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import '../widgets/order_card.dart';
import '../widgets/segmented_tabs.dart';
import 'incoming_page.dart' show OrdersEmptyState;

/// The second tab: the orders this driver claimed.
///
/// Split into what is still running and what is finished, because those are two
/// different jobs: one asks for action, the other is a record. The segment
/// counts are written into the line under the control so the driver knows the
/// other half is not empty before tapping it.
class MyOrdersPage extends StatefulWidget {
  /// Creates the "my orders" tab.
  const MyOrdersPage({
    super.key,
    required this.profile,
    required this.orders,
    required this.loading,
    required this.busyId,
    required this.onCall,
    required this.onShowMap,
    required this.onNear,
    required this.onDelivered,
  });

  /// The signed-in driver, used to measure distance to each customer.
  final DriverProfile profile;

  /// Every order this driver claimed, newest first.
  final List<DriverOrder> orders;

  /// Whether the first snapshot is still on its way.
  final bool loading;

  /// Order id with a write in flight, if any.
  final String? busyId;

  /// Dials the customer.
  final ValueChanged<DriverOrder> onCall;

  /// Opens the delivery pin in Google Maps.
  final ValueChanged<DriverOrder> onShowMap;

  /// Raises the customer's full-screen "driver is near" alert.
  final ValueChanged<DriverOrder> onNear;

  /// Closes the order as delivered.
  final ValueChanged<DriverOrder> onDelivered;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  static const _running = 0;

  int _tab = _running;

  List<DriverOrder> get _runningOrders =>
      widget.orders.where((o) => o.status == OrderStatus.accepted).toList();

  List<DriverOrder> get _closedOrders => widget.orders
      .where((o) => o.status == OrderStatus.delivered ||
          o.status == OrderStatus.cancelled)
      .toList();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final running = _runningOrders;
    final closed = _closedOrders;
    final visible = _tab == _running ? running : closed;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedTabs(
                labels: const ['جارية', 'منتهية'],
                index: _tab,
                onChanged: (index) => setState(() => _tab = index),
                semanticLabel: 'حالة الطلبيات',
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                _tab == _running
                    ? (running.isEmpty
                        ? 'ما عندكش طلبية جارية.'
                        : '${running.length} طلبية جارية — كمّلها و سجّلها.')
                    : (closed.isEmpty
                        ? 'ما زال ما كمّلتش حتى طلبية.'
                        : '${closed.length} طلبية منتهية.'),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.pageBottom,
            ),
            children: [
              if (widget.loading && visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpace.huge),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.accent),
                      ),
                    ),
                  ),
                )
              else if (visible.isEmpty)
                OrdersEmptyState(
                  icon: _tab == _running
                      ? Icons.local_shipping_outlined
                      : Icons.task_alt_rounded,
                  title: _tab == _running
                      ? 'ما عندكش طلبية جارية'
                      : 'ما كاينش طلبيات منتهية',
                  message: _tab == _running
                      ? 'من «الطلبات»، اقبل طلبية و راح تنتقل لهنا مع '
                          'معلومات الزبون و أزرار الاتصال و التبليغ.'
                      : 'كي تسجل طلبية بلي وصلت، تنتقل لهنا كسجل.',
                )
              else
                for (final order in visible) ...[
                  OrderCard(
                    order: order,
                    mode: _tab == _running
                        ? OrderCardMode.running
                        : OrderCardMode.closed,
                    distanceMetres: driverDistance(widget.profile, order),
                    busy: widget.busyId == order.id,
                    onCall: () => widget.onCall(order),
                    onShowMap: () => widget.onShowMap(order),
                    onNear: () => widget.onNear(order),
                    onDelivered: () => widget.onDelivered(order),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
