import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/session_provider.dart';
import '../../widgets/design_system/design_system.dart';

/// DawaaCheck welcome / sign-in screen.
///
/// Clinical Precision redesign: no ambient orbs, no infinite Lottie, no
/// gradient shader on the app name, no radial glow ring. Typography,
/// hairline borders, and restrained one-shot entrance animations carry the
/// weight. The distinctive detail is the mono version stamp in the bottom
/// corner — reads as "build label" rather than "marketing screen."
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Watches the session, not Firebase auth directly: guest mode may
    // resolve to a device-local session when Firebase is unreachable, and
    // that must navigate too.
    ref.listen(sessionProvider, (previous, next) {
      if (next.valueOrNull != null && context.mounted) {
        context.go('/home');
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),

              // ── Logo mark ──
              Center(child: const _LogoMark()
                  .animate()
                  .fadeIn(duration: AppMotion.entranceDuration)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1, 1),
                    duration: AppMotion.entranceDuration,
                    curve: AppMotion.entranceCurve,
                  )),

              const SizedBox(height: AppSpacing.xl),

              Text(
                AppStrings.appName,
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(color: AppColors.primary),
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

              Text(
                AppStrings.tagline,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              )
                  .animate()
                  .fadeIn(
                    delay: AppMotion.sectionStaggerStep * 2,
                    duration: AppMotion.entranceDuration,
                  ),

              const SizedBox(height: AppSpacing.xxl),

              // ── Stat row — hairline mono data grid ──
              MonoDataGrid(rows: [
                MonoDataRow(label: AppStrings.stat1Label, value: AppStrings.stat1),
                MonoDataRow(label: AppStrings.stat2Label, value: AppStrings.stat2),
                MonoDataRow(label: AppStrings.stat3Label, value: AppStrings.stat3),
              ])
                  .animate()
                  .fadeIn(
                    delay: AppMotion.sectionStaggerStep * 3,
                    duration: AppMotion.entranceDuration,
                  )
                  .slideY(
                    begin: AppMotion.slideYOffset,
                    end: 0,
                    delay: AppMotion.sectionStaggerStep * 3,
                    curve: AppMotion.entranceCurve,
                  ),

              const Spacer(flex: 3),

              // ── Auth buttons ──
              Semantics(
                label: 'Sign in with Google button',
                child: _AuthButton(
                  filled: false,
                  icon: SvgPicture.asset('assets/icons/google_g_logo.svg', width: 20, height: 20),
                  label: AppStrings.continueWithGoogle,
                  onPressed: authState.isLoading
                      ? null
                      : () async {
                          final success = await ref.read(authProvider.notifier).signInWithGoogle();
                          if (!context.mounted) return;
                          if (success) {
                            context.go('/home');
                          } else {
                            final error = ref.read(authProvider).error;
                            if (error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: AppColors.danger,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: AppMotion.sectionStaggerStep * 4,
                    duration: AppMotion.entranceDuration,
                  )
                  .slideY(
                    begin: 0.04,
                    end: 0,
                    delay: AppMotion.sectionStaggerStep * 4,
                    curve: AppMotion.entranceCurve,
                  ),

              const SizedBox(height: AppSpacing.md),

              Semantics(
                label: 'Sign in with email button',
                child: _AuthButton(
                  filled: true,
                  icon: const Icon(Iconsax.sms, size: 18, color: AppColors.white),
                  label: AppStrings.signInWithEmail,
                  onPressed: () => context.push('/sign-in'),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: AppMotion.sectionStaggerStep * 5,
                    duration: AppMotion.entranceDuration,
                  )
                  .slideY(
                    begin: 0.04,
                    end: 0,
                    delay: AppMotion.sectionStaggerStep * 5,
                    curve: AppMotion.entranceCurve,
                  ),

              const SizedBox(height: AppSpacing.lg),

              // ── Create account link ──
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/sign-up');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text.rich(
                      TextSpan(
                        text: AppStrings.dontHaveAccount,
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                        children: [
                          TextSpan(
                            text: AppStrings.createAccount,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: AppMotion.sectionStaggerStep * 6,
                    duration: AppMotion.entranceDuration,
                  ),

              const Spacer(),

              // ── Guest entry ──
              Center(
                child: Semantics(
                  label: 'Continue as guest button',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: authState.isLoading
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              await ref.read(authProvider.notifier).continueAsGuest();
                              if (context.mounted) context.go('/home');
                            },
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Text(
                          AppStrings.continueAsGuest,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: AppMotion.sectionStaggerStep * 7,
                    duration: AppMotion.entranceDuration,
                  ),

              const SizedBox(height: AppSpacing.md),

              if (authState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

              // ── Distinctive element: mono version stamp ──
              Center(
                child: Text(
                  'v1.0 · DWA',
                  style: AppTextStyles.monoCaption,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Logo mark — the real DawaaCheck brand logo ───

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return const BrandLogo(size: 96);
  }
}

// ─── Auth button ───
//
// Flat filled (primary) or flat outlined — no shadow, no gradient. Haptic on tap.

class _AuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final bool filled;

  const _AuthButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: filled ? AppColors.primary : surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: filled
                  ? null
                  : Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: AppTextStyles.buttonPrimary.copyWith(
                    color: filled ? AppColors.white : onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
