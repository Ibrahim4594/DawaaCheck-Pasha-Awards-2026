import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/recall_alert_model.dart';
import '../../widgets/design_system/design_system.dart';

class RecallDetailScreen extends StatelessWidget {
  final String recallId;
  final RecallAlertModel? recall;

  const RecallDetailScreen({super.key, required this.recallId, this.recall});

  @override
  Widget build(BuildContext context) {
    final r = recall;
    final isClassI = r?.isClassI ?? true;
    final accent = isClassI ? AppColors.danger : AppColors.warning;

    final displayId = recallId.startsWith('REC-')
        ? recallId
        : 'REC-${recallId.substring((recallId.length > 4 ? recallId.length - 4 : 0).clamp(0, recallId.length)).toUpperCase()}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // ── Top bar ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    _HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.pop();
                      },
                    ),
                    const Spacer(),
                    Text(
                      displayId,
                      style: AppTextStyles.monoCaption
                          .copyWith(color: accent, letterSpacing: 1.4),
                    ),
                    const Spacer(),
                    _HeaderIconButton(
                        icon: Icons.share_rounded,
                        onTap: () => HapticFeedback.lightImpact()),
                  ],
                ),
              ),
            ),
          ),

          // ── Affected banner (only if this recall matches the user's cabinet) ──
          if (r?.userAffected ?? false)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 0),
                child: _AffectedBanner(recall: r!)
                    .animate()
                    .fadeIn(duration: AppMotion.entranceDuration),
              ),
            ),

          // ── Hero recall card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.xxl,
                  (r?.userAffected ?? false) ? AppSpacing.md : AppSpacing.sm,
                  AppSpacing.xxl, AppSpacing.md),
              child: ClinicalCard(
                accentStripColor: accent,
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl,
                    AppSpacing.xl, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE RECALL · DRAP PAKISTAN',
                      style: AppTextStyles.sectionHeader
                          .copyWith(color: accent, letterSpacing: 1.6),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      r?.medicineName ?? 'recallAlert'.tr(),
                      style: AppTextStyles.verdictHeadline,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'recallHeroSub'.tr(),
                      style: AppTextStyles.verdictHeadlineSoft
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          _HeroStat(
                              value: 'ACTIVE',
                              label: 'STATUS',
                              valueColor: accent),
                          _HeroStatDivider(),
                          const _HeroStat(value: 'DRAP', label: 'SOURCE'),
                          _HeroStatDivider(),
                          _HeroStat(
                            value: isClassI ? 'CLASS I' : 'CLASS II',
                            label: 'SEVERITY',
                            valueColor: accent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(duration: AppMotion.entranceDuration)
                .slideY(
                    begin: AppMotion.slideYOffset,
                    end: 0,
                    duration: AppMotion.entranceDuration,
                    curve: AppMotion.entranceCurve),
          ),

          // ── Body ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recall details
                  ClinicalCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(color: accent, label: 'RECALL DETAILS'),
                        const SizedBox(height: AppSpacing.md),
                        if (r != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: isClassI
                                  ? AppColors.dangerLight
                                  : AppColors.warningLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.15),
                                  width: 1),
                            ),
                            child: Text(
                              r.recallReason,
                              style: AppTextStyles.body
                                  .copyWith(fontSize: 13, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MonoRow(
                              label: 'MEDICINE',
                              value: r.medicineName.toUpperCase()),
                          if (r.registrationNumber != null)
                            _MonoRow(
                                label: 'REG NO',
                                value: r.registrationNumber!.toUpperCase()),
                          if (r.batchNumbers.isNotEmpty)
                            _MonoRow(
                                label: 'BATCH',
                                value: r.batchNumbers.join(', ').toUpperCase(),
                                color: accent),
                          _MonoRow(
                              label: 'CLASS',
                              value: isClassI ? 'CLASS I' : 'CLASS II',
                              color: accent),
                          _MonoRow(
                              label: 'ISSUED', value: r.recallDate.formatted),
                          if (r.drapNoticeNumber != null)
                            _MonoRow(
                                label: 'NOTICE',
                                value: r.drapNoticeNumber!.toUpperCase()),
                          _MonoRow(
                              label: 'STATUS',
                              value: 'ACTIVE',
                              color: accent,
                              isLast: true),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.15),
                                  width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: AppColors.danger, size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text('recallDetailFallback'.tr(),
                                      style: AppTextStyles.body
                                          .copyWith(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _MonoRow(
                              label: 'RECALL ID',
                              value: displayId,
                              color: AppColors.danger),
                          _MonoRow(
                              label: 'SOURCE',
                              value: 'DRAP PAKISTAN',
                              isLast: true),
                        ],
                      ],
                    ),
                  ).animate().fadeIn(
                      delay: AppMotion.sectionStaggerStep,
                      duration: AppMotion.entranceDuration),

                  const SizedBox(height: AppSpacing.md),

                  // What to do
                  ClinicalCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                            color: AppColors.primary,
                            label: 'recallWhatToDoTitle'.tr()),
                        const SizedBox(height: AppSpacing.md),
                        ...[
                          'recallStep1'.tr(),
                          'recallStep2'.tr(),
                          'recallStep3'.tr(),
                          'recallStep4'.tr(),
                        ].asMap().entries.map(
                              (entry) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpacing.md),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${entry.key + 1}'.padLeft(2, '0'),
                                        style: AppTextStyles.monoCaption.copyWith(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            letterSpacing: 0),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(entry.value,
                                          style: AppTextStyles.body
                                              .copyWith(fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ).animate().fadeIn(
                      delay: AppMotion.sectionStaggerStep * 2,
                      duration: AppMotion.entranceDuration),

                  const SizedBox(height: AppSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Material(
                      color: AppColors.danger,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusButton),
                      child: InkWell(
                        onTap: () => HapticFeedback.mediumImpact(),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusButton),
                        splashColor: AppColors.white.withValues(alpha: 0.12),
                        child: Center(
                          child: Text('recallContactDrap'.tr(),
                              style: AppTextStyles.buttonPrimary),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(
                      delay: AppMotion.sectionStaggerStep * 3,
                      duration: AppMotion.entranceDuration),

                  SizedBox(
                      height:
                          MediaQuery.of(context).padding.bottom + AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AFFECTED BANNER
// ═══════════════════════════════════════════════════════════════════════════

class _AffectedBanner extends StatelessWidget {
  final RecallAlertModel recall;
  const _AffectedBanner({required this.recall});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: AppColors.white, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IN YOUR CABINET',
                    style: AppTextStyles.sectionHeader.copyWith(
                        color: AppColors.white, letterSpacing: 1.4)),
                const SizedBox(height: 4),
                Text(
                  recall.exactBatchMatch
                      ? 'recallExactBatchWarn'.tr()
                      : 'recallCheckBatch'.tr(),
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.white, fontSize: 13, height: 1.4),
                ),
                if (recall.scannedOn != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'recallScannedAgo'
                        .tr(namedArgs: {'time': recall.scannedOn!.timeAgo}),
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                        fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INTERNAL HELPERS
// ═══════════════════════════════════════════════════════════════════════════

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1.5),
          ),
          child: Icon(icon,
              color: Theme.of(context).colorScheme.onSurface, size: 18),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _HeroStat({required this.value, required this.label, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.mono.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.monoCaption.copyWith(letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

class _HeroStatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.borderSubtle,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final Color color;
  final String label;

  const _SectionTitle({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppTextStyles.sectionHeader
                .copyWith(color: color, letterSpacing: 1.8)),
      ],
    );
  }
}

class _MonoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isLast;

  const _MonoRow({
    required this.label,
    required this.value,
    this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(label,
                    style: AppTextStyles.monoCaption
                        .copyWith(letterSpacing: 1.2)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.mono
                      .copyWith(color: color ?? AppColors.textPrimary, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.borderSubtle),
      ],
    );
  }
}
