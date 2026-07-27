import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/scan_result_model.dart';
import '../../models/recall_alert_model.dart';
import '../../models/adr_report_model.dart';

/// Production Supabase database service for DawaaCheck.
/// Queries all drug data tables in Supabase free tier.
class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  // -------------------------------------------------------------------------
  // Users
  // -------------------------------------------------------------------------

  Future<void> upsertUser(Map<String, dynamic> userData) async {
    try {
      await _client.from('users').upsert(userData);
    } catch (_) {
      // Silently fail — guest/anonymous users may not have write access
    }
  }

  Future<void> updateDeviceToken(String userId, String token) async {
    await _client
        .from('users')
        .update({'device_token': token})
        .eq('id', userId);
  }

  // -------------------------------------------------------------------------
  // Scan Results
  // -------------------------------------------------------------------------

  Future<void> saveScanResult(ScanResultModel result) async {
    try {
      await _client.from('scan_results').insert(result.toJson());
    } catch (_) {
      // RLS may deny for anonymous users — fail gracefully
    }
  }

  Future<List<ScanResultModel>> getScanHistory(String userId) async {
    try {
      final response = await _client
          .from('scan_results')
          .select()
          .eq('user_id', userId)
          .order('scan_timestamp', ascending: false);

      return response
          .map((e) => ScanResultModel.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteScanResult(String scanId) async {
    try {
      await _client.from('scan_results').delete().eq('id', scanId);
    } catch (_) {
      // Fail gracefully
    }
  }

  // -------------------------------------------------------------------------
  // Medicines Search (Full-text + ilike fallback)
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchMedicines(
    String query, {
    int limit = 20,
    String? category,
  }) async {
    var q = _client.from('drap_medicines').select();

    // Try or_ filter across multiple columns
    q = q.or(
      'brand_name.ilike.%$query%,generic_name.ilike.%$query%,manufacturer.ilike.%$query%',
    );

    if (category != null) {
      q = q.eq('category', category);
    }

    final response = await q.limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  // -------------------------------------------------------------------------
  // Medicine Detail (full info with joins)
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getMedicineByRegNumber(
    String registrationNumber,
  ) async {
    final response = await _client
        .from('drap_medicines')
        .select()
        .eq('registration_number', registrationNumber)
        .limit(1);

    if (response.isEmpty) return null;
    return response[0];
  }

  Future<Map<String, dynamic>?> getGenericDrugInfo(String genericName) async {
    final query = genericName.split('+').first.trim();
    final response = await _client
        .from('generic_drugs')
        .select()
        .ilike('generic_name', '%$query%')
        .limit(1);

    if (response.isEmpty) return null;
    return response[0];
  }

  // -------------------------------------------------------------------------
  // Drug Interactions
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getDrugInteractions(
    String drugName,
  ) async {
    final respA = await _client
        .from('drug_interactions')
        .select()
        .ilike('drug_a', '%$drugName%');

    final respB = await _client
        .from('drug_interactions')
        .select()
        .ilike('drug_b', '%$drugName%');

    final seen = <String>{};
    final results = <Map<String, dynamic>>[];
    for (final item in [...respA, ...respB]) {
      final key = '${item['drug_a']}|${item['drug_b']}';
      if (!seen.contains(key)) {
        seen.add(key);
        results.add(item);
      }
    }
    return results;
  }

  Future<Map<String, dynamic>?> checkInteractionPair(
    String drugA,
    String drugB,
  ) async {
    final response = await _client
        .from('drug_interactions')
        .select()
        .or(
          'and(drug_a.ilike.%$drugA%,drug_b.ilike.%$drugB%),and(drug_a.ilike.%$drugB%,drug_b.ilike.%$drugA%)',
        )
        .limit(1);

    if (response.isEmpty) return null;
    return response[0];
  }

  // -------------------------------------------------------------------------
  // Side Effects
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getDrugSideEffects(String drugName) async {
    final response = await _client
        .from('drug_side_effects')
        .select()
        .ilike('drug_name', '%$drugName%')
        .limit(1);

    if (response.isEmpty) return null;
    return response[0];
  }

  // -------------------------------------------------------------------------
  // WHO AWaRe Antibiotic Classification
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getWhoAwareClassification(
    String drugName,
  ) async {
    final response = await _client
        .from('who_aware_antibiotics')
        .select()
        .ilike('name', '%$drugName%')
        .limit(1);

    if (response.isEmpty) return null;
    return response[0];
  }

  // -------------------------------------------------------------------------
  // Pediatric Safety
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getPediatricSafety(
    String drugName,
  ) async {
    final response = await _client
        .from('pediatric_safety')
        .select()
        .ilike('drug_name', '%$drugName%');

    return List<Map<String, dynamic>>.from(response);
  }

  // -------------------------------------------------------------------------
  // Price & Generic Alternatives
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getPriceInfo(String brandName) async {
    final query = brandName.split(' ').first;
    final response = await _client
        .from('medicine_prices')
        .select()
        .ilike('brand_name', '%$query%')
        .limit(1);

    if (response.isEmpty) return null;
    return response[0];
  }

  // -------------------------------------------------------------------------
  // Medicine Images
  // -------------------------------------------------------------------------

  Future<String?> getMedicineImageUrl(String drugName) async {
    final query = drugName.split('+').first.trim().split(' ').first;
    final response = await _client
        .from('medicine_images')
        .select('image_url')
        .ilike('drug_name', '%$query%')
        .limit(1);

    if (response.isEmpty) return null;
    return response[0]['image_url'] as String?;
  }

  // -------------------------------------------------------------------------
  // Treatment Guidelines by Condition
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAllConditions() async {
    final response =
        await _client.from('drug_conditions').select('condition_name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getConditionGuidelines(
    String conditionName,
  ) async {
    final response = await _client
        .from('drug_conditions')
        .select()
        .ilike('condition_name', '%$conditionName%')
        .limit(1);

    if (response.isEmpty) return null;
    return response[0];
  }

  // -------------------------------------------------------------------------
  // Recalls
  // -------------------------------------------------------------------------

  Future<List<RecallAlertModel>> getActiveRecalls() async {
    try {
      final response = await _client
          .from('drap_recalls')
          .select()
          .eq('is_active', true)
          .order('recall_date', ascending: false);

      return response
          .map((e) => RecallAlertModel.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> checkRecallStatus(String medicineName) async {
    final response = await _client
        .from('drap_recalls')
        .select('id')
        .eq('is_active', true)
        .ilike('medicine_name', '%$medicineName%')
        .limit(1);

    return response.isNotEmpty;
  }

  // -------------------------------------------------------------------------
  // ADR Reports
  // -------------------------------------------------------------------------

  Future<void> submitAdrReport(AdrReportModel report) async {
    try {
      await _client.from('adr_reports').insert(report.toJson());
    } catch (_) {
      rethrow; // ADR reports should surface errors to user
    }
  }

  // -------------------------------------------------------------------------
  // Heatmap
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getHeatmapData() async {
    final response = await _client.from('safety_heatmap').select();
    return List<Map<String, dynamic>>.from(response);
  }

  // -------------------------------------------------------------------------
  // Manufacturer Info
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getManufacturerInfo(String name) async {
    final response = await _client
        .from('manufacturers')
        .select()
        .ilike('name', '%$name%')
        .limit(1);

    if (response.isEmpty) return null;
    return response[0];
  }

  // -------------------------------------------------------------------------
  // Database Stats (for debug/about screen)
  // -------------------------------------------------------------------------

  Future<Map<String, int>> getDatabaseStats() async {
    final tables = [
      'drap_medicines',
      'generic_drugs',
      'drug_interactions',
      'drug_side_effects',
      'who_aware_antibiotics',
      'pediatric_safety',
      'medicine_prices',
      'drap_recalls',
    ];

    final stats = <String, int>{};
    int total = 0;

    for (final table in tables) {
      try {
        final response =
            await _client.from(table).select('id').count(CountOption.exact);
        final count = response.count;
        stats[table] = count;
        total += count;
      } catch (_) {
        stats[table] = 0;
      }
    }
    stats['total'] = total;
    return stats;
  }
}
