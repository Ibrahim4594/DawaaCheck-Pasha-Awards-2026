import 'package:flutter_test/flutter_test.dart';
import 'package:dawaacheck/data/models/recall_alert_model.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildRecallJson({
  dynamic id = 'recall_001',
  String recallClass = 'CLASS_I',
  String medicineName = 'Contaminated Syrup X',
  String? registrationNumber = 'REG-99001',
  List<String> batchNumbers = const ['BN-001', 'BN-002', 'BN-003'],
  String recallReason = 'Microbial contamination detected in batch.',
  String recallDate = '2026-03-01T00:00:00.000Z',
  String? drapNoticeNumber = 'DRAP/2026/RC-045',
  bool isActive = true,
  bool userAffected = false,
}) {
  return {
    'id': id,
    'recall_class': recallClass,
    'medicine_name': medicineName,
    'registration_number': registrationNumber,
    'batch_numbers': batchNumbers,
    'recall_reason': recallReason,
    'recall_date': recallDate,
    'drap_notice_number': drapNoticeNumber,
    'is_active': isActive,
    'user_affected': userAffected,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RecallAlertModel.fromJson', () {
    test('parses CLASS_I recall with all fields', () {
      final json = _buildRecallJson();
      final model = RecallAlertModel.fromJson(json);

      expect(model.id, 'recall_001');
      expect(model.recallClass, 'CLASS_I');
      expect(model.medicineName, 'Contaminated Syrup X');
      expect(model.registrationNumber, 'REG-99001');
      expect(model.batchNumbers, ['BN-001', 'BN-002', 'BN-003']);
      expect(model.recallReason, 'Microbial contamination detected in batch.');
      expect(model.recallDate, DateTime.utc(2026, 3, 1));
      expect(model.drapNoticeNumber, 'DRAP/2026/RC-045');
      expect(model.isActive, isTrue);
      expect(model.userAffected, isFalse);
    });

    test('parses CLASS_II recall', () {
      final json = _buildRecallJson(
        recallClass: 'CLASS_II',
        medicineName: 'Mislabeled Tablet Y',
        recallReason: 'Incorrect dosage printed on label.',
      );
      final model = RecallAlertModel.fromJson(json);
      expect(model.recallClass, 'CLASS_II');
      expect(model.medicineName, 'Mislabeled Tablet Y');
    });

    test('converts numeric id to string', () {
      final json = _buildRecallJson(id: 42);
      final model = RecallAlertModel.fromJson(json);
      expect(model.id, '42');
    });

    test('defaults id to empty string when null', () {
      final json = _buildRecallJson(id: null);
      final model = RecallAlertModel.fromJson(json);
      expect(model.id, '');
    });

    test('defaults batch_numbers to empty list when missing', () {
      final json = _buildRecallJson();
      json.remove('batch_numbers');
      final model = RecallAlertModel.fromJson(json);
      expect(model.batchNumbers, isEmpty);
    });

    test('defaults batch_numbers to empty list when null', () {
      final json = _buildRecallJson();
      json['batch_numbers'] = null;
      final model = RecallAlertModel.fromJson(json);
      expect(model.batchNumbers, isEmpty);
    });

    test('parses batch_numbers with mixed types (int and string)', () {
      final json = _buildRecallJson();
      json['batch_numbers'] = ['BN-001', 12345, 'BN-003'];
      final model = RecallAlertModel.fromJson(json);
      expect(model.batchNumbers, ['BN-001', '12345', 'BN-003']);
    });

    test('defaults isActive to true when missing', () {
      final json = _buildRecallJson();
      json.remove('is_active');
      final model = RecallAlertModel.fromJson(json);
      expect(model.isActive, isTrue);
    });

    test('defaults userAffected to false when missing', () {
      final json = _buildRecallJson();
      json.remove('user_affected');
      final model = RecallAlertModel.fromJson(json);
      expect(model.userAffected, isFalse);
    });

    test('handles missing optional fields (registrationNumber, drapNoticeNumber)', () {
      final json = _buildRecallJson(
        registrationNumber: null,
        drapNoticeNumber: null,
      );
      final model = RecallAlertModel.fromJson(json);
      expect(model.registrationNumber, isNull);
      expect(model.drapNoticeNumber, isNull);
    });
  });

  group('RecallAlertModel class getters', () {
    test('isClassI returns true only for CLASS_I', () {
      final model = RecallAlertModel.fromJson(_buildRecallJson(recallClass: 'CLASS_I'));
      expect(model.isClassI, isTrue);
      expect(model.isClassII, isFalse);
    });

    test('isClassII returns true only for CLASS_II', () {
      final model = RecallAlertModel.fromJson(_buildRecallJson(recallClass: 'CLASS_II'));
      expect(model.isClassII, isTrue);
      expect(model.isClassI, isFalse);
    });

    test('both getters false for unexpected class value', () {
      final model = RecallAlertModel.fromJson(_buildRecallJson(recallClass: 'CLASS_III'));
      expect(model.isClassI, isFalse);
      expect(model.isClassII, isFalse);
    });
  });

  group('RecallAlertModel.toJson', () {
    test('serializes all fields correctly', () {
      final json = _buildRecallJson();
      final model = RecallAlertModel.fromJson(json);
      final output = model.toJson();

      expect(output['id'], 'recall_001');
      expect(output['recall_class'], 'CLASS_I');
      expect(output['medicine_name'], 'Contaminated Syrup X');
      expect(output['registration_number'], 'REG-99001');
      expect(output['batch_numbers'], ['BN-001', 'BN-002', 'BN-003']);
      expect(output['recall_reason'], 'Microbial contamination detected in batch.');
      expect(output['recall_date'], isA<String>());
      expect(output['drap_notice_number'], 'DRAP/2026/RC-045');
      expect(output['is_active'], isTrue);
    });

    test('toJson does not include userAffected (not sent to server)', () {
      final json = _buildRecallJson(userAffected: true);
      final model = RecallAlertModel.fromJson(json);
      final output = model.toJson();
      expect(output.containsKey('user_affected'), isFalse);
    });

    test('round-trip fromJson(toJson(model)) preserves data', () {
      final original = RecallAlertModel.fromJson(_buildRecallJson());
      final roundTripped = RecallAlertModel.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.recallClass, original.recallClass);
      expect(roundTripped.medicineName, original.medicineName);
      expect(roundTripped.registrationNumber, original.registrationNumber);
      expect(roundTripped.batchNumbers, original.batchNumbers);
      expect(roundTripped.recallReason, original.recallReason);
      expect(roundTripped.recallDate, original.recallDate);
      expect(roundTripped.drapNoticeNumber, original.drapNoticeNumber);
      expect(roundTripped.isActive, original.isActive);
    });
  });

  group('RecallAlertModel Equatable', () {
    test('two models with same id, recallClass, medicineName are equal', () {
      final a = RecallAlertModel.fromJson(_buildRecallJson());
      final b = RecallAlertModel.fromJson(_buildRecallJson(
        recallReason: 'Different reason',
        userAffected: true,
      ));
      expect(a, equals(b));
    });

    test('two models with different ids are not equal', () {
      final a = RecallAlertModel.fromJson(_buildRecallJson(id: 'recall_001'));
      final b = RecallAlertModel.fromJson(_buildRecallJson(id: 'recall_002'));
      expect(a, isNot(equals(b)));
    });
  });
}
