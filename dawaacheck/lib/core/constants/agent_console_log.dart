/// Default log shown in the Agent Console before a scan has been run.
///
/// Mirrors the real `crew_config.py` pipeline order:
/// Phase 1 core (agents 1-5) → Phase 2 safety (7-10) → Phase 3 verdict (6).
///
/// Lines are intentional Latin "firmware log" data (mono-Latin design rule).
/// Only screen chrome (title/subtitle/button) is localized prose.
library;

enum AgentLineKind { boot, phase, info, pass, warn, fail }

/// Plain-language role for each agent code — shown so a non-technical user
/// understands what the agent is checking, while the mono detail line stays
/// for developers.
const Map<String, String> kAgentRoles = {
  'RAKIB': 'Registration & authenticity',
  'KASHIF': 'Barcode & tamper check',
  'MUNZIR': 'Recall check',
  'BASIR': 'Ingredient check',
  'ADIL': 'Price check',
  'HAKIM': 'Final verdict',
  'HIFAZAT': 'Antibiotic safety',
  'SHAFIQ': 'Child safety',
  'SHAHID': 'Side-effect scan',
  'RAFIQ': 'Drug interactions',
};

class AgentLogLine {
  final String? agent;
  final String text;
  final AgentLineKind kind;

  const AgentLogLine(this.text, {this.agent, this.kind = AgentLineKind.info});
}

const List<AgentLogLine> kAgentConsoleLog = [
  AgentLogLine('DawaaCheck Crew v1.0 — booting 10 agents',
      kind: AgentLineKind.boot),
  AgentLogLine('images received · front · back · ingredients',
      kind: AgentLineKind.boot),

  AgentLogLine('PHASE 1 · CORE VERIFICATION', kind: AgentLineKind.phase),
  AgentLogLine('reading front label · vision OCR', agent: 'RAKIB'),
  AgentLogLine('reg# DRA-012345 matched in DRAP · PASS',
      agent: 'RAKIB', kind: AgentLineKind.pass),
  AgentLogLine('decoding barcode · EAN-13', agent: 'KASHIF'),
  AgentLogLine('check digit valid · GS1 896 PK · no tamper · PASS',
      agent: 'KASHIF', kind: AgentLineKind.pass),
  AgentLogLine('querying DRAP + OpenFDA recalls', agent: 'MUNZIR'),
  AgentLogLine('batch L24F091 not recalled · PASS',
      agent: 'MUNZIR', kind: AgentLineKind.pass),
  AgentLogLine('extracting ingredient panel', agent: 'BASIR'),
  AgentLogLine('actives 100% match · no banned substance · PASS',
      agent: 'BASIR', kind: AgentLineKind.pass),
  AgentLogLine('checking MRP vs DRAP ceiling', agent: 'ADIL'),
  AgentLogLine('PKR 250 within legal range · PASS',
      agent: 'ADIL', kind: AgentLineKind.pass),

  AgentLogLine('PHASE 2 · SAFETY LAYER', kind: AgentLineKind.phase),
  AgentLogLine('WHO AWaRe classification', agent: 'HIFAZAT'),
  AgentLogLine('non-antibiotic · LOW risk · PASS',
      agent: 'HIFAZAT', kind: AgentLineKind.pass),
  AgentLogLine('pediatric dose check', agent: 'SHAFIQ'),
  AgentLogLine('adult patient · not applicable · PASS',
      agent: 'SHAFIQ', kind: AgentLineKind.pass),
  AgentLogLine('ADR signal scan · FAERS', agent: 'SHAHID'),
  AgentLogLine('no adverse signal · PASS',
      agent: 'SHAHID', kind: AgentLineKind.pass),
  AgentLogLine('drug interaction matrix · RxNav', agent: 'RAFIQ'),
  AgentLogLine('0 interactions found · PASS',
      agent: 'RAFIQ', kind: AgentLineKind.pass),

  AgentLogLine('PHASE 3 · VERDICT SYNTHESIS', kind: AgentLineKind.phase),
  AgentLogLine('aggregating 9 agent outputs', agent: 'HAKIM'),
  AgentLogLine('risk score 4/100 · VERIFIED',
      agent: 'HAKIM', kind: AgentLineKind.pass),
  AgentLogLine('done · DWA-4E0A · 2.4s · 10/10 agents',
      kind: AgentLineKind.boot),
];
