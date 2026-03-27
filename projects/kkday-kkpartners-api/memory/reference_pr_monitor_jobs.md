---
name: PR 监控 Job 配置
description: PR #1062 监控的两个 job 配置，用于会话压缩或重启后自动重建
type: reference
---

## 背景

PR #1062 (kkday-it/kkday-kkpartners-api) 需要持续监控 CI、未回复评论、merge 状态。
Session cron 在会话重启/上下文压缩后会失效，每次对话开始时必须检查并重建。

## 每次新会话启动时 MUST 执行（无需等用户指令）

1. 调用 `CronList` 检查是否有包含「PR #1062」的 cron job
2. 若无 → 立即用下方配置重建
3. 调用 `RemoteTrigger {action: "list"}` 确认 `trig_01XhC1VN2VnfJdTXe2MaGjVd` enabled=true

## Session Cron 配置（每 10 分钟，静默）

**关键**：每个步骤必须独立执行，不可用 `&&` 串联。`gh pr checks` 必须加 `timeout 30`，否则 CI pending 时会挂起。

```
cron: "*/10 * * * *"
recurring: true
prompt（完整内容）：

静默检查 PR #1062 (kkday-it/kkday-kkpartners-api)，只在以下情况才通知用户：

步骤 1：检查 PR 状态（若 MERGED 则通知并停止）
  gh pr view 1062 --repo kkday-it/kkday-kkpartners-api --json state --jq '.state'

步骤 2：检查 CI（macOS 无 timeout，用 background kill 限时 15 秒）
  gh pr checks 1062 --repo kkday-it/kkday-kkpartners-api 2>&1 &
  PID=$!; sleep 15 && kill $PID 2>/dev/null &
  wait $PID 2>/dev/null || true
  - 若输出含 fail/error → 通知「CI ❌ 失败：[check名称]」
  - 其余情况（pass/pending/超时）→ 静默

步骤 3：查找未回复评论（独立执行）
  gh api "repos/kkday-it/kkday-kkpartners-api/pulls/1062/comments?per_page=100" \
    --jq '[.[] | select(.in_reply_to_id != null) | .in_reply_to_id] as $replied |
          [.[] | select(.in_reply_to_id == null) | select(.id as $id | $replied | index($id) == null)]'
  - 若有未回复评论 → 用 /replies endpoint 逐条回复，回复后通知「已自动回复 N 条：[ID列表]」
  - 若无 → 静默

步骤 4：一切正常时完全静默，不输出任何内容。
```

**注意**：
- 步骤间不用 `&&` 串联，独立执行互不影响
- 回复评论用 `/replies` endpoint，不能用 `-F in_reply_to`
- `gh pr checks` pending 状态会挂起，必须 `timeout 30`

## Remote Trigger 配置（每小时，云端）

- ID: `trig_01XhC1VN2VnfJdTXe2MaGjVd`
- 名称: PR-1062 Monitor
- 频率: `0 * * * *`（每小时）
- 管理页面: https://claude.ai/code/scheduled/trig_01XhC1VN2VnfJdTXe2MaGjVd
- CCR 环境中使用 `GH_TOKEN=$GITHUB_TOKEN gh ...` 执行所有 gh 命令

**已知限制**：CCR 环境无本地 gh auth，依赖 `$GITHUB_TOKEN`（仅限 xiaoyanger2016 fork 的权限）。
若 `kkday-it` repo 访问失败，remote trigger 会静默失败，以 session cron 为主要监控。
