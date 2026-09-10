#!/usr/bin/env bash
# 回归：pending确认窗口内，无关/近似指令句不得吞真问题（"听对话。"事故）
set -u
cd ~/rokid/lingzhu-hermes
PY=/Users/lacus/.hermes/hermes-agent/venv/bin/python3.11
AK=$(cat .ak_test)
U="regress-$(date +%s)"

send() { # $1=text -> prints answer text
  "$PY" - "$AK" "$U" "$1" <<'EOF'
import json,sys,httpx
ak,user,q=sys.argv[1],sys.argv[2],sys.argv[3]
body={"message_id":"r-"+str(abs(hash(q))%9999),"agent_id":"a","user_id":user,
      "message":[{"role":"user","type":"text","text":q}]}
ans=""
with httpx.Client(timeout=60) as c:
    with c.stream("POST","http://127.0.0.1:8790/metis/agent/api/sse",json=body,
                  headers={"Content-Type":"application/json","Authorization":f"Bearer {ak}"}) as r:
        for line in r.iter_lines():
            line=line.strip()
            if line.startswith("data:") and line[5:].strip()!="[DONE]":
                try: d=json.loads(line[5:])
                except Exception: continue
                if d.get("type")=="answer": ans+=d.get("answer_stream") or ""
print(ans[:80])
EOF
}

fail=0
r1=$(send "换个话题"); echo "1) 换个话题       -> $r1"
[[ "$r1" == *"要开新对话吗"* ]] || fail=1
r2=$(send "听对话。"); echo "2) 听对话。(含'对话')" >&2; echo "   shim应答        -> $r2"
if [[ "$r2" == *"我们重新来过"* ]]; then echo "   FAIL: 被误判为确认→轮换"; fail=1; fi
r3=$(send "是"); echo "3) 是              -> $r3"
[[ "$r3" == *"重新来过"* ]] || fail=1
echo "=== RESULT: $([ $fail -eq 0 ] && echo PASS || echo FAIL)"
