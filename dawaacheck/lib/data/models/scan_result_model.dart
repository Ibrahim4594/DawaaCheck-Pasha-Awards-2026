import 'package:equatable/equatable.dart';
import 'agent_result_model.dart';

class ScanResultModel extends Equatable {
  final String id;
  final String userId;
  final DateTime scanTimestamp;
  final String medicineName;
  final String? manufacturer;
  final String? registrationNumber;
  final String? barcode;
  final String? batchNumber;
  final String? expiryDate;
  final String overallVerdict; // VERIFIED, UNVERIFIED, DANGER
  final double confidenceScore;
  final List<AgentResultModel> agentResults;
  final double? scanLatitude;
  final double? scanLongitude;
  final bool recallAlertSent;

  // Risk assessment from verdict synthesis
  final int riskScore; // 0-100
  final String riskLevel; // LOW, MODERATE, HIGH, CRITICAL
  final List<dynamic> safetyAlerts;
  final List<String> recommendationsList;
  final String consumerMessage;
  final String verdictSummary;

  // Extra details from agents
  final String? genericAlternative;
  final String? genericPrice;
  final String? labelMrp;
  final String? verifiedMrp;
  final bool? isAntibiotic;
  final String? awareClassification;
  final String? stewardshipMessage;

  // Consumer health depth
  final List<String> sideEffects;
  final String? halalStatus; // HALAL, NOT_HALAL, VERIFY, UNKNOWN
  final String? halalReason;

  const ScanResultModel({
    required this.id,
    required this.userId,
    required this.scanTimestamp,
    required this.medicineName,
    this.manufacturer,
    this.registrationNumber,
    this.barcode,
    this.batchNumber,
    this.expiryDate,
    required this.overallVerdict,
    this.confidenceScore = 0.0,
    this.agentResults = const [],
    this.scanLatitude,
    this.scanLongitude,
    this.recallAlertSent = false,
    this.riskScore = 0,
    this.riskLevel = 'UNKNOWN',
    this.safetyAlerts = const [],
    this.recommendationsList = const [],
    this.consumerMessage = '',
    this.verdictSummary = '',
    this.genericAlternative,
    this.genericPrice,
    this.labelMrp,
    this.verifiedMrp,
    this.isAntibiotic,
    this.awareClassification,
    this.stewardshipMessage,
    this.sideEffects = const [],
    this.halalStatus,
    this.halalReason,
  });

