import 'package:flutter_test/flutter_test.dart';
import 'package:dawaacheck/data/models/agent_result_model.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildAgentJson({
  int agentNumber = 1,
  String agentName = 'RAKIB',
  String status = 'PASS',
  double confidenceScore = 0.92,
  String displayMessage = 'Registration verified successfully.',
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AgentResultModel.fromJson', () {
    test('parses PASS status with all fields', () {
      final json = _buildAgentJson(
        details: {'registration_number': 'REG-12345'},
      );
      final model = AgentResultModel.fromJson(json);

      expect(model.agentNumber, 1);
      expect(model.agentName, 'RAKIB');
      expect(model.status, 'PASS');
      expect(model.confidenceScore, 0.92);
      expect(model.displayMessage, 'Registration verified successfully.');
      expect(model.failReason, isNull);
      expect(model.details, isNotNull);
      expect(model.details!['registration_number'], 'REG-12345');
    });

    test('parses FAIL status with failReason', () {
      final json = _buildAgentJson(
        status: 'FAIL',
        confidenceScore: 0.15,
        failReason: 'No matching registration found in DRAP database.',
        displayMessage: 'Registration check failed.',
      );
      final model = AgentResultModel.fromJson(json);

      expect(model.status, 'FAIL');
      expect(model.confidenceScore, 0.15);
      expect(model.failReason, 'No matching registration found in DRAP database.');
    });

    test('parses UNCERTAIN status', () {
      final json = _buildAgentJson(status: 'UNCERTAIN', confidenceScore: 0.5);
      final model = AgentResultModel.fromJson(json);
      expect(model.status, 'UNCERTAIN');
    });

    test('parses PROCESSING status', () {
      final json = _buildAgentJson(status: 'PROCESSING');
      final model = AgentResultModel.fromJson(json);
      expect(model.status, 'PROCESSING');
    });

    test('parses WAITING status', () {
      final json = _buildAgentJson(status: 'WAITING');
      final model = AgentResultModel.fromJson(json);
      expect(model.status, 'WAITING');
    });

    test('defaults confidenceScore to 0.0 when missing', () {
      final json = _buildAgentJson();
      json.remove('confidence_score');
      final model = AgentResultModel.fromJson(json);
      expect(model.confidenceScore, 0.0);
    });

    test('handles missing optional fields (failReason, details)', () {
      final json = _buildAgentJson();
      // failReason and details are already absent by default
      final model = AgentResultModel.fromJson(json);
      expect(model.failReason, isNull);
      expect(model.details, isNull);
    });
  });

  group('AgentResultModel status getters', () {
    test('isPassed returns true only for PASS', () {
      final pass = AgentResultModel.fromJson(_buildAgentJson(status: 'PASS'));
      final fail = AgentResultModel.fromJson(_buildAgentJson(status: 'FAIL'));
      expect(pass.isPassed, isTrue);
      expect(fail.isPassed, isFalse);
    });

    test('isFailed returns true only for FAIL', () {
      final model = AgentResultModel.fromJson(_buildAgentJson(status: 'FAIL'));
      expect(model.isFailed, isTrue);
      expect(model.isPassed, isFalse);
    });

    test('isUncertain returns true only for UNCERTAIN', () {
      final model = AgentResultModel.fromJson(_buildAgentJson(status: 'UNCERTAIN'));
      expect(model.isUncertain, isTrue);
      expect(model.isPassed, isFalse);
      expect(model.isFailed, isFalse);
    });

    test('isProcessing returns true only for PROCESSING', () {
      final model = AgentResultModel.fromJson(_buildAgentJson(status: 'PROCESSING'));
      expect(model.isProcessing, isTrue);
      expect(model.isDone, isFalse);
    });

    test('isWaiting returns true only for WAITING', () {
      final model = AgentResultModel.fromJson(_buildAgentJson(status: 'WAITING'));
      expect(model.isWaiting, isTrue);
      expect(model.isDone, isFalse);
    });

    test('isDone is true for PASS, FAIL, UNCERTAIN and false otherwise', () {
      expect(
        AgentResultModel.fromJson(_buildAgentJson(status: 'PASS')).isDone,
        isTrue,
      );
      expect(
        AgentResultModel.fromJson(_buildAgentJson(status: 'FAIL')).isDone,
        isTrue,
      );
      expect(
        AgentResultModel.fromJson(_buildAgentJson(status: 'UNCERTAIN')).isDone,
        isTrue,
      );
      expect(
        AgentResultModel.fromJson(_buildAgentJson(status: 'PROCESSING')).isDone,
        isFalse,
      );
      expect(
        AgentResultModel.fromJson(_buildAgentJson(status: 'WAITING')).isDone,
        isFalse,
      );
    });
  });

  group('AgentResultModel.toJson', () {
    test('serializes all fields correctly', () {
      final json = _buildAgentJson(
        agentNumber: 3,
        agentName: 'MUNZIR',
        status: 'FAIL',
        failReason: 'Active recall found.',
        details: {'recall_id': 'RC-001'},
      );
      final model = AgentResultModel.fromJson(json);
      final output = model.toJson();

      expect(output['agent_number'], 3);
      expect(output['agent_name'], 'MUNZIR');
      expect(output['status'], 'FAIL');
      expect(output['fail_reason'], 'Active recall found.');
      expect((output['details'] as Map)['recall_id'], 'RC-001');
    });

    test('round-trip fromJson(toJson(model)) preserves data', () {
      final original = AgentResultModel.fromJson(_buildAgentJson(
        agentNumber: 5,
        agentName: 'ADIL',
        status: 'PASS',
        confidenceScore: 0.88,
        details: {'label_mrp': '150'},
      ));
      final roundTripped = AgentResultModel.fromJson(original.toJson());

      expect(roundTripped.agentNumber, original.agentNumber);
      expect(roundTripped.agentName, original.agentName);
      expect(roundTripped.status, original.status);
      expect(roundTripped.confidenceScore, original.confidenceScore);
      expect(roundTripped.displayMessage, original.displayMessage);
      expect(roundTripped.failReason, original.failReason);
      expect(roundTripped.details, original.details);
    });
  });

  group('AgentResultModel Equatable', () {
    test('two models with same agentNumber and status are equal', () {
      final a = AgentResultModel.fromJson(_buildAgentJson(agentNumber: 1, status: 'PASS'));
      final b = AgentResultModel.fromJson(_buildAgentJson(
        agentNumber: 1,
        status: 'PASS',
        displayMessage: 'Different message',
      ));
      expect(a, equals(b));
    });

    test('two models with different status are not equal', () {
      final a = AgentResultModel.fromJson(_buildAgentJson(agentNumber: 1, status: 'PASS'));
      final b = AgentResultModel.fromJson(_buildAgentJson(agentNumber: 1, status: 'FAIL'));
      expect(a, isNot(equals(b)));
    });
  });
}
