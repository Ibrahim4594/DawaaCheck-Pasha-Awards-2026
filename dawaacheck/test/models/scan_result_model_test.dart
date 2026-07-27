import 'package:flutter_test/flutter_test.dart';
import 'package:dawaacheck/data/models/scan_result_model.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildAgentJson({
  int agentNumber = 1,
  String agentName = 'RAKIB',
  String status = 'PASS',
  double confidenceScore = 0.9,
  String displayMessage = 'Agent check complete.',
  String? failReason,
  Map<String, dynamic>? details,
}) {
  return {
    'agent_number': agentNumber,
    'agent_name': agentName,
    'status': status,
    'confidence_score': confidenceScore,
    'display_message': displayMessage,
    'fail_reason': ?failReason,
    'details': ?details,
  };
}

Map<String, dynamic> _buildCompleteScanJson() {
  return {
    'id': 'sc_test_001',
    'user_id': 'user_abc',
    'scan_timestamp': '2026-03-15T10:30:00.000Z',
    'medicine_name': 'Panadol Extra',
    'manufacturer': 'GSK Pakistan',
    'registration_number': 'REG-08765',
    'barcode': '8901234567890',
    'batch_number': 'BN-2026-03',
    'expiry_date': '2027-06-30',
    'overall_verdict': 'VERIFIED',
    'confidence_score': 0.95,
    'agent_results': [
      _buildAgentJson(agentNumber: 1, agentName: 'RAKIB'),
      _buildAgentJson(agentNumber: 2, agentName: 'KASHIF'),
      _buildAgentJson(agentNumber: 3, agentName: 'MUNZIR'),
    ],
    'scan_latitude': 24.8607,
    'scan_longitude': 67.0011,
    'recall_alert_sent': false,
    'risk_score': 12,
    'risk_level': 'LOW',
    'safety_alerts': ['None identified'],
    'recommendations': ['Continue use as prescribed'],
    'consumer_message': 'This medicine has been verified as authentic.',
    'verdict_summary': 'All checks passed.',
  };
}

Map<String, dynamic> _buildMinimalScanJson() {
  return {
    'id': 'sc_test_002',
    'user_id': 'user_xyz',
    'scan_timestamp': '2026-04-01T08:00:00.000Z',
    'medicine_name': 'Unknown Tablet',
    'overall_verdict': 'UNVERIFIED',
  };
}

