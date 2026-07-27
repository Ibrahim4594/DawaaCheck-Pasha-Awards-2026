import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/recall_alert_model.dart';
import '../../data/repositories/recall_repository.dart';
import '../../data/services/medicine_cabinet_service.dart';
import '../../data/services/recall_matcher.dart';

final recallRepositoryProvider = Provider<RecallRepository>((ref) => RecallRepository());

final recallProvider = StateNotifierProvider<RecallNotifier, AsyncValue<List<RecallAlertModel>>>((ref) {
  final notifier = RecallNotifier(ref.watch(recallRepositoryProvider));
  notifier.loadRecalls();
  return notifier;
});

/// Recalls that match a medicine the user has scanned — the "your medicines"
/// section. Derived from the annotated recall list.
final affectedRecallsProvider = Provider<List<RecallAlertModel>>((ref) {
  final recalls = ref.watch(recallProvider);
  return recalls.maybeWhen(
    data: (list) => list.where((r) => r.userAffected).toList(),
    orElse: () => const [],
  );
});

class RecallNotifier extends StateNotifier<AsyncValue<List<RecallAlertModel>>> {
  final RecallRepository _repo;
  final MedicineCabinetService _cabinet = MedicineCabinetService();

  RecallNotifier(this._repo) : super(const AsyncValue.loading());

  Future<void> loadRecalls() async {
    state = const AsyncValue.loading();
    try {
      final recalls = await _repo.getActiveRecalls();
      final annotated = await _annotateAndAlert(recalls);
      state = AsyncValue.data(annotated);
    } catch (e, s) {
      debugPrint('[Recall] load failed: $e\n$s');
      // No recalls available — show empty (safe) state, not error.
      state = const AsyncValue.data([]);
    }
  }

  /// Cross-check the active recalls against the user's cabinet: flag affected
  /// recalls, sort them to the top, and fire a one-time alert for new hits.
  Future<List<RecallAlertModel>> _annotateAndAlert(
    List<RecallAlertModel> recalls,
  ) async {
    final cabinet = await _cabinet.getAll();
    if (cabinet.isEmpty) return recalls;

    final matches = RecallMatcher.match(cabinet, recalls);
    if (matches.isEmpty) return recalls;

    // Best match per recall (prefer an exact-batch hit, then most recent scan).
    final bestByRecall = <String, RecallMatch>{};
    for (final m in matches) {
      final existing = bestByRecall[m.recall.id];
      if (existing == null ||
          (m.isExactBatch && !existing.isExactBatch) ||
          m.item.scannedAt.isAfter(existing.item.scannedAt)) {
        bestByRecall[m.recall.id] = m;
      }
    }

    // Annotate the affected recalls in place.
    final annotated = recalls.map((r) {
      final m = bestByRecall[r.id];
      if (m == null) return r;
      return r.copyWith(
        userAffected: true,
        scannedOn: m.item.scannedAt,
        scannedVerdict: m.item.verdict,
        exactBatchMatch: m.isExactBatch,
      );
    }).toList()
      // Affected first, then by recall date.
      ..sort((a, b) {
        if (a.userAffected != b.userAffected) {
          return a.userAffected ? -1 : 1;
        }
        return b.recallDate.compareTo(a.recallDate);
      });

    await _fireNewAlerts(bestByRecall);
    return annotated;
  }

  /// Notify once per newly-matched recall, then remember it so we don't nag.
  Future<void> _fireNewAlerts(Map<String, RecallMatch> bestByRecall) async {
    final notified = await _cabinet.notifiedRecallIds();
    final fresh = bestByRecall.entries
        .where((e) => !notified.contains(e.key))
        .toList();
    if (fresh.isEmpty) return;

    for (final entry in fresh) {
      final m = entry.value;
      try {
        await NotificationService().showProactiveRecallNotification(
          medicineName: m.recall.medicineName,
          reason: m.recall.recallReason,
          exactBatch: m.isExactBatch,
        );
      } catch (e) {
        debugPrint('[Recall] alert skipped: $e');
      }
    }
    await _cabinet.markNotified(fresh.map((e) => e.key));
  }

  Future<void> refresh() => loadRecalls();
}
