import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../widgets/design_system/design_system.dart';

/// Shared result-screen cards used by the verified / unverified / danger
/// screens so the side-effect and halal sections stay consistent.

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 20,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.sectionHeader.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Lists possible side effects with a calm, informational tone.
class SideEffectsCard extends StatelessWidget {
  final List<String> sideEffects;
  const SideEffectsCard({super.key, required this.sideEffects});

  @override
  Widget build(BuildContext context) {
    if (sideEffects.isEmpty) return const SizedBox.shrink();
    return ClinicalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Iconsax.health,
            label: 'sideEffectsTitle'.tr(),
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.md),
          ...sideEffects.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      e,
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'sideEffectsNote'.tr(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textHint,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Halal status badge + reasoning.
class HalalStatusCard extends StatelessWidget {
  final String status; // HALAL / NOT_HALAL / VERIFY / UNKNOWN
  final String reason;
  const HalalStatusCard({
    super.key,
    required this.status,
    required this.reason,
  });

  ({Color color, IconData icon, String label}) _config() {
    switch (status.toUpperCase()) {
      case 'HALAL':
        return (
          color: AppColors.verified,
          icon: Iconsax.tick_circle,
          label: 'halalConfirmed'.tr(),
        );
      case 'NOT_HALAL':
        return (
          color: AppColors.danger,
          icon: Iconsax.close_circle,
          label: 'halalNotPermissible'.tr(),
        );
      case 'UNKNOWN':
        return (
          color: AppColors.textHint,
          icon: Iconsax.info_circle,
          label: 'halalUnknown'.tr(),
        );
      default: // VERIFY
        return (
          color: AppColors.warning,
          icon: Iconsax.warning_2,
          label: 'halalVerify'.tr(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _config();
    return ClinicalCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Iconsax.shield_tick,
            label: 'halalTitle'.tr(),
            color: c.color,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: c.color.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(c.icon, color: c.color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.label,
                        style: AppTextStyles.h4.copyWith(color: c.color),
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reason,
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
