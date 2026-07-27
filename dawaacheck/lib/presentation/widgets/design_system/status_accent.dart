import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

/// 8×8 square status indicator + uppercase mono label.
///
/// The **square** dot (not a circle) is a signature DawaaCheck element —
/// circles read generic "status chip," squares read engineered instrument.
///
/// Use cases:
/// - Agent rows inside `AgentProgressRail` (RAKIB ▪ RUNNING)
/// - Inline list-row status indicators
/// - Header status flags ("▪ VERIFIED")
class StatusAccent extends StatelessWidget {
  final Color color;
  final String label;
  final double size;

  const StatusAccent({
    super.key,
    required this.color,
    required this.label,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.monoCaption.copyWith(color: color),
        ),
      ],
    );
  }
}
