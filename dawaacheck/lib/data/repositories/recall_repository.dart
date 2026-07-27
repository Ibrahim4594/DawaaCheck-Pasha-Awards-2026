import '../datasources/local/recall_seed_data.dart';
import '../datasources/remote/supabase_service.dart';
import '../models/recall_alert_model.dart';

/// Repository for DRAP recall alerts.
///
/// Merges the live Supabase `drap_recalls` feed with a local seed set so the
/// tab is never empty offline and the proactive-recall demo always works.
class RecallRepository {
  final SupabaseService _supabase = SupabaseService();

  Future<List<RecallAlertModel>> getActiveRecalls() async {
    final remote = await _supabase.getActiveRecalls();
    final seed = RecallSeedData.all();

    // Remote wins on id collisions; otherwise append seeds.
    final byId = <String, RecallAlertModel>{
      for (final s in seed) s.id: s,
      for (final r in remote) r.id: r,
    };

    final merged = byId.values.where((r) => r.isActive).toList()
      ..sort((a, b) => b.recallDate.compareTo(a.recallDate));
    return merged;
  }
}
