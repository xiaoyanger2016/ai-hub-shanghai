---
name: PR 监控自动执行
description: 对话开始时立刻执行 PR 检查 + 定期 cron，不询问二次确认
type: feedback
---

**每次对话开始时，必须主动做两件事（不得等用户指令）：**

1. **重建 cron**：调用 CronList，若无「PR #1062」job 则立刻用 reference_pr_monitor_jobs.md 配置重建
2. **立刻跑一次 PR 检查**：
   - `gh pr view 1062 --repo kkday-it/kkday-kkpartners-api --json state --jq '.state'`
   - CI check（background kill 防挂起）
   - 未回复评论检查 → 有则自动回复

包括：
- gh pr view（状态）
- gh pr checks（CI，background kill 防挂起）
- gh api comments（找未回复评论并自动回复，用 /replies endpoint）

完成后一切正常则完全静默；有异常才通知。

**Why:** cron 只在 idle 时触发，对话期间不会自动插入；用户期望每次对话开始时就主动检查，不需要手动触发。

**How to apply:** 对话第一条消息处理完之前，后台并行完成 A（重建 cron）+ B（PR 检查）。正常结果不输出任何内容。
