import '../../models/recall_alert_model.dart';

/// Local DRAP recall feed — REAL alerts.
///
/// These are actual DRAP / WHO recall alerts issued in June–July 2026, used as
/// a local fallback so the Recalls tab stays populated when the live Supabase
/// `drap_recalls` table is asleep. Sourced from dra.gov.pk product-recall
/// notices and WHO Medical Product Alert N°2/2026.
///
/// The proactive-recall matcher still works against these: if a user scans a
/// medicine that appears here (e.g. an actual recalled batch), it surfaces in
/// the "Your Medicines" section. None of the catalogued packs are currently
/// recalled, so that section only appears for genuine matches — as it should.
///
/// Dates are relative to now so "issued N days ago" always reads sensibly.
class RecallSeedData {
  const RecallSeedData._();

  static List<RecallAlertModel> all() {
    final now = DateTime.now();
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));

    return [
      // ── WHO / DRAP Rapid Alert — falsified anticancer drug (July 2026) ──
      RecallAlertModel(
        id: 'drap-jakavi-2026',
        recallClass: 'CLASS_I',
        medicineName: 'Jakavi (Ruxolitinib) Tablets',
        registrationNumber: null,
        batchNumbers: const [],
        recallReason:
            'Falsified Jakavi identified in circulation. Novartis has confirmed '
            'the batch numbers on the affected packs are NOT genuine. This is an '
            'anticancer medicine — do not use unverified stock. WHO Medical '
            'Product Alert N°2/2026.',
        recallDate: daysAgo(8),
        drapNoticeNumber: 'DRAP Rapid Alert 38',
      ),

      // ── DRAP device recall — BD syringes, infection risk (June 2026) ──
      RecallAlertModel(
        id: 'drap-bd-syringe-2026',
        recallClass: 'CLASS_I',
        medicineName: 'BD 10 mL Syringe',
        registrationNumber: null,
        batchNumbers: const ['5349764'],
        recallReason:
            'DRAP recalled specific syringe batches that could cause serious '
            'infections. Healthcare facilities and pharmacies must stop using '
            'batch 5349764 immediately.',
        recallDate: daysAgo(34),
        drapNoticeNumber: 'DRAP Recall Alert (Device)',
      ),

      // ── DTL Punjab substandard — ZYOCAIN Gel (June 18, 2026, Alert 26) ──
      RecallAlertModel(
        id: 'drap-zyocain-2026',
        recallClass: 'CLASS_II',
        medicineName: 'Zyocain Gel (Lignocaine Hydrochloride)',
        registrationNumber: null,
        batchNumbers: const [],
        recallReason:
            'Sample declared "Substandard" by the Drug Testing Laboratory, '
            'Punjab. The batch failed quality specification and has been '
            'withdrawn from the market.',
        recallDate: daysAgo(36),
        drapNoticeNumber: 'No II/S/03-26-26',
      ),

      // ── DRAP / Punjab — adulterated cough syrup (June 2026) ──
      RecallAlertModel(
        id: 'drap-cestonil-2026',
        recallClass: 'CLASS_I',
        medicineName: 'Cestonil Plus Syrup',
        registrationNumber: null,
        batchNumbers: const [],
        recallReason:
            'DRAP banned the sale and use of affected batches after the Punjab '
            'Drug Testing Laboratory declared them adulterated. Cough syrups are '
            'high-risk for contamination — stop use immediately.',
        recallDate: daysAgo(40),
        drapNoticeNumber: 'DRAP Recall Alert (DTL Punjab)',
      ),

      // ── DTL Punjab substandard — Rolekast (Montelukast) June 2026 ──
      RecallAlertModel(
        id: 'drap-rolekast-2026',
        recallClass: 'CLASS_II',
        medicineName: 'Rolekast 10mg (Montelukast) Tablet',
        registrationNumber: null,
        batchNumbers: const [],
        recallReason:
            'Sample declared "Substandard" by provincial Drug Testing '
            'Laboratories. The affected batch did not meet quality standards and '
            'has been recalled.',
        recallDate: daysAgo(30),
        drapNoticeNumber: 'No II/S/03-26-22',
      ),
    ];
  }
}
