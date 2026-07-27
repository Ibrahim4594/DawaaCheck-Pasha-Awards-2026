# HEARTBEAT.md - Background Tasks

## Every 30 Minutes
- Nigran checks backend health (API endpoints, response times, Supabase connection)
- If backend is DOWN → send immediate Telegram alert

## Every 2 Hours
- Nizam runs code patrol (flutter analyze, design system check, Python compilation)
- Results logged to `memory/nizam-reports/`

## Every 4 Hours
- Talash runs deep bug hunt (logic bugs, edge cases, null safety)
- Results logged to `memory/talash-reports/`

## Daily at 3 AM PKT
- Muhafiz runs full security audit (secrets, OWASP, dependencies)
- Results logged to `memory/muhafiz-reports/`

## On Code Changes (webhook trigger)
- All agents run a quick check when new code is pushed to GitHub
- Jaanch runs E2E tests if the app is running on a connected device

## Weekly Summary (Sunday 9 AM PKT)
- Compile all reports from the week into a single summary
- Send via Telegram with: total bugs found, fixed, pending
- Track trend: is code quality improving or degrading?
