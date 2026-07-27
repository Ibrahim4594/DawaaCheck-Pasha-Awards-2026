import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/agent_console_log.dart';
import '../../core/../../data/services/ocr_verification_builder.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/ingredient_safety.dart';
import '../../core/../../data/datasources/local/reference_catalog.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/agent_result_model.dart';
import '../../data/models/scan_result_model.dart';
import '../../data/repositories/scan_repository.dart';
import '../../data/services/medicine_cabinet_service.dart';
import '../../data/services/pack_recognition_service.dart';
import '../../data/services/ocr_extractor.dart';
import 'agent_console_provider.dart';

final scanRepositoryProvider = Provider<ScanRepository>((ref) => ScanRepository());

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref.watch(scanRepositoryProvider), ref);
});

class ScanState {
  final List<Uint8List> capturedImages;
  final int currentStep; // 0, 1, 2
  final bool isProcessing;
  final ScanResultModel? result;
  final List<AgentResultModel> agentResults;
  final double progress; // 0.0 to 1.0
  final String? error;

  const ScanState({
    this.capturedImages = const [],
    this.currentStep = 0,
    this.isProcessing = false,
    this.result,
    this.agentResults = const [],
    this.progress = 0.0,
    this.error,
  });

  ScanState copyWith({
    List<Uint8List>? capturedImages,
    int? currentStep,
    bool? isProcessing,
    ScanResultModel? result,
    List<AgentResultModel>? agentResults,
    double? progress,
    String? error,
  }) {
    return ScanState(
      capturedImages: capturedImages ?? this.capturedImages,
      currentStep: currentStep ?? this.currentStep,
      isProcessing: isProcessing ?? this.isProcessing,
      result: result ?? this.result,
      agentResults: agentResults ?? this.agentResults,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  final ScanRepository _repo;
  final Ref _ref;
  Timer? _replayTimer;

  /// How long to wait on the live backend before falling back on-device.
  static const Duration _liveTimeout = Duration(seconds: 45);

  /// Pacing for the on-device pipeline, so each agent's finding is readable
  /// rather than all ten landing in one frame.
  static const Duration _offlineDuration = Duration(seconds: 12);

  ScanNotifier(this._repo, this._ref) : super(const ScanState());

  void addImage(Uint8List image) {
    final images = [...state.capturedImages, image];
    state = state.copyWith(
      capturedImages: images,
      currentStep: images.length < 3 ? images.length : 2,
    );
  }

  bool get allImagesCaptured => state.capturedImages.length == 3;

  Future<void> startVerification(String userId) async {
    debugPrint('[SCAN] startVerification called. Images: ${state.capturedImages.length}, userId: $userId');

    if (state.capturedImages.length < 3) {
      debugPrint('[SCAN] ERROR: Less than 3 images captured!');
      state = state.copyWith(error: 'Please capture all 3 images first');
      return;
    }

    state = state.copyWith(isProcessing: true, progress: 0.0, error: null);

    // Primary path: send the three photos to the backend and stream the real
    // 10-agent pipeline (Claude Vision + DRAP/OpenFDA/WHO lookups) over SSE.
    if (await _runLiveVerification(userId)) return;

    // Fallback: the backend is unreachable (offline, or not running locally).
    // Verification then happens entirely on-device — see [_runOfflineVerification].
    debugPrint('[SCAN] backend unavailable — running on-device verification');
    await _runOfflineVerification(userId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIMARY — live backend
  // ─────────────────────────────────────────────────────────────────────────

  /// Streams a real verification from the backend, updating the agent rail and
  /// console as each of the 10 agents reports in.
  ///
  /// Returns `true` when the pipeline produced a verdict. Returns `false` if
  /// the backend could not be reached or never delivered one, so the caller can
  /// fall back to on-device verification. Network failure must never surface as
  /// a scan error — the user still gets a result.
  Future<bool> _runLiveVerification(String userId) async {
    final imgs = state.capturedImages;
    final console = _ref.read(agentConsoleProvider.notifier);

    // Rail starts with all ten agents queued, then fills in as results arrive.
    final rail = <int, AgentResultModel>{
      for (final n in kAgentOrder)
        n: AgentResultModel(
          agentNumber: n,
          agentName: kAgentFullNames[n]!,
          status: 'WAITING',
          displayMessage: AppStrings.waiting,
        ),
    };

    void publishRail() {
      final ordered = kAgentOrder.map((n) => rail[n]!).toList();
      final done = ordered.where((a) => a.status != 'WAITING' &&
          a.status != 'PROCESSING').length;
      state = state.copyWith(
        agentResults: ordered,
        progress: (done / kAgentOrder.length).clamp(0.0, 0.95),
      );
    }

    Map<String, dynamic>? verdict;

    try {
      console.beginLive();
      console.append(const AgentLogLine(
        'connecting to verification backend',
        kind: AgentLineKind.boot,
      ));

      final stream = _repo.verifyMedicineStream(
        frontImage: imgs[0],
        backImage: imgs[1],
        ingredientsImage: imgs[2],
        userId: userId,
      );

      publishRail();

      await for (final event in stream.timeout(_liveTimeout)) {
        if (!mounted) return false;
        final type = event['_event'] as String? ?? 'message';

        switch (type) {
          case 'status':
            console.append(AgentLogLine(
              (event['message'] as String?) ?? 'pipeline started',
              kind: AgentLineKind.boot,
            ));

          case 'agent_update':
            final n = _asInt(event['agent']);
            if (n == null || !rail.containsKey(n)) break;
            final status = (event['status'] as String? ?? 'PASS').toUpperCase();
            final data = event['data'] as Map<String, dynamic>? ?? const {};
            final message = (data['display_message'] ??
                    data['message'] ??
                    data['summary'] ??
                    status)
                .toString();

            rail[n] = AgentResultModel(
              agentNumber: n,
              agentName: kAgentFullNames[n]!,
              status: status,
              confidenceScore: _asDouble(data['confidence_score']),
              displayMessage: message,
            );
            console.append(AgentLogLine(
              message,
              agent: kAgentFullNames[n]!.split(' — ').first,
              kind: _lineKindFor(status),
            ));
            publishRail();

          case 'verdict':
            verdict = event;

          case 'error':
            console.append(AgentLogLine(
              (event['message'] as String?) ?? 'pipeline error',
              kind: AgentLineKind.fail,
            ));
            return false;
        }
      }
    } on TimeoutException {
      debugPrint('[SCAN] live pipeline timed out');
      return false;
    } catch (e) {
      // Connection refused, DNS failure, 5xx — all mean "no backend".
      debugPrint('[SCAN] live pipeline unavailable: $e');
      return false;
    }

    if (verdict == null || !mounted) return false;

    try {
      final result = ScanResultModel.fromJson(verdict);
      console.append(AgentLogLine(
        'done · ${result.riskScore}/100 · ${result.overallVerdict}',
        kind: AgentLineKind.boot,
      ));
      _finish(result, kAgentOrder.map((n) => rail[n]!).toList());
      return true;
    } catch (e) {
      debugPrint('[SCAN] could not parse backend verdict: $e');
      return false;
    }
  }

  static AgentLineKind _lineKindFor(String status) => switch (status) {
        'PASS' => AgentLineKind.pass,
        'FAIL' => AgentLineKind.fail,
        _ => AgentLineKind.warn,
      };

  static int? _asInt(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));

  static double _asDouble(Object? v) =>
      v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.9);

  // ─────────────────────────────────────────────────────────────────────────
  // FALLBACK — on-device verification
  // ─────────────────────────────────────────────────────────────────────────

  /// Verifies without a backend, so the app still works offline — the common
  /// case in the pharmacies this is built for.
  ///
  /// Recognition is layered so a fresh photo of a real pack (any angle or
  /// lighting, and a different physical box of the same product) still
  /// resolves against the on-device reference catalogue:
  ///   1. exact byte-size — instant when the reference image itself is re-sent
  ///   2. OCR text match  — brand name / registration number / barcode
  ///   3. perceptual hash — when OCR yields nothing (e.g. on web)
  ///
  /// A pack that matches nothing in the catalogue is read with on-device OCR
  /// and reported from its own printed label. No path can crash, and a pack
  /// with a known safety problem always resolves to that problem — it can
  /// never silently come back clean.
  Future<void> _runOfflineVerification(String userId) async {
    final imgs = state.capturedImages;
    final front = imgs.first;
    final back = imgs.length >= 2 ? imgs[1] : null;
    final ingredients = imgs.length >= 3 ? imgs[2] : null;

    ReferencePack? pack;
    OcrResult? ocr;
    try {
      pack = PackRecognitionService.matchExact(front);
      if (pack == null) {
        final read = await OcrExtractor.read(front, back, ingredients);
        ocr = read.parsed;
        pack = PackRecognitionService.matchByText(read.rawText);
      }
      pack ??= await PackRecognitionService.matchByHash(front);
    } catch (e, s) {
      debugPrint('[OFFLINE] recognition failed: $e\n$s');
    }

    if (pack != null) {
      _runOfflinePipeline(
        pack.buildConsoleLog(),
        pack.buildAgentResults(),
        pack.buildResult(userId),
      );
    } else {
      await _runLabelScan(userId, ocr);
    }
  }

  /// Pack not in the reference catalogue — read its actual name, manufacturer
  /// and ingredients off the label with on-device OCR and report from those.
  /// Reuses [preOcr] when recognition already ran OCR, so the photos are never
  /// processed twice.
  Future<void> _runLabelScan(String userId, [OcrResult? preOcr]) async {
    OcrResult ocr = preOcr ?? const OcrResult();
    if (preOcr == null) {
      try {
        final imgs = state.capturedImages;
        final back = imgs.length >= 2 ? imgs[1] : null;
        final ingredients = imgs.length >= 3 ? imgs[2] : null;
        ocr = await OcrExtractor.extract(imgs.first, back, ingredients);
      } catch (e) {
        debugPrint('[OCR] label extraction failed: $e');
        ocr = const OcrResult();
      }
    }
    if (!mounted) return;
    final built = buildFromOcr(userId: userId, ocr: ocr);
    _runOfflinePipeline(built.log, built.agents, built.result);
  }

  /// Shared on-device pipeline: streams [log] into the console and reveals
  /// [finals] on the rail over [_offlineDuration], then resolves [result].
  void _runOfflinePipeline(
    List<AgentLogLine> log,
    List<AgentResultModel> finals,
    ScanResultModel result,
  ) {
    _replayTimer?.cancel();
    _ref.read(agentConsoleProvider.notifier).beginScenario(log);

    const tick = Duration(milliseconds: 200);
    final totalTicks = _offlineDuration.inMilliseconds ~/ tick.inMilliseconds;
    var t = 0;

    _replayTimer = Timer.periodic(tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      t++;
      final frac = t / totalTicks;

      _ref
          .read(agentConsoleProvider.notifier)
          .setVisible((frac * log.length).round());

      if (t >= totalTicks) {
        timer.cancel();
        _finish(result, finals);
        return;
      }

      final done = (frac * finals.length).floor().clamp(0, finals.length);
      final rail = <AgentResultModel>[];
      for (var i = 0; i < finals.length; i++) {
        if (i < done) {
          rail.add(finals[i]);
        } else if (i == done) {
          final f = finals[i];
          rail.add(AgentResultModel(
            agentNumber: f.agentNumber,
            agentName: f.agentName,
            status: 'PROCESSING',
            displayMessage: 'Running…',
          ));
        } else {
          final f = finals[i];
          rail.add(AgentResultModel(
            agentNumber: f.agentNumber,
            agentName: f.agentName,
            status: 'WAITING',
            displayMessage: AppStrings.waiting,
          ));
        }
      }
      state = state.copyWith(
        agentResults: rail,
        progress: (done / finals.length).clamp(0.0, 0.95),
      );
    });
  }

  void _finish(ScanResultModel rawResult, List<AgentResultModel> finals) {
    _ref.read(agentConsoleProvider.notifier).finish();

    // Ingredient-based safety warnings (aspirin → children, antibiotics → AMR
    // stewardship …), applied to every result regardless of which path produced it.
    final result = _withIngredientWarnings(rawResult, finals);

    state = state.copyWith(
      result: result,
      agentResults: finals,
      isProcessing: false,
      progress: 1.0,
    );

    // Notifications are best-effort — never let a platform-channel failure
    // break the verdict that's already on screen.
    try {
      NotificationService().showScanResultNotification(
        medicineName: result.medicineName,
        verdict: result.overallVerdict,
        riskScore: result.riskScore,
      );
      final recallAgent = finals.where((a) => a.agentNumber == 3).firstOrNull;
      if (recallAgent != null && recallAgent.isFailed) {
        NotificationService().showRecallNotification(result.medicineName);
      }
      NotificationService().recordScanActivity();
    } catch (e) {
      debugPrint('[SCAN] notification skipped: $e');
    }

    // Persist to history (no-ops silently while Supabase is paused / offline).
    _repo.saveScanResult(result).then(
          (_) => debugPrint('[SCAN] Result saved'),
          onError: (e) => debugPrint('[SCAN] Save failed: $e'),
        );

    // Remember it locally so we can warn the user if DRAP recalls it later.
    MedicineCabinetService().add(result).catchError(
          (Object e) => debugPrint('[SCAN] Cabinet add failed: $e'),
        );
  }

  /// Scan the result's name + composition + agent messages for risky actives
  /// (aspirin, antibiotics, codeine…) and prepend consumer warnings.
  ScanResultModel _withIngredientWarnings(
    ScanResultModel r,
    List<AgentResultModel> finals,
  ) {
    final buf = StringBuffer()
      ..write(r.medicineName)
      ..write(' ')
      ..write(r.consumerMessage)
      ..write(' ')
      ..write(r.recommendationsList.join(' '))
      ..write(' ')
      ..write(r.sideEffects.join(' '));
    for (final a in finals) {
      buf
        ..write(' ')
        ..write(a.displayMessage);
    }
    final text = buf.toString();
    final warnings = <String>[...ingredientSafetyWarnings(text)];

    // On yellow/red verdicts, nudge to a doctor for serious-condition meds.
    final verdict = r.overallVerdict.toUpperCase();
    if (verdict == 'UNVERIFIED' || verdict == 'DANGER') {
      final consult = consultDoctorWarning(text);
      if (consult != null) warnings.add(consult);
    }

    if (warnings.isEmpty) return r;
    return r.copyWith(
      recommendationsList: [...warnings, ...r.recommendationsList],
      safetyAlerts: [...r.safetyAlerts, ...warnings],
    );
  }

  void reset() {
    _replayTimer?.cancel();
    _ref.read(agentConsoleProvider.notifier).reset();
    state = const ScanState();
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    super.dispose();
  }
}
