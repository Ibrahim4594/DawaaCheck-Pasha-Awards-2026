import 'dart:async';

import 'package:animations/animations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/app_notification.dart';
import '../../../domain/providers/notification_provider.dart';
import '../../../domain/providers/recall_provider.dart';
import '../../../domain/providers/scan_provider.dart';
import 'app_bottom_nav.dart';

/// Premium bottom navigation shell wrapping main app screens
class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bannerController;
  late final Animation<Offset> _bannerSlide;
  AppNotification? _bannerNotification;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Register in-app overlay callback
    NotificationService().onForegroundNotification = _showBanner;

    // Kick off the proactive recall cross-check as soon as the app is entered,
    // so a medicine the user scanned that DRAP later recalled surfaces an alert
    // even before they open the Recalls tab. De-duped so it alerts only once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recallProvider);
    });
  }

  @override
  void dispose() {
    NotificationService().onForegroundNotification = null;
    _bannerController.dispose();
    _autoDismiss?.cancel();
    super.dispose();
  }

  void _showBanner(AppNotification notification) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _bannerNotification = notification);
    _bannerController.forward();
    // Refresh the history provider so badge updates
    ref.read(notificationHistoryProvider.notifier).refresh();
    _autoDismiss?.cancel();
    _autoDismiss = Timer(const Duration(seconds: 4), _dismissBanner);
  }

  void _dismissBanner() {
    if (!mounted) return;
    _bannerController.reverse();
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/terminal')) return 2;
    if (location.startsWith('/recalls')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _resumeScan(BuildContext context, ScanState scan) {
    HapticFeedback.lightImpact();
    if (scan.isProcessing) {
      context.go('/scan/processing');
    } else if (scan.result != null) {
      final v = scan.result!.overallVerdict.toUpperCase();
      final route = v == 'VERIFIED'
          ? '/result/verified'
          : v == 'DANGER'
              ? '/result/danger'
              : '/result/unverified';
      context.go(route, extra: scan.result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);
    final scan = ref.watch(scanProvider);
    final showResume = scan.isProcessing || scan.result != null;

    return Scaffold(
      body: Stack(
        children: [
          PageTransitionSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
              return FadeThroughTransition(
                animation: primaryAnimation,
                secondaryAnimation: secondaryAnimation,
                child: child,
              );
            },
            child: KeyedSubtree(
              key: ValueKey(current),
              child: widget.child,
            ),
          ),

          // ── In-app notification banner overlay ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _bannerSlide,
              child: _bannerNotification != null
                  ? _InAppBanner(
                      notification: _bannerNotification!,
                      onTap: () {
                        _dismissBanner();
                        if (_bannerNotification?.route != null) {
                          context.go(_bannerNotification!.route!);
                        }
                      },
                      onDismiss: _dismissBanner,
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // ── Resume-scan pill (shown on tabs while a scan runs / result waits) ──
          if (showResume)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 88,
              child: _ResumeScanPill(
                scan: scan,
                onTap: () => _resumeScan(context, scan),
              ),
            ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}

// ── Resume-scan pill ──

class _ResumeScanPill extends StatelessWidget {
  final ScanState scan;
  final VoidCallback onTap;

  const _ResumeScanPill({required this.scan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final processing = scan.isProcessing;
    final verdict = scan.result?.overallVerdict.toUpperCase();
    final color = processing
        ? AppColors.primary
        : verdict == 'VERIFIED'
            ? AppColors.verified
            : verdict == 'DANGER'
                ? AppColors.danger
                : AppColors.warning;

    final label = processing
        ? 'resumeScanProcessing'.tr()
        : 'resumeScanResult'.tr(
            namedArgs: {'medicine': scan.result?.medicineName ?? ''},
          );

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (processing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              else
                const Icon(Iconsax.document_text,
                    color: AppColors.white, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodySemibold.copyWith(
                    color: AppColors.white,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Iconsax.arrow_right_3,
                  color: AppColors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── In-app notification banner ──

class _InAppBanner extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppBanner({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final config = _bannerConfig(notification.type);

    return GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          onDismiss();
        }
      },
      child: Container(
        margin: EdgeInsets.only(top: topPad + 4, left: 12, right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(
            color: config.color.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: config.color.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(config.icon, color: config.color, size: 22),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: AppTextStyles.bodySemibold.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).hintColor,
                      fontSize: 11,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Close
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded,
                  color: Theme.of(context).hintColor, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerConfig {
  final IconData icon;
  final Color color;
  const _BannerConfig(this.icon, this.color);
}

_BannerConfig _bannerConfig(NotificationType type) {
  switch (type) {
    case NotificationType.scanVerified:
      return const _BannerConfig(Iconsax.shield_tick, AppColors.verified);
    case NotificationType.scanDanger:
      return const _BannerConfig(Iconsax.danger, AppColors.danger);
    case NotificationType.scanUnverified:
      return const _BannerConfig(Iconsax.warning_2, AppColors.warning);
    case NotificationType.recallAlert:
      return const _BannerConfig(
          Iconsax.notification_bing, AppColors.danger);
    case NotificationType.welcome:
      return _BannerConfig(Iconsax.heart, const Color(0xFF7C3AED));
    case NotificationType.safetyTip:
      return const _BannerConfig(Iconsax.lamp_charge, AppColors.primary);
    case NotificationType.scanReminder:
      return _BannerConfig(Iconsax.clock, const Color(0xFF0EA5E9));
  }
}
