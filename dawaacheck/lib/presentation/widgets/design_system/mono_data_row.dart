import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';

/// One label + value pair in the "data voice." Composes into `MonoDataGrid`.
///
/// The label renders as uppercase mono caption (field-tag feel); the value
/// renders as prominent mono data. Use for: authenticity score, risk level,
/// MRP, agent count, lot codes — anything a machine produced.
class MonoDataRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const MonoDataRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    // Mono cells are a Latin-only firmware-plate role per CLAUDE.md. We force
    // LTR directionality so values like "60K+" or "≤ 3s" keep their logical
    // order when the ambient locale is Urdu (RTL) — otherwise the `+` / `≤`
    // characters (Bidi-neutral) get pushed to the visual start and render
    // as "+60K" / "3s ≤".
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // FittedBox.scaleDown guarantees the value stays on a single line
          // and shrinks if the cell is narrower than the text's natural width.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.monoData.copyWith(color: valueColor),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              style: AppTextStyles.monoCaption,
            ),
          ),
        ],
      ),
    );
  }
}
