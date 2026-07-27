import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'ocr_line.dart';

/// Mobile (Android/iOS) on-device OCR via Google ML Kit (Latin script).
final TextRecognizer _recognizer =
    TextRecognizer(script: TextRecognitionScript.latin);

Future<List<OcrLine>> recognizeImage(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes(bytes, flush: true);
  try {
    final recognized =
        await _recognizer.processImage(InputImage.fromFilePath(file.path));
    final lines = <OcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        final text = line.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isNotEmpty) lines.add(OcrLine(text, box.height, box.top));
      }
    }
    return lines;
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}
