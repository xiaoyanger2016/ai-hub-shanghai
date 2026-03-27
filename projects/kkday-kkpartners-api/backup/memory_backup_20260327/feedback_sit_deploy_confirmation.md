---
name: SIT 部署确认行为
description: 用户回复具体环境名时直接触发部署，无需二次确认
type: feedback
---

当询问用户是否需要部署 SIT 测试环境，用户直接回复了具体环境名（如 `sit-05`、`sit-00`、`sit-03`）时，立即触发对应环境的部署，**不得再次询问确认**，直接执行 Jenkins buildWithParameters 直到部署触发成功。

**Why:** 用户觉得回复环境名后还要再次确认是多余步骤，影响效率。

**How to apply:** 只要用户的回复内容是合法的 SIT 环境名，视为隐式 yes，直接调用对应 Jenkins Job URL 触发部署并汇报结果。
