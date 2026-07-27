import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/scan_result_model.dart';
import '../../../data/repositories/scan_repository.dart';
import '../../../domain/providers/session_provider.dart';
import '../../../domain/providers/notification_provider.dart';
import '../../../domain/providers/recall_provider.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/category_icon.dart';
import '../../widgets/common/recall_alert_banner.dart';
import '../../widgets/common/scan_cta_banner.dart';
import '../../widgets/design_system/design_system.dart';
import '../../widgets/notification_center.dart';

/// Recent scans (3 most recent) for the home dashboard.
final _recentScansProvider = FutureProvider<List<ScanResultModel>>((ref) async {
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null) return [];
  try {
    final history = await ScanRepository().getHistory(session.uid);
    return history.take(3).toList();
  } catch (_) {
    return [];
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final recalls = ref.watch(recallProvider);
    final greeting = DateTime.now().greeting;
    // Use first name if set; otherwise fall back to the localized "Guest User"
    // label (reads as a name in h2 rather than the old placeholder "there").
    final name = user?.displayName?.split(' ').first ?? AppStrings.guestUser;
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;
    final theme = Theme.of(context);

    // Distinctive mono date/time line shown under the greeting.
    final dateLine = DateFormat("EEE · d MMM · HH:mm").format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: theme.colorScheme.surface,
        onRefresh: () async {
          ref.invalidate(_recentScansProvider);
          await ref.read(_recentScansProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          slivers: [
            // ── Header: greeting, mono date, notification bell ──
            SliverToBoxAdapter(
              child: Container(
                color: theme.colorScheme.surface,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + AppSpacing.xl,
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  bottom: AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting,',
                                style: AppTextStyles.body.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(name, style: AppTextStyles.h2),
                              const SizedBox(height: 6),
                              // Distinctive element: mono date/time line
                              Text(dateLine, style: AppTextStyles.monoCaption),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => showNotificationCenter(context),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                            child: const _NotificationBell(),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: AppMotion.entranceDuration)
                        .slideY(
                          begin: -0.1,
                          end: 0,
                          duration: AppMotion.entranceDuration,
                          curve: AppMotion.entranceCurve,
                        ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Search bar (flattened — border only, no shadow) ──
                    _SearchBar(onTap: () {
                      HapticFeedback.lightImpact();
                      context.go('/history');
                    })
                        .animate()
                        .fadeIn(
                          delay: AppMotion.sectionStaggerStep,
                          duration: AppMotion.entranceDuration,
                        )
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          delay: AppMotion.sectionStaggerStep,
                          curve: AppMotion.entranceCurve,
                        ),
                  ],
                ),
              ),
            ),

            // ── Body ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  bottomPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live system status strip \u2014 signature detail.
                    // Reads like a status line on a clinical workstation.
                    // FittedBox guards against overflow on narrow viewports
                    // (the full string is ~38 chars of mono at letterSpacing
                    // 1.4 — tight at 360px widths).
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.verified,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'ONLINE \u00B7 329 DRAP MEDICINES \u00B7 10 AGENTS READY',
                              style: AppTextStyles.monoCaption.copyWith(letterSpacing: 1.4),
                            ),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(
                          delay: AppMotion.sectionStaggerStep * 2,
                          duration: AppMotion.entranceDuration,
                        ),

                    const SizedBox(height: AppSpacing.lg),

                    // Category icons row (flat hairline tiles)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        CategoryIcon(
                          icon: Iconsax.scan_barcode,
                          label: AppStrings.scan,
                          color: AppColors.primary,
                          onTap: () => context.push('/scan'),
                        ),
                        CategoryIcon(
                          icon: Iconsax.health,
                          label: AppStrings.medicines,
                          color: AppColors.primary,
                          onTap: () => AppToast.info(context, 'comingSoon'.tr()),
                        ),
                        CategoryIcon(
                          icon: Iconsax.shield_tick,
                          label: AppStrings.recalls,
                          color: AppColors.warning,
                          onTap: () => context.go('/recalls'),
                        ),
                        CategoryIcon(
                          icon: Iconsax.location,
                          label: AppStrings.safetyMap,
                          color: AppColors.verified,
                          onTap: () => context.go('/map'),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(
                          delay: AppMotion.sectionStaggerStep * 2,
                          duration: AppMotion.entranceDuration,
                        )
                        .slideY(
                          begin: AppMotion.slideYOffset,
                          end: 0,
                          delay: AppMotion.sectionStaggerStep * 2,
                          curve: AppMotion.entranceCurve,
                        ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Scan CTA Banner (flat primary, no shimmer, no pulse)
                    ScanCTABanner(onTap: () => context.push('/scan'))
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

                    const SizedBox(height: AppSpacing.xl),

                    // Recall alert banner (conditional)
                    recalls.when(
                      data: (list) {
                        final affected = list.where((r) => r.userAffected).toList();
                        if (affected.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: RecallAlertBanner(
                            count: affected.length,
                            onTap: () => context.go('/recalls'),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),

                    // Recent Scans section header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.recentScans.toUpperCase(),
                          style: AppTextStyles.sectionHeader,
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.go('/history');
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                AppStrings.seeAll,
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(
                          delay: AppMotion.sectionStaggerStep * 5,
                          duration: AppMotion.entranceDuration,
                        ),

                    const SizedBox(height: AppSpacing.md),

                    // Recent scan cards — ClinicalScanCard list with 40ms list stagger
                    ref.watch(_recentScansProvider).when(
                          data: (scans) {
                            if (scans.isEmpty) {
                              return ClinicalCard(
                                child: AppEmptyState.noScans(
                                  onScanTap: () {
                                    HapticFeedback.lightImpact();
                                    context.push('/scan');
                                  },
                                ),
                              )
                                  .animate()
                                  .fadeIn(
                                    delay: AppMotion.sectionStaggerStep * 6,
                                    duration: AppMotion.entranceDuration,
                                  );
                            }
                            return Column(
                              children: scans.asMap().entries.map((entry) {
                                final i = entry.key;
                                final scan = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: Hero(
                                    tag: 'scan-card-${scan.id}',
                                    child: ClinicalScanCard.fromVerdictString(
                                      medicineName: scan.medicineName,
                                      manufacturer: scan.manufacturer ?? 'unknown'.tr(),
                                      verdictString: scan.overallVerdict,
                                      scanCode: ScanCodePill.forId(scan.id),
                                      scanTime: scan.scanTimestamp,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        context.push('/history/${scan.id}', extra: scan);
                                      },
                                    ),
                                  ),
                                )
                                    .animate()
                                    .fadeIn(
                                      delay: AppMotion.sectionStaggerStep * 6 +
                                          AppMotion.listDelay(i),
                                      duration: AppMotion.entranceDuration,
                                    )
                                    .slideY(
                                      begin: AppMotion.slideYOffset,
                                      end: 0,
                                      delay: AppMotion.sectionStaggerStep * 6 +
                                          AppMotion.listDelay(i),
                                      curve: AppMotion.entranceCurve,
                                    );
                              }).toList(),
                            );
                          },
                          loading: () => Skeletonizer(
                            enabled: true,
                            child: Column(
                              children: List.generate(
                                3,
                                (_) => const Padding(
                                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                                  child: _ScanCardSkeleton(),
                                ),
                              ),
                            ),
                          ),
                          error: (_, _) => ClinicalCard(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                            child: Column(
                              children: [
                                Icon(Iconsax.cloud_cross,
                                    color: theme.hintColor, size: 32),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  AppStrings.errorGeneric,
                                  style: AppTextStyles.body
                                      .copyWith(color: theme.hintColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search bar (flat, hairline) ───

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(
              Iconsax.search_normal_1,
              color: AppColors.textHint,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              AppStrings.searchHint,
              style: AppTextStyles.body.copyWith(
                color: theme.hintColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Notification bell with unread badge ───

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final theme = Theme.of(context);

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Center(
              child: Icon(
                Iconsax.notification,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.surface, width: 2),
                ),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
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

// ─── Scan card skeleton (used while recent scans load) ───

class _ScanCardSkeleton extends StatelessWidget {
  const _ScanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 160, height: 16, color: AppColors.white),
                const SizedBox(height: 6),
                Container(width: 120, height: 10, color: AppColors.white),
              ],
            ),
          ),
          Container(width: 50, height: 18, color: AppColors.white),
        ],
      ),
    );
  }
}
