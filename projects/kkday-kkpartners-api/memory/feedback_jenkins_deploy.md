---
name: Jenkins 部署参数规范
description: Jenkins buildWithParameters 的正确参数名及 PR merge 前后的 account 切换规则
type: feedback
---

永远使用 `DEPLOY_GIT_NAME` + `DEPLOY_GIT_ACCOUNT` 两个参数触发部署，禁止猜测参数名（如 `BRANCH`）。

**Why:** 曾两次触发 Jenkins 部署到了 `kkday-it:master`：
1. 第一次用了 `/build`（无参数），Jenkins 使用默认值
2. 第二次用了 `--data "BRANCH=..."`，参数名错误被忽略，Jenkins 仍使用默认值
直到用户截图才发现错误。

**How to apply:**
- `DEPLOY_GIT_NAME` = `branches/<branch名>`（必须加 `branches/` 前缀）
- `DEPLOY_GIT_ACCOUNT`：
  - PR open（未 merge）→ `xiaoyanger2016`
  - PR merge 后 → `kkday-it`
- 若遇到不确定的 Jenkins 参数名，先查看该 job 的 Parameters 页面，不要猜测
