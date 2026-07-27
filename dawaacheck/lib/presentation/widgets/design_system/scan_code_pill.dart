import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Corner-positioned mono scan ID — `DWA-0047`.
///
/// Auto-wraps in `Directionality(textDirection: TextDirection.ltr)` so digits
/// don't reverse in Urdu (RTL) locale. This is the canonical rendering for
/// any scan code in DawaaCheck UI; never render a raw uuid.
class ScanCodePill extends StatelessWidget {
  final String code;
  final Color? color;

  const ScanCodePill({
    super.key,
    required this.code,
    this.color,
  });

  /// Derives a `DWA-XXXX` code from a full scan id (uuid).
  static String forId(String scanId) {
    final clean = scanId.replaceAll('-', '').toUpperCase();
    final suffix = clean.length >= 4 ? clean.substring(0, 4) : clean.padRight(4, '0');
    return 'DWA-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(code, style: AppTextStyles.monoCaption.copyWith(color: tint)),
      ),
    );
  }
}
