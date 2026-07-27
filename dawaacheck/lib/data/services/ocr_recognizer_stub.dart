import 'package:flutter/foundation.dart';

import 'ocr_line.dart';

/// Web / unsupported-platform fallback: no on-device OCR model available, so
/// return nothing, and the caller falls back to image-hash recognition.
Future<List<OcrLine>> recognizeImage(Uint8List bytes) async => const <OcrLine>[];
