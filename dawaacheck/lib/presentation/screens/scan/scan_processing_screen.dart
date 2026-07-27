import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_animations.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/providers/session_provider.dart';
import '../../../domain/providers/scan_provider.dart';
import '../../widgets/common/app_bottom_nav.dart';
import '../../widgets/design_system/design_system.dart';

/// Live scan processing screen — shows the 10 named agents running in sequence.
/// Replaces the orbital shield + Lottie wave + per-row stagger pattern with a
/// flat vertical rail. Status transitions are 300ms color fades only; no
/// pulsing, no rotating, no background motion.
class ScanProcessingScreen extends ConsumerStatefulWidget {
  const ScanProcessingScreen({super.key});

  @override
  ConsumerState<ScanProcessingScreen> createState() => _ScanProcessingScreenState();
}

class _ScanProcessingScreenState extends ConsumerState<ScanProcessingScreen> {
  bool _started = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startVerification());
  }

  void _startVerification() {
    if (_started) return;
    _started = true;

    // Resuming an in-flight or already-finished scan (e.g. user tabbed away and
    // came back via the resume pill) — do NOT kick off a second verification.
    final existing = ref.read(scanProvider);
    if (existing.isProcessing || existing.result != null) return;

    final user = ref.read(sessionProvider).valueOrNull;
    if (user == null) {
      debugPrint('[SCAN] User is null! Cannot start verification.');
      ref.read(scanProvider.notifier).startVerification('guest-user');
      return;
    }

    debugPrint('[SCAN] Starting verification for user: ${user.uid}');
    ref.read(scanProvider.notifier).startVerification(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);

    ref.listen<ScanState>(scanProvider, (prev, next) {
      if (next.result != null && (prev?.result == null) && !_navigating) {
        _navigating = true;
        HapticFeedback.mediumImpact();
        // Suspense pause — let the user see "Final verdict ready" before navigating
        Future.delayed(const Duration(milliseconds: 1200), () {
          // `context.mounted` (not just `mounted`) satisfies
          // `use_build_context_synchronously` — semantically equivalent for a
          // StatefulWidget but the analyzer only tracks the context-scoped form.
          if (!context.mounted) return;
          HapticFeedback.heavyImpact();
          final verdict = next.result!.overallVerdict.toUpperCase();
          final route = switch (verdict) {
            'VERIFIED' => '/result/verified',
            'DANGER' => '/result/danger',
            _ => '/result/unverified',
          };
          context.go(route, extra: next.result);
        });
      }
    });

    final simAgents = _defaultAgents(scanState.progress);
    final realAgents = scanState.agentResults;
    final percent = (scanState.progress * 100).toInt();

    // Phase definitions: group index ranges and labels
    const phases = [
      (label: 'PHASE 1 · BASIC CHECKS', startIndex: 0, endIndex: 4),
      (label: 'PHASE 2 · SAFETY ANALYSIS', startIndex: 5, endIndex: 8),
      (label: 'PHASE 3 · FINAL VERDICT', startIndex: 9, endIndex: 9),
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        bottomNavigationBar: const AppBottomNav(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),

                // ── Status header (mono label + counter) ──
                Text(
                  'SCAN · ${AppStrings.verifying.toUpperCase()}',
                  style: AppTextStyles.sectionHeader,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppStrings.analysingMedicine,
                      style: AppTextStyles.h2,
                    ),
                    const Spacer(),
                    Text('$percent', style: AppTextStyles.monoData.copyWith(color: AppColors.primary)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, left: 2),
                      child: Text('%', style: AppTextStyles.monoCaption),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(AppStrings.agentsWorking, style: AppTextStyles.body),

                const SizedBox(height: AppSpacing.sm),

                // ── Robot AI "thinking" hero (loading animation) ──
                Center(
                  child: SizedBox(
                    height: 108,
                    child: Lottie.asset(
                      AppAnimations.robot,
                      repeat: true,
                      fit: BoxFit.contain,
                      errorBuilder: (_, e, s) => const SizedBox(height: 108),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── Thin progress bar (no shadow, no gradient) ──
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: scanState.progress.clamp(0.0, 1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Agent progress rail (phases + named agents) ──
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    itemCount: AppStrings.agentNames.length + phases.length,
                    itemBuilder: (context, listIndex) {
                      // Determine if this index is a phase header or agent row
                      int agentOffset = 0;
                      for (int p = 0; p < phases.length; p++) {
                        final headerIndex = phases[p].startIndex + p;
                        if (listIndex == headerIndex) {
                          return _PhaseHeader(label: phases[p].label, isFirst: p == 0);
                        }
                        if (listIndex > headerIndex) agentOffset = p + 1;
                      }

                      final i = listIndex - agentOffset;
                      if (i < 0 || i >= AppStrings.agentNames.length) {
                        return const SizedBox.shrink();
                      }

                      final agentName = AppStrings.agentNames[i];
                      // Map display index to agent number: 0-4→1-5, 5-8→7-10, 9→6
                      final agentNum = i < 5 ? i + 1 : i < 9 ? i + 2 : 6;
                      String status = 'WAITING';
                      String message = 'Waiting';
                      final realAgent = realAgents.where((a) => a.agentNumber == agentNum).firstOrNull;
                      if (realAgent != null) {
                        status = realAgent.status;
                        message = realAgent.displayMessage;
                      } else if (i < simAgents.length) {
                        status = simAgents[i].status;
                        message = simAgents[i].displayMessage;
                      }
                      return _AgentRow(
                        agentName: agentName,
                        status: status,
                        message: message,
                      );
                    },
                  )
                      .animate()
                      .fadeIn(duration: AppMotion.entranceDuration),
                ),

                // ── Error message ──
                if (scanState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.warning_2, color: AppColors.danger, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              scanState.error!,
                              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 90),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_SimAgent> _defaultAgents(double progress) {
    final agents = <_SimAgent>[];
    final names = AppStrings.agentNames;
    for (int i = 0; i < names.length; i++) {
      final threshold = (i + 1) / (names.length + 1);
      String status;
      String message;
      if (progress >= threshold + 0.1) {
        status = 'PASS';
        message = _doneMessages[i];
      } else if (progress >= threshold) {
        status = 'PROCESSING';
        message = _processingMessages[i];
      } else {
        status = 'WAITING';
        message = AppStrings.waiting;
      }
      agents.add(_SimAgent(status: status, displayMessage: message));
    }
    return agents;
  }

  List<String> get _doneMessages => AppStrings.doneMessages;
  List<String> get _processingMessages => AppStrings.processingMessages;
}

class _SimAgent {
  final String status;
  final String displayMessage;
  _SimAgent({required this.status, required this.displayMessage});
}

// ─── Phase header (mono uppercase section label) ───

class _PhaseHeader extends StatelessWidget {
  final String label;
  final bool isFirst;

  const _PhaseHeader({required this.label, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(label, style: AppTextStyles.sectionHeader),
    );
  }
}

// ─── Agent row (flat hairline container, status dot, mono status chip) ───

class _AgentRow extends StatelessWidget {
  final String agentName;
  final String status;
  final String message;

  const _AgentRow({
    required this.agentName,
    required this.status,
    required this.message,
  });

  Color get _statusColor {
    switch (status) {
      case 'PASS':
        return AppColors.verified;
      case 'FAIL':
        return AppColors.danger;
      case 'PROCESSING':
        return AppColors.primary;
      default:
        return AppColors.textHint;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'PASS':
        return 'PASS';
      case 'FAIL':
        return 'FAIL';
      case 'PROCESSING':
        return 'RUNNING';
      default:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Split "RAKIB — The Watchman" into code name and title
    final parts = agentName.split(' — ');
    final codeName = parts.isNotEmpty ? parts[0] : agentName;
    final title = parts.length > 1 ? parts[1] : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStatusIcon(),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(codeName, style: AppTextStyles.h4.copyWith(fontSize: 14)),
                      if (title.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text(
                            title,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: AppTextStyles.caption.copyWith(color: _statusColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ClinicalChip.subtle(label: _statusLabel, color: _statusColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    // 8×8 square status dot — the signature element from StatusAccent
    if (status == 'PROCESSING') {
      return SizedBox(
        key: const ValueKey('PROCESSING'),
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
          backgroundColor: AppColors.primaryLight,
        ),
      );
    }
    return Container(
      key: ValueKey(status),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _statusColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
