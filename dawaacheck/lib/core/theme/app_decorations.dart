import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Premium reusable decorations for DawaaCheck
class AppDecorations {
  AppDecorations._();

  // ── Cards ──

  /// Light-only card (no context). Prefer [cardOf] for theme-aware cards.
  static BoxDecoration get card => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
    boxShadow: AppColors.shadowSm,
  );

  /// Theme-aware card decoration.
  static BoxDecoration cardOf(BuildContext context) {
    final c = AppColors.of(context);
    return BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      border: Border.all(color: c.borderSubtle, width: 1.5),
      boxShadow: c.shadowSm,
    );
  }

  /// Light-only elevated card. Prefer [cardElevatedOf] for theme-aware.
  static BoxDecoration get cardElevated => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
    boxShadow: AppColors.shadowMd,
  );

  /// Theme-aware elevated card decoration.
  static BoxDecoration cardElevatedOf(BuildContext context) {
    final c = AppColors.of(context);
    return BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      border: Border.all(color: c.borderSubtle, width: 1.5),
      boxShadow: c.shadowMd,
    );
  }

  static BoxDecoration get cardShadow => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
    boxShadow: AppColors.shadowLg,
  );

  static BoxDecoration get cardHero => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: AppColors.shadowXl,
  );

  // ── Card with Left Accent Strip ──
  // Use for scan results, recalls, agent cards — color communicates status at a glance

  static BoxDecoration cardAccent(Color accentColor) => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
    boxShadow: AppColors.shadowSm,
  );

  /// Builds a card with a colored left accent strip. Wrap your card content with this.
  static Widget accentCard({
    required Color accentColor,
    required Widget child,
    EdgeInsetsGeometry? padding,
    double accentWidth = 3.5,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.borderSubtle, width: 1.5),
        boxShadow: AppColors.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard - 1),
        child: Row(
          children: [
            Container(
              width: accentWidth,
              color: accentColor,
            ),
            Expanded(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Theme-aware accent card.
  static Widget accentCardOf({
    required BuildContext context,
    required Color accentColor,
    required Widget child,
    EdgeInsetsGeometry? padding,
    double accentWidth = 3.5,
  }) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: c.borderSubtle, width: 1.5),
        boxShadow: c.shadowSm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard - 1),
        child: Row(
          children: [
            Container(
              width: accentWidth,
              color: accentColor,
            ),
            Expanded(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tinted Card ──
  // Subtle status-colored background for grouping (5-8% opacity tint)

  static BoxDecoration cardTinted(Color tintColor) => BoxDecoration(
    color: tintColor.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(color: tintColor.withValues(alpha: 0.12), width: 1),
  );

  // ── Stat Card ──
  // For large numbers with labels (scan count, verified count, etc.)

  static BoxDecoration get cardStat => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
  );

  // ── Glass / Frost ──

  static BoxDecoration get glass => BoxDecoration(
    color: AppColors.white.withValues(alpha: 0.72),
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(
      color: AppColors.white.withValues(alpha: 0.5),
      width: 1,
    ),
  );

  static BoxDecoration get glassDark => BoxDecoration(
    color: AppColors.scanBackground.withValues(alpha: 0.6),
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(
      color: AppColors.white.withValues(alpha: 0.08),
      width: 1,
    ),
  );

  // ── Solid decorations (gradients retired per Clinical Precision rules) ──

  static BoxDecoration get primaryGradient => const BoxDecoration(
    color: AppColors.primary,
  );

  static BoxDecoration get verifiedGradient => const BoxDecoration(
    color: AppColors.verified,
  );

  static BoxDecoration get dangerGradient => const BoxDecoration(
    color: AppColors.danger,
  );

  static BoxDecoration get warningGradient => const BoxDecoration(
    color: AppColors.warning,
  );

  // ── Inputs & Containers ──

  static BoxDecoration get inputField => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.03),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get iconContainer => BoxDecoration(
    color: AppColors.primaryLight,
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
  );

  static BoxDecoration get iconContainerLarge => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFFEBF2FD), Color(0xFFF0F6FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get searchBar => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
    boxShadow: AppColors.shadowSm,
  );

  // ── Status Badges ──

  static BoxDecoration statusBadge(Color color) => BoxDecoration(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
    border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
  );

  /// Theme-aware status badge — slightly higher opacity on dark backgrounds.
  static BoxDecoration statusBadgeOf(BuildContext context, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: color.withValues(alpha: isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2), width: 1),
    );
  }

  // ── Navigation ──

  static BoxDecoration get bottomNav => BoxDecoration(
    color: AppColors.white,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
    ),
    boxShadow: AppColors.shadowNav,
  );

  /// Theme-aware bottom nav decoration.
  static BoxDecoration bottomNavOf(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: c.surface,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ]
          : AppColors.shadowNav,
    );
  }

  // ── Utility ──

  /// Frosted glass effect widget wrapper
  static Widget frosted({
    required Widget child,
    double sigma = 12,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(AppSpacing.radiusCard),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}
