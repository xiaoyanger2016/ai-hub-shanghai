---
name: code_review_workflow
description: 每次提交 PR 前必须先运行 /simplify 对本次改动做一遍 code review
type: feedback
---

每次提交 PR **之前**，必须先执行 `/simplify` 对本次分支改动做一遍 code review，检查：
- 重复代码是否可以提取为方法/trait
- 无用参数、冗余状态、魔法字符串
- 循环中的低效操作（array_merge O(n²)、in_array 去重、N+1 Redis hget）
- catch 块是否过于宽泛或重复

**Why:** Copilot 多次指出代码漏洞（重复格式化、无用参数、低效去重），说明提交前未做自检。运行 simplify 可在 PR review 前主动发现并修复这些问题。

**How to apply:** 在执行 `git add + git commit + git push` 之前，先调用 Skill("simplify") 对改动做 review，修复发现的问题后再提交。
