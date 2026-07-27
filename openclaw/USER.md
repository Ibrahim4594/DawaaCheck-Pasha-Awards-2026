# USER.md - Ibrahim Samad

## About
- **Name:** Ibrahim Samad
- **Location:** Karachi, Pakistan
- **Role:** Solo developer building DawaaCheck
- **Competition:** HBL P@SHA ICT Awards 2026

## Project Context
DawaaCheck is Pakistan's first AI-powered medicine verification app.
- **Frontend:** Flutter (Dart) - Clean Architecture + Riverpod + GoRouter
- **Backend:** FastAPI (Python) - SSE streaming + a 10-agent verification pipeline
  (3 Claude vision agents, 7 deterministic engines - see ARCHITECTURE.md)
- **Database:** Supabase (PostgreSQL) - 14 tables
- **AI:** Anthropic Claude Vision for image analysis

## Preferences
- Wants concise, actionable reports - no fluff
- Prefers Telegram notifications
- Working timezone: PKT (UTC+5)
- Wants to know about bugs BEFORE they reach competition judges
- Cares most about: UI consistency, agent accuracy, crash-free experience

## Critical Files
- Flutter app: `dawaacheck/lib/`
- Backend agents: `backend/agents/`
- Design system: `dawaacheck/lib/core/constants/` and `dawaacheck/lib/core/theme/`
- CLAUDE.md has all project rules
