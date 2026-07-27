import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dawaacheck/data/services/ocr_verification_builder.dart';
import 'package:dawaacheck/core/constants/ingredient_safety.dart';
import 'package:dawaacheck/data/datasources/local/reference_catalog.dart';
import 'package:dawaacheck/data/services/pack_recognition_service.dart';
import 'package:dawaacheck/data/services/ocr_extractor.dart';

/// Verifies the demo scan matcher end-to-end: each of the 5 reference medicines,
/// after being re-encoded the way image_picker recompresses a capture (resize to
/// 1024px wide + JPEG q85), is still identified as the correct scenario via the
/// perceptual aHash path — and resolves to the expected verdict.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mimic image_picker(maxWidth: 1024, imageQuality: 85).
  Future<List<int>> recompress(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final decoded = img.decodeImage(data.buffer.asUint8List())!;
    final resized = decoded.width > 1024
        ? img.copyResize(decoded, width: 1024)
        : decoded;
    return img.encodeJpg(resized, quality: 85);
  }

  group('every scenario builds valid, non-null verdict data', () {
    const validVerdicts = {'VERIFIED', 'UNVERIFIED', 'DANGER'};
    for (final scenario in kReferencePacks) {
      test('${scenario.key} pipeline', () {
        final result = scenario.buildResult('test-user');
        expect(validVerdicts.contains(result.overallVerdict), isTrue);
        expect(result.medicineName, isNotEmpty);
        expect(result.agentResults.length, 10);
        expect(result.recommendationsList, isNotEmpty);
        expect(result.consumerMessage, isNotEmpty);
        expect(scenario.buildConsoleLog(), isNotEmpty);
        // Risk score within bounds.
        expect(result.riskScore, inInclusiveRange(0, 100));
      });
    }
  });

  group('ingredient safety warnings', () {
    test('aspirin → child / Reye warning', () {
      final w = ingredientSafetyWarnings('Disprin (Aspirin 300mg) tablets');
      expect(w, isNotEmpty);
      expect(w.first.toLowerCase(), contains('aspirin'));
      expect(w.join(' ').toLowerCase(), contains('children'));
    });

    test('antibiotic → prescription / resistance warning', () {
      final w = ingredientSafetyWarnings('Amoxil (Amoxicillin 500mg)');
      expect(w.join(' ').toLowerCase(), contains('antibiotic'));
    });

    test('plain paracetamol → no warning', () {
      final w = ingredientSafetyWarnings('Panadol (Paracetamol 500mg)');
      expect(w, isEmpty);
    });

    test('serious-condition med → consult-doctor warning', () {
      final w = consultDoctorWarning('DioPlus (Amlodipine + Valsartan)');
      expect(w, isNotNull);
      expect(w!.toLowerCase(), contains('doctor'));
    });

    test('simple supplement → no consult warning', () {
      expect(consultDoctorWarning('Vitamin C 500mg'), isNull);
    });

    test('halal: tablet → HALAL, capsule → VERIFY, pork → NOT_HALAL', () {
      expect(halalAssessment('Panadol Paracetamol', 'Tablets').status, 'HALAL');
      expect(halalAssessment('Zyme CoQ10', 'Capsules').status, 'VERIFY');
      expect(halalAssessment('contains porcine gelatin', null).status,
          'NOT_HALAL');
    });
  });

  test('label-read build always sets a halal status', () {
    final b = buildFromOcr(userId: 'u', ocr: const OcrResult());
    expect(['HALAL', 'VERIFY', 'NOT_HALAL'], contains(b.result.halalStatus));
  });

  group('alien build is always a valid green result', () {
    test('empty OCR still yields green + 10 agents', () {
      final b = buildFromOcr(userId: 'u', ocr: const OcrResult());
      expect(b.result.overallVerdict, 'VERIFIED');
      expect(b.result.medicineName, isNotEmpty);
      expect(b.result.agentResults.length, 10);
      expect(b.agents.length, 10);
      expect(b.log, isNotEmpty);
      expect(b.result.riskScore, inInclusiveRange(0, 30));
    });

    test('real OCR name + ingredients flow through', () {
      final b = buildFromOcr(
        userId: 'u',
        ocr: const OcrResult(
          name: 'Panadol',
          ingredients: ['Paracetamol 500mg'],
        ),
      );
      expect(b.result.medicineName, 'Panadol');
      expect(b.result.overallVerdict, 'VERIFIED');
      expect(b.result.recommendationsList.join(' '), contains('Paracetamol'));
    });
  });

  group('PackRecognitionService identifies each reference medicine', () {
    for (final scenario in kReferencePacks) {
      test('${scenario.key} → ${scenario.verdict}', () async {
        final bytes = await recompress(scenario.assetPath);

        // Recompression must change the byte size so the exact-size fast path
        // is bypassed and the perceptual hash path is exercised.
        expect(bytes.length, isNot(scenario.frontByteSize),
            reason: 'recompressed size should differ from original');

        final matched =
            await PackRecognitionService.match(Uint8List.fromList(bytes));

        expect(matched, isNotNull,
            reason: '${scenario.key} should match (not be treated as alien)');
        expect(matched!.key, scenario.key,
            reason: 'wrong medicine matched for ${scenario.key}');
        expect(matched.verdict, scenario.verdict);
      });
    }
  });
}
