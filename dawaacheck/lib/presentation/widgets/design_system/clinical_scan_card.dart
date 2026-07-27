import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/extensions.dart';
import 'clinical_card.dart';
import 'scan_code_pill.dart';

/// Verdict categorization used by list-row cards.
enum ScanVerdict { verified, unverified, danger }

extension _ScanVerdictColor on ScanVerdict {
  Color get color {
    switch (this) {
      case ScanVerdict.verified:
        return AppColors.verified;
      case ScanVerdict.unverified:
        return AppColors.warning;
      case ScanVerdict.danger:
        return AppColors.danger;
    }
  }

  static ScanVerdict fromString(String raw) {
    switch (raw.toUpperCase()) {
      case 'VERIFIED':
        return ScanVerdict.verified;
      case 'DANGER':
        return ScanVerdict.danger;
      default:
        return ScanVerdict.unverified;
    }
  }
}

/// List-row scan card for home (recent scans) and history list.
///
/// Layout: 3.5px left accent strip (verdict color) · medicine name (h4) ·
/// manufacturer + mono timestamp (caption row) · `ScanCodePill` in top-right
/// corner. Uses `ClinicalCard` for the surface — no shadow, 1.5px border.
class ClinicalScanCard extends StatelessWidget {
  final String medicineName;
  final String manufacturer;
  final ScanVerdict verdict;
  final String scanCode;
  final DateTime scanTime;
  final VoidCallback? onTap;

  const ClinicalScanCard({
    super.key,
    required this.medicineName,
    required this.manufacturer,
    required this.verdict,
    required this.scanCode,
    required this.scanTime,
    this.onTap,
  });

  /// Convenience constructor from a scan result's string verdict.
  ClinicalScanCard.fromVerdictString({
    super.key,
    required this.medicineName,
    required this.manufacturer,
    required String verdictString,
    required this.scanCode,
    required this.scanTime,
    this.onTap,
  }) : verdict = _ScanVerdictColor.fromString(verdictString);

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      onTap: onTap,
      accentStripColor: verdict.color,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(medicineName, style: AppTextStyles.h4),
                const SizedBox(height: 3),
                Text(
                  '$manufacturer  ·  ${scanTime.timeAgo}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ScanCodePill(code: scanCode, color: verdict.color),
        ],
      ),
    );
  }
}
