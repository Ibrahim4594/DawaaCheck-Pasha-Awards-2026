import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/providers/session_provider.dart';
import '../../widgets/design_system/design_system.dart';

/// DawaaCheck splash + onboarding flow.
///
/// Two phases render in a single route so the transition from brand reveal to
/// first-run onboarding is a cross-fade rather than a route push. This matches
/// the Clinical Precision motion budget — one entrance choreography per
/// screen, no ambient loops.
///
/// Phase A — **Splash** (1.6s): logo tile, wordmark, tagline, mono build stamp.
/// Phase B — **Onboarding**: 4-page PageView (language picker + 3 content pages).
/// Returning users skip phase B entirely.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Phase control ──
  bool _showOnboarding = false;

  // ── Cross-fade splash → onboarding (also used for final exit) ──
  late final AnimationController _fade;

  // ── Onboarding state ──
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();

    _fade = AnimationController(
      vsync: this,
      duration: AppMotion.entranceDuration,
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Hold the splash for 1.6s so the brand registers before anything moves.
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

    if (onboardingDone) {
      // Returning user — fade splash out, route directly.
      final user = ref.read(sessionProvider).valueOrNull;
      await _fade.forward();
      if (mounted) context.go(user != null ? '/home' : '/welcome');
    } else {
      // New user — cross-fade to onboarding.
      await _fade.forward();
      if (mounted) {
        setState(() => _showOnboarding = true);
        _fade.reverse();
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_currentPage == 0) {
      // Commit locale choice before leaving the language page.
      context.setLocale(Locale(_selectedLanguage));
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool('language_selected', true),
      );
    }
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: AppMotion.entranceCurve,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('language_selected', true);
    await prefs.setBool('onboarding_complete', true);
    // Fade the onboarding shell out before routing to prevent any flash.
    await _fade.forward();
    if (mounted) context.go('/welcome');
  }

  @override
  void dispose() {
    _fade.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _fade,
        builder: (context, child) {
          // Splash phase: _fade plays forward (0→1), opacity fades 1→0.
          // Swap to onboarding with _fade still at 1, then reverse (1→0),
          // bringing onboarding opacity 0→1. On final _finish, _fade plays
          // forward again to fade onboarding out before navigation.
          final opacity = (1.0 - _fade.value).clamp(0.0, 1.0);
          // Each phase is wrapped in Positioned.fill so it always receives
          // tight full-screen constraints. Without this, the Column (which
          // uses Spacer / Expanded) can size to its natural height under the
          // Stack's loose constraints and render top-aligned — the "half in,
          // half out of screen" onboarding bug.
          return Stack(
            children: [
              if (!_showOnboarding)
                Positioned.fill(
                  child: Opacity(opacity: opacity, child: const _SplashContent()),
                ),
              if (_showOnboarding)
                Positioned.fill(
                  child: Opacity(
                    opacity: opacity,
                    child: _OnboardingShell(
                      pageController: _pageController,
                      currentPage: _currentPage,
                      selectedLanguage: _selectedLanguage,
                      onPageChanged: _onPageChanged,
                      onLanguageChanged: (code) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedLanguage = code);
                      },
                      onNext: _next,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PHASE A — SPLASH
// ═════════════════════════════════════════════════════════════════════════════

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          children: [
            const Spacer(flex: 4),

            // ── Logo tile ──
            const _LogoTile()
                .animate()
                .fadeIn(duration: AppMotion.entranceDuration)
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1, 1),
                  duration: AppMotion.entranceDuration,
                  curve: AppMotion.entranceCurve,
                ),

            const SizedBox(height: AppSpacing.xl),

            // ── Wordmark ──
            Text(
              AppStrings.appName,
              textAlign: TextAlign.center,
              style: AppTextStyles.h1.copyWith(
                color: AppColors.primary,
                fontSize: 32,
                letterSpacing: -0.7,
              ),
            )
                .animate()
                .fadeIn(
                  delay: AppMotion.sectionStaggerStep,
                  duration: AppMotion.entranceDuration,
                )
                .slideY(
                  begin: AppMotion.slideYOffset,
                  end: 0,
                  delay: AppMotion.sectionStaggerStep,
                  curve: AppMotion.entranceCurve,
                ),

            const SizedBox(height: AppSpacing.xs),

            // ── Tagline ──
            Text(
              AppStrings.tagline,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 13),
            )
                .animate()
                .fadeIn(
                  delay: AppMotion.sectionStaggerStep * 2,
                  duration: AppMotion.entranceDuration,
                ),

            const Spacer(flex: 5),

            // ── Signature detail: mono build stamp ──
            // Reads like a firmware plate on medical hardware, not marketing.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 1.5,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'DWA-CORE · v1.0',
                  style: AppTextStyles.monoCaption.copyWith(
                    letterSpacing: 1.6,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'PAKISTAN · DRAP REGISTRY',
                  style: AppTextStyles.monoCaption.copyWith(letterSpacing: 1.6),
                ),
              ],
            )
                .animate()
                .fadeIn(
                  delay: AppMotion.sectionStaggerStep * 4,
                  duration: AppMotion.entranceDuration,
                ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// The DawaaCheck brand mark — the real logo, sized to read as a brand plate.
class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return const BrandLogo(size: 104);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PHASE B — ONBOARDING
// ═════════════════════════════════════════════════════════════════════════════

class _OnboardingShell extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final String selectedLanguage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onNext;

  const _OnboardingShell({
    required this.pageController,
    required this.currentPage,
    required this.selectedLanguage,
    required this.onPageChanged,
    required this.onLanguageChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    // bottom: false — the _BottomBar adds MediaQuery.padding.bottom itself, so
    // letting SafeArea also inset the bottom would double-count it and float
    // the whole shell upward.
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── Top rail: page counter in mono ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.md,
              AppSpacing.xxl,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${'onbStepLabel'.tr()} ${(currentPage + 1).toString().padLeft(2, '0')} / 04',
                  style: AppTextStyles.monoCaption.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.6,
                  ),
                ),
                if (currentPage < 3)
                  _SkipLink(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      SharedPreferences.getInstance().then((prefs) async {
                        await prefs.setBool('language_selected', true);
                        await prefs.setBool('onboarding_complete', true);
                        if (context.mounted) context.go('/welcome');
                      });
                    },
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Pages ──
          // Translation keys are resolved inside _ContentPage.build(), so the
          // PageView rebuilds into the new locale when `setLocale` fires.
          Expanded(
            child: PageView(
              controller: pageController,
              onPageChanged: onPageChanged,
              physics: const ClampingScrollPhysics(),
              children: [
                _LanguagePage(
                  selected: selectedLanguage,
                  onSelect: onLanguageChanged,
                ),
                const _ContentPage(
                  lottieAsset: 'assets/animations/doc-scan.json',
                  sectionHeaderKey: 'onbScanHeader',
                  headlineKey: 'onbScanHeadline',
                  bodyKey: 'onbScanBody',
                  statsLabelKeys: [
                    'onbScanStat1Label',
                    'onbScanStat2Label',
                    'onbScanStat3Label',
                  ],
                  statsValueKeys: [
                    'onbScanStat1Value',
                    'onbScanStat2Value',
                    'onbScanStat3Value',
                  ],
                ),
                const _ContentPage(
                  lottieAsset: 'assets/animations/robot-3d.json',
                  sectionHeaderKey: 'onbInvestHeader',
                  headlineKey: 'onbInvestHeadline',
                  bodyKey: 'onbInvestBody',
                  features: [
                    (
                      Icons.fact_check_rounded,
                      'onbInvestFeature1Title',
                      'onbInvestFeature1Desc',
                    ),
                    (
                      Icons.biotech_rounded,
                      'onbInvestFeature2Title',
                      'onbInvestFeature2Desc',
                    ),
                    (
                      Icons.notifications_active_rounded,
                      'onbInvestFeature3Title',
                      'onbInvestFeature3Desc',
                    ),
                  ],
                ),
                const _ContentPage(
                  lottieAsset: 'assets/animations/lock-shield.json',
                  sectionHeaderKey: 'onbTrustHeader',
                  headlineKey: 'onbTrustHeadline',
                  bodyKey: 'onbTrustBody',
                  statsLabelKeys: [
                    'onbTrustStat1Label',
                    'onbTrustStat2Label',
                    'onbTrustStat3Label',
                  ],
                  statsValueKeys: [
                    'onbTrustStat1Value',
                    'onbTrustStat2Value',
                    'onbTrustStat3Value',
                  ],
                ),
              ],
            ),
          ),

          // ── Bottom bar: dots + primary action ──
          _BottomBar(
            currentPage: currentPage,
            buttonLabel: currentPage == 3
                ? AppStrings.onboarding3Button
                : (currentPage == 0
                    ? 'onbContinueBtn'.tr()
                    : 'onbNextBtn'.tr()),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _SkipLink extends StatelessWidget {
  final VoidCallback onTap;
  const _SkipLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            AppStrings.skip.toUpperCase(),
            style: AppTextStyles.monoCaption.copyWith(
              letterSpacing: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE 0 — LANGUAGE PICKER
// ─────────────────────────────────────────────────────────────────────────────

class _LanguagePage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _LanguagePage({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'onbLangHeader'.tr(),
            style: AppTextStyles.sectionHeader,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'onbLangHeadline'.tr(),
            style: AppTextStyles.h1.copyWith(letterSpacing: -0.5),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'onbLangSubtitle'.tr(),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Language option copy stays in each language's native script
          // regardless of the current locale — the whole point of a language
          // picker is to show the user what each option looks like.
          _LanguageOption(
            code: 'en',
            tag: 'EN',
            title: 'onbLangEnglishTitle'.tr(),
            subtitle: 'onbLangEnglishSubtitle'.tr(),
            isSelected: selected == 'en',
            onTap: () => onSelect('en'),
          ),
          const SizedBox(height: AppSpacing.md),
          _LanguageOption(
            code: 'ur',
            // Two-letter Latin tag mirrors the English card's "EN" for visual
            // consistency; the Nastaliq subtitle below already signals the
            // language's actual script.
            tag: 'UR',
            title: 'onbLangUrduTitle'.tr(),
            subtitle: 'onbLangUrduSubtitle'.tr(),
            isSelected: selected == 'ur',
            onTap: () => onSelect('ur'),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String tag;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.code,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      onTap: onTap,
      accentStripColor: isSelected ? AppColors.primary : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          // Mono tag badge on the left — reads like a form field label.
          // Both EN and UR tags now use the same mono font size for visual
          // symmetry (the old Urdu glyph used a larger size to compensate for
          // Nastaliq's smaller visual x-height; with a Latin "UR" tag we keep
          // a consistent 13px).
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text(
              tag,
              style: AppTextStyles.mono.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.white : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          // Selection marker — square, not circular (Clinical Precision).
          _SelectionMarker(isSelected: isSelected),
        ],
      ),
    );
  }
}

class _SelectionMarker extends StatelessWidget {
  final bool isSelected;
  const _SelectionMarker({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.white, size: 14)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGES 1-3 — CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _ContentPage extends StatelessWidget {
  final String lottieAsset;

  /// Translation keys — resolved via `.tr()` at build time so locale changes
  /// rebuild the page into the new language.
  final String sectionHeaderKey;
  final String headlineKey;
  final String bodyKey;

  /// Parallel lists of translation keys for the stats strip. Both must be the
  /// same length. Keys for labels (e.g. "AGENTS") AND values (e.g. "10") so
  /// locale can flip both in unison ("ایجنٹ" + "10").
  final List<String>? statsLabelKeys;
  final List<String>? statsValueKeys;

  /// Feature list: (icon, titleKey, descKey).
  final List<(IconData, String, String)>? features;

  const _ContentPage({
    required this.lottieAsset,
    required this.sectionHeaderKey,
    required this.headlineKey,
    required this.bodyKey,
    this.statsLabelKeys,
    this.statsValueKeys,
    this.features,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lottie — one-shot, rendered in a soft primary-tinted tile so it
          // sits on the page rather than floats ambiently.
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
            child: Lottie.asset(
              lottieAsset,
              fit: BoxFit.contain,
              repeat: false,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary.withValues(alpha: 0.4),
                  size: 64,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Section header (mono uppercase — signature detail).
          Text(sectionHeaderKey.tr(), style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.md),

          // Headline
          Text(
            headlineKey.tr(),
            style: AppTextStyles.h1.copyWith(letterSpacing: -0.5),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Body
          Text(bodyKey.tr(), style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xl),

          // Stats OR Features
          if (statsLabelKeys != null && statsValueKeys != null)
            _StatsRow(
              labels: statsLabelKeys!.map((k) => k.tr()).toList(),
              values: statsValueKeys!.map((k) => k.tr()).toList(),
            ),
          if (features != null)
            Column(
              children: features!
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _FeatureRow(
                        icon: f.$1,
                        title: f.$2.tr(),
                        description: f.$3.tr(),
                      ),
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<String> labels;
  final List<String> values;

  const _StatsRow({required this.labels, required this.values});

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: List.generate(labels.length, (i) {
            final isLast = i == labels.length - 1;
            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          right: BorderSide(
                            color: AppColors.borderSubtle,
                            width: 1,
                          ),
                        ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                  horizontal: AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      values[i],
                      style: AppTextStyles.monoData.copyWith(
                        color: AppColors.primary,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: AppTextStyles.monoCaption.copyWith(
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTextStyles.body.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM BAR — dots + primary CTA
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentPage;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _BottomBar({
    required this.currentPage,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final isActive = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: AppMotion.entranceCurve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                splashColor: AppColors.white.withValues(alpha: 0.1),
                child: Center(
                  child: Text(
                    buttonLabel,
                    style: AppTextStyles.buttonPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
