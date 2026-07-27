import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// Default container for any card surface in DawaaCheck.
///
/// Replaces ad-hoc `Container(decoration: BoxDecoration(...))` patterns with a
/// consistent clinical surface: white background, 1.5px hairline border, 14px
/// radius, **no shadow**. Shadows are reserved for elements that truly float
/// above the content plane (bottom nav, modals, FAB) — cards use the border
/// to create separation instead.
///
/// When given an [onTap], wires `Material + InkWell` with proper splash and
/// haptic feedback (never `GestureDetector` per CLAUDE.md strict rule).
class ClinicalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? accentStripColor;
  final double borderRadius;
  final Color? backgroundColor;

  const ClinicalCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.accentStripColor,
    this.borderRadius = AppSpacing.radiusCard,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final surface = backgroundColor ?? Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    final body = accentStripColor != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1),
            // IntrinsicHeight bounds the Row's vertical extent to the natural
            // height of [content] so `CrossAxisAlignment.stretch` on the accent
            // strip doesn't try to fill infinite height inside a scroll view.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3.5, color: accentStripColor),
                  Expanded(child: content),
                ],
              ),
            ),
          )
        : content;

    final container = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: body,
    );

    if (onTap == null) return container;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: AppColors.primary.withValues(alpha: 0.06),
        highlightColor: AppColors.primary.withValues(alpha: 0.03),
        child: container,
      ),
    );
  }
}
