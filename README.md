# ai-hub-shanghai

集中管理各项目的 Claude AI 配置：memory 记忆文件、specs 规格文档、开发文档等。

## 目录结构

```
ai-hub-shanghai/
├── global/                    # 全局通用配置（预留）
└── projects/
    └── <project-name>/
        ├── memory/            # Claude 自动记忆文件
        │   ├── MEMORY.md      # 记忆索引
        │   └── *.md           # 各类记忆条目
        └── specs/             # 规格文档、PRD、设计文档
            └── <branch>/
```

## 接入方式（方案 A）

各项目 CLAUDE.md 保持在项目 git 仓库中，本仓库只管 memory + specs。

在项目根目录创建 `.claude/settings.local.json`（加入 .gitignore）：

```json
{
  "autoMemoryDirectory": "~/path/to/ai-hub-shanghai/projects/<project-name>/memory/",
  "permissions": {
    "additionalDirectories": ["~/path/to/ai-hub-shanghai/projects/<project-name>/"]
  }
}
```
