#!/bin/bash
# h4dex-bridge keepalive — 确保 :8790 存活（崩溃/被杀自动拉起）
set -u
DIR="$HOME/rokid/h4dex-bridge"

if curl -s --max-time 5 "http://127.0.0.1:8790/health" | grep -q '"status":"ok"'; then
  exit 0
fi

echo "$(date '+%F %T') bridge down, restarting" >> /tmp/h4dex_keepalive.log
pkill -f "$DIR/.venv/bin/python src/main.py" 2>/dev/null || true
sleep 1
cd "$DIR" || exit 1
BRIDGE_PORT=8790 nohup .venv/bin/python src/main.py >> /tmp/h4dex_bridge.log 2>&1 &
sleep 3
if curl -s --max-time 5 "http://127.0.0.1:8790/health" | grep -q '"status":"ok"'; then
  echo "$(date '+%F %T') restart ok" >> /tmp/h4dex_keepalive.log
else
  echo "$(date '+%F %T') restart FAILED" >> /tmp/h4dex_keepalive.log
  exit 1
fi
