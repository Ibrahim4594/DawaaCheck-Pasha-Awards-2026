import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import 'mono_data_row.dart';

/// 2 or 3 column grid of `MonoDataRow` values with 1px inner dividers.
/// Replaces the "row of floating stat cards with shadows" anti-pattern.
///
/// Example: on a verdict screen, three cells show AUTH 94 / RISK LOW / AGENTS 10/10.
class MonoDataGrid extends StatelessWidget {
  final List<MonoDataRow> rows;
  final EdgeInsetsGeometry padding;

  const MonoDataGrid({
    super.key,
    required this.rows,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    final cells = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      cells.add(Expanded(child: Padding(padding: padding, child: rows[i])));
      if (i < rows.length - 1) {
        cells.add(Container(width: 1, height: 52, color: borderColor));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cells,
        ),
      ),
    );
  }
}