  ScanResultModel copyWith({
    String? overallVerdict,
    int? riskScore,
    String? riskLevel,
    List<dynamic>? safetyAlerts,
    List<String>? recommendationsList,
    List<String>? sideEffects,
    String? consumerMessage,
  }) {
    return ScanResultModel(
      id: id,
      userId: userId,
      scanTimestamp: scanTimestamp,
      medicineName: medicineName,
      manufacturer: manufacturer,
      registrationNumber: registrationNumber,
      barcode: barcode,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      overallVerdict: overallVerdict ?? this.overallVerdict,
      confidenceScore: confidenceScore,
      agentResults: agentResults,
      scanLatitude: scanLatitude,
      scanLongitude: scanLongitude,
      recallAlertSent: recallAlertSent,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      safetyAlerts: safetyAlerts ?? this.safetyAlerts,
      recommendationsList: recommendationsList ?? this.recommendationsList,
      consumerMessage: consumerMessage ?? this.consumerMessage,
      verdictSummary: verdictSummary,
      genericAlternative: genericAlternative,
      genericPrice: genericPrice,
      labelMrp: labelMrp,
      verifiedMrp: verifiedMrp,
      isAntibiotic: isAntibiotic,
      awareClassification: awareClassification,
      stewardshipMessage: stewardshipMessage,
      sideEffects: sideEffects ?? this.sideEffects,
      halalStatus: halalStatus,
      halalReason: halalReason,
    );
  }

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    return ScanResultModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      scanTimestamp: DateTime.parse(json['scan_timestamp'] as String),
      medicineName: json['medicine_name'] as String,
      manufacturer: json['manufacturer'] as String?,
      registrationNumber: json['registration_number'] as String?,
      barcode: json['barcode'] as String?,
      batchNumber: json['batch_number'] as String?,
      expiryDate: json['expiry_date'] as String?,
      overallVerdict: json['overall_verdict'] as String,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      agentResults: (json['agent_results'] as List<dynamic>?)
              ?.map((e) => AgentResultModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      scanLatitude: (json['scan_latitude'] as num?)?.toDouble(),
      scanLongitude: (json['scan_longitude'] as num?)?.toDouble(),
      recallAlertSent: json['recall_alert_sent'] as bool? ?? false,
      riskScore: (json['risk_score'] as num?)?.toInt() ?? 0,
      riskLevel: json['risk_level'] as String? ?? 'UNKNOWN',
      safetyAlerts: (json['safety_alerts'] as List<dynamic>?) ?? const [],
      recommendationsList: (json['recommendations'] as List<dynamic>?)?.cast<String>() ?? const [],
      consumerMessage: json['consumer_message'] as String? ?? '',
      verdictSummary: json['verdict_summary'] as String? ?? '',
      genericAlternative: json['generic_alternative'] as String?,
      genericPrice: json['generic_price'] as String?,
      labelMrp: json['label_mrp'] as String?,
      verifiedMrp: json['verified_mrp'] as String?,
      isAntibiotic: json['is_antibiotic'] as bool?,
      awareClassification: json['aware_classification'] as String?,
      stewardshipMessage: json['stewardship_message'] as String?,
      sideEffects: (json['side_effects'] as List<dynamic>?)?.cast<String>() ?? const [],
      halalStatus: json['halal_status'] as String?,
      halalReason: json['halal_reason'] as String?,
    );
  }

  /// Create from backend crew_config response (different key format)
  factory ScanResultModel.fromBackendJson(Map<String, dynamic> json) {
    final agentResults = <AgentResultModel>[];
    final agentData = json['agent_results'] as Map<String, dynamic>? ?? {};
    for (final entry in agentData.entries) {
      try {
        agentResults.add(AgentResultModel.fromJson(entry.value as Map<String, dynamic>));
      } catch (_) {}
    }

    final agent1 = agentData['agent_1'] as Map<String, dynamic>?;
    final extracted = agent1?['extracted_data'] as Map<String, dynamic>?;

    final agent5 = agentData['agent_5'] as Map<String, dynamic>?;
    final agent7 = agentData['agent_7'] as Map<String, dynamic>?;

    return ScanResultModel(
      id: 'sc_${DateTime.now().millisecondsSinceEpoch}',
      userId: json['user_id'] as String? ?? '',
      scanTimestamp: DateTime.now(),
      medicineName: extracted?['brand_name'] as String? ?? 'Unknown Medicine',
      manufacturer: extracted?['manufacturer'] as String?,
      registrationNumber: extracted?['registration_number'] as String?,
      batchNumber: extracted?['batch_number'] as String?,
      expiryDate: extracted?['expiry_date'] as String?,
      overallVerdict: json['overall_verdict'] as String? ?? 'UNVERIFIED',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      agentResults: agentResults,
      riskScore: (json['risk_score'] as num?)?.toInt() ?? 0,
      riskLevel: json['risk_level'] as String? ?? 'UNKNOWN',
      safetyAlerts: (json['safety_alerts'] as List<dynamic>?) ?? const [],
      recommendationsList: (json['recommendations'] as List<dynamic>?)?.cast<String>() ?? const [],
      consumerMessage: json['consumer_message'] as String? ?? '',
      verdictSummary: json['verdict_summary'] as String? ?? '',
      isAntibiotic: agent7?['is_antibiotic'] as bool?,
      awareClassification: agent7?['aware_classification'] as String?,
      stewardshipMessage: agent7?['stewardship_message'] as String?,
      labelMrp: agent5?['label_mrp'] as String?,
      verifiedMrp: agent5?['verified_mrp'] as String?,
      genericAlternative: agent5?['generic_alternative'] as String?,
      genericPrice: agent5?['generic_price'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'scan_timestamp': scanTimestamp.toIso8601String(),
      'medicine_name': medicineName,
      'manufacturer': manufacturer,
      'registration_number': registrationNumber,
      'barcode': barcode,
      'batch_number': batchNumber,
      'expiry_date': expiryDate,
      'overall_verdict': overallVerdict,
      'confidence_score': confidenceScore,
      'agent_results': agentResults.map((e) => e.toJson()).toList(),
      'scan_latitude': scanLatitude,
      'scan_longitude': scanLongitude,
      'recall_alert_sent': recallAlertSent,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'safety_alerts': safetyAlerts,
      'recommendations': recommendationsList,
      'consumer_message': consumerMessage,
      'verdict_summary': verdictSummary,
      'side_effects': sideEffects,
      'halal_status': halalStatus,
      'halal_reason': halalReason,
    };
  }

  bool get isVerified => overallVerdict == 'VERIFIED';
  bool get isDanger => overallVerdict == 'DANGER';
  bool get isUnverified => overallVerdict == 'UNVERIFIED';

  @override
  List<Object?> get props => [id, overallVerdict];
}
