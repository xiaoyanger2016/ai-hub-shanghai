# Memory Index

| 文件 | 类型 | 摘要 |
|------|------|------|
| [feedback_pr_workflow.md](feedback_pr_workflow.md) | feedback | PR 流程：禁止直接 PATCH kkday-it 分支、禁止自动 merge，必须人工确认 |
| [feedback_logging.md](feedback_logging.md) | feedback | 日志规范：统一使用 KkdayLogHelper，禁止直接用 Log Facade |
| [reference_jenkins.md](reference_jenkins.md) | reference | Jenkins SIT job URL 及认证信息（kkday-kkpartners-api 部署用）|
| [feedback_output_language.md](feedback_output_language.md) | feedback | Claude 输出语言：所有对话文字一律使用简体中文 |
| [feedback_jenkins_deploy.md](feedback_jenkins_deploy.md) | feedback | Jenkins 部署参数：DEPLOY_GIT_NAME + DEPLOY_GIT_ACCOUNT，PR 前后 account 不同 |
| [feedback_git_commit_workflow.md](feedback_git_commit_workflow.md) | feedback | 提交前必须先运行 git status，避免遗漏用户手动修改和 CLAUDE.md |
| [feedback_bugfix_style.md](feedback_bugfix_style.md) | feedback | 修 bug 不要粗暴删除，用 fallback（?:）在取值源头兼容多种参数键名 |
| [feedback_code_review_workflow.md](feedback_code_review_workflow.md) | feedback | 提交 PR 前必须先运行 /simplify 做 code review，避免被 Copilot 指出低级问题 |
| [reference_api_auth.md](reference_api_auth.md) | reference | KKpartners 两步登录取 x-auth-token 方法（账号/密码位置/host 对照表）|
| [feedback_sit_deploy_confirmation.md](feedback_sit_deploy_confirmation.md) | feedback | 用户回复具体 SIT 环境名时直接触发部署，无需二次确认 |
| [feedback_pr_comment_autoreply.md](feedback_pr_comment_autoreply.md) | feedback | PR 未回复评论自动回复，不询问确认，回复后留记录 |
| [feedback_worklog_autoupdate.md](feedback_worklog_autoupdate.md) | feedback | 工作日志自动更新，不询问确认，更新后展示新增条目 |
| [feedback_pr_monitor_auto.md](feedback_pr_monitor_auto.md) | feedback | PR 监控检查自动执行，不询问确认，结果一次性汇报 |
| [reference_jira.md](reference_jira.md) | reference | Jira URL 从分支名推导、API 认证、PR 后自动转 Review/Demo(id:61) |
| [reference_pr_monitor_jobs.md](reference_pr_monitor_jobs.md) | reference | PR #1062 监控 job 配置，会话重启后自动重建 session cron + remote trigger |
