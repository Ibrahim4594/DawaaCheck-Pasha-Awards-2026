# DawaaCheck OpenClaw Setup Guide

## Step 1: Install OpenClaw

```bash
# Option A: Quick install (recommended)
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash

# Option B: Manual via npm (requires Node 22+)
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

## Step 2: Set Up API Key

```bash
# Set your Anthropic API key
openclaw config set providers.anthropic.apiKey "your-anthropic-api-key"

# Or use environment variable
export ANTHROPIC_API_KEY="your-key-here"
```

## Step 3: Connect Telegram (for notifications)

1. Open Telegram, search for @BotFather
2. Send `/newbot` and follow instructions
3. Copy the bot token
4. Run:
```bash
openclaw config set channels.telegram.token "your-telegram-bot-token"
openclaw config set channels.telegram.enabled true
```
5. Message your bot on Telegram to activate

## Step 4: Copy DawaaCheck Config

```bash
# Copy all OpenClaw files to your home directory
cp openclaw/SOUL.md ~/.openclaw/
cp openclaw/USER.md ~/.openclaw/
cp openclaw/agents/AGENTS.md ~/.openclaw/
cp openclaw/HEARTBEAT.md ~/.openclaw/
cp openclaw/openclaw-config.json ~/.openclaw/openclaw.json

# Copy skills
cp -r openclaw/skills/* ~/.openclaw/skills/
```

## Step 5: Install flutter-skill (for E2E testing)

```bash
npm install -g flutter-skill
```

Then add 2 lines to your Flutter app's `main.dart`:
```dart
import 'package:flutter_skill/flutter_skill.dart';

void main() {
  if (kDebugMode) FlutterSkillBinding.ensureInitialized(); // Add this
  // ... rest of your main()
}
```

Add to pubspec.yaml:
```yaml
dev_dependencies:
  flutter_skill: ^latest
```

## Step 6: Install Community Skills

```bash
# Bug detection
clawhub install clawhub/bughunter

# QA automation
clawhub install clawhub/qa-patrol

# Code review
clawhub install clawhub/code-reviewer
```

## Step 7: Start OpenClaw

```bash
# Start the gateway daemon
openclaw gateway start

# Verify it's running
openclaw status

# Open the dashboard
# Visit http://127.0.0.1:18789/
```

## Step 8: Set Up Cron Jobs

```bash
# Import cron config
openclaw cron import openclaw/openclaw-config.json

# Verify crons are active
openclaw cron list

# Expected output:
# nizam-patrol    | Every 2 hours  | Code quality patrol
# talash-hunt     | Every 4 hours  | Deep bug hunt
# nigran-health   | Every 30 min   | Backend health check
# muhafiz-audit   | Daily 3 AM PKT | Security audit
```

## Step 9: Test Everything

```bash
# Test Nizam (code patrol)
openclaw run "Hey Nizam, run a code patrol check on DawaaCheck"

# Test Nigran (backend monitor) - make sure backend is running first
cd backend && uvicorn main:app --reload --port 8000 &
openclaw run "Hey Nigran, check the backend health"

# Test the full team
openclaw run "Run a full QA check on DawaaCheck"
```

## Step 10: Keep It Running 24/7

### Option A: Keep your laptop on (simple)
Just leave the terminal open with `openclaw gateway start`. Make sure:
- Sleep mode is disabled
- Power is plugged in
- WiFi stays connected

### Option B: VPS (recommended for 24/7)
```bash
# On a $5/month Hetzner/DigitalOcean VPS:
ssh your-vps
git clone your-dawaacheck-repo
npm install -g openclaw@latest
openclaw onboard --install-daemon
# Copy all config files as in Step 4
openclaw gateway start
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Command not found: openclaw" | Run `npm install -g openclaw@latest` |
| "API key not set" | Run `openclaw config set providers.anthropic.apiKey "key"` |
| Telegram not receiving messages | Check bot token, message the bot first |
| flutter-skill not connecting | Make sure app is running: `flutter run` |
| Cron not firing | Check `openclaw cron list` and `openclaw logs` |

## File Structure
```
~/.openclaw/
├── openclaw.json          # Main config (from openclaw-config.json)
├── SOUL.md                # Agent personality
├── USER.md                # Your preferences
├── AGENTS.md              # Agent team definition
├── HEARTBEAT.md           # Background task schedule
├── skills/
│   ├── nizam-code-patrol/
│   │   └── SKILL.md       # Code quality patrol instructions
│   ├── talash-bug-hunter/
│   │   └── SKILL.md       # Deep bug detection instructions
│   ├── jaanch-e2e-tester/
│   │   └── SKILL.md       # E2E test flow instructions
│   ├── nigran-backend-monitor/
│   │   └── SKILL.md       # Backend health monitoring
│   └── muhafiz-security-auditor/
│       └── SKILL.md       # Security audit instructions
└── memory/                # Agent reports and logs
```
