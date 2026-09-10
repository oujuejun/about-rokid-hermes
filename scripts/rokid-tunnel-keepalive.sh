#!/bin/bash
# rokid2hermes named tunnel 守护：掉了就拉起（launchd 之外的兜底，手动跑或 cron 用）
if ! pgrep -f 'cloudflared tunnel run rokid2hermes' >/dev/null; then
  nohup cloudflared tunnel run rokid2hermes >> /tmp/cf_named.log 2>&1 &
  echo "restarted $(date)"
else
  echo "alive"
fi
