import 'package:hive_flutter/hive_flutter.dart';
import '../../models/medicine_model.dart';
import '../../models/scan_result_model.dart';

/// Local cache using Hive for offline access
class CacheService {
  static const String _medicinesBox = 'medicines_cache';
  static const String _historyBox = 'scan_history_cache';
  static const String _recallsBox = 'recalls_cache';
  static const String _settingsBox = 'settings';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(_medicinesBox);
    await Hive.openBox<Map>(_historyBox);
    await Hive.openBox<Map>(_recallsBox);
    await Hive.openBox(_settingsBox);
  }

  // --- Settings ---
  Box get _settings => Hive.box(_settingsBox);

  bool get hasCompletedOnboarding => _settings.get('onboarding_complete', defaultValue: false);
  Future<void> setOnboardingComplete() => _settings.put('onboarding_complete', true);

  // --- Medicines Cache (5000 common) ---
  Box<Map> get _medicines => Hive.box<Map>(_medicinesBox);

  Future<void> cacheMedicines(List<MedicineModel> medicines) async {
    final entries = <String, Map>{};
    for (final m in medicines) {
      entries[m.registrationNumber] = m.toJson();
    }
    await _medicines.putAll(entries);
  }

  List<MedicineModel> searchCachedMedicines(String query) {
    final q = query.toLowerCase();
    return _medicines.values
        .where((m) =>
            (m['brand_name'] as String?)?.toLowerCase().contains(q) == true ||
            (m['generic_name'] as String?)?.toLowerCase().contains(q) == true)
        .take(20)
        .map((m) => MedicineModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // --- History Cache ---
  Box<Map> get _history => Hive.box<Map>(_historyBox);

  Future<void> cacheHistory(List<ScanResultModel> results) async {
    await _history.clear();
    for (final r in results) {
      await _history.put(r.id, r.toJson());
    }
  }

  List<ScanResultModel> getCachedHistory() {
    return _history.values
        .map((m) => ScanResultModel.fromJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.scanTimestamp.compareTo(a.scanTimestamp));
  }

  Future<void> clearAll() async {
    await _medicines.clear();
    await _history.clear();
    await Hive.box<Map>(_recallsBox).clear();
  }
}
