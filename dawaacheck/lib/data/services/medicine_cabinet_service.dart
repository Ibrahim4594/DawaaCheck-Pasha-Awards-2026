import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cabinet_item.dart';
import '../models/scan_result_model.dart';

/// Local, on-device store of every medicine the user has scanned.
///
/// This powers proactive recalls: when DRAP later recalls a medicine the user
/// already has, DawaaCheck can match it against this cabinet and warn them.
/// Nothing here leaves the device — it lives in [SharedPreferences].
class MedicineCabinetService {
  static final MedicineCabinetService _instance =
      MedicineCabinetService._();
  factory MedicineCabinetService() => _instance;
  MedicineCabinetService._();

  static const _cabinetKey = 'medicine_cabinet';
  static const _notifiedKey = 'recall_notified_ids';
  static const _maxItems = 100;

  // ───────────────────────────────────────────────────────────────────────
  // Cabinet contents
  // ───────────────────────────────────────────────────────────────────────

  Future<List<CabinetItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cabinetKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CabinetItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException catch (e) {
      debugPrint('[Cabinet] parse failed: $e');
      return const [];
    }
  }

  /// Remember a scanned medicine. De-dupes on brand + batch so re-scanning the
  /// same pack refreshes rather than piling up.
  Future<void> add(ScanResultModel scan) async {
    final item = CabinetItem.fromScan(scan);
    final prefs = await SharedPreferences.getInstance();
    final items = await getAll();

    final key = _dedupeKey(item.name, item.batchNumber);
    items.removeWhere(
      (e) => _dedupeKey(e.name, e.batchNumber) == key,
    );
    items.insert(0, item);

    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }
    await _save(prefs, items);
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getAll()
      ..removeWhere((e) => e.id == id);
    await _save(prefs, items);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cabinetKey);
    await prefs.remove(_notifiedKey);
  }

  Future<void> _save(SharedPreferences prefs, List<CabinetItem> items) async {
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_cabinetKey, raw);
  }

  String _dedupeKey(String name, String? batch) {
    final n = name.toLowerCase().trim();
    final b = (batch ?? '').toLowerCase().trim();
    return '$n|$b';
  }

  // ───────────────────────────────────────────────────────────────────────
  // Notified-recall tracking (so each recall alerts the user only once)
  // ───────────────────────────────────────────────────────────────────────

  Future<Set<String>> notifiedRecallIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_notifiedKey) ?? const []).toSet();
  }

  Future<void> markNotified(Iterable<String> recallIds) async {
    if (recallIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_notifiedKey) ?? const []).toSet()
      ..addAll(recallIds);
    await prefs.setStringList(_notifiedKey, current.toList());
  }
}
