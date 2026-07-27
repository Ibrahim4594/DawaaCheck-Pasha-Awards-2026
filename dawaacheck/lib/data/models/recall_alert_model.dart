import 'package:equatable/equatable.dart';

class RecallAlertModel extends Equatable {
  final String id;
  final String recallClass; // CLASS_I or CLASS_II
  final String medicineName;
  final String? registrationNumber;
  final List<String> batchNumbers;
  final String recallReason;
  final DateTime recallDate;
  final String? drapNoticeNumber;
  final bool isActive;
  final bool userAffected;

  // ── Proactive-recall annotations (set when this recall matches a medicine
  //    the user has scanned; not persisted to Supabase) ──
  final DateTime? scannedOn;
  final String? scannedVerdict;
  final bool exactBatchMatch;

  const RecallAlertModel({
    required this.id,
    required this.recallClass,
    required this.medicineName,
    this.registrationNumber,
    this.batchNumbers = const [],
    required this.recallReason,
    required this.recallDate,
    this.drapNoticeNumber,
    this.isActive = true,
    this.userAffected = false,
    this.scannedOn,
    this.scannedVerdict,
    this.exactBatchMatch = false,
  });

  factory RecallAlertModel.fromJson(Map<String, dynamic> json) {
    return RecallAlertModel(
      id: json['id']?.toString() ?? '',
      recallClass: json['recall_class'] as String,
      medicineName: json['medicine_name'] as String,
      registrationNumber: json['registration_number'] as String?,
      batchNumbers: (json['batch_numbers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recallReason: json['recall_reason'] as String,
      recallDate: DateTime.parse(json['recall_date'] as String),
      drapNoticeNumber: json['drap_notice_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      userAffected: json['user_affected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recall_class': recallClass,
      'medicine_name': medicineName,
      'registration_number': registrationNumber,
      'batch_numbers': batchNumbers,
      'recall_reason': recallReason,
      'recall_date': recallDate.toIso8601String(),
      'drap_notice_number': drapNoticeNumber,
      'is_active': isActive,
    };
  }

  RecallAlertModel copyWith({
    bool? userAffected,
    DateTime? scannedOn,
    String? scannedVerdict,
    bool? exactBatchMatch,
  }) {
    return RecallAlertModel(
      id: id,
      recallClass: recallClass,
      medicineName: medicineName,
      registrationNumber: registrationNumber,
      batchNumbers: batchNumbers,
      recallReason: recallReason,
      recallDate: recallDate,
      drapNoticeNumber: drapNoticeNumber,
      isActive: isActive,
      userAffected: userAffected ?? this.userAffected,
      scannedOn: scannedOn ?? this.scannedOn,
      scannedVerdict: scannedVerdict ?? this.scannedVerdict,
      exactBatchMatch: exactBatchMatch ?? this.exactBatchMatch,
    );
  }

  bool get isClassI => recallClass == 'CLASS_I';
  bool get isClassII => recallClass == 'CLASS_II';

  @override
  List<Object?> get props => [id, recallClass, medicineName];
}
