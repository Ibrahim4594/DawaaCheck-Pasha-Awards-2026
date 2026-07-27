import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_spacing.dart';

/// Premium toast notification system — replaces default SnackBar.
/// Slides in from top with a spring animation, auto-dismisses.
class AppToast {
  AppToast._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Show a success toast (green accent)
  static void success(BuildContext context, String message) {
    _show(context, message: message, type: _ToastType.success);
  }

  /// Show an error toast (red accent)
  static void error(BuildContext context, String message) {
    _show(context, message: message, type: _ToastType.error);
  }

  /// Show a warning toast (amber accent)
  static void warning(BuildContext context, String message) {
    _show(context, message: message, type: _ToastType.warning);
  }

  /// Show an info toast (blue accent)
  static void info(BuildContext context, String message) {
    _show(context, message: message, type: _ToastType.info);
  }

  /// Show a custom toast
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? color,
    Duration duration = const Duration(seconds: 3),
  }) {
    _show(
      context,
      message: message,
      type: _ToastType.info,
      customIcon: icon,
      customColor: color,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required _ToastType type,
    IconData? customIcon,
    Color? customColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Dismiss any existing toast
    dismiss();
    HapticFeedback.lightImpact();

    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    final color = customColor ?? type.color;
    final icon = customIcon ?? type.icon;

    _currentEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        icon: icon,
        color: color,
        topPadding: topPadding,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    _dismissTimer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

enum _ToastType {
  success,
  error,
  warning,
  info;

  Color get color => switch (this) {
        success => AppColors.verified,
        error => AppColors.danger,
        warning => AppColors.warning,
        info => AppColors.primary,
      };

  IconData get icon => switch (this) {
        success => Icons.check_circle_rounded,
        error => Icons.error_rounded,
        warning => Icons.warning_rounded,
        info => Icons.info_rounded,
      };
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final double topPadding;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.topPadding,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                widget.onDismiss();
              }
            },
            onTap: widget.onDismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusCard),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.06),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Accent icon with colored circle
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Message
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppTextStyles.bodySemibold.copyWith(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Subtle accent bar on right
                    Container(
                      width: 3,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
