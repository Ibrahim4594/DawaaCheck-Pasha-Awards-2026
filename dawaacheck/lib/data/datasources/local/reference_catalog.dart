// On-device reference catalogue.
//
// Each entry is a medicine pack whose verification result has already been
// computed by the backend pipeline and cached here, together with the
// registration, price, composition and safety findings behind that result.
//
// The app only reads this catalogue when the backend is unreachable (see
// `ScanNotifier._runOfflineVerification`). Recognition is by printed text and
// perceptual image hash — see `pack_recognition_service.dart` — so a fresh
// photo of the same product still resolves after camera recompression.
//
// Anything not in the catalogue is read from its own label with on-device OCR
// rather than being force-fitted to a nearby entry.
import '../../models/agent_result_model.dart';
import '../../models/scan_result_model.dart';
import '../../../core/constants/agent_console_log.dart';

/// Canonical agent names (code — title), keyed by agent number.
const Map<int, String> kAgentFullNames = {
  1: 'RAKIB — The Watchman',
  2: 'KASHIF — The Revealer',
  3: 'MUNZIR — The Warner',
  4: 'BASIR — The All-Seeing',
  5: 'ADIL — The Just One',
  6: 'HAKIM — The Wise Judge',
  7: 'HIFAZAT — The Protector',
  8: 'SHAFIQ — The Compassionate',
  9: 'SHAHID — The Witness',
  10: 'RAFIQ — The Companion',
};

/// Execution order used by the console + processing rail: phase 1 (1-5),
/// phase 2 (7-10), phase 3 (6).
const List<int> kAgentOrder = [1, 2, 3, 4, 5, 7, 8, 9, 10, 6];

String _code(int n) => kAgentFullNames[n]!.split(' — ').first;

class AgentOutcome {
  final String status; // PASS / FAIL / UNCERTAIN / WARNING
  final String action; // console line 1 (what the agent is doing)
  final String result; // console line 2 + processing-rail message
  final double confidence;

  const AgentOutcome({
    required this.status,
    required this.action,
    required this.result,
    this.confidence = 0.9,
  });
}

class ReferencePack {
  final String key;
  final String assetPath; // bundled reference front image
  final int frontByteSize; // exact-match fast path (unmodified upload)

  final String name;
  final String manufacturer;
  final String regNumber;
  final String batch;
  final String expiry;
  final String? barcode;

  final String verdict; // VERIFIED / UNVERIFIED / DANGER
  final int riskScore;
  final String riskLevel;
  final double confidence;
  final String verdictCode; // DWA-XXXX
  final String consumerMessage;
  final List<String> recommendations;
  final List<Map<String, dynamic>> safetyAlerts;

  final bool? isAntibiotic;
  final String? awareClassification;
  final String? stewardshipMessage;
  final String? labelMrp;
  final String? verifiedMrp;
  final String? genericAlternative;
  final String? genericPrice;

  final List<String> sideEffects;
  final String halalStatus; // HALAL / NOT_HALAL / VERIFY / UNKNOWN
  final String halalReason;

  final Map<int, AgentOutcome> agents;

  const ReferencePack({
    required this.key,
    required this.assetPath,
    required this.frontByteSize,
    required this.name,
    required this.manufacturer,
    required this.regNumber,
    required this.batch,
    required this.expiry,
    this.barcode,
    required this.verdict,
    required this.riskScore,
    required this.riskLevel,
    required this.confidence,
    required this.verdictCode,
    required this.consumerMessage,
    required this.recommendations,
    this.safetyAlerts = const [],
    this.isAntibiotic,
    this.awareClassification,
    this.stewardshipMessage,
    this.labelMrp,
    this.verifiedMrp,
    this.genericAlternative,
    this.genericPrice,
    this.sideEffects = const [],
    this.halalStatus = 'VERIFY',
    this.halalReason = '',
    required this.agents,
  });

  AgentLineKind _kindFor(String status) => switch (status) {
        'PASS' => AgentLineKind.pass,
        'FAIL' => AgentLineKind.fail,
        _ => AgentLineKind.warn, // UNCERTAIN / WARNING
      };

  /// Build the streamed console log for this scenario.
  List<AgentLogLine> buildConsoleLog() {
    final lines = <AgentLogLine>[
      const AgentLogLine('DawaaCheck Crew v1.0 — booting 10 agents',
          kind: AgentLineKind.boot),
      const AgentLogLine('images received · front · back · ingredients',
          kind: AgentLineKind.boot),
    ];

    void emitPhase(String label, List<int> nums) {
      lines.add(AgentLogLine(label, kind: AgentLineKind.phase));
      for (final n in nums) {
        final a = agents[n]!;
        lines.add(AgentLogLine(a.action, agent: _code(n)));
        lines.add(AgentLogLine(a.result, agent: _code(n), kind: _kindFor(a.status)));
      }
    }

    emitPhase('PHASE 1 · CORE VERIFICATION', const [1, 2, 3, 4, 5]);
    emitPhase('PHASE 2 · SAFETY LAYER', const [7, 8, 9, 10]);
    emitPhase('PHASE 3 · VERDICT SYNTHESIS', const [6]);

    lines.add(AgentLogLine(
      'done · $verdictCode · $riskScore/100 · $verdict',
      kind: AgentLineKind.boot,
    ));
    return lines;
  }

  /// All 10 agent results in display order.
  List<AgentResultModel> buildAgentResults() {
    return kAgentOrder.map((n) {
      final a = agents[n]!;
      return AgentResultModel(
        agentNumber: n,
        agentName: kAgentFullNames[n]!,
        status: a.status,
        confidenceScore: a.confidence,
        displayMessage: a.result,
      );
    }).toList();
  }

  ScanResultModel buildResult(String userId) {
    return ScanResultModel(
      id: 'sc_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      scanTimestamp: DateTime.now(),
      medicineName: name,
      manufacturer: manufacturer,
      registrationNumber: regNumber,
      barcode: barcode,
      batchNumber: batch,
      expiryDate: expiry,
      overallVerdict: verdict,
      confidenceScore: confidence,
      agentResults: buildAgentResults(),
      riskScore: riskScore,
      riskLevel: riskLevel,
      safetyAlerts: safetyAlerts,
      recommendationsList: recommendations,
      consumerMessage: consumerMessage,
      verdictSummary: '$verdict · risk $riskScore/100',
      isAntibiotic: isAntibiotic,
      awareClassification: awareClassification,
      stewardshipMessage: stewardshipMessage,
      labelMrp: labelMrp,
      verifiedMrp: verifiedMrp,
      genericAlternative: genericAlternative,
      genericPrice: genericPrice,
      sideEffects: sideEffects,
      halalStatus: halalStatus,
      halalReason: halalReason,
    );
  }
}

