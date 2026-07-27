import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/app_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/agent_result_model.dart';
import '../../../data/models/scan_result_model.dart';
import '../../widgets/common/app_bottom_nav.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/result_extra_cards.dart';
import 'widgets/verdict_hero.dart';

class ResultVerifiedScreen extends StatefulWidget {
  final ScanResultModel result;

  const ResultVerifiedScreen({super.key, required this.result});

  @override
  State<ResultVerifiedScreen> createState() => _ResultVerifiedScreenState();
}

class _ResultVerifiedScreenState extends State<ResultVerifiedScreen>
{

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':
        return AppColors.verified;
      case 'MODERATE':
        return AppColors.warning;
      case 'HIGH':
        return AppColors.danger;
      case 'CRITICAL':
        return AppColors.dangerDark;
      default:
        return AppColors.textHint;
    }
  }

  IconData _agentStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PASS':
        return Icons.check_circle_rounded;
      case 'FAIL':
        return Icons.cancel_rounded;
      case 'UNCERTAIN':
        return Icons.help_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  Color _agentStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PASS':
        return AppColors.verified;
      case 'FAIL':
        return AppColors.danger;
      case 'UNCERTAIN':
        return AppColors.warning;
      default:
        return AppColors.textHint;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      bottomNavigationBar: const AppBottomNav(),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // ── Verdict header now scrolls with the page ──
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
                  _buildRiskScoreCard(result),
                  const SizedBox(height: AppSpacing.xxl),

                  _buildMedicineDetailsCard(result),
                  const SizedBox(height: AppSpacing.xxl),

                  if (result.agentResults.isNotEmpty) ...[
                    _buildAgentBreakdownCard(result),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  if (result.isAntibiotic == true) ...[
                    _buildSafetyInfoCard(result),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  if ((result.labelMrp != null && result.labelMrp!.isNotEmpty) ||
                      (result.verifiedMrp != null && result.verifiedMrp!.isNotEmpty)) ...[
                    _buildPriceInfoCard(result),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  if (result.consumerMessage.isNotEmpty) ...[
                    _buildConsumerMessageCard(result),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (result.safetyAlerts.isNotEmpty) ...[
                    _buildSafetyAlertsCard(result),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  if (result.recommendationsList.isNotEmpty) ...[
                    _buildRecommendationsCard(result),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  if (result.sideEffects.isNotEmpty) ...[
                    SideEffectsCard(sideEffects: result.sideEffects),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  if (result.halalStatus != null &&
                      result.halalStatus!.isNotEmpty) ...[
                    HalalStatusCard(
                      status: result.halalStatus!,
                      reason: result.halalReason ?? '',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  _buildActionButtons(context, result),
                  const SizedBox(height: AppSpacing.xxl),
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

  // ---------------------------------------------------------------------------
  // VERDICT HEADER — flat white with 4px top rule, mono scan code, verdict
  // headline sentence, and agent byline. The signature hero for DawaaCheck.
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, ScanResultModel result) {
    return VerdictHero(
      gradient: AppColors.verifiedGradient,
      accent: AppColors.verified,
      lottieAsset: AppAnimations.shieldCheck,
      heroIcon: Iconsax.shield_tick,
      absolute: 'verdictAuthentic'.tr(),
      soft: 'verdictAuthenticSoft'.tr(),
      riskScore: result.riskScore,
      riskLevel: result.riskLevel,
      scanCode: ScanCodePill.forId(result.id),
      coAgentCount: (result.agentResults.length - 1).clamp(0, 9),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. RISK + DATA STRIP — MonoDataGrid of the three numbers that matter
  // ---------------------------------------------------------------------------

  Widget _buildRiskScoreCard(ScanResultModel result) {
    final riskColor = _riskColor(result.riskLevel);
    final confidencePct = (result.confidenceScore * 100).round();
    final passCount = result.agentResults
        .where((a) => a.status.toUpperCase() == 'PASS')
        .length;
    final totalAgents = result.agentResults.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoDataGrid(rows: [
          MonoDataRow(
            label: 'AUTH',
            value: '$confidencePct',
            valueColor: AppColors.primary,
          ),
          MonoDataRow(
            label: 'RISK',
            value: result.riskLevel.toUpperCase(),
            valueColor: riskColor,
          ),
          MonoDataRow(
            label: 'AGENTS',
            value: totalAgents > 0 ? '$passCount/$totalAgents' : '—',
            valueColor: AppColors.verified,
          ),
        ]),
        if (result.verdictSummary.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            result.verdictSummary,
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. MEDICINE DETAILS CARD
  // ---------------------------------------------------------------------------

  Widget _buildMedicineDetailsCard(ScanResultModel result) {
    final details = <_DetailRowData>[
      _DetailRowData(
        label: 'brandName'.tr(),
        value: result.medicineName,
        statusColor: AppColors.verified,
      ),
      _DetailRowData(
        label: 'manufacturer'.tr(),
        value: result.manufacturer ?? 'detailNotAvailable'.tr(),
        statusColor: result.manufacturer != null ? AppColors.verified : null,
      ),
      _DetailRowData(
        label: 'drapRegistration'.tr(),
        value: result.registrationNumber ?? 'valid'.tr(),
        statusColor: AppColors.verified,
        statusText: 'valid'.tr(),
      ),
      _DetailRowData(
        label: 'expiryDate'.tr(),
        value: result.expiryDate ?? 'detailNotAvailable'.tr(),
        statusColor: result.expiryDate != null ? AppColors.verified : null,
      ),
      _DetailRowData(
        label: 'batchNumber'.tr(),
        value: result.batchNumber ?? 'detailNotAvailable'.tr(),
        statusColor: result.batchNumber != null ? AppColors.verified : null,
      ),
      _DetailRowData(
        label: 'barcode'.tr(),
        value: result.barcode ?? 'detailNotAvailable'.tr(),
        statusColor: result.barcode != null ? AppColors.verified : null,
      ),
    ];

    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            icon: Icons.medication_rounded,
            label: AppStrings.medicineDetails,
            color: AppColors.verified,
          ),
          const SizedBox(height: 16),
          ...List.generate(details.length, (i) {
            final d = details[i];
            return _DetailRow(
              label: d.label,
              value: d.value,
              statusColor: d.statusColor,
              statusText: d.statusText,
              showDivider: i < details.length - 1,
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. AGENT BREAKDOWN CARD
  // ---------------------------------------------------------------------------

  Widget _buildAgentBreakdownCard(ScanResultModel result) {
    // Sort agents by agent number
    final sortedAgents = List.of(result.agentResults)
      ..sort((a, b) => a.agentNumber.compareTo(b.agentNumber));

    // Group agents by phase
    final phase1 = sortedAgents.where((a) => a.agentNumber >= 1 && a.agentNumber <= 5).toList();
    final phase2 = sortedAgents.where((a) => a.agentNumber >= 7 && a.agentNumber <= 10).toList();
    final phase3 = sortedAgents.where((a) => a.agentNumber == 6).toList();

    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            icon: Icons.hub_rounded,
            label: AppStrings.agentBreakdown,
            color: AppColors.primary,
          ),
          if (phase1.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PhaseHeader(label: 'PHASE 1 — BASIC CHECKS', color: AppColors.primary),
            const SizedBox(height: 8),
            ...List.generate(phase1.length, (i) => _buildAgentRow(phase1[i], isLast: i == phase1.length - 1)),
          ],
          if (phase2.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PhaseHeader(label: 'PHASE 2 — SAFETY ANALYSIS', color: AppColors.warning),
            const SizedBox(height: 8),
            ...List.generate(phase2.length, (i) => _buildAgentRow(phase2[i], isLast: i == phase2.length - 1)),
          ],
          if (phase3.isNotEmpty) ...[
            const SizedBox(height: 20),
            _PhaseHeader(label: 'PHASE 3 — FINAL VERDICT', color: AppColors.verified),
            const SizedBox(height: 8),
            ...List.generate(phase3.length, (i) => _buildAgentRow(phase3[i], isLast: true)),
          ],
        ],
      ),
    );
  }

  Widget _buildAgentRow(AgentResultModel agent, {bool isLast = false}) {
    final statusColor = _agentStatusColor(agent.status);
    final statusIcon = _agentStatusIcon(agent.status);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            agent.agentName,
                            style: AppTextStyles.bodySemibold.copyWith(fontSize: 13),
                          ),
                        ),
                        // Confidence chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(agent.confidenceScore * 100).round()}%',
                            style: AppTextStyles.monoCaption.copyWith(
                              color: statusColor,
                              fontSize: 11,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      agent.displayMessage,
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (agent.isFailed && agent.failReason != null && agent.failReason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          agent.failReason!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.danger,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. SAFETY INFORMATION CARD (Antibiotic / AWaRe)
  // ---------------------------------------------------------------------------

  Widget _buildSafetyInfoCard(ScanResultModel result) {
    // Determine color based on AWaRe classification
    Color awareColor;
    IconData awareIcon;
    switch (result.awareClassification?.toUpperCase()) {
      case 'ACCESS':
        awareColor = AppColors.verified;
        awareIcon = Icons.lock_open_rounded;
        break;
      case 'WATCH':
        awareColor = AppColors.warning;
        awareIcon = Icons.visibility_rounded;
        break;
      case 'RESERVE':
        awareColor = AppColors.danger;
        awareIcon = Icons.shield_rounded;
        break;
      default:
        awareColor = AppColors.primary;
        awareIcon = Icons.science_rounded;
    }

    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            icon: Icons.health_and_safety_rounded,
            label: 'ANTIBIOTIC SAFETY',
            color: awareColor,
          ),
          const SizedBox(height: 16),

          // AMR / AWaRe badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: awareColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: awareColor.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: awareColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(awareIcon, color: awareColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHO AWaRe Classification',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        result.awareClassification?.toUpperCase() ?? 'UNCLASSIFIED',
                        style: AppTextStyles.h4.copyWith(
                          color: awareColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (result.stewardshipMessage != null && result.stewardshipMessage!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.stewardshipMessage!,
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
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

  // ---------------------------------------------------------------------------
  // 6. PRICE INFORMATION CARD
  // ---------------------------------------------------------------------------

  Widget _buildPriceInfoCard(ScanResultModel result) {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            icon: Icons.attach_money_rounded,
            label: 'PRICE INFORMATION',
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),

          // Price rows
          if (result.labelMrp != null && result.labelMrp!.isNotEmpty)
            _PriceRow(label: 'Label MRP', value: 'PKR ${result.labelMrp}'),
          if (result.verifiedMrp != null && result.verifiedMrp!.isNotEmpty)
            _PriceRow(
              label: 'DRAP Verified MRP',
              value: 'PKR ${result.verifiedMrp}',
              highlight: true,
            ),

          // Price match indicator
          if (result.labelMrp != null && result.verifiedMrp != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.verifiedLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.verified, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Price is within approved MRP range',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.verified,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Generic alternative
          if (result.genericAlternative != null && result.genericAlternative!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.genericAlternative,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.genericAlternative!,
                        style: AppTextStyles.bodySemibold.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (result.genericPrice != null && result.genericPrice!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.verifiedLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PKR ${result.genericPrice}',
                      style: AppTextStyles.badge.copyWith(
                        color: AppColors.verified,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. CONSUMER MESSAGE CARD
  // ---------------------------------------------------------------------------

  Widget _buildConsumerMessageCard(ScanResultModel result) {
    return _CardWrapper(
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consumer Advisory',
                  style: AppTextStyles.sectionHeader.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.consumerMessage,
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAFETY ALERTS CARD
  // ---------------------------------------------------------------------------

  Widget _buildSafetyAlertsCard(ScanResultModel result) {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            icon: Icons.warning_amber_rounded,
            label: AppStrings.safetyAlerts,
            color: AppColors.warning,
          ),
          const SizedBox(height: 14),
          ...result.safetyAlerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.warning_rounded, color: AppColors.warning, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          alert.toString(),
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECOMMENDATIONS CARD
  // ---------------------------------------------------------------------------

  Widget _buildRecommendationsCard(ScanResultModel result) {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            icon: Icons.tips_and_updates_rounded,
            label: AppStrings.recommendations,
            color: AppColors.verified,
          ),
          const SizedBox(height: 14),
          ...List.generate(result.recommendationsList.length, (i) {
            final rec = result.recommendationsList[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.verifiedLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: AppTextStyles.badge.copyWith(
                          color: AppColors.verified,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rec,
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
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

  // ---------------------------------------------------------------------------
  // 8. ACTION BUTTONS
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons(BuildContext context, ScanResultModel result) {
    return Column(
      children: [
        // Primary row: Report + Scan Again
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/adr', extra: {
                    'medicine_name': result.medicineName,
                    'batch_number': result.batchNumber,
                  });
                },
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(AppStrings.reportSideEffect),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                label: 'Scan another medicine',
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.go('/scan');
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: Text(AppStrings.scanAgain),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Back to Home text button
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.go('/home');
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              AppStrings.backToHome,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// REUSABLE PRIVATE WIDGETS
// =============================================================================

/// Standard card wrapper with consistent styling
class _PhaseHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _PhaseHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.sectionHeader.copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _CardWrapper extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _CardWrapper({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: borderColor ?? Theme.of(context).colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// Section header row with accent bar + icon + label
class _SectionHeaderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeaderRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.sectionHeader.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Helper to carry detail row data
class _DetailRowData {
  final String label;
  final String value;
  final Color? statusColor;
  final String? statusText;

  const _DetailRowData({
    required this.label,
    required this.value,
    this.statusColor,
    this.statusText,
  });
}

/// Detail row with label, value, optional status dot
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? statusColor;
  final String? statusText;
  final bool showDivider;

  const _DetailRow({
    required this.label,
    required this.value,
    this.statusColor,
    this.statusText,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: AppTextStyles.label),
              ),
              if (statusColor != null) ...[
                // Square status indicator — signature Clinical Precision element
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  statusText ?? value,
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
      ],
    );
  }
}

/// Price comparison row
class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _PriceRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: highlight ? AppColors.verified : AppColors.textHint,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodySemibold.copyWith(
              fontSize: 15,
              color: highlight ? AppColors.verified : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CONFETTI PAINTER
// =============================================================================
