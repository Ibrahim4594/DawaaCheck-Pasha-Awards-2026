import 'dart:convert';
import 'dart:typed_data';

/// Utility helpers
class Helpers {
  Helpers._();

  static String bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  static String generateScanId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'sc_$timestamp';
  }

  static String getVerdictLabel(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'VERIFIED':
        return 'Verified';
      case 'DANGER':
        return 'Danger';
      case 'UNVERIFIED':
        return 'Unverified';
      default:
        return verdict;
    }
  }
}
