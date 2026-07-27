import 'package:equatable/equatable.dart';

class AgentResultModel extends Equatable {
  final int agentNumber;
  final String agentName;
  final String status; // PASS, FAIL, UNCERTAIN, PROCESSING, WAITING
  final double confidenceScore;
  final String displayMessage;
  final String? failReason;
  final Map<String, dynamic>? details;

  const AgentResultModel({
    required this.agentNumber,
    required this.agentName,
    required this.status,
    this.confidenceScore = 0.0,
    required this.displayMessage,
    this.failReason,
    this.details,
  });

  factory AgentResultModel.fromJson(Map<String, dynamic> json) {
    return AgentResultModel(
      agentNumber: json['agent_number'] as int,
      agentName: json['agent_name'] as String,
      status: json['status'] as String,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      displayMessage: json['display_message'] as String,
      failReason: json['fail_reason'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent_number': agentNumber,
      'agent_name': agentName,
      'status': status,
      'confidence_score': confidenceScore,
      'display_message': displayMessage,
      'fail_reason': failReason,
      'details': details,
    };
  }

  bool get isPassed => status == 'PASS';
  bool get isFailed => status == 'FAIL';
  bool get isUncertain => status == 'UNCERTAIN';
  bool get isProcessing => status == 'PROCESSING';
  bool get isWaiting => status == 'WAITING';
  bool get isDone => isPassed || isFailed || isUncertain;

  @override
  List<Object?> get props => [agentNumber, status];
}
