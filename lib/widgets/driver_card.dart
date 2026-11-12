import 'package:flutter/material.dart';

import '../models/driver_offer.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_buttons.dart';
import 'glass_surface.dart';

/// One available driver: who is on shift, what water, how much, and the price
/// they are asking.
///
/// The card is the customer's *price board*: tapping it opens the order form
/// pre-filled with these terms. It is not a dispatch choice — the order goes to
/// every available driver and the first one to accept takes it — so the button
/// says «اطلب بهذا السعر» rather than naming the driver as the one who will
/// come. Promising a specific driver would be a lie the product cannot keep.
///
/// The whole card is tappable and the explicit button repeats the same action,
/// so a first-time user never has to guess that the card is a control.
class DriverCard extends StatelessWidget {
  /// Creates a driver card.
  const DriverCard({
    super.key,
    required this.offer,
    required this.onOrder,
  });

  /// The driver's public offer.
  final DriverOffer offer;

  /// Opens the order form with these terms.
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassSurface(
      onTap: onOrder,
      semanticLabel:
          '${offer.fullName}، ${offer.waterType}، ${formatVolume(offer.volumeM3)}، '
          '${formatDzd(offer.price)} دينار. اطلب بهذا السعر',
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InitialBadge(initial: offer.initial),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.fullName,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'متوفر دابا',
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
              _PriceTag(price: offer.price),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              MetaChip(
                icon: offer.waterType.contains('غير')
                    ? Icons.warning_amber_rounded
                    : Icons.water_drop_outlined,
                label: offer.waterType,
                tint: offer.waterType.contains('غير')
                    ? AppColors.warning
                    : AppColors.accent,
              ),
              MetaChip(
                icon: Icons.straighten_rounded,
                label: formatVolume(offer.volumeM3),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              width: 168,
              child: PrimaryButton(
                label: 'اطلب بهذا السعر',
                onPressed: onOrder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The driver's initial in the same glass tile the header uses. Decorative: the
/// card's semantic label already names the driver.
class _InitialBadge extends StatelessWidget {
  const _InitialBadge({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
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
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// The price, the second thing the eye should find on the card.
class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatDzd(price),
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
            height: 1.1,
          ),
        ),
        const Text(
          'دج',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textFaint,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
