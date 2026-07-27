import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import 'clinical_chip.dart';
import 'status_accent.dart';

/// Status of an agent in a running or completed scan.
enum AgentStatus { pending, running, pass, fail, uncertain }

extension _AgentStatusVisual on AgentStatus {
  Color get color {
    switch (this) {
      case AgentStatus.pending:
        return AppColors.textHint;
      case AgentStatus.running:
        return AppColors.primary;
      case AgentStatus.pass:
        return AppColors.verified;
      case AgentStatus.fail:
        return AppColors.danger;
      case AgentStatus.uncertain:
        return AppColors.warning;
    }
  }

  String get label {
    switch (this) {
      case AgentStatus.pending:
        return 'PENDING';
      case AgentStatus.running:
        return 'RUNNING';
      case AgentStatus.pass:
        return 'PASS';
      case AgentStatus.fail:
        return 'FAIL';
      case AgentStatus.uncertain:
        return 'UNCERTAIN';
    }
  }
}

/// A single agent's state in the scan pipeline.
class AgentProgress {
  final String name;
  final String role;
  final AgentStatus status;

  const AgentProgress({
    required this.name,
    required this.role,
    required this.status,
  });
}

/// Vertical list showing each of DawaaCheck's 10 named agents with live
/// status — the scan-processing screen's hero content. Replaces abstract
/// Lottie loading animations with named progress: the user sees RAKIB check
/// authenticity, then KASHIF verify the barcode, and so on.
///
/// Status transitions use a 200ms color fade only (no pulsing / throbbing).
class AgentProgressRail extends StatelessWidget {
  final List<AgentProgress> agents;

  const AgentProgressRail({super.key, required this.agents});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < agents.length; i++) ...[
          if (i > 0)
            Container(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          _AgentRow(agent: agents[i]),
        ],
      ],
    );
  }
}

class _AgentRow extends StatelessWidget {
  final AgentProgress agent;

  const _AgentRow({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: StatusAccent(
              key: ValueKey(agent.status),
              color: agent.status.color,
              label: agent.name,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              agent.role,
              style: AppTextStyles.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ClinicalChip.subtle(label: agent.status.label, color: agent.status.color),
        ],
      ),
    );
  }
}
