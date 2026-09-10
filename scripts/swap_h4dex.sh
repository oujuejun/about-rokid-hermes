#!/bin/bash
# 顶替到 h4dex 桥（实机试跑用）。回滚: bash swap_h4dex.sh rollback
FLAG=/tmp/rokid_try_upstream.flag
if [ "${1:-}" = "rollback" ]; then
  launchctl load ~/Library/LaunchAgents/com.hermes.rokid-shim-keepalive.plist 2>/dev/null
  rm -f $FLAG; pkill -f "rokid-hermes-bridge/src/main.py"; sleep 1
  curl -s -m 5 http://127.0.0.1:8790/health && echo " <- shim 已回来"
  exit 0
fi
launchctl unload ~/Library/LaunchAgents/com.hermes.rokid-shim-keepalive.plist 2>/dev/null
pkill -f "uvicorn app.main"; pkill -f "python3.11 app.py"; pkill -f "run.sh"; sleep 1
touch $FLAG
cd ~/rokid/h4dex-bridge
BRIDGE_PORT=8790 nohup .venv/bin/python src/main.py >/tmp/h4dex_bridge.log 2>&1 &
sleep 3
echo "local: $(curl -s -m 5 http://127.0.0.1:8790/health)"
echo "tunnel->shim(8790): $(curl -s -m 15 https://rokid2hermes.ccwu.cc/health)"