Map<String, dynamic> _buildBackendJson() {
  return {
    'user_id': 'user_backend_1',
    'overall_verdict': 'VERIFIED',
    'confidence_score': 0.88,
    'risk_score': 20,
    'risk_level': 'LOW',
    'safety_alerts': ['Check expiry date'],
    'recommendations': ['Store in cool place'],
    'consumer_message': 'Medicine verified.',
    'verdict_summary': 'Passed all checks.',
    'agent_results': {
      'agent_1': {
        'agent_number': 1,
        'agent_name': 'RAKIB',
        'status': 'PASS',
        'confidence_score': 0.92,
        'display_message': 'Registration verified.',
        'extracted_data': {
          'brand_name': 'Augmentin 625mg',
          'manufacturer': 'GlaxoSmithKline',
          'registration_number': 'REG-55432',
          'batch_number': 'BN-AUG-01',
          'expiry_date': '2027-12-31',
        },
      },
      'agent_5': {
        'agent_number': 5,
        'agent_name': 'ADIL',
        'status': 'PASS',
        'confidence_score': 0.85,
        'display_message': 'Price verified.',
        'label_mrp': 'Rs. 450',
        'verified_mrp': 'Rs. 440',
        'generic_alternative': 'Amoxicillin + Clavulanate',
        'generic_price': 'Rs. 180',
      },
      'agent_7': {
        'agent_number': 7,
        'agent_name': 'HIFAZAT',
        'status': 'PASS',
        'confidence_score': 0.90,
        'display_message': 'Antibiotic classified.',
        'is_antibiotic': true,
        'aware_classification': 'Access',
        'stewardship_message': 'Use as prescribed. Complete full course.',
      },
    },
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ScanResultModel.fromJson', () {
    test('parses complete valid JSON with all fields populated', () {
      final json = _buildCompleteScanJson();
      final model = ScanResultModel.fromJson(json);

      expect(model.id, 'sc_test_001');
      expect(model.userId, 'user_abc');
      expect(model.scanTimestamp, DateTime.utc(2026, 3, 15, 10, 30));
      expect(model.medicineName, 'Panadol Extra');
      expect(model.manufacturer, 'GSK Pakistan');
      expect(model.registrationNumber, 'REG-08765');
      expect(model.barcode, '8901234567890');
      expect(model.batchNumber, 'BN-2026-03');
      expect(model.expiryDate, '2027-06-30');
      expect(model.overallVerdict, 'VERIFIED');
      expect(model.confidenceScore, 0.95);
      expect(model.agentResults, hasLength(3));
      expect(model.agentResults[0].agentName, 'RAKIB');
      expect(model.agentResults[1].agentName, 'KASHIF');
      expect(model.agentResults[2].agentName, 'MUNZIR');
      expect(model.scanLatitude, 24.8607);
      expect(model.scanLongitude, 67.0011);
      expect(model.recallAlertSent, isFalse);
      expect(model.riskScore, 12);
      expect(model.riskLevel, 'LOW');
      expect(model.safetyAlerts, ['None identified']);
      expect(model.recommendationsList, ['Continue use as prescribed']);
      expect(model.consumerMessage, 'This medicine has been verified as authentic.');
      expect(model.verdictSummary, 'All checks passed.');
    });

    test('parses minimal JSON with defaults for missing fields', () {
      final json = _buildMinimalScanJson();
      final model = ScanResultModel.fromJson(json);

      expect(model.id, 'sc_test_002');
      expect(model.userId, 'user_xyz');
      expect(model.medicineName, 'Unknown Tablet');
      expect(model.overallVerdict, 'UNVERIFIED');
      // Defaults
      expect(model.confidenceScore, 0.0);
      expect(model.agentResults, isEmpty);
      expect(model.manufacturer, isNull);
      expect(model.registrationNumber, isNull);
      expect(model.barcode, isNull);
      expect(model.batchNumber, isNull);
      expect(model.expiryDate, isNull);
      expect(model.scanLatitude, isNull);
      expect(model.scanLongitude, isNull);
      expect(model.recallAlertSent, isFalse);
      expect(model.riskScore, 0);
      expect(model.riskLevel, 'UNKNOWN');
      expect(model.safetyAlerts, isEmpty);
      expect(model.recommendationsList, isEmpty);
      expect(model.consumerMessage, '');
      expect(model.verdictSummary, '');
      expect(model.genericAlternative, isNull);
      expect(model.genericPrice, isNull);
      expect(model.labelMrp, isNull);
      expect(model.verifiedMrp, isNull);
      expect(model.isAntibiotic, isNull);
      expect(model.awareClassification, isNull);
      expect(model.stewardshipMessage, isNull);
    });

    test('handles null agent_results list gracefully', () {
      final json = _buildMinimalScanJson();
      json['agent_results'] = null;
      final model = ScanResultModel.fromJson(json);
      expect(model.agentResults, isEmpty);
    });

    test('handles empty agent_results list', () {
      final json = _buildMinimalScanJson();
      json['agent_results'] = <dynamic>[];
      final model = ScanResultModel.fromJson(json);
      expect(model.agentResults, isEmpty);
    });
  });

  group('ScanResultModel.fromBackendJson', () {
    test('extracts medicine name from agent_1 extracted_data', () {
      final json = _buildBackendJson();
      final model = ScanResultModel.fromBackendJson(json);

      expect(model.medicineName, 'Augmentin 625mg');
      expect(model.manufacturer, 'GlaxoSmithKline');
      expect(model.registrationNumber, 'REG-55432');
      expect(model.batchNumber, 'BN-AUG-01');
      expect(model.expiryDate, '2027-12-31');
    });

    test('extracts price info from agent_5', () {
      final json = _buildBackendJson();
      final model = ScanResultModel.fromBackendJson(json);

      expect(model.labelMrp, 'Rs. 450');
      expect(model.verifiedMrp, 'Rs. 440');
      expect(model.genericAlternative, 'Amoxicillin + Clavulanate');
      expect(model.genericPrice, 'Rs. 180');
    });

    test('extracts antibiotic info from agent_7', () {
      final json = _buildBackendJson();
      final model = ScanResultModel.fromBackendJson(json);

      expect(model.isAntibiotic, isTrue);
      expect(model.awareClassification, 'Access');
      expect(model.stewardshipMessage, 'Use as prescribed. Complete full course.');
    });

    test('parses agent results from map entries', () {
      final json = _buildBackendJson();
      final model = ScanResultModel.fromBackendJson(json);

      // 3 agents in the backend response: agent_1, agent_5, agent_7
      expect(model.agentResults, hasLength(3));
    });

    test('uses overall_verdict and risk fields from top level', () {
      final json = _buildBackendJson();
      final model = ScanResultModel.fromBackendJson(json);

      expect(model.overallVerdict, 'VERIFIED');
      expect(model.confidenceScore, 0.88);
      expect(model.riskScore, 20);
      expect(model.riskLevel, 'LOW');
      expect(model.safetyAlerts, ['Check expiry date']);
      expect(model.recommendationsList, ['Store in cool place']);
      expect(model.consumerMessage, 'Medicine verified.');
      expect(model.verdictSummary, 'Passed all checks.');
    });

    test('generates a timestamped id starting with sc_', () {
      final json = _buildBackendJson();
      final model = ScanResultModel.fromBackendJson(json);
      expect(model.id, startsWith('sc_'));
    });

    test('defaults medicine name to Unknown Medicine when agent_1 absent', () {
      final json = _buildBackendJson();
      (json['agent_results'] as Map).remove('agent_1');
      final model = ScanResultModel.fromBackendJson(json);
      expect(model.medicineName, 'Unknown Medicine');
    });

    test('handles completely missing agent_results map', () {
      final json = <String, dynamic>{
        'user_id': 'u1',
        'overall_verdict': 'UNVERIFIED',
      };
      final model = ScanResultModel.fromBackendJson(json);

      expect(model.medicineName, 'Unknown Medicine');
      expect(model.overallVerdict, 'UNVERIFIED');
      expect(model.agentResults, isEmpty);
      expect(model.isAntibiotic, isNull);
      expect(model.labelMrp, isNull);
    });

    test('defaults overall_verdict to UNVERIFIED when missing', () {
      final json = <String, dynamic>{
        'agent_results': <String, dynamic>{},
      };
      final model = ScanResultModel.fromBackendJson(json);
      expect(model.overallVerdict, 'UNVERIFIED');
    });
  });

  group('ScanResultModel.toJson', () {
    test('serializes all standard fields', () {
      final json = _buildCompleteScanJson();
      final model = ScanResultModel.fromJson(json);
      final output = model.toJson();

      expect(output['id'], 'sc_test_001');
      expect(output['user_id'], 'user_abc');
      expect(output['medicine_name'], 'Panadol Extra');
      expect(output['manufacturer'], 'GSK Pakistan');
      expect(output['overall_verdict'], 'VERIFIED');
      expect(output['confidence_score'], 0.95);
      expect(output['risk_score'], 12);
      expect(output['risk_level'], 'LOW');
      expect(output['safety_alerts'], ['None identified']);
      expect(output['recommendations'], ['Continue use as prescribed']);
      expect(output['recall_alert_sent'], isFalse);
      expect(output['agent_results'], isList);
      expect((output['agent_results'] as List), hasLength(3));
    });

    test('round-trip fromJson(toJson(model)) preserves all fields', () {
      final original = ScanResultModel.fromJson(_buildCompleteScanJson());
      final roundTripped = ScanResultModel.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.userId, original.userId);
      expect(roundTripped.scanTimestamp, original.scanTimestamp);
      expect(roundTripped.medicineName, original.medicineName);
      expect(roundTripped.manufacturer, original.manufacturer);
      expect(roundTripped.registrationNumber, original.registrationNumber);
      expect(roundTripped.barcode, original.barcode);
      expect(roundTripped.batchNumber, original.batchNumber);
      expect(roundTripped.expiryDate, original.expiryDate);
      expect(roundTripped.overallVerdict, original.overallVerdict);
      expect(roundTripped.confidenceScore, original.confidenceScore);
      expect(roundTripped.agentResults.length, original.agentResults.length);
      expect(roundTripped.scanLatitude, original.scanLatitude);
      expect(roundTripped.scanLongitude, original.scanLongitude);
      expect(roundTripped.recallAlertSent, original.recallAlertSent);
      expect(roundTripped.riskScore, original.riskScore);
      expect(roundTripped.riskLevel, original.riskLevel);
      expect(roundTripped.safetyAlerts, original.safetyAlerts);
      expect(roundTripped.recommendationsList, original.recommendationsList);
      expect(roundTripped.consumerMessage, original.consumerMessage);
      expect(roundTripped.verdictSummary, original.verdictSummary);
    });

    test('round-trip with minimal data preserves defaults', () {
      final original = ScanResultModel.fromJson(_buildMinimalScanJson());
      final roundTripped = ScanResultModel.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.confidenceScore, 0.0);
      expect(roundTripped.agentResults, isEmpty);
      expect(roundTripped.riskScore, 0);
      expect(roundTripped.riskLevel, 'UNKNOWN');
    });
  });

  group('ScanResultModel verdict getters', () {
    test('isVerified is true only for VERIFIED verdict', () {
      final model = ScanResultModel.fromJson(_buildCompleteScanJson());
      expect(model.isVerified, isTrue);
      expect(model.isDanger, isFalse);
      expect(model.isUnverified, isFalse);
    });

    test('isDanger is true only for DANGER verdict', () {
      final json = _buildMinimalScanJson();
      json['overall_verdict'] = 'DANGER';
      final model = ScanResultModel.fromJson(json);
      expect(model.isDanger, isTrue);
      expect(model.isVerified, isFalse);
      expect(model.isUnverified, isFalse);
    });

    test('isUnverified is true only for UNVERIFIED verdict', () {
      final model = ScanResultModel.fromJson(_buildMinimalScanJson());
      expect(model.isUnverified, isTrue);
      expect(model.isVerified, isFalse);
      expect(model.isDanger, isFalse);
    });

    test('all getters false for unexpected verdict value', () {
      final json = _buildMinimalScanJson();
      json['overall_verdict'] = 'PENDING';
      final model = ScanResultModel.fromJson(json);
      expect(model.isVerified, isFalse);
      expect(model.isDanger, isFalse);
      expect(model.isUnverified, isFalse);
    });
  });

  group('ScanResultModel Equatable', () {
    test('two models with same id and verdict are equal', () {
      final a = ScanResultModel.fromJson(_buildCompleteScanJson());
      final jsonB = _buildCompleteScanJson();
      jsonB['confidence_score'] = 0.5; // different confidence, but same id + verdict
      final b = ScanResultModel.fromJson(jsonB);
      expect(a, equals(b));
    });

    test('two models with different ids are not equal', () {
      final jsonA = _buildCompleteScanJson();
      final jsonB = _buildCompleteScanJson();
      jsonB['id'] = 'sc_test_999';
      expect(
        ScanResultModel.fromJson(jsonA),
        isNot(equals(ScanResultModel.fromJson(jsonB))),
      );
    });
  });
}
