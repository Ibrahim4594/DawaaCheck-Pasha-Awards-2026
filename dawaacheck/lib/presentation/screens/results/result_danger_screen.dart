import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../data/models/scan_result_model.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/app_bottom_nav.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/result_extra_cards.dart';
import 'widgets/verdict_hero.dart';

class ResultDangerScreen extends StatefulWidget {
  final ScanResultModel result;

  const ResultDangerScreen({super.key, required this.result});

  @override
  State<ResultDangerScreen> createState() => _ResultDangerScreenState();
}

class _ResultDangerScreenState extends State<ResultDangerScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    // Second pulse after a beat so the user's attention is caught.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final failedAgents = result.agentResults.where((a) => a.isFailed).toList();
    final passedAgents = result.agentResults.where((a) => a.isPassed).toList();
    final uncertainAgents = result.agentResults.where((a) => a.isUncertain).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(context, result),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                MediaQuery.of(context).padding.bottom + 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mono data strip \u2014 matches verified/unverified flow.
                  MonoDataGrid(rows: [
                    MonoDataRow(
                      label: 'AUTH',
                      value: '${(result.confidenceScore * 100).round()}',
                      valueColor: AppColors.danger,
                    ),
                    MonoDataRow(
                      label: 'RISK',
                      value: result.riskLevel.toUpperCase(),
                      valueColor: AppColors.danger,
                    ),
                    MonoDataRow(
                      label: 'AGENTS',
                      value: result.agentResults.isEmpty
                          ? '\u2014'
                          : '${result.agentResults.where((a) => a.status.toUpperCase() == 'FAIL').length}/${result.agentResults.length} FAIL',
                      valueColor: AppColors.danger,
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.lg),

                  _buildRiskAssessmentCard(result),
                  const SizedBox(height: AppSpacing.xl),

                  if (result.safetyAlerts.isNotEmpty) ...[
                    _buildSafetyAlertsCard(result),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  _buildIssuesFoundCard(failedAgents),
                  const SizedBox(height: AppSpacing.xl),

                  _buildAgentBreakdownCard(passedAgents, failedAgents, uncertainAgents),
                  const SizedBox(height: AppSpacing.xl),

                  if (result.recommendationsList.isNotEmpty) ...[
                    _buildRecommendationsCard(result),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  _buildMedicineInfoCard(result),
                  const SizedBox(height: AppSpacing.xxl),

                  if (result.sideEffects.isNotEmpty) ...[
                    SideEffectsCard(sideEffects: result.sideEffects),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (result.halalStatus != null &&
                      result.halalStatus!.isNotEmpty) ...[
                    HalalStatusCard(
                      status: result.halalStatus!,
                      reason: result.halalReason ?? '',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  _buildActionButtons(context),
                ],
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
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // VERDICT HEADER — flat white + 4px red top rule, counterfeit verdict
  // sentence, agent byline. Same pattern as verified/unverified, danger red.
  // ════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context, ScanResultModel result) {
    return VerdictHero(
      gradient: AppColors.dangerGradient,
      accent: AppColors.danger,
      heroIcon: Iconsax.danger,
      absolute: 'verdictCounterfeit'.tr(),
      soft: 'verdictCounterfeitSoft'.tr(),
      riskScore: result.riskScore,
      riskLevel: result.riskLevel,
      scanCode: ScanCodePill.forId(result.id),
      coAgentCount: (result.agentResults.length - 1).clamp(0, 9),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 2 — Risk Assessment Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildRiskAssessmentCard(ScanResultModel result) {
    return _DangerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              _sectionAccent(),
              const SizedBox(width: 10),
              Text(
                AppStrings.overallRisk.toUpperCase(),
                style:
                    AppTextStyles.sectionHeader.copyWith(color: AppColors.danger),
              ),
              const Spacer(),
              // Risk level badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _riskBadgeColor(result.riskLevel),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result.riskLevel,
                  style: AppTextStyles.badge.copyWith(
                    color: AppColors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Risk score horizontal bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.riskScore,
                    style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                  ),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: result.riskScore),
                    duration: const Duration(milliseconds: 1200),
                    builder: (context, value, child) {
                      return Text(
                        '$value/100',
                        style: AppTextStyles.bodySemibold.copyWith(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      // Track
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Fill
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: (result.riskScore / 100).clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, animValue, _) {
                          return FractionallySizedBox(
                            widthFactor: animValue,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Consumer message highlighted box
          if (result.consumerMessage.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: AppDecorations.cardTinted(AppColors.danger),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.consumerMessage,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.dangerDark,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Verdict summary
          if (result.verdictSummary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              result.verdictSummary,
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 3 — Safety Alerts Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildSafetyAlertsCard(ScanResultModel result) {
    return _DangerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionAccent(),
              const SizedBox(width: 10),
              Text(
                AppStrings.safetyAlerts.toUpperCase(),
                style:
                    AppTextStyles.sectionHeader.copyWith(color: AppColors.danger),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${result.safetyAlerts.length}',
                  style: AppTextStyles.badge.copyWith(
                    color: AppColors.danger,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...result.safetyAlerts.asMap().entries.map((entry) {
            final index = entry.key;
            final alert = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < result.safetyAlerts.length - 1 ? 10 : 0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: AppDecorations.cardTinted(AppColors.danger),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          alert.toString(),
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.dangerDark,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 4 — Issues Found Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildIssuesFoundCard(List failedAgents) {
    return _DangerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionAccent(),
              const SizedBox(width: 10),
              Text(
                AppStrings.issuesFound.toUpperCase(),
                style:
                    AppTextStyles.sectionHeader.copyWith(color: AppColors.danger),
              ),
              const Spacer(),
              if (failedAgents.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${failedAgents.length} failed',
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.danger,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (failedAgents.isEmpty)
            _AgentRow(
              icon: Icons.close_rounded,
              iconColor: AppColors.danger,
              iconBgColor: AppColors.danger.withValues(alpha: 0.1),
              title: AppStrings.verificationFailed,
              subtitle: AppStrings.couldNotVerify,
            )
          else
            ...failedAgents.asMap().entries.map((entry) {
              final index = entry.key;
              final agent = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < failedAgents.length - 1 ? 12 : 0,
                ),
                child: _AgentRow(
                  icon: Icons.close_rounded,
                  iconColor: AppColors.danger,
                  iconBgColor: AppColors.danger.withValues(alpha: 0.1),
                  title: agent.agentName,
                  subtitle: agent.failReason ?? agent.displayMessage,
                  trailing: agent.confidenceScore > 0
                      ? Text(
                          '${(agent.confidenceScore * 100).round()}%',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 5 — Agent Breakdown Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildAgentBreakdownCard(
    List passedAgents,
    List failedAgents,
    List uncertainAgents,
  ) {
    final allAgents = [
      ...widget.result.agentResults,
    ]..sort((a, b) => a.agentNumber.compareTo(b.agentNumber));

    return _DangerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionAccent(),
              const SizedBox(width: 10),
              Text(
                AppStrings.agentBreakdown.toUpperCase(),
                style:
                    AppTextStyles.sectionHeader.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Summary chips
          Row(
            children: [
              if (passedAgents.isNotEmpty)
                _buildStatusChip(
                  '${passedAgents.length} Passed',
                  AppColors.verified,
                ),
              if (passedAgents.isNotEmpty) const SizedBox(width: 8),
              if (failedAgents.isNotEmpty)
                _buildStatusChip(
                  '${failedAgents.length} Failed',
                  AppColors.danger,
                ),
              if (failedAgents.isNotEmpty && uncertainAgents.isNotEmpty)
                const SizedBox(width: 8),
              if (uncertainAgents.isNotEmpty)
                _buildStatusChip(
                  '${uncertainAgents.length} Uncertain',
                  AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Agent list
          ...allAgents.asMap().entries.map((entry) {
            final index = entry.key;
            final agent = entry.value;
            final statusIcon = agent.isPassed
                ? Icons.check_circle_rounded
                : agent.isFailed
                    ? Icons.cancel_rounded
                    : Icons.help_rounded;
            final statusColor = agent.isPassed
                ? AppColors.verified
                : agent.isFailed
                    ? AppColors.danger
                    : AppColors.warning;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < allAgents.length - 1 ? 1 : 0,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: index.isEven
                      ? Colors.transparent
                      : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Agent number
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${agent.agentNumber}',
                        style: AppTextStyles.badge.copyWith(
                          color: statusColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Agent name
                    Expanded(
                      child: Text(
                        agent.agentName,
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Confidence
                    if (agent.confidenceScore > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${(agent.confidenceScore * 100).round()}%',
                          style: AppTextStyles.caption.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    // Status icon
                    Icon(statusIcon, color: statusColor, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 6 — Recommendations Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildRecommendationsCard(ScanResultModel result) {
    return _DangerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionAccent(),
              const SizedBox(width: 10),
              Text(
                AppStrings.recommendations.toUpperCase(),
                style:
                    AppTextStyles.sectionHeader.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...result.recommendationsList.asMap().entries.map((entry) {
            final index = entry.key;
            final rec = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom:
                    index < result.recommendationsList.length - 1 ? 12 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Numbered circle
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.danger,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        rec,
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 7 — Medicine Info Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildMedicineInfoCard(ScanResultModel result) {
    final infoRows = <_InfoEntry>[
      _InfoEntry(AppStrings.medicineName, result.medicineName),
      if (result.manufacturer != null && result.manufacturer!.isNotEmpty)
        _InfoEntry('Manufacturer', result.manufacturer!),
      if (result.registrationNumber != null &&
          result.registrationNumber!.isNotEmpty)
        _InfoEntry('Reg. Number', result.registrationNumber!),
      if (result.batchNumber != null && result.batchNumber!.isNotEmpty)
        _InfoEntry('Batch Number', result.batchNumber!),
      if (result.expiryDate != null && result.expiryDate!.isNotEmpty)
        _InfoEntry('Expiry Date', result.expiryDate!),
      if (result.isAntibiotic == true) ...[
        _InfoEntry('Antibiotic', 'Yes'),
        if (result.awareClassification != null)
          _InfoEntry('AWaRe Class', result.awareClassification!),
      ],
    ];

    return _DangerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionAccent(),
              const SizedBox(width: 10),
              Text(
                AppStrings.medicineDetails.toUpperCase(),
                style:
                    AppTextStyles.sectionHeader.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...infoRows.asMap().entries.map((entry) {
            final index = entry.key;
            final info = entry.value;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              decoration: BoxDecoration(
                border: index < infoRows.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      info.label,
                      style: AppTextStyles.label.copyWith(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      info.value,
                      style: AppTextStyles.bodySemibold.copyWith(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Stewardship message
          if (result.stewardshipMessage != null &&
              result.stewardshipMessage!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.medication_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.stewardshipMessage!,
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 8 — Action Buttons
  // ════════════════════════════════════════════════════════════════════

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Report to DRAP — filled red
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.heavyImpact();
              AppToast.error(context, 'DRAP Helpline: 0800-02345 | adr@dfrarpak.gov.pk');
            },
            icon: const Icon(Icons.flag_rounded, size: 20),
            label: Text(
              AppStrings.reportToDrap,
              style: AppTextStyles.buttonPrimary,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Return to Pharmacy — outlined red
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              context.go('/home');
            },
            icon: Icon(Icons.storefront_rounded,
                size: 20, color: AppColors.danger),
            label: Text(
              AppStrings.returnToPharmacy,
              style: AppTextStyles.buttonPrimary.copyWith(
                color: AppColors.danger,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Scan Again — text button
        Semantics(
          label: 'Scan another medicine',
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go('/scan');
              },
              icon: Icon(Icons.qr_code_scanner_rounded,
                  size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              label: Text(
                AppStrings.scanAgain,
                style: AppTextStyles.bodySemibold.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Helpers
  // ════════════════════════════════════════════════════════════════════

  Widget _sectionAccent() {
    return Container(
      width: 4,
      height: 18,
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.badge.copyWith(color: color, fontSize: 10),
      ),
    );
  }

  Color _riskBadgeColor(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.dangerDark;
      case 'HIGH':
        return AppColors.danger;
      case 'MODERATE':
        return AppColors.warning;
      case 'LOW':
        return AppColors.verified;
      default:
        return AppColors.danger;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════
// Reusable _DangerCard — 18px radius, white bg, danger-tinted border
// ══════════════════════════════════════════════════════════════════════

class _DangerCard extends StatelessWidget {
  final Widget child;

  const _DangerCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// _AgentRow — individual agent issue row
// ══════════════════════════════════════════════════════════════════════

class _AgentRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _AgentRow({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodySemibold.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.body.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// _InfoEntry — label/value pair for medicine info
// ══════════════════════════════════════════════════════════════════════

class _InfoEntry {
  final String label;
  final String value;
  const _InfoEntry(this.label, this.value);
}
