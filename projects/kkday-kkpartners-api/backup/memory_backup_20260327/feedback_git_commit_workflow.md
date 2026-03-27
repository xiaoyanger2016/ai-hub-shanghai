---
name: git_commit_workflow
description: 提交代码前必须先运行 git status，确保不遗漏用户手动修改和 CLAUDE.md 等文件
type: feedback
---

提交代码前，**必须先运行 `git status`**，查看所有已修改/未追踪的文件，再决定哪些文件需要 add。

**Why:** 曾两次将用户手动修改的文件（如 `DownloadCsvService.php` 中用户重新添加的代码行）以及 `CLAUDE.md` 的变更遗漏在 commit 之外。原因是只按 Claude 自己修改的文件名逐一 add，没有检查全局状态。

**How to apply:**
1. 每次准备 `git add` 前，先执行 `git status`，浏览所有 modified / untracked 文件
2. 对比列表，把用户手动编辑的文件和 CLAUDE.md 一并纳入 staging
3. 再执行 `git diff --cached` 确认暂存内容符合预期，最后才 commit
