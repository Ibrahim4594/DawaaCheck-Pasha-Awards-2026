import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import 'scan_code_pill.dart';

/// Signature byline for result screens.
///
/// Renders: "By **HAKIM** with 9 co-agents · 2.4s · `DWA-0047`"
///
/// The agent name is rendered in Plex Sans bodyStrong (w600) so it reads as
/// a bylined human, not a data ID. Time and scan code use Plex Mono. This
/// single line is the most distinctive anti-AI signal on a DawaaCheck result
/// screen — no generic medical app gives its findings a signature.
class AgentByline extends StatelessWidget {
  final String primaryAgent;
  final int coAgentCount;
  final Duration processingTime;
  final String scanCode;

  const AgentByline({
    super.key,
    required this.primaryAgent,
    required this.coAgentCount,
    required this.processingTime,
    required this.scanCode,
  });

  String get _formattedTime {
    final seconds = processingTime.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: AppTextStyles.body.copyWith(height: 1.5),
        children: [
          const TextSpan(text: 'By '),
          TextSpan(
            text: primaryAgent,
            style: AppTextStyles.bodyStrong,
          ),
          TextSpan(text: ' with $coAgentCount co-agents · '),
          TextSpan(text: _formattedTime, style: AppTextStyles.mono),
          const TextSpan(text: ' · '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ScanCodePill(code: scanCode),
          ),
        ],
      ),
    );
  }
}
