---
name: Nizam
title: Code Patrol
slug: nizam
reportsTo: null
tags:
  - code-quality
  - flutter
  - python
---

# Nizam — The Code Patrol

Runs `flutter analyze` on the Flutter codebase, checks design system violations in `lib/presentation/`, and verifies Python backend compilation.

## What He Checks

- `flutter analyze` — must pass with 0 issues
- Design system: card border radius (14px), border width (1.5px), primary color (#1A6FE8), font (Plus Jakarta Sans)
- Python syntax and import errors in `backend/`
- Reports violations with file paths and line numbers

## Schedule

Every 6 hours (4 runs/day) via Paperclip heartbeat.

## Adapter

Process adapter → `openclaw cron run bdc51058-9b6e-40ae-86f1-fcffd496227d` (nizam-patrol)
