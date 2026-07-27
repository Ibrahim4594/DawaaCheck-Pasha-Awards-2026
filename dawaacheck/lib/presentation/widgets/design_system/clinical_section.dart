import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

/// Section wrapper — mono uppercase section header + hairline rule + content.
///
/// Standard rhythm for screen sections: a small field-tag-style label (e.g.
/// "AGENT FINDINGS"), a 1px accent rule below it, then the content. Keeps
/// visual hierarchy without relying on shadow-based cards-within-cards.
class ClinicalSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? trailing;
  final EdgeInsetsGeometry padding;

  const ClinicalSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(), style: AppTextStyles.sectionHeader),
              if (trailing != null)
                Text(trailing!.toUpperCase(), style: AppTextStyles.monoCaption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(height: 1, color: AppColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
