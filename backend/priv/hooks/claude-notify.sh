#!/usr/bin/env bash
# Canopy hook v1
# Called by Claude Code (and compatible agents) on every lifecycle event.
# Reads JSON payload from stdin, POSTs it to the Canopy hooks endpoint.
# Fire-and-forget: exits 0 immediately so the agent is never blocked.

payload=$(cat)

curl -sS -X POST \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "http://localhost:9190/api/v1/hooks/notify" \
  --connect-timeout 1 \
  --max-time 2 \
  > /dev/null 2>&1 &

exit 0
