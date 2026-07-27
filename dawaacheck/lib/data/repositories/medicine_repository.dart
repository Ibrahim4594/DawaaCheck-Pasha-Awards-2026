import '../datasources/remote/api_service.dart';
import '../datasources/remote/supabase_service.dart';
import '../datasources/local/cache_service.dart';
import '../models/medicine_model.dart';

/// Repository for medicine data — queries Supabase directly for speed,
/// falls back to backend API or local cache when offline.
class MedicineRepository {
  final ApiService _api;
  final SupabaseService _supabase;
  final CacheService _cache;

  MedicineRepository({
    required ApiService api,
    required SupabaseService supabase,
    required CacheService cache,
  })  : _api = api,
        _supabase = supabase,
        _cache = cache;

  /// Search medicines — Supabase direct, falls back to API, then cache.
  Future<List<MedicineModel>> search(String query) async {
    try {
      final results = await _supabase.searchMedicines(query);
      return results.map((e) => MedicineModel.fromJson(e)).toList();
    } catch (_) {
      try {
        final apiResult = await _api.searchMedicines(query);
        final list = apiResult['results'] as List? ?? [];
        return list
            .map((e) => MedicineModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return _cache.searchCachedMedicines(query);
      }
    }
  }

  /// Get full medicine details including generic info, side effects, price.
  Future<Map<String, dynamic>?> getMedicineDetail(
    String registrationNumber,
  ) async {
    try {
      return await _api.getMedicineDetail(registrationNumber);
    } catch (_) {
      return _supabase.getMedicineByRegNumber(registrationNumber);
    }
  }

  /// Get drug interactions for a medicine.
  Future<List<Map<String, dynamic>>> getInteractions(String drugName) async {
    return _supabase.getDrugInteractions(drugName);
  }

  /// Check interaction between two specific drugs.
  Future<Map<String, dynamic>?> checkInteractionPair(
    String drugA,
    String drugB,
  ) async {
    return _supabase.checkInteractionPair(drugA, drugB);
  }

  /// Get side effects for a drug.
  Future<Map<String, dynamic>?> getSideEffects(String drugName) async {
    return _supabase.getDrugSideEffects(drugName);
  }

  /// Get WHO AWaRe classification.
  Future<Map<String, dynamic>?> getWhoAwareClassification(
    String drugName,
  ) async {
    return _supabase.getWhoAwareClassification(drugName);
  }

  /// Get pediatric safety info.
  Future<List<Map<String, dynamic>>> getPediatricSafety(
    String drugName,
  ) async {
    return _supabase.getPediatricSafety(drugName);
  }

  /// Get generic alternatives with price comparison.
  Future<Map<String, dynamic>?> getGenericAlternatives(
    String brandName,
  ) async {
    return _supabase.getPriceInfo(brandName);
  }

  /// Get generic drug clinical info.
  Future<Map<String, dynamic>?> getGenericInfo(String genericName) async {
    return _supabase.getGenericDrugInfo(genericName);
  }

  /// Get medicine image URL.
  Future<String?> getMedicineImage(String drugName) async {
    return _supabase.getMedicineImageUrl(drugName);
  }

  /// Check if medicine has active recalls.
  Future<bool> hasActiveRecall(String medicineName) async {
    return _supabase.checkRecallStatus(medicineName);
  }

  /// Get manufacturer info.
  Future<Map<String, dynamic>?> getManufacturerInfo(String name) async {
    return _supabase.getManufacturerInfo(name);
  }

  /// Get database stats.
  Future<Map<String, int>> getDatabaseStats() async {
    return _supabase.getDatabaseStats();
  }
}
