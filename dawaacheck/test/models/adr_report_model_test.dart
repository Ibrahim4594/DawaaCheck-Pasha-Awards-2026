import 'package:flutter_test/flutter_test.dart';
import 'package:dawaacheck/data/models/adr_report_model.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildAdrJson({
  dynamic id = 'adr_001',
  String userId = 'user_abc',
  String? scanId = 'sc_test_001',
  String medicineName = 'Augmentin 625mg',
  String? batchNumber = 'BN-AUG-01',
  String reactionDescription = 'Severe nausea and vomiting after first dose.',
  String severity = 'MODERATE',
  String reactionDate = '2026-03-20T14:00:00.000Z',
  String patientAgeGroup = 'ADULT',
  String? meddraTerm = 'Nausea',
  bool isFlagged = false,
}) {
  return {
    'id': id,
    'user_id': userId,
    'scan_id': scanId,
    'medicine_name': medicineName,
    'batch_number': batchNumber,
    'reaction_description': reactionDescription,
    'severity': severity,
    'reaction_date': reactionDate,
    'patient_age_group': patientAgeGroup,
    'meddra_term': meddraTerm,
    'is_flagged': isFlagged,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AdrReportModel.fromJson', () {
    test('parses complete JSON with all fields', () {
      final json = _buildAdrJson();
      final model = AdrReportModel.fromJson(json);

      expect(model.id, 'adr_001');
      expect(model.userId, 'user_abc');
      expect(model.scanId, 'sc_test_001');
      expect(model.medicineName, 'Augmentin 625mg');
      expect(model.batchNumber, 'BN-AUG-01');
      expect(model.reactionDescription, 'Severe nausea and vomiting after first dose.');
      expect(model.severity, 'MODERATE');
      expect(model.reactionDate, DateTime.utc(2026, 3, 20, 14, 0));
      expect(model.patientAgeGroup, 'ADULT');
      expect(model.meddraTerm, 'Nausea');
      expect(model.isFlagged, isFalse);
    });

    test('parses MILD severity', () {
      final model = AdrReportModel.fromJson(_buildAdrJson(severity: 'MILD'));
      expect(model.severity, 'MILD');
    });

    test('parses SEVERE severity', () {
      final model = AdrReportModel.fromJson(_buildAdrJson(severity: 'SEVERE'));
      expect(model.severity, 'SEVERE');
    });

    test('parses LIFE_THREATENING severity', () {
      final model = AdrReportModel.fromJson(_buildAdrJson(severity: 'LIFE_THREATENING'));
      expect(model.severity, 'LIFE_THREATENING');
    });

    test('converts numeric id to string', () {
      final model = AdrReportModel.fromJson(_buildAdrJson(id: 99));
      expect(model.id, '99');
    });

    test('handles null id', () {
      final model = AdrReportModel.fromJson(_buildAdrJson(id: null));
      expect(model.id, isNull);
    });

    test('handles missing optional fields', () {
      final json = _buildAdrJson(
        scanId: null,
        batchNumber: null,
        meddraTerm: null,
      );
      final model = AdrReportModel.fromJson(json);

      expect(model.scanId, isNull);
      expect(model.batchNumber, isNull);
      expect(model.meddraTerm, isNull);
    });

    test('defaults isFlagged to false when missing', () {
      final json = _buildAdrJson();
      json.remove('is_flagged');
      final model = AdrReportModel.fromJson(json);
      expect(model.isFlagged, isFalse);
    });

    test('parses flagged report', () {
      final model = AdrReportModel.fromJson(_buildAdrJson(isFlagged: true));
      expect(model.isFlagged, isTrue);
    });
  });

  group('AdrReportModel.toJson', () {
    test('serializes fields needed for server submission', () {
      final json = _buildAdrJson();
      final model = AdrReportModel.fromJson(json);
      final output = model.toJson();

      expect(output['user_id'], 'user_abc');
      expect(output['scan_id'], 'sc_test_001');
      expect(output['medicine_name'], 'Augmentin 625mg');
      expect(output['batch_number'], 'BN-AUG-01');
      expect(output['reaction_description'], 'Severe nausea and vomiting after first dose.');
      expect(output['severity'], 'MODERATE');
      expect(output['reaction_date'], isA<String>());
      expect(output['patient_age_group'], 'ADULT');
    });

    test('toJson does not include id, meddraTerm, or isFlagged (server-side only)', () {
      final json = _buildAdrJson();
      final model = AdrReportModel.fromJson(json);
      final output = model.toJson();

      expect(output.containsKey('id'), isFalse);
      expect(output.containsKey('meddra_term'), isFalse);
      expect(output.containsKey('is_flagged'), isFalse);
    });

    test('round-trip preserves serialized fields', () {
      final original = AdrReportModel.fromJson(_buildAdrJson());
      final output = original.toJson();

      // Re-add the server-only fields so we can reconstruct
      output['id'] = 'adr_001';
      output['meddra_term'] = 'Nausea';
      output['is_flagged'] = false;

      final roundTripped = AdrReportModel.fromJson(output);

      expect(roundTripped.userId, original.userId);
      expect(roundTripped.scanId, original.scanId);
      expect(roundTripped.medicineName, original.medicineName);
      expect(roundTripped.batchNumber, original.batchNumber);
      expect(roundTripped.reactionDescription, original.reactionDescription);
      expect(roundTripped.severity, original.severity);
      expect(roundTripped.reactionDate, original.reactionDate);
      expect(roundTripped.patientAgeGroup, original.patientAgeGroup);
    });
  });

  group('AdrReportModel Equatable', () {
    test('two models with same id, medicineName, severity are equal', () {
      final a = AdrReportModel.fromJson(_buildAdrJson());
      final b = AdrReportModel.fromJson(_buildAdrJson(
        reactionDescription: 'Different description',
      ));
      expect(a, equals(b));
    });

    test('two models with different severity are not equal', () {
      final a = AdrReportModel.fromJson(_buildAdrJson(severity: 'MILD'));
      final b = AdrReportModel.fromJson(_buildAdrJson(severity: 'SEVERE'));
      expect(a, isNot(equals(b)));
    });
  });
}
