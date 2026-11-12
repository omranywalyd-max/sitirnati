import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_buttons.dart';
import 'glass_surface.dart';

/// Shows the confirmation dialog after an order is placed.
///
/// Resolves `true` when the customer asks to see their orders, `false` when
/// they dismiss it. The order is already saved by the time this opens, so the
/// dialog is a confirmation, not a gate: the barrier is not dismissible, but
/// the "واخا" action closes it without doing anything else.
Future<bool> showOrderSuccessDialog(BuildContext context, Order order) async {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'تم تسجيل الطلبية',
    barrierColor: const Color(0xB8000000),
    transitionDuration: reduceMotion ? Duration.zero : AppMotion.standard,
    pageBuilder: (_, _, _) => _OrderSuccessDialog(order: order),
    transitionBuilder: (context, animation, _, child) {
      if (reduceMotion) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.045),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
  return result ?? false;
}

/// The dialog body: a drawn check mark, the order summary and two actions.
///
/// Everything is built from the app's own glass material and the water accent,
/// so the confirmation belongs to the same product as the card that opened it.
class _OrderSuccessDialog extends StatefulWidget {
  const _OrderSuccessDialog({required this.order});

  final Order order;

  @override
  State<_OrderSuccessDialog> createState() => _OrderSuccessDialogState();
}

class _OrderSuccessDialogState extends State<_OrderSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _discScale;
  late final Animation<double> _halo;
  late final Animation<double> _check;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _discScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _halo = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
      ),
    );
    _check = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion: land on the finished frame instead of animating to it.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final order = widget.order;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Semantics(
            namesRoute: true,
            container: true,
            label: 'تم تسجيل الطلبية',
            child: GlassSurface(
              tint: AppColors.surfaceSheet,
              blur: AppGlass.sheetBlur,
              radius: AppRadius.sheet,
              padding: const EdgeInsets.all(AppSpace.xxl),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: _SuccessMark(
                        discScale: _discScale,
                        halo: _halo,
                        check: _check,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'الطلبية تسجلت',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'طلبية ${order.driverName} تزادت في «طلبياتي» '
                      'على هذا الهاتف بحالة «مُرسل».',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    _StatusLine(status: order.status),
                    const SizedBox(height: AppSpace.lg),
                    _OrderSummary(order: order),
                    const SizedBox(height: AppSpace.xl),
                    PrimaryButton(
                      label: 'شوف طلبياتي',
                      icon: Icons.receipt_long_rounded,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    SecondaryButton(
                      label: 'واخا',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The accent disc with the check mark being drawn inside it.
///
/// The halo, the disc and the stroke are three stages of one controller, so the
/// whole mark reads as a single gesture rather than three unrelated fades.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark({
    required this.discScale,
    required this.halo,
    required this.check,
  });

  final Animation<double> discScale;
  final Animation<double> halo;
  final Animation<double> check;

  static const _box = 108.0;
  static const _disc = 78.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: _box,
        height: _box,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: halo,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1).animate(halo),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.30),
                        AppColors.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: const SizedBox(width: _box, height: _box),
                ),
              ),
            ),
            ScaleTransition(
              scale: discScale,
              child: Container(
                width: _disc,
                height: _disc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentSoft,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: AnimatedBuilder(
                      animation: check,
                      builder: (context, _) => CustomPaint(
                        painter: _CheckPainter(progress: check.value),
                      ),
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
}

/// Draws a check mark up to [progress] of its length.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.54)
      ..lineTo(size.width * 0.42, size.height * 0.73)
      ..lineTo(size.width * 0.79, size.height * 0.29);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// The order state, in the same chip language the orders list uses.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (status) {
      OrderStatus.sent => (Icons.send_rounded, AppColors.warning),
      OrderStatus.accepted => (Icons.local_shipping_rounded, AppColors.accent),
      OrderStatus.delivered => (Icons.check_circle_rounded, AppColors.success),
    };

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.14),
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
      ),
    );
  }
}

/// What was ordered: driver, water, load and price, on one inset panel.
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceField,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'السائق', value: order.driverName),
          const _SummaryDivider(),
          _SummaryRow(label: 'الماء', value: order.waterType),
          const _SummaryDivider(),
          _SummaryRow(label: 'الحجم', value: formatVolume(order.volumeM3)),
          const _SummaryDivider(),
          _SummaryRow(
            label: 'الثمن',
            value: '${formatDzd(order.price)} دج',
            tone: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

/// One label/value line of the summary.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.tone = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: AppColors.textFaint,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          // The value takes the remaining width and truncates rather than
          // pushing the label out at a large text scale.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: tone,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.divider);
  }
}
