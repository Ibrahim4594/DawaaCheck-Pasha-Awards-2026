import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Status / tag chip — outline-only, subtle-fill, or mono variant.
///
/// No filled pills with glow or shadow — those read AI-default. DawaaCheck
/// chips use a 1px border and a subtle tonal fill (or no fill at all).
class ClinicalChip extends StatelessWidget {
  final String label;
  final Color color;
  final _ChipVariant _variant;

  const ClinicalChip.outline({
    super.key,
    required this.label,
    this.color = AppColors.textSecondary,
  }) : _variant = _ChipVariant.outline;

  const ClinicalChip.subtle({
    super.key,
    required this.label,
    required this.color,
  }) : _variant = _ChipVariant.subtle;

  const ClinicalChip.mono({
    super.key,
    required this.label,
    this.color = AppColors.textSecondary,
  }) : _variant = _ChipVariant.mono;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final Color? borderColor;
    final TextStyle labelStyle;

    switch (_variant) {
      case _ChipVariant.outline:
        background = Colors.transparent;
        foreground = color;
        borderColor = color.withValues(alpha: 0.3);
        labelStyle = AppTextStyles.badge.copyWith(color: color);
        break;
      case _ChipVariant.subtle:
        background = color.withValues(alpha: 0.08);
        foreground = color;
        borderColor = null;
        labelStyle = AppTextStyles.badge.copyWith(color: color);
        break;
      case _ChipVariant.mono:
        background = AppColors.background;
        foreground = color;
        borderColor = AppColors.border;
        labelStyle = AppTextStyles.monoCaption.copyWith(color: color);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1)
            : null,
      ),
      child: Text(
        _variant == _ChipVariant.mono ? label : label.toUpperCase(),
        style: labelStyle.copyWith(color: foreground),
      ),
    );
  }
}

enum _ChipVariant { outline, subtle, mono }
