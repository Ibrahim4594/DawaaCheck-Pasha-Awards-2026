import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../../domain/providers/session_provider.dart';
import '../../../domain/providers/notification_provider.dart';
import '../../../domain/providers/theme_provider.dart';
import '../../../data/repositories/scan_repository.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/design_system/design_system.dart';

// ── Scan stats provider — fetches real data from Supabase ──

final _scanStatsProvider =
    FutureProvider.family<_ScanStats, String>((ref, userId) async {
  try {
    final history = await ScanRepository().getHistory(userId);
    final total = history.length;
    final verified =
        history.where((s) => s.overallVerdict == 'VERIFIED').length;
    final danger = history.where((s) => s.overallVerdict == 'DANGER').length;
    return _ScanStats(total: total, verified: verified, danger: danger);
  } catch (_) {
    return const _ScanStats(total: 0, verified: 0, danger: 0);
  }
});

class _ScanStats {
  final int total;
  final int verified;
  final int danger;
  const _ScanStats({
    required this.total,
    required this.verified,
    required this.danger,
  });
}

// ── Profile Screen ──

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    final name = user?.displayName ?? AppStrings.guestUser;
    final email = user?.email ?? AppStrings.noEmail;
    final initials = name.isNotEmpty
        ? name
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'G';

    final statsAsync = user != null
        ? ref.watch(_scanStatsProvider(user.uid))
        : const AsyncValue<_ScanStats>.data(
            _ScanStats(total: 0, verified: 0, danger: 0));

    final bottomPad = MediaQuery.of(context).padding.bottom + 80;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // ── Gradient Header with Avatar + Stats ──
            _GradientHeader(
              name: name,
              email: email,
              initials: initials,
              photoUrl: user?.photoUrl,
              statsAsync: statsAsync,
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad),
              child: Column(
                children: [
                  // ── Quick Actions Row ──
                  _QuickActionsRow(),

                  const SizedBox(height: 20),

                  // ── Settings Card ──
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const _NotificationTile(),
                        _divider(),
                        const _DarkModeTile(),
                        _divider(),
                        _SettingTile(
                          icon: Iconsax.global,
                          label: AppStrings.language,
                          accentColor: const Color(0xFF7C3AED),
                          trailing: Text(
                            switch (context.locale.languageCode) {
                              'ur' => AppStrings.urdu,
                              _ => AppStrings.english,
                            },
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textHint, fontSize: 13),
                          ),
                          onTap: () => _showLanguageSheet(context),
                        ),
                        _divider(),
                        _SettingTile(
                          icon: Iconsax.lock,
                          label: AppStrings.privacy,
                          accentColor: AppColors.verified,
                          onTap: () => _showPrivacySheet(context),
                        ),
                        _divider(),
                        _SettingTile(
                          icon: Iconsax.star,
                          label: AppStrings.rateApp,
                          accentColor: AppColors.warning,
                          onTap: () => AppToast.info(context, 'comingSoon'.tr()),
                        ),
                        _divider(),
                        _SettingTile(
                          icon: Iconsax.message_question,
                          label: AppStrings.helpSupport,
                          accentColor: const Color(0xFF0EA5E9),
                          onTap: () => AppToast.info(context, 'comingSoon'.tr()),
                        ),
                        _divider(),
                        _SettingTile(
                          icon: Iconsax.info_circle,
                          label: AppStrings.about,
                          accentColor: AppColors.textSecondary,
                          onTap: () => _showAboutSheet(context),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 450.ms, duration: 500.ms)
                      .slideY(
                          begin: 0.05,
                          end: 0,
                          delay: 450.ms,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic),

                  const SizedBox(height: 24),

                  // ── Sign Out Button ──
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusButton),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _showSignOutDialog(context, ref);
                        },
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusButton),
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusButton),
                            border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.3),
                                width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.logout,
                                  color: AppColors.danger, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                AppStrings.signOut,
                                style: AppTextStyles.bodySemibold
                                    .copyWith(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 400.ms),

                  const SizedBox(height: 28),

                  // ── App Info Section ──
                  _AppInfoSection()
                      .animate()
                      .fadeIn(delay: 700.ms, duration: 500.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gradient Header ──

class _GradientHeader extends ConsumerStatefulWidget {
  final String name;
  final String email;
  final String initials;
  final String? photoUrl;
  final AsyncValue<_ScanStats> statsAsync;

  const _GradientHeader({
    required this.name,
    required this.email,
    required this.initials,
    this.photoUrl,
    required this.statsAsync,
  });

  @override
  ConsumerState<_GradientHeader> createState() => _GradientHeaderState();
}

class _GradientHeaderState extends ConsumerState<_GradientHeader> {
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Flat white header
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(top: topPadding + 20, bottom: 60),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // Mono signature header
              Text(
                'PROFILE \u00B7 DWA-ID',
                style: AppTextStyles.sectionHeader.copyWith(letterSpacing: 1.6),
              ),
              const SizedBox(height: 6),
              // Title
              Text(
                AppStrings.profile,
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 24),

              // Avatar with primary ring
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: ClipOval(
                  child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                      ? Image.network(
                          widget.photoUrl!.contains('googleusercontent.com')
                              ? widget.photoUrl!.replaceAll(RegExp(r'=s\d+-c'), '=s200-c').replaceAll(RegExp(r'/s\d+-c/'), '/s200-c/')
                              : widget.photoUrl!,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _InitialsAvatar(initials: widget.initials);
                          },
                          errorBuilder: (context, error, stack) => _InitialsAvatar(initials: widget.initials),
                        )
                      : _InitialsAvatar(initials: widget.initials),
                ),
              ),
              const SizedBox(height: 14),

              // Name with edit icon
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showEditNameDialog(context, ref, widget.name);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.name,
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.edit_2,
                              color: AppColors.primary,
                              size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Email — rendered in mono so it reads as an account identifier
              Text(
                widget.email,
                style: AppTextStyles.monoSmall,
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(
                begin: -0.03,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic),

        // Stats card overlapping bottom
        Positioned(
          left: 20,
          right: 20,
          bottom: -32,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: widget.statsAsync.when(
              data: (stats) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AnimatedStatColumn(
                    value: stats.total,
                    label: AppStrings.totalScans,
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border.withValues(alpha: 0.5)),
                  _AnimatedStatColumn(
                    value: stats.verified,
                    label: AppStrings.verified,
                    valueColor: AppColors.verified,
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border.withValues(alpha: 0.5)),
                  _AnimatedStatColumn(
                    value: stats.danger,
                    label: AppStrings.danger,
                    valueColor: AppColors.danger,
                  ),
                ],
              ),
              loading: () => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatColumn(value: '-', label: AppStrings.totalScans),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border.withValues(alpha: 0.5)),
                  _StatColumn(
                    value: '-',
                    label: AppStrings.verified,
                    valueColor: AppColors.verified,
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border.withValues(alpha: 0.5)),
                  _StatColumn(
                    value: '-',
                    label: AppStrings.danger,
                    valueColor: AppColors.danger,
                  ),
                ],
              ),
              error: (e, s) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatColumn(value: '0', label: AppStrings.totalScans),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border.withValues(alpha: 0.5)),
                  _StatColumn(
                    value: '0',
                    label: AppStrings.verified,
                    valueColor: AppColors.verified,
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppColors.border.withValues(alpha: 0.5)),
                  _StatColumn(
                    value: '0',
                    label: AppStrings.danger,
                    valueColor: AppColors.danger,
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(
                  begin: 0.1,
                  end: 0,
                  delay: 200.ms,
                  duration: 400.ms,
                  curve: Curves.easeOutCubic),
        ),
      ],
    );
  }
}

