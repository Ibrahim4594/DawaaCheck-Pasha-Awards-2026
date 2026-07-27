import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/constants/agent_console_log.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/providers/agent_console_provider.dart';
import '../../widgets/design_system/design_system.dart';

/// Agent Console — clinical-light execution log that streams the 10-agent
/// verification sequence line by line.
///
/// The stream is driven by [agentConsoleProvider], which is started by the scan
/// action (`ScanNotifier.startVerification`). So the console stays idle until
/// the user uploads the 3 images and presses Scan — then it flows. The on-screen
/// "Run Verification" button is a demo shortcut that triggers the same replay.
class AgentTerminalScreen extends ConsumerStatefulWidget {
  const AgentTerminalScreen({super.key});

  @override
  ConsumerState<AgentTerminalScreen> createState() =>
      _AgentTerminalScreenState();
}

class _AgentTerminalScreenState extends ConsumerState<AgentTerminalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: AppMotion.entranceDuration,
    );
    _fade = CurvedAnimation(parent: _entrance, curve: AppMotion.entranceCurve);
    _slide = Tween<Offset>(
      begin: const Offset(0, AppMotion.slideYOffset),
      end: Offset.zero,
    ).animate(_fade);
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom + 80;
    final console = ref.watch(agentConsoleProvider);

    // Keep the newest line in view as lines reveal.
    ref.listen(agentConsoleProvider, (prev, next) {
      if (next.visible != (prev?.visible ?? 0)) _autoScroll();
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                bottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(visible: console.visible, total: console.total),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(child: _console(console)),
                  const SizedBox(height: AppSpacing.lg),
                  _runButton(console.status),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _console(AgentConsoleState console) {
    if (console.status == ConsoleStatus.idle) {
      return const _IdleState();
    }
    return ClinicalCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: ListView.builder(
        controller: _scroll,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: console.visible.clamp(0, console.log.length),
        itemBuilder: (context, i) => _LogLineView(line: console.log[i]),
      ),
    );
  }

  Widget _runButton(ConsoleStatus status) {
    final running = status == ConsoleStatus.running;
    final label = switch (status) {
      ConsoleStatus.running => AppStrings.agentConsoleRunning,
      ConsoleStatus.done => AppStrings.agentConsoleReplay,
      ConsoleStatus.idle => AppStrings.agentConsoleReplay,
    };
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: running
            ? AppColors.primary.withValues(alpha: 0.35)
            : AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        child: InkWell(
          onTap: running
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  ref.read(agentConsoleProvider.notifier).start();
                },
          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  running ? Iconsax.flash_1 : Iconsax.play_circle,
                  color: AppColors.white,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(label, style: AppTextStyles.buttonPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Idle (no scan yet) ──

class _IdleState extends StatelessWidget {
  const _IdleState();

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Iconsax.code, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'AWAITING SCAN',
              style: AppTextStyles.sectionHeader,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.agentConsoleHint,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──

class _Header extends StatelessWidget {
  final int visible;
  final int total;

  const _Header({required this.visible, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('AGENT EXECUTION LOG', style: AppTextStyles.sectionHeader),
            const Spacer(),
            Text(
              '${visible.toString().padLeft(2, '0')}/$total',
              style: AppTextStyles.monoSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(AppStrings.agentConsole, style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.agentConsoleSubtitle, style: AppTextStyles.body),
      ],
    );
  }
}

// ── A single rendered log line ──

class _LogLineView extends StatelessWidget {
  final AgentLogLine line;

  const _LogLineView({required this.line});

  Color get _color => switch (line.kind) {
        AgentLineKind.pass => AppColors.verified,
        AgentLineKind.fail => AppColors.danger,
        AgentLineKind.warn => AppColors.warning,
        AgentLineKind.boot => AppColors.textHint,
        _ => AppColors.primary,
      };

  bool get _isResult =>
      line.kind == AgentLineKind.pass ||
      line.kind == AgentLineKind.fail ||
      line.kind == AgentLineKind.warn;

  @override
  Widget build(BuildContext context) {
    // ── Step header (e.g. "PHASE 1 · CORE VERIFICATION") ──
    if (line.kind == AgentLineKind.phase) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                line.text,
                style: AppTextStyles.bodySemibold.copyWith(
                  color: AppColors.primary,
                  fontSize: 12.5,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Boot / system line ──
    if (line.agent == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Iconsax.cpu, size: 13, color: AppColors.textHint),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                line.text,
                style: AppTextStyles.monoCaption.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Agent line ──
    final role = kAgentRoles[line.agent] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _isResult
                  ? Icon(_statusIcon, size: 18, color: _color)
                  : const SizedBox(
                      width: 16,
                      height: 16,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plain-language line: AGENT · friendly role
                  Row(
                    children: [
                      Text(
                        line.agent!,
                        style: AppTextStyles.bodySemibold.copyWith(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (role.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '· $role',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                              fontSize: 11.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Technical detail (mono) for developers
                  Text(
                    line.text,
                    style: AppTextStyles.monoCaption.copyWith(
                      color: _isResult ? _color : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_isResult) ...[
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(label: _statusLabel, color: _color),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _statusIcon => switch (line.kind) {
        AgentLineKind.pass => Icons.check_circle_rounded,
        AgentLineKind.fail => Icons.cancel_rounded,
        AgentLineKind.warn => Icons.error_rounded,
        _ => Icons.radio_button_unchecked_rounded,
      };

  String get _statusLabel => switch (line.kind) {
        AgentLineKind.pass => 'PASSED',
        AgentLineKind.fail => 'FAILED',
        AgentLineKind.warn => 'REVIEW',
        _ => '',
      };
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: AppTextStyles.monoCaption.copyWith(
          color: color,
          fontSize: 9.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
