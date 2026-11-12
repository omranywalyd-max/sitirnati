import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The compact brand lockup used at the top of the sign-in and sign-up pages:
/// the same water-drop tile as the splash, at header size, with the wordmark
/// and the role.
class BrandLockup extends StatelessWidget {
  /// Creates the lockup.
  const BrandLockup({super.key, this.size = 60});

  /// Side length of the glass tile.
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'سيترنتي للسائق',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.32),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x4D5FD3E8), Color(0x0D5FD3E8)],
                ),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D5FD3E8),
                    blurRadius: 26,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Icon(
                Icons.water_drop_rounded,
                size: size * 0.48,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              'سيترنتي',
              style: text.headlineSmall?.copyWith(letterSpacing: -0.4),
            ),
            const SizedBox(height: 2),
            Text(
              'للسائق',
              style: text.labelMedium?.copyWith(
                color: AppColors.accent,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A block of inline error copy that a screen reader announces when it appears.
///
/// The message is placed in a `liveRegion` so a driver using TalkBack hears the
/// failure without having to hunt for it after the button press.
class InlineError extends StatelessWidget {
  /// Creates an inline error, or nothing when [message] is `null`.
  const InlineError({super.key, required this.message});

  /// Arabic, user-facing failure copy.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpace.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: const Color(0x66FF8A8A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 17,
              color: AppColors.danger,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.danger,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal rule with a word in the middle: `──── ولا ────`.
class OrDivider extends StatelessWidget {
  /// Creates the divider.
  const OrDivider({super.key, required this.label});

  /// The word between the rules.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textFaint,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider, height: 1)),
        ],
      ),
    );
  }
}
