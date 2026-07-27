import '../models/cabinet_item.dart';
import '../models/recall_alert_model.dart';

/// How a recall matched a medicine in the user's cabinet, strongest first.
enum RecallMatchType { registration, batch, name }

/// One cabinet medicine that a DRAP recall applies to.
class RecallMatch {
  final RecallAlertModel recall;
  final CabinetItem item;
  final RecallMatchType type;

  const RecallMatch({
    required this.recall,
    required this.item,
    required this.type,
  });

  bool get isExactBatch => type == RecallMatchType.batch;
}

/// Pure cross-check between the user's scanned medicines and active recalls.
///
/// Kept free of Flutter/IO so it can be unit-tested directly. Matching is
/// intentionally conservative: a shared brand token OR an equal registration
/// number, with a batch hit upgraded to the strongest signal.
class RecallMatcher {
  const RecallMatcher._();

  /// Returns one [RecallMatch] per (cabinet item × recall) hit. A single recall
  /// can match multiple cabinet packs; a single pack can hit multiple recalls.
  static List<RecallMatch> match(
    List<CabinetItem> cabinet,
    List<RecallAlertModel> recalls,
  ) {
    final matches = <RecallMatch>[];

    for (final recall in recalls) {
      if (!recall.isActive) continue;
      for (final item in cabinet) {
        final type = _matchType(item, recall);
        if (type != null) {
          matches.add(RecallMatch(recall: recall, item: item, type: type));
        }
      }
    }
    return matches;
  }

  static RecallMatchType? _matchType(
    CabinetItem item,
    RecallAlertModel recall,
  ) {
    final nameHit = _brandToken(item.name) == _brandToken(recall.medicineName) &&
        _brandToken(item.name).isNotEmpty;
    final regHit = _regEquals(item.registrationNumber, recall.registrationNumber);

    // Not the same medicine at all → no match.
    if (!nameHit && !regHit) return null;

    // Same medicine AND the recall names this exact batch → strongest signal.
    if (_batchHit(item.batchNumber, recall.batchNumbers)) {
      return RecallMatchType.batch;
    }
    if (regHit) return RecallMatchType.registration;
    return RecallMatchType.name;
  }

  // ── Normalisation helpers ──

  /// First meaningful word of a brand name, lowercased and stripped of
  /// punctuation. "STAT-A 40mg (Atorvastatin)" → "stata";
  /// "SeaCal Bone Strength" → "seacal".
  static String _brandToken(String name) {
    var head = name;
    final paren = head.indexOf('(');
    if (paren > 0) head = head.substring(0, paren);
    final word = head.trim().split(RegExp(r'\s+')).first;
    final token = word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return token.length >= 3 ? token : '';
  }

  /// DRAP registration numbers vary ("013121280002", "0017-0018",
  /// "DRAP Enlist 00770012"). Strip to alphanumerics; require length and a
  /// digit so placeholders ("verify", "NOT FOUND") never match.
  static String _normReg(String? reg) {
    if (reg == null) return '';
    final norm = reg.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (norm.length < 5) return '';
    if (!RegExp(r'[0-9]').hasMatch(norm)) return '';
    return norm;
  }

  static bool _regEquals(String? a, String? b) {
    final na = _normReg(a);
    final nb = _normReg(b);
    return na.isNotEmpty && na == nb;
  }

  static bool _batchHit(String? batch, List<String> recallBatches) {
    if (batch == null || recallBatches.isEmpty) return false;
    final b = batch.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (b.isEmpty || b == 'VERIFY' || b == 'SUSPECT') return false;
    for (final rb in recallBatches) {
      final norm = rb.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      if (norm.isNotEmpty && norm == b) return true;
    }
    return false;
  }
}
