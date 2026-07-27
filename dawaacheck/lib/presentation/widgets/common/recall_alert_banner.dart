import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

/// Recall alert banner — shown on home when the user has a scanned medicine
/// that's been recalled. Flat danger tone, no gradient, no pulsing dot.
///
/// The urgency signal is the square danger dot + the word "RECALL ALERT" in
/// sectionHeader caps — not animation.
class RecallAlertBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const RecallAlertBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        splashColor: AppColors.danger.withValues(alpha: 0.08),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              // Square danger indicator (not a pulsing dot)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECALL ALERT',
                      style: AppTextStyles.sectionHeader.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      count == 1
                          ? '1 medicine you scanned has been recalled'
                          : '$count medicines you scanned have been recalled',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.dangerDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Iconsax.arrow_right_3,
                color: AppColors.danger,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
