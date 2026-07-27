---
name: DawaaGuard
slug: dawaa-guard
description: QA monitoring team for DawaaCheck — Pakistan's AI medicine verification app
version: "1.0"
spec: agentcompanies/v1
---

# DawaaGuard

5 AI agents that monitor the DawaaCheck codebase 24/7 for code quality, bugs, backend health, and security vulnerabilities.

## Departments

- **Code Quality** — Nizam (code patrol), Talash (bug hunter), Jaanch (E2E tester)
- **Ops & Security** — Nigran (backend monitor), Muhafiz (security auditor)

## Model

All agents run on Anthropic Claude Sonnet 4.6 via OpenClaw.

## Execution

Paperclip manages scheduling and budget. OpenClaw executes agents and delivers WhatsApp alerts.

## Budget

Global daily cap: $1.00/day (~15 scheduled runs/day, ~$0.75 base cost).
