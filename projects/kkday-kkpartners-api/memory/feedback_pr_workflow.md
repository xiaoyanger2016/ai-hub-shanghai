---
name: PR 提交与合并工作流规范
description: kkday-kkpartners-api fork PR 流程：禁止直接更新远程 kkday-it 分支，禁止自动 merge，必须人工确认
type: feedback
---

禁止直接通过 GitHub API PATCH 更新 `kkday-it` 远程分支的分支指针。禁止自动 merge PR，必须由人工在 GitHub 上确认合并。

**Why:** 直接 PATCH `kkday-it:branch` 的 ref 会绕过 PR review 流程，把代码悄悄推进远程主干，等同于强推，破坏了 code review 机制。Merge 必须由人工在 GitHub 确认，Claude 不得代劳。

**How to apply:**
- 每次有新 commit 需要合并到 `kkday-it`，只允许：
  1. `git push origin <branch>` 推送到 `xiaoyanger2016` fork
  2. 用 `gh pr create` 从 `xiaoyanger2016:<branch>` → `kkday-it:<branch>` 开一个新 PR
  3. 把 PR URL 告知用户，等待人工 review & merge
- 禁止使用 `gh api repos/kkday-it/.../git/refs/heads/... -X PATCH` 更新 kkday-it 任何分支
- 禁止使用 `gh pr merge` 或任何自动合并操作
- `kkday-it` 侧的同名 base branch 不存在时，才允许通过 `gh api` **创建**（POST）新分支，但不得更新（PATCH）已有分支
