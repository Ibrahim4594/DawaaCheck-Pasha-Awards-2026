# Architecture

Every claim below points at the file that implements it, so it can be checked
against the code rather than taken on trust.

---

## Request path

A scan is three base64 images plus patient context, POSTed to `/scan/verify`.

| Step | File | What happens |
|------|------|--------------|
| 1 | [`routers/scan.py`](backend/routers/scan.py) | Validates the request, opens an SSE response, runs the pipeline in a thread so the event loop stays free, and forwards each agent update to the client as it lands. |
| 2 | [`agents/crew_config.py`](backend/agents/crew_config.py) | Orchestrates the ten agents across three phases, with a per-agent timeout and a 180s pipeline ceiling. |
| 3 | [`utils/verification_cache.py`](backend/utils/verification_cache.py) | After agent 1 establishes identity, checks for a cached verdict and short-circuits the remaining nine agents on a hit. |
| 4 | [`agents/agent_6_verdict.py`](backend/agents/agent_6_verdict.py) | Combines all nine findings into a verdict and a 0–100 risk score. |

Client side, [`scan_provider.dart`](dawaacheck/lib/domain/providers/scan_provider.dart)
consumes that stream, fills the agent rail and console live, and falls back to
on-device verification if the backend cannot be reached.

---

## Execution phases

```
Phase 1   agents 1,2,3,4,5    parallel — 5 workers
             │                 agent 1 extracts pack identity
             ▼
re-enrich agents 2,3,4,5      parallel — re-run with that identity, because
             │                 barcode/recall/price checks need to know which
             │                 medicine they are checking
             ▼
Phase 2   agents 7,8,9,10     parallel — 4 workers
             ▼
Phase 3   agent 6            sequential — needs every other result
```

The re-enrich pass exists because phase 1 runs everything at once for latency,
which means agents 2, 3 and 5 start before the medicine has been identified.
They run once speculatively, then again with real inputs.

---

## Which agents call a model

| Agent | Implementation | Why |
|-------|---------------|-----|
| 1 RAKIB, 2 KASHIF, 4 BASIR | Claude vision | Reading a real label — angled, glare, mixed Urdu/English, often worn — is genuinely a perception problem. |
| 3 MUNZIR | SQL + batch-range matching | Recall status is a lookup against published notices. A model would add nondeterminism to a factual question. |
| 5 ADIL | Table comparison | MRP is a published ceiling; the check is arithmetic. |
| 6 HAKIM | Weighted scoring | A verdict must be reproducible and explainable to a regulator. Weights are explicit constants in the file. |
| 7 HIFAZAT | WHO AWaRe table | AWaRe is a published classification, not a judgement call. |
| 8 SHAFIQ | mg/kg dosing rules | Paediatric dosing is arithmetic on published limits; guessing is unacceptable. |
| 9 SHAHID | Naranjo algorithm | Naranjo is a fixed ten-question scale with defined scoring. |
| 10 RAFIQ | Interaction matrix | Pairwise lookup against a curated table. |

The model id used by the three vision agents lives in
[`utils/model_config.py`](backend/utils/model_config.py) and is overridable via
`ANTHROPIC_VISION_MODEL`, so an evaluator can pin it.

---

## Failure behaviour

The pipeline is built so that no single failure loses the scan.

- **One agent fails** → `_make_error_result` returns an `UNCERTAIN` finding and
  the pipeline continues. HAKIM weights the remaining agents. A missing check
  lowers confidence rather than producing a false pass.
- **Pipeline exceeds 180s** → returns `UNVERIFIED` with an explanatory message.
- **Backend unreachable from the app** → the client falls back to on-device
  verification, and checks that needed the backend are reported as not run.
- **Cache unavailable** → lookups and writes both swallow their errors, so a
  degraded cache means a slower scan, never a failed one.

---

## Cache correctness

Caching a safety verdict is only safe with explicit rules, which are enforced
in `verification_cache.py`:

| Rule | Implementation |
|------|----------------|
| Identity must come from the current photo | Agent 1 always runs before any lookup |
| Only confident results are reusable | `is_cacheable` requires ≥ 0.75 confidence and no errors |
| Riskier verdicts expire sooner | `TTL_BY_VERDICT` — 14d `VERIFIED`, 2d `UNVERIFIED`, 12h `DANGER` |
| A recall must invalidate stale passes | `agent_3_recall.py` calls `invalidate_medicine` on any `FAIL` |
| Key must be stable across formatting | `_norm` strips to uppercase alphanumerics before keying |

---

## On-device verification

Used when the backend is unreachable.

| Stage | File | Method |
|-------|------|--------|
| Exact | [`pack_recognition_service.dart`](dawaacheck/lib/data/services/pack_recognition_service.dart) | Byte-size match, for a re-sent reference image |
| Text | same | OCR text scored against brand tokens, registration number and barcode |
| Visual | same | 8×8 perceptual average hash, Hamming distance ≤ 16 |
| Unrecognised | [`ocr_verification_builder.dart`](dawaacheck/lib/data/services/ocr_verification_builder.dart) | Reports from the label's own printed text |

Text matching is tried before image hashing because it survives a fresh
photograph of a different physical box; a perceptual hash does not.

---

## Data

20 tables across three migrations — see the setup table in the
[README](README.md#2-database) for the required order.

Row-level security is enabled on every user-owned table (`users`,
`scan_results`, `adr_reports`): a user reads and writes only their own rows.
Drug reference tables are public-read. The verification cache is
service-role-only and holds no personal data.

---

## Mobile structure

Clean Architecture, enforced by import direction:

```
presentation/  screens and widgets — no business logic, no direct I/O
     │  ref.watch
     ▼
domain/        Riverpod providers — own state, call repositories
     │
     ▼
data/          repositories → datasources (remote API, Supabase, on-device)
```

A widget never calls the network directly; a provider never builds UI.
