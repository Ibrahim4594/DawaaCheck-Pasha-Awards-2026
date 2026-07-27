import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/agent_console_log.dart';

/// Lifecycle of the Agent Console stream.
enum ConsoleStatus { idle, running, done }

/// Drives the Agent Console replay. Owned outside the screen so the stream can
/// be kicked off by the scan action (`ScanNotifier.startVerification`) even when
/// the console tab is not currently mounted — the user presses Scan, then
/// switches to the Console tab to watch the agents work.
///
/// Two drive modes:
/// - **self-timed** (`start`): the manual "Run Verification" demo button. Uses
///   the default generic log and times itself.
/// - **externally driven** (`beginScenario` + `setVisible` + `finish`): the offline
///   scan pipeline pushes the scenario log and advances the cursor so the
///   console stays in lock-step with the processing screen.
@immutable
class AgentConsoleState {
  final List<AgentLogLine> log;

  /// Number of log lines currently revealed.
  final int visible;
  final ConsoleStatus status;

  const AgentConsoleState({
    this.log = kAgentConsoleLog,
    this.visible = 0,
    this.status = ConsoleStatus.idle,
  });

  int get total => log.length;

  AgentConsoleState copyWith({
    List<AgentLogLine>? log,
    int? visible,
    ConsoleStatus? status,
  }) {
    return AgentConsoleState(
      log: log ?? this.log,
      visible: visible ?? this.visible,
      status: status ?? this.status,
    );
  }
}

class AgentConsoleNotifier extends StateNotifier<AgentConsoleState> {
  AgentConsoleNotifier() : super(const AgentConsoleState());

  static const Duration _step = Duration(milliseconds: 320);
  Timer? _timer;

  /// Self-timed replay of the default log (manual demo button).
  void start() {
    _timer?.cancel();
    state = const AgentConsoleState(
      log: kAgentConsoleLog,
      visible: 0,
      status: ConsoleStatus.running,
    );
    _timer = Timer.periodic(_step, (timer) {
      if (state.visible >= state.total) {
        timer.cancel();
        state = state.copyWith(status: ConsoleStatus.done);
        return;
      }
      state = state.copyWith(visible: state.visible + 1);
    });
  }

  /// Load a pre-built log and reset the cursor. The offline verification
  /// pipeline advances it via [setVisible] and ends with [finish].
  void beginScenario(List<AgentLogLine> log) {
    _timer?.cancel();
    state = AgentConsoleState(
      log: log,
      visible: 0,
      status: ConsoleStatus.running,
    );
  }

  /// Open an empty console for a **live** backend run. Lines are appended with
  /// [append] as each agent reports in over SSE, rather than replayed from a
  /// pre-built list, so the console shows real pipeline output in real time.
  void beginLive() {
    _timer?.cancel();
    state = const AgentConsoleState(
      log: [],
      visible: 0,
      status: ConsoleStatus.running,
    );
  }

  /// Append one line from the live agent stream and reveal it immediately.
  void append(AgentLogLine line) {
    final log = [...state.log, line];
    state = state.copyWith(log: log, visible: log.length);
  }

  void setVisible(int n) {
    final clamped = n.clamp(0, state.total);
    if (clamped == state.visible) return;
    state = state.copyWith(visible: clamped);
  }

  void finish() {
    _timer?.cancel();
    state = state.copyWith(visible: state.total, status: ConsoleStatus.done);
  }

  void reset() {
    _timer?.cancel();
    state = const AgentConsoleState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final agentConsoleProvider =
    StateNotifierProvider<AgentConsoleNotifier, AgentConsoleState>(
  (ref) => AgentConsoleNotifier(),
);
