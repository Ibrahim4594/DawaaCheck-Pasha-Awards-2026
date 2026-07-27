import 'package:flutter/material.dart';

/// DawaaCheck color palette — Clean Light Blue Medical UI
class AppColors {
  AppColors._();

  // ── Context-aware colors (light/dark) ──

  /// Returns context-aware colors based on current theme brightness
  static DawaaColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? _darkColors : _lightColors;
  }

  static final DawaaColors _lightColors = DawaaColors(
    background: const Color(0xFFF4F8FF),
    surface: const Color(0xFFFFFFFF),
    surfaceElevated: const Color(0xFFFAFCFF),
    primary: const Color(0xFF2952E6),
    primaryDark: const Color(0xFF1E3FB5),
    primaryLight: const Color(0xFFE9EFFF),
    primaryExtraLight: const Color(0xFFF4F8FF),
    textPrimary: const Color(0xFF0A1628),
    textSecondary: const Color(0xFF4A5D7A),
    textHint: const Color(0xFF9AABC4),
    border: const Color(0xFFE4ECF7),
    borderSubtle: const Color(0xFFEDF2FA),
    verified: const Color(0xFF12A05C),
    verifiedLight: const Color(0xFFEDFAF3),
    danger: const Color(0xFFE53935),
    dangerLight: const Color(0xFFFFF0F0),
    warning: const Color(0xFFE07B00),
    warningLight: const Color(0xFFFFF8EC),
    shadowSm: [
      BoxShadow(
        color: const Color(0xFF0A1628).withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
    shadowMd: [
      BoxShadow(
        color: const Color(0xFF0A1628).withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: const Color(0xFF2952E6).withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final DawaaColors _darkColors = DawaaColors(
    background: const Color(0xFF0B1120),
    surface: const Color(0xFF131B2E),
    surfaceElevated: const Color(0xFF192337),
    primary: const Color(0xFF5B8AF5),
    primaryDark: const Color(0xFF2952E6),
    primaryLight: const Color(0xFF152040),
    primaryExtraLight: const Color(0xFF0F1829),
    textPrimary: const Color(0xFFE2E8F0),
    textSecondary: const Color(0xFF94A3B8),
    textHint: const Color(0xFF64748B),
    border: const Color(0xFF1E2D45),
    borderSubtle: const Color(0xFF192337),
    verified: const Color(0xFF34D399),
    verifiedLight: const Color(0xFF0D2818),
    danger: const Color(0xFFF87171),
    dangerLight: const Color(0xFF2D1215),
    warning: const Color(0xFFFBBF24),
    warningLight: const Color(0xFF2D2006),
    shadowSm: [
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.2),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
    shadowMd: [
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.25),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.15),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Primary
  static const Color primary = Color(0xFF2952E6);
  static const Color primaryDark = Color(0xFF1E3FB5);
  static const Color primaryDeepDark = Color(0xFF16307F);
  static const Color primaryLight = Color(0xFFE9EFFF);
  static const Color primaryExtraLight = Color(0xFFF4F8FF);

  // Surfaces
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF4F8FF);
  static const Color surfaceElevated = Color(0xFFFAFCFF);

  // Text
  static const Color textPrimary = Color(0xFF0A1628);
  static const Color textSecondary = Color(0xFF4A5D7A);
  static const Color textHint = Color(0xFF9AABC4);
  static const Color textOnDark = Color(0xFFF0F4FA);

  // Border
  static const Color border = Color(0xFFE4ECF7);
  static const Color borderSubtle = Color(0xFFEDF2FA);

  // Verified (Green)
  static const Color verified = Color(0xFF12A05C);
  static const Color verifiedDark = Color(0xFF0D6B3A);
  static const Color verifiedLight = Color(0xFFEDFAF3);

  // Danger (Red)
  static const Color danger = Color(0xFFE53935);
  static const Color dangerDark = Color(0xFFB71C1C);
  static const Color dangerLight = Color(0xFFFFF0F0);

  // Warning (Amber)
  static const Color warning = Color(0xFFE07B00);
  static const Color warningLight = Color(0xFFFFF8EC);

  // Scan Screen (Dark)
  static const Color scanBackground = Color(0xFF0C1825);
  static const Color scanSurface = Color(0xFF12202F);
  static const Color scanAccent = Color(0xFF5BA8FF);

  // ── Premium Gradients ──

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF16307F), Color(0xFF2952E6), Color(0xFF5B8AF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primarySoftGradient = LinearGradient(
    colors: [Color(0xFFE9EFFF), Color(0xFFF4F8FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient verifiedGradient = LinearGradient(
    colors: [Color(0xFF085E33), verifiedDark, verified],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFF7F1010), dangerDark, danger],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFF8B4800), Color(0xFFC66900), warning],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0xFFE9EFFF),
      Color(0xFFF8FAFF),
      Color(0xFFE9EFFF),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  // ── Premium Shadow Presets ──

  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF2952E6).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF2952E6).withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF2952E6).withValues(alpha: 0.03),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> get shadowXl => [
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF2952E6).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF2952E6).withValues(alpha: 0.04),
      blurRadius: 64,
      offset: const Offset(0, 24),
    ),
  ];

  static List<BoxShadow> get shadowGlow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.25),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowNav => [
    BoxShadow(
      color: const Color(0xFF0A1628).withValues(alpha: 0.04),
      blurRadius: 20,
      offset: const Offset(0, -8),
    ),
    BoxShadow(
      color: const Color(0xFF2952E6).withValues(alpha: 0.03),
      blurRadius: 40,
      offset: const Offset(0, -4),
    ),
  ];
}

/// Context-aware color set for light/dark themes.
/// Access via `AppColors.of(context)`.
class DawaaColors {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryExtraLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color border;
  final Color borderSubtle;
  final Color verified;
  final Color verifiedLight;
  final Color danger;
  final Color dangerLight;
  final Color warning;
  final Color warningLight;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;

  const DawaaColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryExtraLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.border,
    required this.borderSubtle,
    required this.verified,
    required this.verifiedLight,
    required this.danger,
    required this.dangerLight,
    required this.warning,
    required this.warningLight,
    required this.shadowSm,
    required this.shadowMd,
  });
}
