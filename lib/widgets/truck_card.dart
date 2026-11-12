import 'package:flutter/material.dart';

import '../models/truck.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_buttons.dart';
import 'glass_surface.dart';

/// A driver card: who is driving, what water, how much, how much it costs, and
/// one obvious action.
///
/// The whole card is tappable and the explicit button is there for the same
/// action, so a first-time user never has to guess that the card is a control.
class TruckCard extends StatelessWidget {
  /// Creates a driver card.
  const TruckCard({
    super.key,
    required this.truck,
    required this.onOrder,
  });

  /// Driver data rendered by the card.
  final Truck truck;

  /// Opens the order form for this truck.
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GlassSurface(
      onTap: onOrder,
      semanticLabel:
          '${truck.driverName}، ${truck.waterType}، ${formatVolume(truck.volumeM3)}، '
          '${formatDzd(truck.price)} دينار. اطلب منه',
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _WaterBadge(),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truck.driverName,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: AppColors.textFaint,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            truck.city,
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
              _PriceTag(price: truck.price),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              MetaChip(
                icon: Icons.water_drop_outlined,
                label: truck.waterType,
                tint: AppColors.accent,
              ),
              MetaChip(
                icon: Icons.straighten_rounded,
                label: formatVolume(truck.volumeM3),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              width: 140,
              child: PrimaryButton(
                label: 'اطلب الآن',
                onPressed: onOrder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The round water glyph at the start of the card. Decorative: the card's
/// semantic label already names the driver and the water type.
class _WaterBadge extends StatelessWidget {
  const _WaterBadge();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.field),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accentSoft, Color(0x0D5FD3E8)],
          ),
          border: Border.all(color: const Color(0x4D5FD3E8)),
        ),
        child: const Icon(
          Icons.water_drop_rounded,
          size: 24,
          color: AppColors.accent,
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
