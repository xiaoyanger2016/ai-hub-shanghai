---
name: Jira 链接与工作流
description: Jira ticket URL 格式、完整工作流状态、transition ID 对照表
type: reference
---

## URL 格式

`https://kkday.atlassian.net/browse/KKPAR-{number}`

**URL 推导规则：** Jira 编号直接来自分支名（如 `task/KKPAR-1063_xxx` → `KKPAR-1063`），无需询问用户。

## 认证

`$JIRA_EMAIL` / `$JIRA_TOKEN`（已在 `~/.claude/settings.json` 配置）

## KKPAR 项目完整工作流

```
New Request
  → In Development
  → Review/Demo
  → PR                  ← PR 提交后应切换到此状态
  → REVIEW TEST CASE
  → Waiting for QA
  → Testing
  → Waiting for Stage
  → REVIEW TEST CASE
  → Wait For Release
```

## API Endpoints

- 查询当前状态：`GET /rest/api/3/issue/{KEY}?fields=status`
- 查询可用 transitions：`GET /rest/api/3/issue/{KEY}/transitions`
- 执行转换：`POST /rest/api/3/issue/{KEY}/transitions`  body: `{"transition":{"id":"<id>"}}`

## Transition ID 对照（从 Review/Demo 出发已验证）

| 目标状态 | transition id |
|---------|---------------|
| Pull Request (PR) | 71 |
| To Do | 11 |
| In Progress | 21 |
| Done | 31 |
| Closed | 211 |
| 规划中 | 231 |
| Waiting for Development | 241 |

## 自动化规则

PR push + CI pass 后，执行：
1. 查询当前 ticket transitions
2. 找到 `Pull Request` 对应 id（通常为 71）
3. 执行转换，将 ticket 切到 `PR` 状态
