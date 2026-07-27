import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';

/// Empty state shown when a list has no items (no scans, no results, no
/// recalls, error). Clinical Precision flat version: hairline-bordered
/// icon tile, title, subtitle, optional CTA. No Lottie, no floating
/// particles, no pulsing controller, no gradient circle.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;
  final Color accentColor;
  final String? lottieAsset;

  const AppEmptyState._({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
    this.accentColor = AppColors.primary,
    this.lottieAsset,
  });

  /// No scan history
  factory AppEmptyState.noScans({VoidCallback? onScanTap}) => AppEmptyState._(
        icon: Iconsax.scan_barcode,
        title: 'emptyScansTitle'.tr(),
        subtitle: 'emptyScansSubtitle'.tr(),
        buttonLabel: AppStrings.scanNow,
        onButtonTap: onScanTap,
        accentColor: AppColors.primary,
        lottieAsset: AppAnimations.docScan,
      );

  /// No search results
  factory AppEmptyState.noResults({String query = ''}) => AppEmptyState._(
        icon: Iconsax.search_status,
        title: 'emptyResultsTitle'.tr(),
        subtitle: query.isNotEmpty
            ? 'emptyResultsQuery'.tr(namedArgs: {'query': query})
            : 'emptyResultsAny'.tr(),
        accentColor: AppColors.textSecondary,
        lottieAsset: AppAnimations.empty,
      );

  /// No notifications
  factory AppEmptyState.noNotifications() => AppEmptyState._(
        icon: Iconsax.notification_bing,
        title: 'emptyNotificationsTitle'.tr(),
        subtitle: 'emptyNotificationsSubtitle'.tr(),
        accentColor: AppColors.primary,
        lottieAsset: AppAnimations.empty,
      );

  /// No recalls (positive)
  factory AppEmptyState.noRecalls() => AppEmptyState._(
        icon: Iconsax.shield_tick,
        title: 'emptyRecallsTitle'.tr(),
        subtitle: 'emptyRecallsSubtitle'.tr(),
        accentColor: AppColors.verified,
        lottieAsset: AppAnimations.shieldCheck,
      );

  /// Error state
  factory AppEmptyState.error({
    String? message,
    VoidCallback? onRetry,
  }) =>
      AppEmptyState._(
        icon: Iconsax.cloud_cross,
        title: 'errorTitle'.tr(),
        subtitle: 'errorCheckConnection'.tr(
          namedArgs: {
            'message': message ?? 'errorGenericMessage'.tr(),
          },
        ),
        buttonLabel: AppStrings.retry,
        onButtonTap: onRetry,
        accentColor: AppColors.danger,
      );

  Widget _iconTile(BuildContext context) => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Icon(icon, color: accentColor, size: 32),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxxl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lottieAsset != null)
            // Eye-catching Lottie (robot / shield-check / empty box)
            SizedBox(
              width: 160,
              height: 160,
              child: Lottie.asset(
                lottieAsset!,
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (_, e, s) => _iconTile(context),
              ),
            )
          else
            _iconTile(context),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (buttonLabel != null && onButtonTap != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onButtonTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                  ),
                ),
                child: Text(buttonLabel!, style: AppTextStyles.buttonPrimary),
              ),
            ),
          ],
        ],
      )
          .animate()
          .fadeIn(duration: AppMotion.entranceDuration),
    );
  }
}
