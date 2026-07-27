import 'dart:math' as math;
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
import '../../../data/models/scan_result_model.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/app_bottom_nav.dart';
import '../../widgets/design_system/design_system.dart';
import 'widgets/result_extra_cards.dart';
import 'widgets/verdict_hero.dart';

class ResultUnverifiedScreen extends StatefulWidget {
  final ScanResultModel result;

  const ResultUnverifiedScreen({super.key, required this.result});

  @override
  State<ResultUnverifiedScreen> createState() => _ResultUnverifiedScreenState();
}

class _ResultUnverifiedScreenState extends State<ResultUnverifiedScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    final passedAgents = result.agentResults.where((a) => a.isPassed).toList();
    final failedAgents = result.agentResults.where((a) => a.isFailed).toList();
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
                  // Mono data strip \u2014 matches verified flow, signature detail.
                  MonoDataGrid(rows: [
                    MonoDataRow(
                      label: 'AUTH',
                      value: '${(result.confidenceScore * 100).round()}',
                      valueColor: AppColors.warning,
                    ),
                    MonoDataRow(
                      label: 'RISK',
                      value: result.riskLevel.toUpperCase(),
                      valueColor: AppColors.warning,
                    ),
                    MonoDataRow(
                      label: 'AGENTS',
                      value: result.agentResults.isEmpty
                          ? '\u2014'
                          : '${result.agentResults.where((a) => a.status.toUpperCase() == 'PASS').length}/${result.agentResults.length}',
                      valueColor: AppColors.textSecondary,
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.lg),

                  _buildRiskAssessmentCard(result),
                  const SizedBox(height: AppSpacing.xxl),

                  _buildAgentBreakdownCard(
                    result.agentResults,
                    passedAgents.length,
                    failedAgents.length,
                    uncertainAgents.length,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (result.safetyAlerts.isNotEmpty) ...[
                    _buildSafetyAlertsCard(result.safetyAlerts),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  _buildWhatThisMeansCard(result),
                  const SizedBox(height: AppSpacing.lg),

                  _buildRecommendationsCard(result.recommendationsList),
                  const SizedBox(height: AppSpacing.lg),

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
  // VERDICT HEADER — flat white + 4px amber top rule, verdict headline,
  // agent byline. Same pattern as verified screen, warning color.
  // ════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context, ScanResultModel result) {
    return VerdictHero(
      gradient: AppColors.warningGradient,
      accent: AppColors.warning,
      heroIcon: Iconsax.warning_2,
      absolute: 'verdictUnconfirmed'.tr(),
      soft: 'verdictUnconfirmedSoft'.tr(),
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
    return _WarningCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            title: AppStrings.overallRisk,
            color: AppColors.warning,
          ),
          const SizedBox(height: 20),

          // Risk score circle + level badge row
          Row(
            children: [
              // Circular risk gauge
              Semantics(
                label: 'Risk score: ${result.riskScore} out of 100',
                child: _RiskScoreGauge(
                  score: result.riskScore,
                  riskLevel: result.riskLevel,
                ),
              ),
              const SizedBox(width: 24),

              // Risk level + summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RiskLevelBadge(riskLevel: result.riskLevel),
                    const SizedBox(height: 10),
                    if (result.verdictSummary.isNotEmpty)
                      Text(
                        result.verdictSummary,
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Consumer message
          if (result.consumerMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.consumerMessage,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
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
  // Section 3 — Agent Breakdown Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildAgentBreakdownCard(
    List agentResults,
    int passedCount,
    int failedCount,
    int uncertainCount,
  ) {
    return _WarningCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            title: AppStrings.agentBreakdown,
            color: AppColors.warning,
          ),
          const SizedBox(height: 14),

          // Summary chips row
          Row(
            children: [
              if (passedCount > 0)
                _AgentCountChip(
                  count: passedCount,
                  label: 'PASS',
                  color: AppColors.verified,
                  icon: Icons.check_circle_rounded,
                ),
              if (passedCount > 0) const SizedBox(width: 8),
              if (failedCount > 0)
                _AgentCountChip(
                  count: failedCount,
                  label: 'FAIL',
                  color: AppColors.danger,
                  icon: Icons.cancel_rounded,
                ),
              if (failedCount > 0) const SizedBox(width: 8),
              if (uncertainCount > 0)
                _AgentCountChip(
                  count: uncertainCount,
                  label: 'UNCERTAIN',
                  color: AppColors.warning,
                  icon: Icons.help_rounded,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: AppColors.warning.withValues(alpha: 0.1),
          ),

          const SizedBox(height: 14),

          // Agent rows
          ...widget.result.agentResults.asMap().entries.map(
                (entry) => _AgentRow(
                  agent: entry.value,
                  isLast:
                      entry.key == widget.result.agentResults.length - 1,
                ),
              ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 4 — Safety Alerts Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildSafetyAlertsCard(List<dynamic> alerts) {
    return _WarningCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            title: AppStrings.safetyAlerts,
            color: AppColors.danger,
          ),
          const SizedBox(height: 14),
          ...alerts.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < alerts.length - 1 ? 10 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
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
                        entry.value.toString(),
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
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
  // Section 5 — What This Means Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildWhatThisMeansCard(ScanResultModel result) {
    // Use consumer message if available, otherwise static recommendations
    final hasConsumerMessage = result.consumerMessage.isNotEmpty;

    return _WarningCard(
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            title: AppStrings.whatThisMeans,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          if (hasConsumerMessage)
            Text(
              result.consumerMessage,
              style: AppTextStyles.body.copyWith(
                fontSize: 13.5,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            )
          else
            ...[
              AppStrings.recommendation1,
              AppStrings.recommendation2,
              AppStrings.recommendation3,
              AppStrings.recommendation4,
            ].asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key < 3 ? 12 : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: AppTextStyles.badge.copyWith(
                                color: AppColors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              entry.value,
                              style:
                                  AppTextStyles.body.copyWith(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Section 6 — Recommendations Card
  // ════════════════════════════════════════════════════════════════════

  Widget _buildRecommendationsCard(List<String> recommendations) {
    final items = recommendations.isNotEmpty
        ? recommendations
        : [
            AppStrings.recommendation1,
            AppStrings.recommendation2,
            AppStrings.recommendation3,
            AppStrings.recommendation4,
          ];

    return _WarningCard(
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            title: AppStrings.recommendations,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < items.length - 1 ? 14 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: AppTextStyles.monoCaption.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        entry.value,
                        style: AppTextStyles.body.copyWith(fontSize: 13),
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
    final details = <_InfoItem>[
      _InfoItem(
        label: AppStrings.medicineName,
        value: result.medicineName,
        icon: Icons.medication_rounded,
      ),
      if (result.manufacturer != null && result.manufacturer!.isNotEmpty)
        _InfoItem(
          label: 'manufacturer'.tr(),
          value: result.manufacturer!,
          icon: Icons.business_rounded,
        ),
      if (result.registrationNumber != null &&
          result.registrationNumber!.isNotEmpty)
        _InfoItem(
          label: 'drapRegistration'.tr(),
          value: result.registrationNumber!,
          icon: Icons.verified_user_outlined,
        ),
      if (result.batchNumber != null && result.batchNumber!.isNotEmpty)
        _InfoItem(
          label: 'batchNumber'.tr(),
          value: result.batchNumber!,
          icon: Icons.tag_rounded,
        ),
      if (result.expiryDate != null && result.expiryDate!.isNotEmpty)
        _InfoItem(
          label: 'expiryDate'.tr(),
          value: result.expiryDate!,
          icon: Icons.calendar_today_rounded,
        ),
    ];

    return _WarningCard(
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeaderRow(
            title: AppStrings.medicineDetails,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          ...details.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == details.length - 1;
            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        color: AppColors.primary.withValues(alpha: 0.6),
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.value,
                            style: AppTextStyles.bodySemibold.copyWith(
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isLast) ...[
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 48),
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          }),
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
        // Try Scanning Again — amber filled
        Semantics(
          label: 'Scan another medicine',
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go('/scan');
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: Text(
                AppStrings.tryScanAgain,
                style: AppTextStyles.buttonPrimary,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 1200.ms, duration: 400.ms)
            .slideY(
              begin: 0.15,
              end: 0,
              delay: 1200.ms,
              duration: 350.ms,
              curve: Curves.easeOutCubic,
            ),

        const SizedBox(height: 12),

        // Contact DRAP Helpline — amber outlined
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              AppToast.warning(context, 'DRAP Helpline: 0800-02345 | adr@dfrarpak.gov.pk');
            },
            icon: const Icon(Icons.phone_outlined, size: 20),
            label: Text(
              AppStrings.contactDrap,
              style: AppTextStyles.buttonPrimary.copyWith(
                color: AppColors.warning,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: const BorderSide(color: AppColors.warning, width: 1.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 1350.ms, duration: 400.ms)
            .slideY(
              begin: 0.15,
              end: 0,
              delay: 1350.ms,
              duration: 350.ms,
              curve: Curves.easeOutCubic,
            ),

        const SizedBox(height: 8),

        // Back to Home — text button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.go('/home');
            },
            child: Text(
              AppStrings.backToHome,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 1450.ms, duration: 400.ms),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Reusable Private Widgets
// ══════════════════════════════════════════════════════════════════════

/// Standard card wrapper with warning-tinted border
class _WarningCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _WarningCard({
    required this.child,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: borderColor ??
              AppColors.warning.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

/// Section header with colored bar
class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeaderRow({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTextStyles.sectionHeader.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Circular risk score gauge widget
class _RiskScoreGauge extends StatelessWidget {
  final int score;
  final String riskLevel;

  const _RiskScoreGauge({
    required this.score,
    required this.riskLevel,
  });

  Color get _gaugeColor {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return AppColors.verified;
      case 'MODERATE':
        return AppColors.warning;
      case 'HIGH':
        return AppColors.danger;
      case 'CRITICAL':
        return AppColors.dangerDark;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _gaugeColor;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle track — animated
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: (score / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, _) {
              return SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: animValue,
                    color: color,
                    trackColor: color.withValues(alpha: 0.1),
                    strokeWidth: 7,
                  ),
                ),
              );
            },
          ),
          // Score text — animated count-up
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 1200),
            builder: (context, value, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$value',
                    style: AppTextStyles.h2.copyWith(
                      color: color,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    '/100',
                    style: AppTextStyles.caption.copyWith(
                      color: color.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the risk score ring
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Risk level badge (colored pill)
class _RiskLevelBadge extends StatelessWidget {
  final String riskLevel;

  const _RiskLevelBadge({required this.riskLevel});

  Color get _bgColor {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return AppColors.verifiedLight;
      case 'MODERATE':
        return AppColors.warningLight;
      case 'HIGH':
        return AppColors.dangerLight;
      case 'CRITICAL':
        return AppColors.dangerLight;
      default:
        return AppColors.warningLight;
    }
  }

  Color get _textColor {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return AppColors.verifiedDark;
      case 'MODERATE':
        return AppColors.warning;
      case 'HIGH':
        return AppColors.danger;
      case 'CRITICAL':
        return AppColors.dangerDark;
      default:
        return AppColors.warning;
    }
  }

  IconData get _icon {
    switch (riskLevel.toUpperCase()) {
      case 'LOW':
        return Icons.shield_outlined;
      case 'MODERATE':
        return Icons.warning_amber_rounded;
      case 'HIGH':
        return Icons.error_outline_rounded;
      case 'CRITICAL':
        return Icons.dangerous_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _textColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _textColor, size: 14),
          const SizedBox(width: 6),
          Text(
            '${AppStrings.riskLevel}: ${riskLevel.toUpperCase()}',
            style: AppTextStyles.badge.copyWith(
              color: _textColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary chip showing agent counts
class _AgentCountChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _AgentCountChip({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: AppTextStyles.badge.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single agent result row
class _AgentRow extends StatelessWidget {
  final dynamic agent;
  final bool isLast;

  const _AgentRow({required this.agent, required this.isLast});

  Color get _statusColor {
    if (agent.isPassed) return AppColors.verified;
    if (agent.isFailed) return AppColors.danger;
    return AppColors.warning;
  }

  IconData get _statusIcon {
    if (agent.isPassed) return Icons.check_circle_rounded;
    if (agent.isFailed) return Icons.cancel_rounded;
    return Icons.help_rounded;
  }

  Color get _statusBg {
    if (agent.isPassed) return AppColors.verifiedLight;
    if (agent.isFailed) return AppColors.dangerLight;
    return AppColors.warningLight;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon, color: color, size: 18),
              ),
              const SizedBox(width: 14),

              // Agent name + message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            agent.agentName,
                            style: AppTextStyles.bodySemibold.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ),
                        // Confidence score badge
                        if (agent.confidenceScore > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(agent.confidenceScore * 100).round()}%',
                              style: AppTextStyles.caption.copyWith(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      agent.displayMessage,
                      style: AppTextStyles.body.copyWith(fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Fail reason if present
                    if (agent.isFailed &&
                        agent.failReason != null &&
                        agent.failReason!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        agent.failReason!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.danger,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 46),
            color: AppColors.borderSubtle,
          ),
      ],
    );
  }
}

/// Helper class for medicine info items
class _InfoItem {
  final String label;
  final String value;
  final IconData icon;

  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}
