import 'package:equatable/equatable.dart';
import 'scan_result_model.dart';

/// A medicine the user has scanned, remembered locally so DawaaCheck can warn
/// them if DRAP recalls it later. This is the user's "medicine cabinet".
class CabinetItem extends Equatable {
  final String id;
  final String name;
  final String? registrationNumber;
  final String? batchNumber;
  final String? manufacturer;
  final String verdict; // VERIFIED / UNVERIFIED / DANGER
  final DateTime scannedAt;

  const CabinetItem({
    required this.id,
    required this.name,
    this.registrationNumber,
    this.batchNumber,
    this.manufacturer,
    required this.verdict,
    required this.scannedAt,
  });

  factory CabinetItem.fromScan(ScanResultModel scan) {
    return CabinetItem(
      id: scan.id,
      name: scan.medicineName,
      registrationNumber: scan.registrationNumber,
      batchNumber: scan.batchNumber,
      manufacturer: scan.manufacturer,
      verdict: scan.overallVerdict,
      scannedAt: scan.scanTimestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'registration_number': registrationNumber,
        'batch_number': batchNumber,
        'manufacturer': manufacturer,
        'verdict': verdict,
        'scanned_at': scannedAt.toIso8601String(),
      };

  factory CabinetItem.fromJson(Map<String, dynamic> json) => CabinetItem(
        id: json['id'] as String,
        name: json['name'] as String,
        registrationNumber: json['registration_number'] as String?,
        batchNumber: json['batch_number'] as String?,
        manufacturer: json['manufacturer'] as String?,
        verdict: json['verdict'] as String? ?? 'UNVERIFIED',
        scannedAt: DateTime.parse(json['scanned_at'] as String),
      );

  @override
  List<Object?> get props => [id, name, batchNumber];
}
