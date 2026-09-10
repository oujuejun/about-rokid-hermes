#!/bin/bash
# 真实 SSE 探测：专杀"进程活但每请求500"这类路由级故障。命中则交给 keepalive 重拉。
AK_FILE="$HOME/rokid/h4dex-bridge/.env"
[ -f "$AK_FILE" ] || exit 0
AK=$(grep "^ROKID_AK=" "$AK_FILE" | cut -d= -f2)
out=$(curl -sN --max-time 25 -H "Authorization: Bearer ***" -X POST -H 'Content-Type: application/json' \
  -d '{"message_id":"keepalive-probe","agent_id":"bb77b72ce3414ad8808a384c2","user_id":"__keepalive__","message":[{"role":"user","type":"text","text":"ping"}],"metadata":{}}' \
  http://127.0.0.1:8790/metis/agent/api/sse 2>/dev/null)
if echo "$out" | grep -q "Internal Server Error"; then
  pkill -f "h4dex-bridge/.venv/bin/python src/main.py" 2>/dev/null
  echo "[sse-probe $(date '+%m-%d %H:%M')] FAIL -> killed bridge, keepalive will restart" >> /tmp/h4dex_keepalive.log
else
  echo "[sse-probe $(date '+%m-%d %H:%M')] ok" >> /tmp/h4dex_keepalive.log
fi
