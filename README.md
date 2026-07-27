# DawaaCheck

DawaaCheck is Pakistan's first AI-powered consumer medicine verification app.
An AI vision scan reads any medicine box; 16 AI agents cross-check it in real
time against DRAP's database and deliver one **GREEN**, **AMBER** or **RED**
verdict in under 30 seconds — free, in Urdu and English, on any Android phone.
If it's ever recalled, a Recall Alert push notification warns the patient —
protection at the point of purchase, and beyond.

*16 agents: [10 verification agents](#the-ten-agents) in the scan pipeline, plus
[6 automation agents](openclaw/) — 5 OpenClaw monitors and Paperclip — that keep
the recall feed, backend and codebase under continuous watch.*

---

Photograph a medicine pack — front, back, ingredients — and the ten-agent
pipeline cross-checks it against DRAP, OpenFDA and WHO data, returning a
verdict: **Authentic**, **Unconfirmed**, or **Counterfeit**, with a 0–100 risk
score, recall status, drug interactions, paediatric dosing safety, and an
adverse-reaction reporting flow.

Bilingual English/Urdu, offline-capable, built for budget Android hardware.

> **Quick start:** put your Claude API key in `backend/.env`
> (see [Setup](#setup)), run the backend, run the app. Without a key the app
> still runs — it falls back to [on-device verification](#working-offline).
>
> **No Firebase credentials are published here.** The app ships placeholder
> config so it builds and runs out of the box; guest mode uses a device-local
> session. See [Firebase — optional](#4-firebase--optional).

---

## The problem

Counterfeit and substandard medicine is a public-health problem in Pakistan,
and the tooling that exists does not reach the people affected by it. DRAP
publishes recall notices as PDFs. Someone standing in a pharmacy holding a box
has no practical way to check whether it is genuine, whether that batch has
been recalled, or whether the price is above the legal ceiling.

DawaaCheck answers those questions from three photographs.

---

## How verification works

```
  3 photos ──▶ FastAPI ──▶ Phase 1   agents 1-5   (parallel)
                            │         registration · barcode · recall
                            │         ingredients  · price
                            ▼
                        re-enrich    agents 2,3,4,5 re-run with the pack
                            │        identity that agent 1 extracted
                            ▼
                          Phase 2    agents 7-10  (parallel)
                            │         AMR · paediatric · ADR · interactions
                            ▼
                          Phase 3    agent 6 — verdict synthesis
                            │
                            ▼
                    verdict + risk score  ──▶  SSE stream to the app
```

Each agent reports as it finishes, streamed over Server-Sent Events, so the
user watches the pipeline work instead of a spinner.

### The ten agents

Three agents call Claude, and all three do the same kind of work: reading a
label from a photograph. The other seven are deterministic engines running
against the database.

| # | Agent | Responsibility | Implementation |
|---|-------|----------------|----------------|
| 1 | RAKIB — The Watchman | Reads the front label; verifies DRAP registration and authenticity | **Claude vision** |
| 2 | KASHIF — The Revealer | Decodes the barcode; detects tampering and repackaging | **Claude vision** |
| 4 | BASIR — The All-Seeing | Reads the ingredients panel; verifies declared composition | **Claude vision** |
| 3 | MUNZIR — The Warner | Batch-level recall matching against DRAP and OpenFDA | Deterministic |
| 5 | ADIL — The Just One | Price against the legal MRP ceiling; generic alternatives | Deterministic |
| 6 | HAKIM — The Wise Judge | Weighted synthesis of all nine findings into verdict + risk score | Deterministic |
| 7 | HIFAZAT — The Protector | Antimicrobial-resistance guard, WHO AWaRe classification | Deterministic |
| 8 | SHAFIQ — The Compassionate | Paediatric safety; age- and weight-based dosing | Deterministic |
| 9 | SHAHID — The Witness | Adverse-drug-reaction reporting, Naranjo causality scale | Deterministic |
| 10 | RAFIQ — The Companion | Drug-interaction and contraindication checking | Deterministic |

**Why the split is deliberate.** Vision is the part that genuinely needs a
model: reading a smudged Urdu-and-English label at an angle under pharmacy
lighting. Scoring is not. A safety verdict should be reproducible and
auditable — the same findings must always produce the same verdict, and a
regulator should be able to read why. So HAKIM is explicit weighted arithmetic
(registration 0.22, recall 0.20, price 0.05, and so on in
[`agent_6_verdict.py`](backend/agents/agent_6_verdict.py)) rather than a model
asked to be careful. The same reasoning applies to AWaRe classification,
mg/kg paediatric dosing and Naranjo scoring: those are published rules, and
implementing them as rules makes them checkable.

### Verification cache

A given pack is scanned by many different people. Re-running the pipeline for a
verdict already known wastes money and time, so completed verdicts are cached
in Postgres, keyed on registration number plus batch.

Agent 1 always runs — identity has to come from *this* photo before a cached
answer can be attributed to it. Everything downstream is skipped on a hit. The
cache is deliberately conservative for a safety product:

- only confident, error-free verdicts are stored;
- entries expire, and anything that is not a clean pass expires sooner
  (14 days for `VERIFIED`, 12 hours for `DANGER`);
- **a new recall invalidates every cached verdict for that medicine**, so a
  pack that verified clean yesterday is re-checked rather than served stale.

See [`verification_cache.py`](backend/utils/verification_cache.py). Hit counts
are exposed on `/health`.

### Working offline

Connectivity in Pakistani pharmacies is unreliable, so verification degrades
rather than failing. When the backend is unreachable the app verifies
on-device: it recognises the pack against an on-device reference catalogue
(printed text first, perceptual image hash as fallback), and a pack it does not
recognise is read from its own label with ML Kit OCR and reported from what the
label actually says.

Checks that genuinely need the backend — live recall lookup, MRP comparison —
are reported as *not run*, not as passed.

---

## Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter · Dart 3.11 · Riverpod · GoRouter · Clean Architecture |
| Backend | FastAPI 0.115 · Python 3.11 · SSE streaming · slowapi rate limiting |
| AI | Anthropic Claude (vision agents) — model configurable, defaults to Opus 4.6 |
| Database | Supabase Postgres · 20 tables · GIN trigram indexes · RLS on user tables |
| Auth & push | Firebase Auth · Cloud Messaging · Crashlytics |
| On-device | Google ML Kit OCR · perceptual image hashing |
| Automation | OpenClaw + Paperclip — 6 agents: `jaanch`, `muhafiz`, `nigran`, `nizam`, `talash` + Paperclip orchestrator ([`openclaw/`](openclaw/)) |

---

## Setup

### 1. Backend

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env
```

**Open `.env` and add your Claude API key:**

```env
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

Get one at **https://console.anthropic.com/settings/keys**. This is the only
key the verification pipeline strictly needs — Supabase credentials are
required for reference data and the cache, Firebase only for push.

Then run it:

```bash
uvicorn main:app --reload --port 8000
```

API docs at `http://localhost:8000/docs`; health and cache stats at
`http://localhost:8000/health`.

### 2. Database

Run all four in the Supabase SQL editor, **in this order**. The first two are
complementary rather than successive versions — `supabase_migration.sql`
creates the core user and DRAP tables, `_v2` adds the drug reference tables.
Skipping the first leaves the app without `users`, `scan_results` or
`drap_medicines`, and scans will fail on write.

| Order | File | Creates |
|-------|------|---------|
| 1 | `backend/data/supabase_migration.sql` | Core: `users`, `scan_results`, `adr_reports`, `drap_medicines`, `drap_recalls`, `safety_heatmap` — with RLS |
| 2 | `backend/data/supabase_migration_v2.sql` | Reference: `generic_drugs`, `drug_interactions`, `drug_side_effects`, `who_aware_antibiotics`, `pediatric_safety`, `medicine_prices`, OpenFDA mirrors, and more |
| 3 | `backend/data/search_optimization.sql` | GIN trigram indexes for medicine search |
| 4 | `backend/data/verification_cache.sql` | Verdict cache + expiry housekeeping |

Then load the reference data:

```bash
python backend/data/upload_to_supabase.py
```

### 3. App

```bash
cd dawaacheck
flutter pub get
flutter run
```

The app finds a local backend automatically — it uses `10.0.2.2:8000` on the
Android emulator (the emulator's alias for the host machine) and
`localhost:8000` elsewhere. For a deployed backend:

```bash
flutter run --dart-define=DAWAACHECK_API_URL=https://your-api.example.com
```

**With no backend running the app still works**, falling back to on-device
verification — so it is usable immediately after `flutter run`.

### 4. Firebase — optional

**You do not need Firebase to build, run or evaluate this app.** No real
Firebase credentials are published in this repository: `google-services.json`
and `firebase_options.dart` ship with placeholder values so that a clone
compiles and boots. Everything that matters still works — scanning, the
verification pipeline, history, recalls, the medicine cabinet, the safety map,
both languages.

What is off without it: accounts, Google Sign-In, push notifications and
Crashlytics. Tapping **Continue as guest** falls back to a
[device-local session](dawaacheck/lib/data/services/local_session_service.dart),
so the app is fully explorable on first launch.

To enable the account features, point it at a Firebase project of your own:

```bash
cd dawaacheck
flutterfire configure          # rewrites firebase_options.dart + google-services.json
```

Google Sign-In additionally needs the web client id from
**Authentication → Sign-in method → Google → Web SDK configuration**:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_ID.apps.googleusercontent.com
```

`flutterfire configure` overwrites the placeholder
`android/app/google-services.json` with your real project — that file has to
stay tracked for the Gradle plugin to build, so take care not to commit your
own credentials back into a fork.

### 5. Tests

```bash
cd dawaacheck && flutter analyze && flutter test    # 177 tests
cd backend     && pytest
```

---

## Layout

```
backend/
  agents/          ten agents + crew_config.py orchestration
  routers/         scan · medicines · recalls · adr · notifications
  utils/           supabase client · verification cache · model config · auth
  data/            SQL migrations, seed data, loaders
dawaacheck/
  lib/core/        design tokens, router, theme, geography
  lib/data/        models · repositories · datasources · on-device services
  lib/domain/      Riverpod providers
  lib/presentation/  19 screens + design-system widgets
openclaw/          five monitoring agents, Paperclip scheduling
```

---

## Security

- **No credentials in source.** `.env` and `secrets/` are gitignored; every
  key is read from the environment.
- **Row-level security** on all user-owned tables. The Supabase service-role
  key stays server-side and never ships to a client.
- **Release builds** use ProGuard and Dart obfuscation.
- The verification cache stores pack identity and verdicts only — no personal
  data, and clients never read it directly.

---

## Status and limitations

Working end to end: the ten-agent pipeline with live SSE streaming, the
verification cache, offline verification, proactive recall alerts, bilingual
EN/UR, and the full 19-screen app. 171 automated tests pass.

Stated plainly, because they matter:

- **Recall data is not exhaustive.** DRAP publishes recalls as PDF notices with
  no API. Recent notices are seeded locally and a scraper keeps the table
  current, but complete coverage is not possible without a DRAP data feed.
- **The offline reference catalogue is small.** On-device recognition covers a
  limited set of packs; everything else falls back to reading the label
  directly, which yields less than a full backend verification.
- **Price data is partial.** MRP reference data covers common medicines, not
  the full DRAP schedule.
- **Not a substitute for a pharmacist.** The app surfaces regulatory and safety
  signals; it does not give medical advice.

---

Built by **Ibrahim Samad**, Karachi.
Submitted to the **HBL P@SHA ICT Awards 2026**.
