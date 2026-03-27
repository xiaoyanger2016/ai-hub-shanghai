---
name: 工作日志自动更新
description: 更新工作日志不询问确认，更新后展示给用户查看
type: feedback
---

每次完成一批改动后，自动更新 worklog.md，**不得向用户二次确认是否更新**。

更新完成后，在对话中简短展示本次新增的日志条目供用户查阅。

**Why:** 用户认为工作日志是常规记录动作，每次确认是不必要的打扰。做好记录才是进步的关键。

**How to apply:**
- worklog 实际路径：`/Applications/ServBay/www/ai-hub-shanghai/projects/kkday-kkpartners-api/specs/<branch>/worklog.md`
- specs 已从项目 git 迁移到 ai-hub-shanghai，**不再是项目相对路径 `specs/<branch>/worklog.md`**
- 每次 push 新 commit 或完成一个功能阶段后，直接追加记录，然后输出「✅ 工作日志已更新：[新增条目摘要]」
- 更新后记得同步 commit 到 ai-hub-shanghai 仓库
