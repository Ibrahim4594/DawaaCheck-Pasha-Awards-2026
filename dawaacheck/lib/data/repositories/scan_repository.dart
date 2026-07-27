import 'dart:typed_data';
import '../datasources/remote/api_service.dart';
import '../datasources/remote/supabase_service.dart';
import '../models/scan_result_model.dart';
import '../../core/utils/helpers.dart';

/// Repository for medicine scanning and verification
class ScanRepository {
  final ApiService _api = ApiService();
  final SupabaseService _supabase = SupabaseService();

  /// Send 3 images to backend for AI verification (non-streaming, works on web)
  Future<Map<String, dynamic>> verifyMedicine({
    required Uint8List frontImage,
    required Uint8List backImage,
    required Uint8List ingredientsImage,
    required String userId,
    String patientType = 'adult',
    int? childAge,
    double? childWeight,
    List<String>? currentMedicines,
  }) {
    return _api.scanVerifyJson(
      frontImage: Helpers.bytesToBase64(frontImage),
      backImage: Helpers.bytesToBase64(backImage),
      ingredientsImage: Helpers.bytesToBase64(ingredientsImage),
      userId: userId,
      patientType: patientType,
      childAge: childAge,
      childWeight: childWeight,
      currentMedicines: currentMedicines,
    );
  }

  /// Send 3 images to backend for AI verification (SSE streaming, mobile only)
  Stream<Map<String, dynamic>> verifyMedicineStream({
    required Uint8List frontImage,
    required Uint8List backImage,
    required Uint8List ingredientsImage,
    required String userId,
    String patientType = 'adult',
    int? childAge,
    double? childWeight,
    List<String>? currentMedicines,
  }) {
    return _api.scanVerify(
      frontImage: Helpers.bytesToBase64(frontImage),
      backImage: Helpers.bytesToBase64(backImage),
      ingredientsImage: Helpers.bytesToBase64(ingredientsImage),
      userId: userId,
      patientType: patientType,
      childAge: childAge,
      childWeight: childWeight,
      currentMedicines: currentMedicines,
    );
  }

  /// Save scan result to Supabase
  Future<void> saveScanResult(ScanResultModel result) async {
    await _supabase.saveScanResult(result);
  }

  /// Get scan history
  Future<List<ScanResultModel>> getHistory(String userId) async {
    return _supabase.getScanHistory(userId);
  }

  /// Delete a scan from history
  Future<void> deleteScan(String scanId) async {
    await _supabase.deleteScanResult(scanId);
  }
}
