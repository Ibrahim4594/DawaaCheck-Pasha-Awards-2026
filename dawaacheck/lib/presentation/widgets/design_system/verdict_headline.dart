import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

/// Two-line signature hero for result screens.
///
/// Pattern: **absolute statement** (bold Plex Sans w600) on line one, the
/// **emotional payoff** (italic Plex Sans w300) on line two, with a short
/// 2px colored accent underline sitting between them and whatever follows.
///
/// Examples:
/// - "Authentic." / "Registered with DRAP. Safe for your family." (verified)
/// - "Counterfeit." / "Do not use. Return it to the pharmacy today." (danger)
/// - "Unconfirmed." / "We couldn't verify this medicine. Consult your pharmacist." (unverified)
///
/// The sentences carry emotional impact — they are what the user reads first,
/// remembers, and screenshots. The data that supports them lives below.
class VerdictHeadline extends StatelessWidget {
  final String absolute;
  final String soft;
  final Color accentColor;
  final double accentWidth;

  const VerdictHeadline({
    super.key,
    required this.absolute,
    required this.soft,
    required this.accentColor,
    this.accentWidth = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bold, plain, colour-coded verdict word — the first thing the user
        // reads. Colour marks the outcome (green / amber / red).
        Text(
          absolute.toUpperCase(),
          style: AppTextStyles.h2.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w800,
            fontSize: 30,
            height: 1.05,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          soft,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          height: 3,
          width: accentWidth,
          color: accentColor,
        ),
      ],
    );
  }
}
