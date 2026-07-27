import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

/// 1px hairline rule in DawaaCheck border color. Replaces `Divider` which
/// can't be made thin enough by default (minimum 1px but with space).
///
/// Optional centered label renders a mono uppercase caption inside the rule
/// — useful for section breaks like "AGENT FINDINGS" that need more emphasis
/// than a plain divider.
class HairlineDivider extends StatelessWidget {
  final double start;
  final double end;
  final String? label;

  const HairlineDivider({
    super.key,
    this.start = 0,
    this.end = 0,
  }) : label = null;

  const HairlineDivider.inset({
    super.key,
    this.start = AppSpacing.xl,
    this.end = AppSpacing.xl,
  }) : label = null;

  const HairlineDivider.withLabel({
    super.key,
    required String this.label,
    this.start = 0,
    this.end = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;

    if (label == null) {
      return Padding(
        padding: EdgeInsets.only(left: start, right: end),
        child: Container(height: 1, color: color),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: start, right: end),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              label!.toUpperCase(),
              style: AppTextStyles.monoCaption,
            ),
          ),
          Expanded(child: Container(height: 1, color: color)),
        ],
      ),
    );
  }
}
