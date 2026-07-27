import 'package:equatable/equatable.dart';

class AdrReportModel extends Equatable {
  final String? id;
  final String userId;
  final String? scanId;
  final String medicineName;
  final String? batchNumber;
  final String reactionDescription;
  final String severity; // MILD, MODERATE, SEVERE, LIFE_THREATENING
  final DateTime reactionDate;
  final String patientAgeGroup;
  final String? meddraTerm;
  final bool isFlagged;

  const AdrReportModel({
    this.id,
    required this.userId,
    this.scanId,
    required this.medicineName,
    this.batchNumber,
    required this.reactionDescription,
    required this.severity,
    required this.reactionDate,
    required this.patientAgeGroup,
    this.meddraTerm,
    this.isFlagged = false,
  });

  factory AdrReportModel.fromJson(Map<String, dynamic> json) {
    return AdrReportModel(
      id: json['id']?.toString(),
      userId: json['user_id'] as String,
      scanId: json['scan_id'] as String?,
      medicineName: json['medicine_name'] as String,
      batchNumber: json['batch_number'] as String?,
      reactionDescription: json['reaction_description'] as String,
      severity: json['severity'] as String,
      reactionDate: DateTime.parse(json['reaction_date'] as String),
      patientAgeGroup: json['patient_age_group'] as String,
      meddraTerm: json['meddra_term'] as String?,
      isFlagged: json['is_flagged'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'scan_id': scanId,
      'medicine_name': medicineName,
      'batch_number': batchNumber,
      'reaction_description': reactionDescription,
      'severity': severity,
      'reaction_date': reactionDate.toIso8601String(),
      'patient_age_group': patientAgeGroup,
    };
  }

  @override
  List<Object?> get props => [id, medicineName, severity];
}
