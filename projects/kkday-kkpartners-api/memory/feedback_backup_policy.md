---
name: 备份文件存放规范
description: 所有备份文件统一存放到 ai-hub-shanghai 对应项目的 backup 目录，不留在项目本身
type: feedback
---

所有备份文件必须放到 ai-hub-shanghai 对应项目的 backup 目录，禁止留在项目目录下。

**Why:** 避免备份文件污染项目仓库，集中管理便于清理和查找。

**How to apply:**
- kkday-kkpartners-api 备份路径：`/Applications/ServBay/www/ai-hub-shanghai/projects/kkday-kkpartners-api/backup/`
- 命名规范：`<内容>_backup_<YYYYMMDD>`，如 `specs_backup_20260327`、`memory_backup_20260327`
- 备份完成后及时 commit 到 ai-hub-shanghai 仓库