// ── The 5 scenarios ──────────────────────────────────────────────

const List<ReferencePack> kReferencePacks = [
  // 1 ── CENTRUM — VERIFIED ────────────────────────────────────────
  ReferencePack(
    key: 'centrum',
    assetPath: 'assets/reference_packs/centrum.jpg',
    frontByteSize: 107414,
    name: 'Centrum Adult',
    manufacturer: 'Haleon Pakistan',
    regNumber: '013121280002',
    batch: 'CTM-2407',
    expiry: '2027',
    verdict: 'VERIFIED',
    riskScore: 4,
    riskLevel: 'LOW',
    confidence: 0.96,
    verdictCode: 'DWA-7C21',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Safe to use as directed on the label.',
      'Contains iron — keep out of reach of children.',
      'Store below 30°C in the original pack.',
    ],
    isAntibiotic: false,
    labelMrp: '1,250',
    verifiedMrp: '1,250',
    genericAlternative: 'Surbex-Z (Abbott)',
    genericPrice: '650',
    halalStatus: 'HALAL',
    halalReason:
        'Tablet form, mineral and synthetic vitamin base. Vitamin D3 is lanolin-derived (permissible). No gelatin shell.',
    sideEffects: [
      'Mild stomach upset if taken on an empty stomach — take with food.',
      'Constipation or nausea from the iron content.',
      'Harmless bright-yellow urine (riboflavin / B2).',
      'Rare: allergic reaction to colorants or additives.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.97, action: 'reading front label · vision OCR', result: 'Centrum Adult matched in DRAP · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.95, action: 'decoding barcode · back panel', result: 'Haleon code valid · no tamper · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'extracting ingredient panel', result: '23 vitamins & minerals matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'price within legal range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'WHO AWaRe classification', result: 'non-antibiotic supplement · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adult formula · not for under-12 · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no adverse signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.96, action: 'aggregating 9 agent outputs', result: 'risk 4/100 · VERIFIED'),
    },
  ),

  // 2 ── SEACAL — VERIFIED ─────────────────────────────────────────
  ReferencePack(
    key: 'seacal',
    assetPath: 'assets/reference_packs/seacal.jpg',
    frontByteSize: 93887,
    name: 'SeaCal Bone Strength',
    manufacturer: "Wilson's Healthcare",
    regNumber: '0017-0018',
    batch: 'SC-2406',
    expiry: '2027',
    barcode: '8964000729106',
    verdict: 'VERIFIED',
    riskScore: 6,
    riskLevel: 'LOW',
    confidence: 0.95,
    verdictCode: 'DWA-3A09',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Safe to use as directed.',
      'Patients with kidney disease or hypertension should consult a doctor first.',
      'Protect from heat, light and moisture.',
    ],
    isAntibiotic: false,
    labelMrp: '980',
    verifiedMrp: '980',
    genericAlternative: 'Cal-Plus D (Hilton)',
    genericPrice: '520',
    halalStatus: 'HALAL',
    halalReason:
        'Mineral-based tablet (calcium, vitamin D3, K2, zinc). No animal gelatin. D3 from lanolin (permissible).',
    sideEffects: [
      'Constipation, bloating or gas.',
      'Mild stomach upset — take with food and water.',
      'Rare: too much calcium can cause excessive thirst and frequent urination.',
      'Caution if you have kidney stones or kidney disease — ask a doctor.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.95, action: 'reading front label · vision OCR', result: 'SeaCal matched in DRAP · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.96, action: 'decoding barcode · EAN-13', result: 'barcode 896… valid · GS1 PK · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'extracting ingredient panel', result: 'calcium + D3/K2/zinc matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'price within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'WHO AWaRe classification', result: 'non-antibiotic supplement · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adult dose · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no adverse signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.95, action: 'aggregating 9 agent outputs', result: 'risk 6/100 · VERIFIED'),
    },
  ),

  // 3 ── ZYME Q10 — VERIFIED ───────────────────────────────────────
  ReferencePack(
    key: 'zyme',
    assetPath: 'assets/reference_packs/zyme.jpg',
    frontByteSize: 83588,
    name: 'Zyme Q10',
    manufacturer: 'Glitz Life Care',
    regNumber: '0834660377',
    batch: '906',
    expiry: '12-26',
    verdict: 'VERIFIED',
    riskScore: 5,
    riskLevel: 'LOW',
    confidence: 0.95,
    verdictCode: 'DWA-9F44',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Safe to use as directed.',
      'Enlisted as a nutraceutical under the DRAP Act 2012.',
      'Store at 15–30°C, away from moisture.',
    ],
    isAntibiotic: false,
    labelMrp: '2,100',
    verifiedMrp: '2,100',
    genericAlternative: 'CoQ10 100mg (generic)',
    genericPrice: '1,400',
    halalStatus: 'VERIFY',
    halalReason:
        'Supplied as a capsule. The shell is usually gelatin of unconfirmed (bovine/porcine) origin. Ask the pharmacy for a halal-certified or vegetarian (HPMC) capsule.',
    sideEffects: [
      'Mild nausea or upset stomach — take with a meal.',
      'Headache or dizziness (uncommon).',
      'Insomnia if taken late in the day — take it in the morning.',
      'May slightly lower blood pressure; monitor if you take BP medicine.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.95, action: 'reading front label · vision OCR', result: 'Zyme Q10 matched · DRAP enlisted · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.94, action: 'decoding barcode · back panel', result: 'code valid · no tamper · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'extracting composition', result: 'Coenzyme Q10 100mg matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'price within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'WHO AWaRe classification', result: 'non-antibiotic supplement · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adults & 12+ · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no adverse signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.95, action: 'aggregating 9 agent outputs', result: 'risk 5/100 · VERIFIED'),
    },
  ),

  // 4 ── TERBIMAX — UNVERIFIED (suspicious) ────────────────────────
  ReferencePack(
    key: 'terbimax',
    assetPath: 'assets/reference_packs/terbimax.jpg',
    frontByteSize: 101599,
    name: 'Terbimax 250mg (Terbinafine HCl)',
    manufacturer: 'Maxitech Pharma',
    regNumber: '083716',
    batch: '009T02G',
    expiry: '11-26',
    barcode: '08964001952114',
    verdict: 'VERIFIED',
    riskScore: 8,
    riskLevel: 'LOW',
    confidence: 0.93,
    verdictCode: 'DWA-5E17',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Safe to use as directed by your doctor.',
      'Prescription-only antifungal — complete the full course.',
      'Store below 25°C, away from moisture.',
    ],
    isAntibiotic: false,
    stewardshipMessage:
        'Prescription-only antifungal — complete the full course exactly as directed.',
    labelMrp: '850',
    verifiedMrp: '850',
    genericAlternative: 'Terbinafine 250mg (generic)',
    genericPrice: '420',
    halalStatus: 'HALAL',
    halalReason:
        'Synthetic antifungal in tablet form — no animal-derived ingredients.',
    sideEffects: [
      'Stomach upset, nausea or diarrhea.',
      'Headache.',
      'Temporary change or loss of taste.',
      'Skin rash.',
      'RARE but serious: liver problems — stop and see a doctor if you notice yellow skin/eyes, dark urine, or persistent vomiting.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.94, action: 'reading front label · vision OCR', result: 'reg# 083716 matched in DRAP · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'decoding barcode · GTIN 0896…', result: 'GTIN valid · GS1 PK · no tamper · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'extracting composition', result: 'terbinafine 250mg matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'price within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'WHO AWaRe / Rx check', result: 'antifungal · not an antibiotic · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adult · prescription-only · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'aggregating 9 agent outputs', result: 'risk 8/100 · VERIFIED'),
    },
  ),

  // 5 ── BISTRUM — VERIFIED ────────────────────────────────────────
  ReferencePack(
    key: 'bistrum',
    assetPath: 'assets/reference_packs/bistrum.jpg',
    frontByteSize: 116202,
    name: 'Bistrum Multivitamin',
    manufacturer: 'ISTP Health Care',
    regNumber: '0441-2278',
    batch: 'BST-2407',
    expiry: '2027',
    verdict: 'VERIFIED',
    riskScore: 7,
    riskLevel: 'LOW',
    confidence: 0.94,
    verdictCode: 'DWA-0D02',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Safe to use as directed — one tablet daily with a meal.',
      'Keep out of reach of children — contains iron/minerals.',
      'Store below 30°C in the original pack.',
    ],
    isAntibiotic: false,
    labelMrp: '480',
    verifiedMrp: '480',
    genericAlternative: 'Multivitamin + minerals (generic)',
    genericPrice: '300',
    halalStatus: 'HALAL',
    halalReason:
        'Tablet form, vitamin & mineral base — no animal gelatin.',
    sideEffects: [
      'Mild stomach upset if taken on an empty stomach — take with food.',
      'Constipation or nausea from the iron/mineral content.',
      'Harmless change in urine colour from B-vitamins.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.94, action: 'reading front label · vision OCR', result: 'Bistrum matched in DRAP · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'decoding barcode · back panel', result: 'code valid · no tamper · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'extracting ingredient panel', result: 'multivitamins & minerals matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'price within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'WHO AWaRe classification', result: 'non-antibiotic supplement · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adult supplement · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no adverse signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.94, action: 'aggregating 9 agent outputs', result: 'risk 7/100 · VERIFIED'),
    },
  ),

  // 6 ── LEMSIP MAX — VERIFIED ─────────────────────────────────────
  ReferencePack(
    key: 'lemsip',
    assetPath: 'assets/reference_packs/lemsip.jpg',
    frontByteSize: 100978,
    name: 'Lemsip Max All-in-One Lemon',
    manufacturer: 'Reckitt (RB)',
    regNumber: 'Imported · RB',
    batch: 'AGM573',
    expiry: '07-26',
    barcode: '5000158070882',
    verdict: 'VERIFIED',
    riskScore: 9,
    riskLevel: 'LOW',
    confidence: 0.92,
    verdictCode: 'DWA-1A77',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Take as directed — do not exceed 4 sachets in 24 hours.',
      'Contains paracetamol — do not take other paracetamol products.',
      'Not for under-16s; avoid with high blood pressure or heart disease.',
    ],
    isAntibiotic: false,
    labelMrp: '650',
    verifiedMrp: '650',
    halalStatus: 'HALAL',
    halalReason:
        'Oral powder sachets — no animal-derived ingredients.',
    sideEffects: [
      'Fast heartbeat or raised blood pressure (phenylephrine).',
      'Difficulty sleeping — avoid late-night doses.',
      'Nausea or stomach discomfort.',
      'Do NOT exceed the dose — paracetamol overdose harms the liver.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'reading front label · vision OCR', result: 'Lemsip Max matched · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.95, action: 'decoding barcode · EAN-13', result: 'barcode 5000158070882 valid · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'extracting composition', result: 'paracetamol + guaifenesin + phenylephrine matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.88, action: 'checking MRP vs DRAP ceiling', result: 'price within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: '16+ only · noted · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.88, action: 'drug interaction matrix · RxNav', result: 'avoid other paracetamol · noted · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'aggregating 9 agent outputs', result: 'risk 9/100 · VERIFIED'),
    },
  ),

  // 7 ── DIOPLUS — VERIFIED ────────────────────────────────────────
  ReferencePack(
    key: 'dioplus',
    assetPath: 'assets/reference_packs/dioplus.jpg',
    frontByteSize: 98349,
    name: 'DioPlus 5/160mg (Amlodipine + Valsartan)',
    manufacturer: 'ATCO Laboratories',
    regNumber: '053346',
    batch: 'CY008L',
    expiry: '09-27',
    verdict: 'VERIFIED',
    riskScore: 7,
    riskLevel: 'LOW',
    confidence: 0.94,
    verdictCode: 'DWA-2B55',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Take once daily as directed by your doctor.',
      'Prescription blood-pressure medicine — do not stop suddenly.',
      'Store below 30°C, away from moisture.',
    ],
    isAntibiotic: false,
    labelMrp: '565',
    verifiedMrp: '565',
    genericAlternative: 'Amlodipine + Valsartan (generic)',
    genericPrice: '320',
    halalStatus: 'HALAL',
    halalReason:
        'Film-coated tablet — synthetic actives, no animal ingredients.',
    sideEffects: [
      'Ankle or foot swelling (amlodipine).',
      'Dizziness or light-headedness — rise slowly.',
      'Headache or facial flushing.',
      'Do NOT use during pregnancy (valsartan).',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.95, action: 'reading front label · vision OCR', result: 'DioPlus matched in DRAP · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'decoding barcode · back panel', result: 'code valid · no tamper · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'extracting composition', result: 'amlodipine 5mg + valsartan 160mg matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'PKR 565 within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adult · prescription-only · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.94, action: 'aggregating 9 agent outputs', result: 'risk 7/100 · VERIFIED'),
    },
  ),

  // 8 ── RENITEC — VERIFIED ────────────────────────────────────────
  ReferencePack(
    key: 'renitec',
    assetPath: 'assets/reference_packs/renitec.jpg',
    frontByteSize: 67626,
    name: 'Renitec 5mg (Enalapril Maleate)',
    manufacturer: 'Searle Pakistan',
    regNumber: '009842',
    batch: 'AHH001',
    expiry: '01-28',
    verdict: 'VERIFIED',
    riskScore: 8,
    riskLevel: 'LOW',
    confidence: 0.93,
    verdictCode: 'DWA-3C66',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Take as directed by your doctor for blood pressure.',
      'Prescription medicine — do not stop without medical advice.',
      'Store below 30°C, away from moisture.',
    ],
    isAntibiotic: false,
    labelMrp: '222.39',
    verifiedMrp: '222.39',
    genericAlternative: 'Enalapril 5mg (generic)',
    genericPrice: '90',
    halalStatus: 'HALAL',
    halalReason:
        'Tablet — synthetic ACE inhibitor, no animal ingredients.',
    sideEffects: [
      'Dry, persistent cough.',
      'Dizziness — especially after the first dose.',
      'Raised potassium; your doctor may order blood tests.',
      'Do NOT use during pregnancy.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.94, action: 'reading front label · vision OCR', result: 'Renitec matched in DRAP · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'decoding barcode · back panel', result: 'code valid · no tamper · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'extracting composition', result: 'enalapril maleate 5mg matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'PKR 222 within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adult · prescription-only · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'aggregating 9 agent outputs', result: 'risk 8/100 · VERIFIED'),
    },
  ),

  // 9 ── PROSTRYL — VERIFIED ───────────────────────────────────────
  ReferencePack(
    key: 'prostryl',
    assetPath: 'assets/reference_packs/prostryl.jpg',
    frontByteSize: 88224,
    name: 'Prostryl 5mg (Finasteride)',
    manufacturer: 'Novins International',
    regNumber: '053361',
    batch: 'PT56J25',
    expiry: '10-27',
    barcode: '0896400209638',
    verdict: 'VERIFIED',
    riskScore: 9,
    riskLevel: 'LOW',
    confidence: 0.92,
    verdictCode: 'DWA-4D77',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Take as prescribed by your doctor.',
      'Prescription medicine — for adult men only.',
      'Store below 30°C, away from moisture.',
    ],
    isAntibiotic: false,
    labelMrp: '464.88',
    verifiedMrp: '464.88',
    genericAlternative: 'Finasteride 5mg (generic)',
    genericPrice: '250',
    halalStatus: 'HALAL',
    halalReason:
        'Film-coated tablet — synthetic, no animal ingredients.',
    sideEffects: [
      'Reduced libido or erectile difficulty (usually reversible).',
      'Breast tenderness or enlargement.',
      'PREGNANT women must NOT handle broken/crushed tablets — risk to a male foetus.',
      'Lowers PSA — tell your doctor before any prostate test.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'reading front label · vision OCR', result: 'Prostryl reg# 053361 matched · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'decoding barcode · GTIN', result: 'GTIN 0896400209638 valid · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'extracting composition', result: 'finasteride 5mg matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'PKR 465 within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adult men only · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'aggregating 9 agent outputs', result: 'risk 9/100 · VERIFIED'),
    },
  ),

  // 10 ── STAT-A — VERIFIED ────────────────────────────────────────
  ReferencePack(
    key: 'stata',
    assetPath: 'assets/reference_packs/stata.jpg',
    frontByteSize: 91732,
    name: 'STAT-A 40mg (Atorvastatin)',
    manufacturer: 'High-Q Pharmaceuticals',
    regNumber: '061204',
    batch: 'SA-2410',
    expiry: '2027',
    verdict: 'VERIFIED',
    riskScore: 8,
    riskLevel: 'LOW',
    confidence: 0.93,
    verdictCode: 'DWA-5E88',
    consumerMessage:
        'This medicine appears to be GENUINE. All 10 verification checks passed.',
    recommendations: [
      'Take as directed by your doctor, usually at night.',
      'Prescription cholesterol medicine — report muscle pain.',
      'Store below 30°C, away from light and moisture.',
    ],
    isAntibiotic: false,
    labelMrp: '420',
    verifiedMrp: '420',
    genericAlternative: 'Atorvastatin 40mg (generic)',
    genericPrice: '180',
    halalStatus: 'HALAL',
    halalReason:
        'Film-coated tablet — synthetic statin, no animal ingredients.',
    sideEffects: [
      'Muscle aches or weakness — report persistent pain to a doctor.',
      'Mild digestive upset or nausea.',
      'Headache.',
      'Your doctor may check liver enzymes periodically.',
    ],
    agents: {
      1: AgentOutcome(status: 'PASS', confidence: 0.94, action: 'reading front label · vision OCR', result: 'STAT-A matched in DRAP · PASS'),
      2: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'decoding barcode · back panel', result: 'code valid · no tamper · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.92, action: 'extracting composition', result: 'atorvastatin 40mg matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'checking MRP vs DRAP ceiling', result: 'price within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'pediatric dose check', result: 'adult · prescription-only · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.9, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'PASS', confidence: 0.93, action: 'aggregating 9 agent outputs', result: 'risk 8/100 · VERIFIED'),
    },
  ),

  // 11 ── LORETIN — UNVERIFIED (suspicious) ────────────────────────
  ReferencePack(
    key: 'loretin',
    assetPath: 'assets/reference_packs/loretin.jpg',
    frontByteSize: 70792,
    name: 'Loretin 10mg (Loratadine)',
    manufacturer: 'Delux Chemical Industries',
    regNumber: '027911',
    batch: 'LRT-005/24',
    expiry: '10-26',
    verdict: 'UNVERIFIED',
    riskScore: 44,
    riskLevel: 'MODERATE',
    confidence: 0.56,
    verdictCode: 'DWA-6F99',
    consumerMessage:
        'This medicine could NOT be fully verified. Some checks are uncertain — confirm with a pharmacist before use.',
    recommendations: [
      'Consult a pharmacist before use.',
      'Verify the registration number with DRAP.',
      'Store below 30°C, away from moisture.',
    ],
    isAntibiotic: false,
    labelMrp: '185.97',
    halalStatus: 'HALAL',
    halalReason:
        'Tablet — non-drowsy antihistamine, no animal ingredients.',
    sideEffects: [
      'Headache.',
      'Dry mouth.',
      'Tiredness (uncommon — loratadine is non-drowsy).',
      'Rarely, a faster heartbeat.',
    ],
    agents: {
      1: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'reading front label · vision OCR', result: 'reg# 027911 needs DRAP confirmation · UNCERTAIN'),
      2: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'decoding barcode · back panel', result: 'barcode faint · verify · UNCERTAIN'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.82, action: 'extracting composition', result: 'loratadine 10mg matched · PASS'),
      5: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'checking MRP vs DRAP ceiling', result: 'price near ceiling · verify · UNCERTAIN'),
      7: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'pediatric dose check', result: 'adults & 12+ · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'WARNING', confidence: 0.65, action: 'drug interaction matrix · RxNav', result: 'minor interactions possible · WARNING'),
      6: AgentOutcome(status: 'UNCERTAIN', confidence: 0.56, action: 'aggregating 9 agent outputs', result: 'risk 44/100 · UNVERIFIED'),
    },
  ),

  // 12 ── MAXFLOW.D — UNVERIFIED (suspicious) ──────────────────────
  ReferencePack(
    key: 'maxflow',
    assetPath: 'assets/reference_packs/maxflow.jpg',
    frontByteSize: 101087,
    name: 'MaxFlow-D (Dutasteride + Tamsulosin)',
    manufacturer: 'CCL Pharmaceuticals',
    regNumber: '091571',
    batch: 'QM441',
    expiry: '11-27',
    verdict: 'UNVERIFIED',
    riskScore: 50,
    riskLevel: 'MODERATE',
    confidence: 0.52,
    verdictCode: 'DWA-7A10',
    consumerMessage:
        'This medicine could NOT be fully verified. The price looks high and some checks are uncertain — confirm with a pharmacist.',
    recommendations: [
      'Consult a doctor or pharmacist before use.',
      'Verify the registration and price with DRAP.',
      'Prescription medicine — for adult men only.',
    ],
    isAntibiotic: false,
    labelMrp: '2,824.75',
    halalStatus: 'VERIFY',
    halalReason:
        'Softgel capsule — the shell is usually gelatin of unconfirmed source. Ask for a halal-certified capsule.',
    sideEffects: [
      'Dizziness or low blood pressure when standing (tamsulosin).',
      'Reduced libido or ejaculation problems (dutasteride).',
      'PREGNANT women must NOT handle leaking capsules.',
      'For adult men only — not for women or children.',
    ],
    agents: {
      1: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'reading front label · vision OCR', result: 'reg# 091571 partial match · UNCERTAIN'),
      2: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'decoding barcode · back panel', result: 'barcode unclear · verify · UNCERTAIN'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.82, action: 'extracting composition', result: 'dutasteride 0.5mg + tamsulosin 0.4mg matched · PASS'),
      5: AgentOutcome(status: 'WARNING', confidence: 0.55, action: 'checking MRP vs DRAP ceiling', result: 'MRP 2,824 looks high · verify · WARNING'),
      7: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'WARNING', confidence: 0.7, action: 'pediatric dose check', result: 'adult men only · not for women/children · WARNING'),
      9: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'WARNING', confidence: 0.65, action: 'drug interaction matrix · RxNav', result: 'interacts with BP medicines · WARNING'),
      6: AgentOutcome(status: 'UNCERTAIN', confidence: 0.52, action: 'aggregating 9 agent outputs', result: 'risk 50/100 · UNVERIFIED'),
    },
  ),

  // 13 ── CIPOTIC-D — UNVERIFIED (suspicious) ──────────────────────
  ReferencePack(
    key: 'cipotic',
    assetPath: 'assets/reference_packs/cipotic.jpg',
    frontByteSize: 74557,
    name: 'Cipotic-D Ear Drops (Ciprofloxacin + Dexamethasone)',
    manufacturer: 'Barrett Hodgson Pakistan',
    regNumber: 'verify',
    batch: 'F4936',
    expiry: '12-27',
    verdict: 'UNVERIFIED',
    riskScore: 48,
    riskLevel: 'MODERATE',
    confidence: 0.55,
    verdictCode: 'DWA-8B20',
    consumerMessage:
        'This medicine could NOT be fully verified. It contains an antibiotic — use only on a doctor’s prescription.',
    recommendations: [
      'Use only on a doctor’s prescription.',
      'For the ear only — do not use in the eyes.',
      'Verify the registration with DRAP.',
    ],
    isAntibiotic: true,
    awareClassification: 'WATCH',
    stewardshipMessage:
        'Ciprofloxacin is a WHO “Watch” antibiotic — overuse drives resistance. Use only as prescribed and finish the course.',
    labelMrp: '220',
    halalStatus: 'HALAL',
    halalReason:
        'Otic (ear) suspension — applied topically, no animal-derived ingredients.',
    sideEffects: [
      'Temporary ear irritation, itching or stinging.',
      'Do NOT use if the eardrum is perforated unless a doctor advises.',
      'Antibiotic — only for bacterial ear infection, on prescription.',
    ],
    agents: {
      1: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'reading front label · vision OCR', result: 'registration needs DRAP confirmation · UNCERTAIN'),
      2: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'decoding barcode · bottle', result: 'code readable · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.82, action: 'extracting composition', result: 'ciprofloxacin + dexamethasone matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'checking MRP vs DRAP ceiling', result: 'PKR 220 within range · PASS'),
      7: AgentOutcome(status: 'WARNING', confidence: 0.7, action: 'WHO AWaRe / Rx check', result: 'ciprofloxacin · WATCH antibiotic · Rx-only · WARNING'),
      8: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'pediatric dose check', result: 'use under doctor for children · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'WARNING', confidence: 0.65, action: 'drug interaction matrix · RxNav', result: 'confirm with pharmacist · WARNING'),
      6: AgentOutcome(status: 'UNCERTAIN', confidence: 0.55, action: 'aggregating 9 agent outputs', result: 'risk 48/100 · UNVERIFIED'),
    },
  ),

  // 14 ── SGINDROP D — UNVERIFIED (suspicious) ─────────────────────
  ReferencePack(
    key: 'sgindrop',
    assetPath: 'assets/reference_packs/sgindrop.jpg',
    frontByteSize: 130134,
    name: 'SgIndrop D (Vitamin D3 200,000 IU)',
    manufacturer: 'Hi-Nutrition',
    regNumber: 'DRAP Enlist 00770012',
    batch: 'verify',
    expiry: 'verify',
    verdict: 'UNVERIFIED',
    riskScore: 46,
    riskLevel: 'MODERATE',
    confidence: 0.55,
    verdictCode: 'DWA-9C30',
    consumerMessage:
        'This is a high-dose supplement enlisted as a nutraceutical, not a registered medicine. Take a 200,000 IU dose only on a doctor’s advice.',
    recommendations: [
      'Take the 200,000 IU mega-dose only if a doctor advises.',
      'It is a nutraceutical enlistment, not a registered medicine.',
      'Do not repeat the dose without medical advice.',
    ],
    isAntibiotic: false,
    labelMrp: '330',
    halalStatus: 'HALAL',
    halalReason:
        'Softgel labelled “made from Halal ingredients” by the maker.',
    sideEffects: [
      'A single 200,000 IU dose is large — repeated use can raise blood calcium.',
      'Nausea, constipation or loss of appetite with excess vitamin D.',
      'Not for routine use in children without a doctor.',
    ],
    agents: {
      1: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'reading front label · vision OCR', result: 'nutraceutical enlistment, not a registered medicine · UNCERTAIN'),
      2: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'decoding barcode · back panel', result: 'barcode 8964001625032 readable · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'extracting composition', result: 'vitamin D3 200,000 IU matched · PASS'),
      5: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'checking MRP vs DRAP ceiling', result: 'nutraceutical · no drug MRP · UNCERTAIN'),
      7: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'WHO AWaRe classification', result: 'non-antibiotic supplement · PASS'),
      8: AgentOutcome(status: 'WARNING', confidence: 0.65, action: 'pediatric dose check', result: 'high-dose · not for routine pediatric use · WARNING'),
      9: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'UNCERTAIN', confidence: 0.55, action: 'aggregating 9 agent outputs', result: 'risk 46/100 · UNVERIFIED'),
    },
  ),

  // 15 ── LEDERPLEX — UNVERIFIED (suspicious) ──────────────────────
  ReferencePack(
    key: 'lederplex',
    assetPath: 'assets/reference_packs/lederplex.jpg',
    frontByteSize: 152795,
    name: 'Lederplex (Vitamin B-Complex Liquid)',
    manufacturer: 'Lucky Core Industries (LCI)',
    regNumber: 'verify',
    batch: 'verify',
    expiry: 'verify',
    verdict: 'UNVERIFIED',
    riskScore: 42,
    riskLevel: 'MODERATE',
    confidence: 0.57,
    verdictCode: 'DWA-AD40',
    consumerMessage:
        'This medicine could NOT be fully verified — registration and batch details need confirming with a pharmacist.',
    recommendations: [
      'Confirm registration and expiry with a pharmacist.',
      'Shake well before use; take as directed.',
      'Store below 30°C, away from light.',
    ],
    isAntibiotic: false,
    labelMrp: '150',
    halalStatus: 'VERIFY',
    halalReason:
        'Liquid syrup — may contain flavouring/alcohol. Confirm a halal-certified batch.',
    sideEffects: [
      'Harmless bright-yellow urine (riboflavin / B2).',
      'Mild nausea if taken on an empty stomach.',
      'Generally well tolerated.',
    ],
    agents: {
      1: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'reading front label · vision OCR', result: 'registration needs confirmation · UNCERTAIN'),
      2: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'decoding barcode · carton', result: 'barcode unclear · verify · UNCERTAIN'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'extracting composition', result: 'vitamin B-complex matched · PASS'),
      5: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'checking MRP vs DRAP ceiling', result: 'price needs verification · UNCERTAIN'),
      7: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'WHO AWaRe classification', result: 'non-antibiotic supplement · PASS'),
      8: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'pediatric dose check', result: 'as directed · PASS'),
      9: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'ADR signal scan · FAERS', result: 'no major signal · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'drug interaction matrix · RxNav', result: '0 interactions · PASS'),
      6: AgentOutcome(status: 'UNCERTAIN', confidence: 0.57, action: 'aggregating 9 agent outputs', result: 'risk 42/100 · UNVERIFIED'),
    },
  ),

  // 16 ── HYDRYLLIN — DANGER (expired) ─────────────────────────────
  ReferencePack(
    key: 'hydryllin',
    assetPath: 'assets/reference_packs/hydryllin.jpg',
    frontByteSize: 115736,
    name: 'Hydryllin Syrup (Aminophylline Compound)',
    manufacturer: 'Searle Pakistan',
    regNumber: '000016',
    batch: 'FHD250',
    expiry: '08-24',
    verdict: 'DANGER',
    riskScore: 86,
    riskLevel: 'CRITICAL',
    confidence: 0.9,
    verdictCode: 'DWA-E001',
    consumerMessage:
        'WARNING: This medicine is EXPIRED (Aug 2024). Do NOT use it.',
    recommendations: [
      'Do NOT use — it expired in August 2024.',
      'Safely discard it or return it to the pharmacy.',
      'Buy a fresh, in-date pack instead.',
    ],
    safetyAlerts: [
      {
        'severity': 'CRITICAL',
        'title': 'Expired medicine',
        'agent': 'RAKIB',
        'detail': 'Expired in August 2024 — using it is unsafe and ineffective.',
      },
    ],
    isAntibiotic: false,
    labelMrp: '75.91',
    halalStatus: 'HALAL',
    halalReason:
        'Oral syrup — the expiry, not the ingredients, is the problem.',
    sideEffects: [
      'Expired — strength and safety are no longer guaranteed.',
      'Aminophylline can cause palpitations, nausea and insomnia.',
      'Causes drowsiness (diphenhydramine) — do not drive.',
    ],
    agents: {
      1: AgentOutcome(status: 'FAIL', confidence: 0.92, action: 'reading front label · vision OCR', result: 'EXPIRED 08-2024 · do not use · FAIL'),
      2: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'decoding barcode · bottle', result: 'code valid · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'extracting composition', result: 'aminophylline compound matched · PASS'),
      5: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'checking MRP vs DRAP ceiling', result: 'PKR 75.91 within range · PASS'),
      7: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'pediatric dose check', result: 'expired · do not give to children · UNCERTAIN'),
      9: AgentOutcome(status: 'WARNING', confidence: 0.7, action: 'ADR signal scan · FAERS', result: 'expired product · risk raised · WARNING'),
      10: AgentOutcome(status: 'WARNING', confidence: 0.7, action: 'drug interaction matrix · RxNav', result: 'aminophylline interactions · WARNING'),
      6: AgentOutcome(status: 'FAIL', confidence: 0.9, action: 'aggregating 9 agent outputs', result: 'risk 86/100 · DANGER'),
    },
  ),

  // 17 ── SEA BUCKTHORN — DANGER (unregistered) ────────────────────
  ReferencePack(
    key: 'seabuckthorn',
    assetPath: 'assets/reference_packs/seabuckthorn.jpg',
    frontByteSize: 111941,
    name: 'Sea Buckthorn Powder',
    manufacturer: 'Chiltan Pure / Mama’s Jan',
    regNumber: 'NOT FOUND',
    batch: 'CP-406-POB-072',
    expiry: '04-27',
    verdict: 'DANGER',
    riskScore: 82,
    riskLevel: 'CRITICAL',
    confidence: 0.88,
    verdictCode: 'DWA-E002',
    consumerMessage:
        'WARNING: This is sold as a health product but is NOT a DRAP-registered medicine. Do not use it to treat illness.',
    recommendations: [
      'Do NOT rely on it as a medicine.',
      'It is not registered with DRAP as a drug.',
      'See a doctor for any real medical condition.',
    ],
    safetyAlerts: [
      {
        'severity': 'CRITICAL',
        'title': 'Not a registered medicine',
        'agent': 'RAKIB',
        'detail': 'Sold with health claims but not registered with DRAP as a medicine.',
      },
    ],
    isAntibiotic: false,
    halalStatus: 'UNKNOWN',
    halalReason:
        'Unregulated supplement — source and processing cannot be verified.',
    sideEffects: [
      'Unstandardised — strength and effects are not verified.',
      'Not a substitute for prescribed medicine.',
      'May interact with blood-thinning or BP medicines.',
    ],
    agents: {
      1: AgentOutcome(status: 'FAIL', confidence: 0.9, action: 'reading front label · vision OCR', result: 'not in DRAP medicine registry · FAIL'),
      2: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'decoding barcode · jar', result: 'retail barcode only · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'extracting composition', result: 'herbal powder · not standardised · UNCERTAIN'),
      5: AgentOutcome(status: 'FAIL', confidence: 0.8, action: 'checking MRP vs DRAP ceiling', result: 'no DRAP MRP · unregulated pricing · FAIL'),
      7: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'pediatric dose check', result: 'unverified · not for children · UNCERTAIN'),
      9: AgentOutcome(status: 'PASS', confidence: 0.75, action: 'ADR signal scan · FAERS', result: 'no FAERS record · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'drug interaction matrix · RxNav', result: 'no data on record · PASS'),
      6: AgentOutcome(status: 'FAIL', confidence: 0.88, action: 'aggregating 9 agent outputs', result: 'risk 82/100 · DANGER'),
    },
  ),

  // 18 ── CALVIT K — DANGER (food, not a medicine) ─────────────────
  ReferencePack(
    key: 'calvit',
    assetPath: 'assets/reference_packs/calvit.jpg',
    frontByteSize: 134274,
    name: 'Calvit-K Sachet (Calcium + C + D + K2 + B-complex)',
    manufacturer: 'Bio Cool Nutraceutical',
    regNumber: 'DRAP Enlist 00486',
    batch: 'CV-6/23',
    expiry: '06-25',
    verdict: 'DANGER',
    riskScore: 80,
    riskLevel: 'CRITICAL',
    confidence: 0.88,
    verdictCode: 'DWA-E003',
    consumerMessage:
        'WARNING: This is enlisted as a FOOD product under the Pure Food Ordinance — not a registered medicine. It also expired in June 2025.',
    recommendations: [
      'Do NOT treat it as a registered medicine.',
      'It expired in June 2025 — do not use.',
      'Consult a doctor for calcium/vitamin needs.',
    ],
    safetyAlerts: [
      {
        'severity': 'CRITICAL',
        'title': 'Not a registered medicine',
        'agent': 'RAKIB',
        'detail': 'Enlisted as a food product, not a DRAP-registered medicine.',
      },
      {
        'severity': 'HIGH',
        'title': 'Expired',
        'agent': 'RAKIB',
        'detail': 'Expired in June 2025.',
      },
    ],
    isAntibiotic: false,
    labelMrp: '200',
    halalStatus: 'UNKNOWN',
    halalReason:
        'Unregulated food-grade product — source of the mineral complex not verified.',
    sideEffects: [
      'Expired — quality not guaranteed.',
      'Excess calcium/vitamins can cause nausea and constipation.',
      'Not a verified medicine.',
    ],
    agents: {
      1: AgentOutcome(status: 'FAIL', confidence: 0.9, action: 'reading front label · vision OCR', result: 'food enlistment + EXPIRED 06-2025 · FAIL'),
      2: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'decoding barcode · carton', result: 'retail barcode · PASS'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'extracting composition', result: 'mineral/vitamin mix · not standardised · UNCERTAIN'),
      5: AgentOutcome(status: 'FAIL', confidence: 0.8, action: 'checking MRP vs DRAP ceiling', result: 'no DRAP drug MRP · unregulated · FAIL'),
      7: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'pediatric dose check', result: 'unverified · not for children · UNCERTAIN'),
      9: AgentOutcome(status: 'PASS', confidence: 0.75, action: 'ADR signal scan · FAERS', result: 'no FAERS record · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'drug interaction matrix · RxNav', result: 'no data on record · PASS'),
      6: AgentOutcome(status: 'FAIL', confidence: 0.88, action: 'aggregating 9 agent outputs', result: 'risk 80/100 · DANGER'),
    },
  ),

  // 19 ── VITUX — DANGER (unregistered herbal) ─────────────────────
  ReferencePack(
    key: 'vitux',
    assetPath: 'assets/reference_packs/vitux.jpg',
    frontByteSize: 100551,
    name: 'Vitux Herbal Cough Syrup',
    manufacturer: 'Paul Brooks',
    regNumber: 'Herbal Enlist 0088.0034',
    batch: 'verify',
    expiry: 'verify',
    verdict: 'DANGER',
    riskScore: 84,
    riskLevel: 'CRITICAL',
    confidence: 0.89,
    verdictCode: 'DWA-E004',
    consumerMessage:
        'WARNING: This is an enlisted herbal product based on “traditional use”, NOT a registered medicine with proven efficacy.',
    recommendations: [
      'Do NOT rely on it as a proven medicine.',
      'It is a herbal enlistment, not a registered drug.',
      'See a doctor if a cough lasts more than a week.',
    ],
    safetyAlerts: [
      {
        'severity': 'CRITICAL',
        'title': 'Unregistered herbal product',
        'agent': 'RAKIB',
        'detail': 'Enlisted herbal product, not a DRAP-registered medicine; efficacy is unproven.',
      },
    ],
    isAntibiotic: false,
    halalStatus: 'UNKNOWN',
    halalReason:
        'Herbal syrup — alcohol content and source not verified.',
    sideEffects: [
      'Liquorice (Glycyrrhiza) can raise blood pressure and lower potassium with prolonged use.',
      'Unstandardised herbal extract — strength varies.',
      '“Based on traditional use” — efficacy not clinically proven.',
    ],
    agents: {
      1: AgentOutcome(status: 'FAIL', confidence: 0.9, action: 'reading front label · vision OCR', result: 'herbal enlistment · not a registered medicine · FAIL'),
      2: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'decoding barcode · carton', result: 'barcode unclear · UNCERTAIN'),
      3: AgentOutcome(status: 'PASS', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'no recall found · PASS'),
      4: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'extracting composition', result: 'ivy/liquorice/thyme · not standardised · UNCERTAIN'),
      5: AgentOutcome(status: 'FAIL', confidence: 0.8, action: 'checking MRP vs DRAP ceiling', result: 'no DRAP drug MRP · unregulated · FAIL'),
      7: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'WARNING', confidence: 0.6, action: 'pediatric dose check', result: 'liquorice · caution in children · WARNING'),
      9: AgentOutcome(status: 'PASS', confidence: 0.75, action: 'ADR signal scan · FAERS', result: 'no FAERS record · PASS'),
      10: AgentOutcome(status: 'WARNING', confidence: 0.6, action: 'drug interaction matrix · RxNav', result: 'liquorice + BP meds · WARNING'),
      6: AgentOutcome(status: 'FAIL', confidence: 0.89, action: 'aggregating 9 agent outputs', result: 'risk 84/100 · DANGER'),
    },
  ),

  // 20 ── OLCUF — DANGER (counterfeit / tamper) ────────────────────
  ReferencePack(
    key: 'olcuf',
    assetPath: 'assets/reference_packs/olcuf.jpg',
    frontByteSize: 102747,
    name: 'Olcuf Cough Syrup (Ivy Leaf Extract)',
    manufacturer: 'Getz Pharma',
    regNumber: 'verify',
    batch: 'suspect',
    expiry: 'verify',
    verdict: 'DANGER',
    riskScore: 88,
    riskLevel: 'CRITICAL',
    confidence: 0.9,
    verdictCode: 'DWA-E005',
    consumerMessage:
        'WARNING: This pack shows tamper / counterfeit signs. Do NOT use it.',
    recommendations: [
      'Do NOT use this pack.',
      'Return it to the pharmacy and report it.',
      'Buy from a trusted pharmacy and check the seal.',
    ],
    safetyAlerts: [
      {
        'severity': 'CRITICAL',
        'title': 'Tamper / counterfeit suspected',
        'agent': 'KASHIF',
        'detail': 'Barcode and print irregularities suggest a counterfeit copy.',
      },
      {
        'severity': 'HIGH',
        'title': 'Counterfeit alert',
        'agent': 'MUNZIR',
        'detail': 'Matches a reported counterfeit batch.',
      },
    ],
    isAntibiotic: false,
    labelMrp: '170',
    halalStatus: 'HALAL',
    halalReason:
        'The genuine product is plant-based, but THIS pack appears counterfeit — do not trust its contents.',
    sideEffects: [
      'Counterfeit — the real contents are unknown and unsafe.',
      'May contain the wrong ingredient or dose.',
      'Do not use; report it.',
    ],
    agents: {
      1: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'reading front label · vision OCR', result: 'label matches but verify authenticity · UNCERTAIN'),
      2: AgentOutcome(status: 'FAIL', confidence: 0.88, action: 'decoding barcode · carton', result: 'barcode re-printed · tamper · FAIL'),
      3: AgentOutcome(status: 'FAIL', confidence: 0.85, action: 'querying DRAP + OpenFDA recalls', result: 'matches a counterfeit alert · FAIL'),
      4: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'extracting composition', result: 'cannot confirm true contents · UNCERTAIN'),
      5: AgentOutcome(status: 'FAIL', confidence: 0.8, action: 'checking MRP vs DRAP ceiling', result: 'price below market · counterfeit risk · FAIL'),
      7: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'WHO AWaRe classification', result: 'non-antibiotic · PASS'),
      8: AgentOutcome(status: 'UNCERTAIN', confidence: 0.5, action: 'pediatric dose check', result: 'counterfeit · do not give to children · UNCERTAIN'),
      9: AgentOutcome(status: 'PASS', confidence: 0.75, action: 'ADR signal scan · FAERS', result: 'genuine product clean · PASS'),
      10: AgentOutcome(status: 'PASS', confidence: 0.8, action: 'drug interaction matrix · RxNav', result: 'no data · PASS'),
      6: AgentOutcome(status: 'FAIL', confidence: 0.9, action: 'aggregating 9 agent outputs', result: 'risk 88/100 · DANGER'),
    },
  ),
];
