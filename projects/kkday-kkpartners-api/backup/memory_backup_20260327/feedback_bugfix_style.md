---
name: bugfix_style
description: 修 bug 时不要粗暴删除逻辑，应在取值处加 fallback 兼容多种键名/调用方
type: feedback
---

修复命名不一致的 bug 时，**不要直接删掉"多余"的赋值行**，而应在取值源头加 fallback，兼容所有合法调用方。

**Why:** 删除 `end_date` 覆写行后，只传 `end_date` 的调用方无法正常生成带日期的文件名，导致功能回归。正确写法是 `ended_date ?: end_date`，在 `$file_name_params` 初始化处统一处理，无需在各分支里补丁。

**How to apply:** 遇到"两种键名/参数名"的兼容问题，优先在赋值处用 `?:` fallback，而不是删掉某一侧或在每个分支重复赋值。
