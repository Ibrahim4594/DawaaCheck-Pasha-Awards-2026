import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/app_notification.dart';
import '../../domain/providers/notification_provider.dart';
import 'common/app_empty_state.dart';

void showNotificationCenter(BuildContext context) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _NotificationCenterSheet(),
  );
}

class _NotificationCenterSheet extends ConsumerStatefulWidget {
  const _NotificationCenterSheet();

  @override
  ConsumerState<_NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState
    extends ConsumerState<_NotificationCenterSheet> {
  @override
  void initState() {
    super.initState();
    // Refresh history when opened
    Future.microtask(
        () => ref.read(notificationHistoryProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(notificationHistoryProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Iconsax.notification,
                          color: AppColors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppStrings.notifications,
                              style: AppTextStyles.h3
                                  .copyWith(fontSize: 18)),
                          if (unread > 0)
                            Text(
                              '$unread ${'unread'.tr()}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      _HeaderAction(
                        icon: Iconsax.tick_circle,
                        label: 'readAll'.tr(),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(notificationHistoryProvider.notifier)
                              .markAllRead();
                        },
                      ),
                    const SizedBox(width: 8),
                    _HeaderAction(
                      icon: Iconsax.trash,
                      label: 'clearAll'.tr(),
                      color: AppColors.danger,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(notificationHistoryProvider.notifier)
                            .clearAll();
                      },
                    ),
                  ],
                ),
              ),

              Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.5), height: 1),

              // ── List ──
              Expanded(
                child: historyAsync.when(
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return _EmptyState();
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return _NotificationCard(
                          notification: notif,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(notificationHistoryProvider.notifier)
                                .markRead(notif.id);
                            if (notif.route != null) {
                              Navigator.pop(context);
                              context.go(notif.route!);
                            }
                          },
                        )
                            .animate()
                            .fadeIn(
                                delay: Duration(milliseconds: index * 40),
                                duration: 300.ms)
                            .slideX(
                              begin: 0.03,
                              end: 0,
                              delay: Duration(milliseconds: index * 40),
                              duration: 250.ms,
                              curve: Curves.easeOutCubic,
                            );
                      },
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  ),
                  error: (_, _) => AppEmptyState.error(
                    message: 'failedToLoadNotifications'.tr(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Header action button ──

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: c,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppEmptyState.noNotifications();
  }
}

// ── Notification card ──

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = _typeConfig(notification.type);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? theme.colorScheme.surface
              : config.color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? theme.colorScheme.outlineVariant
                : config.color.withValues(alpha: 0.2),
            width: notification.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(config.icon, color: config.color, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: config.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          config.label,
                          style: AppTextStyles.caption.copyWith(
                            color: config.color,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Time ago
                      Text(
                        _timeAgo(notification.timestamp),
                        style: AppTextStyles.caption.copyWith(
                          color: theme.hintColor,
                          fontSize: 10,
                        ),
                      ),
                      // Unread dot
                      if (!notification.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: config.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.title,
                    style: AppTextStyles.bodySemibold.copyWith(
                      fontSize: 13,
                      color: notification.isRead
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: theme.hintColor,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Type configuration ──

class _NotifTypeConfig {
  final IconData icon;
  final Color color;
  final String label;

  const _NotifTypeConfig(this.icon, this.color, this.label);
}

_NotifTypeConfig _typeConfig(NotificationType type) {
  switch (type) {
    case NotificationType.scanVerified:
      return const _NotifTypeConfig(
          Iconsax.shield_tick, AppColors.verified, 'VERIFIED');
    case NotificationType.scanDanger:
      return const _NotifTypeConfig(
          Iconsax.danger, AppColors.danger, 'DANGER');
    case NotificationType.scanUnverified:
      return const _NotifTypeConfig(
          Iconsax.warning_2, AppColors.warning, 'UNVERIFIED');
    case NotificationType.recallAlert:
      return const _NotifTypeConfig(
          Iconsax.notification_bing, AppColors.danger, 'RECALL');
    case NotificationType.welcome:
      return _NotifTypeConfig(
          Iconsax.heart, const Color(0xFF7C3AED), 'WELCOME');
    case NotificationType.safetyTip:
      return const _NotifTypeConfig(
          Iconsax.lamp_charge, AppColors.primary, 'TIP');
    case NotificationType.scanReminder:
      return _NotifTypeConfig(
          Iconsax.clock, const Color(0xFF0EA5E9), 'REMINDER');
  }
}

// ── Time ago helper ──

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'justNow'.tr();
  if (diff.inMinutes < 60) {
    return 'minAgo'.tr(namedArgs: {'n': diff.inMinutes.toString()});
  }
  if (diff.inHours < 24) {
    return 'hrAgo'.tr(namedArgs: {'n': diff.inHours.toString()});
  }
  if (diff.inDays < 7) {
    return 'dayAgo'.tr(namedArgs: {'n': diff.inDays.toString()});
  }
  return '${dt.day}/${dt.month}/${dt.year}';
}
