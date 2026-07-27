import 'package:flutter_test/flutter_test.dart';
import 'package:dawaacheck/data/models/cabinet_item.dart';
import 'package:dawaacheck/data/models/recall_alert_model.dart';
import 'package:dawaacheck/data/services/recall_matcher.dart';

CabinetItem _item({
  String name = 'SeaCal Bone Strength',
  String? reg,
  String? batch,
  String verdict = 'VERIFIED',
}) {
  return CabinetItem(
    id: 'sc_1',
    name: name,
    registrationNumber: reg,
    batchNumber: batch,
    manufacturer: 'Test Pharma',
    verdict: verdict,
    scannedAt: DateTime(2026, 7, 1),
  );
}

RecallAlertModel _recall({
  String id = 'r1',
  String name = 'SeaCal Bone Strength (Calcium)',
  String recallClass = 'CLASS_II',
  String? reg,
  List<String> batches = const [],
  bool active = true,
}) {
  return RecallAlertModel(
    id: id,
    recallClass: recallClass,
    medicineName: name,
    registrationNumber: reg,
    batchNumbers: batches,
    recallReason: 'test reason',
    recallDate: DateTime(2026, 7, 5),
    isActive: active,
  );
}

void main() {
  group('RecallMatcher', () {
    test('matches on shared brand token even with different suffixes', () {
      final matches = RecallMatcher.match(
        [_item(name: 'SeaCal Bone Strength')],
        [_recall(name: 'SeaCal Bone Strength (Calcium + D3)')],
      );
      expect(matches, hasLength(1));
      expect(matches.first.type, RecallMatchType.name);
    });

    test('matches on registration number when brand differs', () {
      final matches = RecallMatcher.match(
        [_item(name: 'BrandA', reg: '0017-0018')],
        [_recall(name: 'BrandB', reg: '00170018')],
      );
      expect(matches, hasLength(1));
      expect(matches.first.type, RecallMatchType.registration);
    });

    test('exact batch hit is the strongest match type', () {
      final matches = RecallMatcher.match(
        [_item(reg: '0017-0018', batch: 'SC-2406')],
        [
          _recall(
              reg: '0017-0018',
              batches: const ['SC-2406'],
              name: 'SeaCal Bone Strength'),
        ],
      );
      expect(matches, hasLength(1));
      expect(matches.first.type, RecallMatchType.batch);
      expect(matches.first.isExactBatch, isTrue);
    });

    test('different medicine does not match', () {
      final matches = RecallMatcher.match(
        [_item(name: 'Panadol Extra', reg: '999999')],
        [_recall(name: 'SeaCal Bone Strength', reg: '0017-0018')],
      );
      expect(matches, isEmpty);
    });

    test('placeholder registration numbers never match', () {
      final matches = RecallMatcher.match(
        [_item(name: 'Alpha', reg: 'verify')],
        [_recall(name: 'Beta', reg: 'verify')],
      );
      expect(matches, isEmpty);
    });

    test('short shared tokens do not cause false positives', () {
      // Both start with "D" but are unrelated — token length guard blocks it.
      final matches = RecallMatcher.match(
        [_item(name: 'D 3 Drops')],
        [_recall(name: 'D Plus Syrup')],
      );
      expect(matches, isEmpty);
    });

    test('inactive recalls are ignored', () {
      final matches = RecallMatcher.match(
        [_item(name: 'SeaCal Bone Strength')],
        [_recall(name: 'SeaCal Bone Strength', active: false)],
      );
      expect(matches, isEmpty);
    });

    test('empty cabinet yields no matches', () {
      final matches = RecallMatcher.match([], [_recall()]);
      expect(matches, isEmpty);
    });
  });
}
