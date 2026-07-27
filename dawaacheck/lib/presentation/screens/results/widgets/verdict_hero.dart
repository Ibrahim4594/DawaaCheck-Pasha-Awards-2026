import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Bold, full-bleed gradient verdict banner shared by all three result screens
/// (verified / unverified / danger). White content on a colour-coded gradient,
/// a white hero badge (Lottie or icon), a huge verdict word, and a risk pill.
class VerdictHero extends StatelessWidget {
  final LinearGradient gradient;
  final Color accent; // solid verdict colour (for the white-badge icon)
  final String? lottieAsset; // null → show [heroIcon]
  final IconData heroIcon;
  final String absolute; // "Authentic" / "Counterfeit" / "Unconfirmed"
  final String soft;
  final int riskScore;
  final String riskLevel;
  final String scanCode;
  final String primaryAgent;
  final int coAgentCount;
  final int processingMs;

  const VerdictHero({
    super.key,
    required this.gradient,
    required this.accent,
    required this.heroIcon,
    required this.absolute,
    required this.soft,
    required this.riskScore,
    required this.riskLevel,
    required this.scanCode,
    this.lottieAsset,
    this.primaryAgent = 'HAKIM',
    this.coAgentCount = 9,
    this.processingMs = 2400,
  });

  @override
  Widget build(BuildContext context) {
    const white = AppColors.white;
    final faint = white.withValues(alpha: 0.85);
    final secs = (processingMs / 1000).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Back + scan meta
              Row(
                children: [
                  Material(
                    color: white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Iconsax.arrow_left, color: white, size: 18),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'VERDICT · $secs s',
                    style: AppTextStyles.monoCaption.copyWith(color: faint),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // White hero badge — Lottie (verified) or icon
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: lottieAsset != null
                      ? Lottie.asset(
                          lottieAsset!,
                          fit: BoxFit.contain,
                          repeat: false,
                          errorBuilder: (_, e, s) =>
                              Icon(heroIcon, color: accent, size: 48),
                        )
                      : Icon(heroIcon, color: accent, size: 52),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Huge bold verdict word
              Center(
                child: Text(
                  absolute.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(
                    color: white,
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                    height: 1.05,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  soft,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: faint,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Risk pill
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border: Border.all(
                      color: white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    'RISK $riskScore/100 · ${riskLevel.toUpperCase()}',
                    style: AppTextStyles.monoData.copyWith(color: white),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Agent byline (white)
              Center(
                child: Text(
                  '$primaryAgent · +$coAgentCount agents · ${secs}s · $scanCode',
                  style: AppTextStyles.monoCaption.copyWith(
                    color: white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