// ── Quick Actions Row ──

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Iconsax.warning_2,
              label: AppStrings.reportAdr,
              color: AppColors.danger,
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/adr');
              },
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.15, end: 0, delay: 300.ms, duration: 350.ms, curve: Curves.easeOutCubic),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAction(
              icon: Iconsax.shield_tick,
              label: AppStrings.recalls,
              color: AppColors.warning,
              onTap: () {
                HapticFeedback.selectionClick();
                context.go('/recalls');
              },
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.15, end: 0, delay: 400.ms, duration: 350.ms, curve: Curves.easeOutCubic),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAction(
              icon: Iconsax.location,
              label: AppStrings.safetyMap,
              color: AppColors.verified,
              onTap: () {
                HapticFeedback.selectionClick();
                context.go('/map');
              },
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(begin: 0.15, end: 0, delay: 500.ms, duration: 350.ms, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        splashColor: color.withValues(alpha: 0.08),
        highlightColor: color.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryExtraLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App Info Section ──

class _AppInfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Iconsax.shield_tick, color: AppColors.white, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.appName,
          style: AppTextStyles.h4.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.version,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textHint,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.madeWithLove,
                style: AppTextStyles.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const Icon(Icons.favorite_rounded,
                  color: AppColors.danger, size: 12),
              Text(
                AppStrings.inPakistan,
                style: AppTextStyles.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.developedBy,
          style: AppTextStyles.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.copyright,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textHint,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.trademark,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textHint,
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Sign Out Confirmation Dialog ──

Future<void> _showSignOutDialog(BuildContext context, WidgetRef ref) async {
  HapticFeedback.mediumImpact();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      title: Text(
        AppStrings.signOut,
        style: AppTextStyles.h3,
      ),
      content: Text(
        AppStrings.areYouSureSignOut,
        style: AppTextStyles.body,
      ),
      actions: [
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(ctx, false);
          },
          child: Text(
            AppStrings.cancel,
            style: AppTextStyles.bodySemibold
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.heavyImpact();
            Navigator.pop(ctx, true);
          },
          style: TextButton.styleFrom(
            backgroundColor: AppColors.danger.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
          ),
          child: Text(
            AppStrings.signOut,
            style:
                AppTextStyles.bodySemibold.copyWith(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(authProvider.notifier).signOut();
    if (context.mounted) context.go('/welcome');
  }
}

// ── Edit Name Dialog ──

Future<void> _showEditNameDialog(
    BuildContext context, WidgetRef ref, String currentName) async {
  final controller = TextEditingController(text: currentName);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      title: Text(AppStrings.fullName, style: AppTextStyles.h3),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: AppStrings.fullName,
          hintStyle:
              AppTextStyles.body.copyWith(color: AppColors.textHint),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: AppTextStyles.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            AppStrings.cancel,
            style: AppTextStyles.bodySemibold
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
            ),
          ),
          child: Text(
            AppStrings.submit,
            style: AppTextStyles.bodySemibold
                .copyWith(color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    final newName = controller.text.trim();
    if (newName.isNotEmpty && newName != currentName) {
      final success =
          await ref.read(authProvider.notifier).updateDisplayName(newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'profileNameUpdated'.tr(namedArgs: {'field': AppStrings.fullName})
                : AppStrings.errorGeneric),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Force auth state to refresh so UI updates
        if (success) ref.invalidate(authStateProvider);
      }
    }
  }
  controller.dispose();
}

// ── Language Bottom Sheet ──

void _showLanguageSheet(BuildContext context) {
  final currentLocale = context.locale;
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(AppStrings.language, style: AppTextStyles.h3),
              const SizedBox(height: 20),
              _LanguageOption(
                label: 'English',
                nativeLabel: 'English',
                isSelected: currentLocale.languageCode == 'en',
                onTap: () {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              _LanguageOption(
                label: 'Urdu',
                nativeLabel: '\u0627\u0631\u062F\u0648',
                isSelected: currentLocale.languageCode == 'ur',
                onTap: () {
                  context.setLocale(const Locale('ur'));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

// ── Privacy Bottom Sheet ──

void _showPrivacySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.verified.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.lock, color: AppColors.verified, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(AppStrings.privacyPolicy, style: AppTextStyles.h3),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      controller: scrollController,
                      children: [
                        _privacySection(context,
                          AppStrings.privacyDataCollection,
                          AppStrings.privacyDataCollectionBody,
                        ),
                        _privacySection(context,
                          AppStrings.privacyHowWeUse,
                          AppStrings.privacyHowWeUseBody,
                        ),
                        _privacySection(context,
                          AppStrings.privacyCameraStorage,
                          AppStrings.privacyCameraStorageBody,
                        ),
                        _privacySection(context,
                          AppStrings.privacyAuthentication,
                          AppStrings.privacyAuthenticationBody,
                        ),
                        _privacySection(context,
                          AppStrings.privacyAdr,
                          AppStrings.privacyAdrBody,
                        ),
                        _privacySection(context,
                          AppStrings.privacyDataSecurity,
                          AppStrings.privacyDataSecurityBody,
                        ),
                        _privacySection(context,
                          AppStrings.privacyYourRights,
                          AppStrings.privacyYourRightsBody,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.lastUpdated,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _privacySection(BuildContext context, String title, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.bodySemibold),
        const SizedBox(height: 6),
        Text(
          body,
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

// ── About Bottom Sheet ──

void _showAboutSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // App icon — the real brand logo
                const BrandLogo(size: 64),
                const SizedBox(height: 16),
                Text(AppStrings.appName, style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  AppStrings.versionFull,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    AppStrings.aboutDescription,
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Features summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _aboutFeature(context, Iconsax.cpu, AppStrings.aiAgents),
                    _aboutFeature(context, Iconsax.shield_tick, AppStrings.drapVerified),
                    _aboutFeature(context, Iconsax.flash_1, AppStrings.realTime),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  AppStrings.developedBy,
                  style: AppTextStyles.bodySemibold.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.copyright,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.trademark,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _aboutFeature(BuildContext context, IconData icon, String label) {
  return Column(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      const SizedBox(height: 6),
      Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

// ── Reusable Widgets ──

Widget _divider() {
  // indent = 16 (padding) + 38 (icon) + 14 (gap) = 68
  return Divider(
    height: 1,
    color: AppColors.border.withValues(alpha: 0.4),
    indent: 68,
    endIndent: 16,
  );
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String nativeLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.nativeLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodySemibold),
                  Text(
                    nativeLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatColumn(
      {required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.statNumber
              .copyWith(color: valueColor ?? Theme.of(context).colorScheme.onSurface, fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.monoCaption.copyWith(letterSpacing: 1.4),
        ),
      ],
    );
  }
}

class _AnimatedStatColumn extends StatelessWidget {
  final int value;
  final String label;
  final Color? valueColor;

  const _AnimatedStatColumn(
      {required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, animatedValue, child) {
            return Text(
              '$animatedValue',
              style: AppTextStyles.statNumber
                  .copyWith(color: valueColor ?? Theme.of(context).colorScheme.onSurface, fontSize: 22),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.monoCaption.copyWith(letterSpacing: 1.4),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.accentColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Icon container — solid tile in a soft neutral fill, no glassy alpha.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryExtraLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: AppTextStyles.bodyMedium),
            ),
            trailing ??
                Icon(Iconsax.arrow_right_3,
                    color: AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Notification Toggle Tile (reads real state from provider) ──

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsEnabledProvider);
    final isEnabled = notifState.valueOrNull ?? true;

    return _SettingTile(
      icon: Iconsax.notification,
      label: AppStrings.notifications,
      accentColor: AppColors.primary,
      trailing: Switch.adaptive(
        value: isEnabled,
        onChanged: (_) {
          HapticFeedback.selectionClick();
          ref.read(notificationsEnabledProvider.notifier).toggle();
        },
        activeTrackColor: AppColors.primary,
        activeThumbColor: AppColors.white,
      ),
    );
  }
}

// ── Dark Mode Toggle Tile ──

class _DarkModeTile extends ConsumerStatefulWidget {
  const _DarkModeTile();

  @override
  ConsumerState<_DarkModeTile> createState() => _DarkModeTileState();
}

class _DarkModeTileState extends ConsumerState<_DarkModeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  void _onToggle() {
    HapticFeedback.selectionClick();
    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
    if (isDark) {
      _lottieController.reverse();
    } else {
      _lottieController.forward();
    }
    ref.read(themeModeProvider.notifier).toggle();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return _SettingTile(
      icon: isDark ? Iconsax.moon : Iconsax.sun_1,
      label: 'darkMode'.tr(),
      accentColor: isDark ? const Color(0xFF7C3AED) : const Color(0xFFE07B00),
      trailing: GestureDetector(
        onTap: _onToggle,
        child: SizedBox(
          width: 60,
          height: 36,
          child: Lottie.asset(
            'assets/animations/dark-mode-toggle.json',
            controller: _lottieController,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              _lottieController.duration = composition.duration * 0.4;
              if (isDark) _lottieController.value = 1.0;
            },
            errorBuilder: (context, error, stackTrace) {
              return Switch.adaptive(
                value: isDark,
                onChanged: (_) => _onToggle(),
                activeTrackColor: const Color(0xFF7C3AED),
                activeThumbColor: AppColors.white,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Initials Avatar Fallback ──

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.h1.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
