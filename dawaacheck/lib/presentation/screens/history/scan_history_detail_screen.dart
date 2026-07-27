import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/scan_result_model.dart';
import '../../widgets/design_system/design_system.dart';

class ScanHistoryDetailScreen extends StatelessWidget {
  final String scanId;
  final ScanResultModel? result;

  const ScanHistoryDetailScreen({
    super.key,
    required this.scanId,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text('scanDetail'.tr())),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
                child: const Icon(Icons.search_off_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text('scanNotFound'.tr(), style: AppTextStyles.h4),
              const SizedBox(height: 8),
              Text('scanDeletedMsg'.tr(), style: AppTextStyles.body),
            ],
          ),
        ),
      );
    }

    final r = result!;
    final verdictColor = switch (r.overallVerdict.toUpperCase()) {
      'VERIFIED' => AppColors.verified,
      'DANGER' => AppColors.danger,
      _ => AppColors.warning,
    };

    final verdictHeadline = switch (r.overallVerdict.toUpperCase()) {
      'VERIFIED' => ('verdictAuthentic'.tr(), 'verdictAuthenticSoft'.tr()),
      'DANGER' => ('verdictCounterfeit'.tr(), 'verdictCounterfeitSoft'.tr()),
      _ => ('verdictUnconfirmed'.tr(), 'verdictUnconfirmedSoft'.tr()),
    };

    // Short scan code from id (last 4 hex of result id).
    final scanCode = 'DWA-${r.id.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').padLeft(4, '0').substring((r.id.length > 4 ? r.id.length - 4 : 0).clamp(0, r.id.length)).toUpperCase()}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // ── Flat white header with back + mono scan code ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
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
                      scanCode,
                      style: AppTextStyles.monoCaption.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    _HeaderIconButton(
                      icon: Icons.share_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Hero verdict card (left accent strip, signature pattern) ──
          SliverToBoxAdapter(
            child: Hero(
              tag: 'scan-card-${r.id}',
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.sm,
                    AppSpacing.xxl,
                    AppSpacing.md,
                  ),
                  child: ClinicalCard(
                    accentStripColor: verdictColor,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.overallVerdict.toUpperCase()} \u00B7 ${r.scanTimestamp.formattedWithTime.toUpperCase()}',
                          style: AppTextStyles.sectionHeader.copyWith(
                            color: verdictColor,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          verdictHeadline.$1,
                          style: AppTextStyles.verdictHeadline,
                        ),
                        Text(
                          verdictHeadline.$2,
                          style: AppTextStyles.verdictHeadlineSoft.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Mono stats grid
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              _HeroStat(
                                value: '${r.riskScore}',
                                label: 'RISK',
                                valueColor: verdictColor,
                              ),
                              _HeroStatDivider(),
                              _HeroStat(
                                value: '${(r.confidenceScore * 100).toInt()}',
                                label: 'CONFIDENCE',
                                suffix: '%',
                              ),
                              _HeroStatDivider(),
                              _HeroStat(
                                value: '${r.agentResults.length}',
                                label: 'AGENTS',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: AppMotion.entranceDuration)
                .slideY(
                  begin: AppMotion.slideYOffset,
                  end: 0,
                  duration: AppMotion.entranceDuration,
                  curve: AppMotion.entranceCurve,
                ),
          ),

          // Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Medicine Name Card
                  _SectionCard(
                    accentColor: verdictColor,
                    sectionTitle: AppStrings.medicineDetails,
                    child: Column(
                      children: [
                        _DetailRow(label: 'detailMedicine'.tr(), value: r.medicineName),
                        _DetailRow(label: 'detailManufacturer'.tr(), value: r.manufacturer ?? 'detailNotAvailable'.tr()),
                        _DetailRow(label: 'detailRegistration'.tr(), value: r.registrationNumber ?? 'detailNotAvailable'.tr()),
                        _DetailRow(label: 'detailBatch'.tr(), value: r.batchNumber ?? 'detailNotAvailable'.tr()),
                        _DetailRow(label: 'detailExpiry'.tr(), value: r.expiryDate ?? 'detailNotAvailable'.tr()),
                        if (r.riskLevel != 'UNKNOWN')
                          _DetailRow(
                            label: AppStrings.riskLevel,
                            value: r.riskLevel,
                            valueColor: _riskColor(r.riskLevel),
                            showDivider: false,
                          )
                        else
                          _DetailRow(
                            label: AppStrings.confidenceScore,
                            value: '${(r.confidenceScore * 100).toInt()}%',
                            showDivider: false,
                          ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.06, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 14),

                  // Consumer Message
                  if (r.consumerMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: verdictColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: verdictColor.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: verdictColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              r.consumerMessage,
                              style: AppTextStyles.body.copyWith(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms),

                  if (r.consumerMessage.isNotEmpty)
                    const SizedBox(height: 14),

                  // Agent Breakdown
                  if (r.agentResults.isNotEmpty)
                    _SectionCard(
                      accentColor: AppColors.primary,
                      sectionTitle: AppStrings.agentBreakdown,
                      child: Column(
                        children: r.agentResults.asMap().entries.map((entry) {
                          final a = entry.value;
                          final isLast = entry.key == r.agentResults.length - 1;
                          final statusColor = a.isPassed
                              ? AppColors.verified
                              : a.isFailed
                                  ? AppColors.danger
                                  : AppColors.warning;
                          final statusIcon = a.isPassed
                              ? Icons.check_circle_rounded
                              : a.isFailed
                                  ? Icons.cancel_rounded
                                  : Icons.help_rounded;

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(statusIcon, color: statusColor, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a.agentName, style: AppTextStyles.bodySemibold.copyWith(fontSize: 13)),
                                          Text(
                                            a.displayMessage,
                                            style: AppTextStyles.caption.copyWith(color: statusColor, fontSize: 11),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        a.status,
                                        style: AppTextStyles.badge.copyWith(color: statusColor, fontSize: 9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
                            ],
                          );
                        }).toList(),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.06, end: 0, delay: 200.ms, duration: 350.ms, curve: Curves.easeOutCubic),

                  if (r.agentResults.isNotEmpty)
                    const SizedBox(height: 14),

                  // Safety Alerts
                  if (r.safetyAlerts.isNotEmpty) ...[
                    _SectionCard(
                      accentColor: AppColors.danger,
                      sectionTitle: AppStrings.safetyAlerts,
                      child: Column(
                        children: r.safetyAlerts.map((alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(alert.toString(), style: AppTextStyles.body.copyWith(fontSize: 13)),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms),
                    const SizedBox(height: 14),
                  ],

                  // Recommendations
                  if (r.recommendationsList.isNotEmpty) ...[
                    _SectionCard(
                      accentColor: AppColors.primary,
                      sectionTitle: AppStrings.recommendations,
                      child: Column(
                        children: r.recommendationsList.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: AppTextStyles.badge.copyWith(color: AppColors.primary, fontSize: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(entry.value, style: AppTextStyles.body.copyWith(fontSize: 13)),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 400.ms),
                    const SizedBox(height: 14),
                  ],

                  // AMR Info
                  if (r.isAntibiotic == true && r.stewardshipMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medication_rounded, color: AppColors.warning, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'ANTIBIOTIC - ${r.awareClassification ?? ""}',
                                style: AppTextStyles.sectionHeader.copyWith(color: AppColors.warning),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(r.stewardshipMessage!, style: AppTextStyles.body.copyWith(fontSize: 13)),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 500.ms, duration: 400.ms),
                    const SizedBox(height: 14),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.push('/scan');
                          },
                          child: Text(AppStrings.scanAgain),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.go('/home');
                          },
                          child: Text(AppStrings.backToHome),
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 400.ms),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _riskColor(String level) => switch (level.toUpperCase()) {
    'LOW' => AppColors.verified,
    'MODERATE' => AppColors.warning,
    'HIGH' => AppColors.danger,
    'CRITICAL' => AppColors.dangerDark,
    _ => AppColors.textHint,
  };
}

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
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurface,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final String? suffix;
  final Color? valueColor;

  const _HeroStat({
    required this.value,
    required this.label,
    this.suffix,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: value,
              style: AppTextStyles.monoData.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 22,
              ),
              children: [
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: AppTextStyles.monoCaption.copyWith(
                      fontSize: 13,
                      color: valueColor ?? AppColors.textHint,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.monoCaption.copyWith(letterSpacing: 1.4),
          ),
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

class _SectionCard extends StatelessWidget {
  final Color accentColor;
  final String sectionTitle;
  final Widget child;

  const _SectionCard({
    required this.accentColor,
    required this.sectionTitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 16,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                sectionTitle,
                style: AppTextStyles.sectionHeader.copyWith(color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.label)),
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    color: valueColor,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
      ],
    );
  }
}
