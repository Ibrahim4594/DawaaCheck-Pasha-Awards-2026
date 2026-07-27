#!/bin/bash
# DawaaGuard Health Probe — Backend crash detection
# Called by Paperclip every 5 minutes.
# Triggers Nigran after 3 consecutive failures (grace period).

BACKEND_URL="http://localhost:8000/"
FAIL_COUNT_FILE="${TEMP:-/tmp}/dawaacheck-health-probe-failures"
MAX_FAILURES=3

# Initialize failure counter if missing
if [ ! -f "$FAIL_COUNT_FILE" ]; then
  echo "0" > "$FAIL_COUNT_FILE"
fi

# Probe backend
if curl -sf --max-time 10 "$BACKEND_URL" > /dev/null 2>&1; then
  # Backend is UP — reset counter
  echo "0" > "$FAIL_COUNT_FILE"
  echo '{"status":"up","failures":0}'
  exit 0
else
  # Backend is DOWN — increment counter
  FAILURES=$(cat "$FAIL_COUNT_FILE")
  FAILURES=$((FAILURES + 1))
  echo "$FAILURES" > "$FAIL_COUNT_FILE"

  if [ "$FAILURES" -ge "$MAX_FAILURES" ]; then
    # Grace period exceeded — trigger Nigran via Paperclip
    echo '{"status":"down","failures":'"$FAILURES"',"action":"trigger_nigran"}'
    if ! npx paperclipai heartbeat run \
      --agent-id ee93cc90-b1a2-41c2-93ae-ef04964ad2f6 \
      --source automation \
      --trigger callback \
      --timeout-ms 300000 2>/dev/null; then
      # Paperclip is down — fall back to direct OpenClaw
      echo '{"fallback":"paperclip_down","using":"openclaw_direct"}'
      openclaw cron run c68a6e52-8806-4ad7-9754-559ec51cec4f 2>/dev/null || \
        openclaw agent --agent nigran --message "URGENT: Backend is DOWN. Run health check immediately." 2>/dev/null
    fi
    # Reset counter after triggering
    echo "0" > "$FAIL_COUNT_FILE"
    exit 1
  else
    # Within grace period — just log
    echo '{"status":"down","failures":'"$FAILURES"',"action":"waiting","threshold":'"$MAX_FAILURES"'}'
    exit 0
  fi
fi
