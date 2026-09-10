# about-rokid-hermes

乐奇（Rokid）AR 眼镜 ↔ Hermes Agent 语音助手的部署与运维档案。
运行实例：2026-09-10 上线并实测通过（持续对话、唤醒词、拍照链路均正常）。

## 架构

```
Rokid 眼镜 ──(唤醒"乐奇，打开拉克丝")──▶ 灵珠云 (rizon.rokid.com, 47.98.x)
    ──HTTPS POST /metis/agent/api/sse──▶ Cloudflare Tunnel rokid2hermes.ccwu.cc
    ──▶ h4dex-bridge  127.0.0.1:8790   (AK 鉴权 + SSE 转译 + 多轮记忆)
    ──▶ Hermes Gateway api_server  127.0.0.1:8642  (Bearer API_SERVER_KEY)
    ──▶ Hermes Agent（toolsets: terminal/web/file/memory/delegation…）
```

- 桥 = fork [h4dex/rokid-hermes-bridge](https://github.com/h4dex/rokid-hermes-bridge) v3.0.0（Python 3.12 + FastAPI），本地补丁见 `docs/patched-main.py.0910`
- 会话隔离：session_id = `rokid:<user_id>:<YYYYMMDD>`
- 协议细节见上游仓库 `docs/lingzhu-protocol.md`

## 本机路径

| 路径 | 说明 |
|---|---|
| `~/rokid/h4dex-bridge/` | 运行实例（`.env` 存密钥，勿入库） |
| `~/rokid/lingzhu-hermes/swap_h4dex.sh` | 新旧桥切换/回滚 |
| `~/.hermes/scripts/rokid-{shim-keepalive,sse-probe,tunnel-keepalive}.sh` | 守护探针（cron 每 5 分钟） |
| LaunchAgent `com.hermes.gateway` | Gateway（绑定 127.0.0.1:8642） |
| `cloudflared tunnel run rokid2hermes` | 出洞（本机仅发起外连，零监听端口暴露） |

## 安全基线（0910 审计落地）

1. **AK 强度**：43 字符 `secrets.token_urlsafe`；旧 32 位 AK 已轮换并销毁
2. **Gateway 只绑 127.0.0.1**，公网唯一入口 = CF Tunnel → 桥
3. **CF WAF**：`http_ratelimit` 规则限 `/api/sse` 爆破（Free 计划 period≥10s）；GeoIP 规则因新加坡出口误伤已禁用
4. **鉴权通道**：桥只认 `Authorization: Bearer <ak>` 头或 body 顶层 `ak` 字段（`X-API-Key` 无效；日志里 `用户[8836…]` 是 user_id 不是 AK）
5. **后台改 AK**：rizon.rokid.com → 空间项目 → 第三方智能体 → 编辑 → token 输入框（React 受控组件，自动化要用 native setter + dispatch input 事件）

## 运维手册

```bash
bash scripts/rokid-shim-keepalive.sh   # 桥挂了拉起
bash scripts/rokid-sse-probe.sh        # 深度探测（真发一条 SSE），rc=0 即健康
curl -s http://127.0.0.1:8790/health   # 秒级存活
# 改 .env 后必须重启桥才生效：
pkill -f "h4dex-bridge/.venv/bin/python src/main.py"; bash scripts/rokid-shim-keepalive.sh
```

已知坑（全录于 skill `rokid-glasses-dev`）：
- 换 AK 前先在灵珠后台同步，否则云端缓存旧 key → 401 → 眼镜端"正在思考"卡死
- 重启 Gateway 用 `launchctl kickstart -k gui/501/ai.hermes.gateway`，先确认旧进程退净，防 Errno 48 端口占用导致 api_server 起不来
- 长任务静默 >10s 会触发客户端超时 → main.py 已打心跳补丁（wait_for 先行检查）
- 测试 payload 用 `message` 数组（非 `messages`），字段错会假阴性

## 备份

双镜像：GitHub `oujuejun/about-rokid-hermes`（private）+ NAS 裸仓 `kira851023@10.0.0.39:/volume2/git/about-rokid-hermes.git`（走 opc-git wrapper，新仓需在 DSM `/usr/bin/git-*` wrapper 的路径映射内）。
