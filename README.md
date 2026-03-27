# ai-hub-shanghai

集中管理各项目的 Claude AI 配置：memory 记忆文件、specs 规格文档、开发工作流等。

---

## 目录结构

```
ai-hub-shanghai/
├── README.md                  # 本文件：工作流说明 + 新项目接入指南
├── global/
│   ├── initialized_projects.md   # 已初始化项目记录（初始化前先查此文件）
│   ├── speckit/                  # 公共 speckit 配置（新项目初始化时复制）
│   │   ├── init-options.json
│   │   ├── scripts/bash/         # speckit 脚本
│   │   └── templates/            # speckit 模板（spec/plan/tasks/checklist 等）
│   └── templates/
│       ├── requirements-template.md   # 通用需求填写模板（各项目复用）
│       └── CLAUDE.md.template         # 通用 CLAUDE.md 模板（新项目复制使用）
├── scripts/
│   └── project-init.sh        # 一键初始化新项目脚本
└── projects/
    └── <project-name>/
        ├── memory/            # Claude 自动记忆文件（跨会话持久化）
        │   ├── MEMORY.md      # 记忆索引（每次对话自动加载）
        │   └── *.md           # 各类记忆条目（user/feedback/project/reference）
        └── specs/             # 规格文档、需求文档、工作日志
            └── <branch-name>/
                ├── requirements.md   # 需求模板（每个功能分支一份）
                ├── spec.md           # 功能规格（speckit 生成）
                ├── plan.md           # 实现计划（speckit 生成）
                ├── tasks.md          # 任务列表（speckit 生成）
                ├── worklog.md        # 工作日志（自动追加）
                └── ...
```

---

## 完整开发工作流

### 一、需求规划工作流（/speckit.specify 触发）

> **前提：一切操作必须先有 Jira 单**

| 步骤 | 执行方 | 动作 |
|------|------|------|
| **Step 0** | Claude | 确认 Jira ticket 存在，若无则代为创建；推导分支命名 `task/KKPAR-XXXX_描述` |
| **Step 1** | Claude（自动）| 在 `ai-hub-shanghai/projects/<project>/specs/<branch>/` 创建目录，复制 requirements-template.md → requirements.md |
| **Step 1** | Claude | 展示 requirements.md，提示用户填写所有 `[必填]` 字段 |
| **Step 2** | 用户 | 填写完毕后告知 Claude：「需求模板已填写完毕」 |
| **Step 3** | Claude（自动）| 检查并完善 requirements.md；Jira ticket 切换为 `Waiting for Development` |
| **Step 3** | Claude | 询问：是否需要修改，或直接进入 `speckit.plan`？ |
| **Step 4** | Claude | 依序执行：`speckit.plan` → `speckit.tasks` → `speckit.implement` |
| **Step 5** | Claude（自动）| `speckit.tasks` 完成后，为每个任务（T001/T002…）在父 Jira ticket 下创建对应**子任务** |
| **Step 6** | Claude（自动）| 每完成一个任务时，将对应 Jira 子任务切换为 `Review/Demo`，并添加完成内容评论 |

---

### 二、提交前检查工作流（每次 push 前 MUST）

| 步骤 | 动作 |
|------|------|
| Step 1 | `/simplify` 三路并行 code review（reuse / quality / efficiency）|
| Step 2 | 专职 code review 子任务（传入完整 `git diff`，检查命名/安全/错误处理/外部调用/测试覆盖）|
| Step 3 | `./vendor/bin/phpcs`（有错先 `phpcbf` 修复）|
| Step 4 | `./vendor/bin/phpunit --testsuite Unit`（全绿才可继续）|
| Step 5 | `git push` |

---

### 三、PR 流程工作流

| 步骤 | 动作 |
|------|------|
| PR 提交前 | 确认 fork 远端同名分支存在（不存在则从主干创建）|
| PR 提交后 | Jira ticket 自动切换为 `PR` 状态 |
| 每次 push 后 | 等待 `gh pr checks` 全部通过 |
| CI 通过后 | 询问是否部署测试环境（列出所有环境 + 当前将部署的 branch）|
| 收到 reviewer 评论 | 所有评论必须逐条回复（接受改/不改均需说明，不得沉默）|
| PR merge 后 | 询问是否部署测试环境（改用合并后分支）|

---

### 四、测试工作流（提交 PR 前 MUST）

| 步骤 | 动作 |
|------|------|
| Step 1 | 生成 `specs/<branch>/test-checklist.md`（功能点 + 正常/异常场景 + 单测覆盖情况）|
| Step 2 | 展示 checklist，等待用户逐条确认 |
| Step 3 | 完成 Feature Test 后，生成 `api-test-checklist.md`（接口 / 参数 / 预期 / 实际 / 通过？）|
| Step 4 | 有 API 变更时，询问是否本地测试 |
| Step 5 | 有 Web 界面时，询问测试页面 URL（可用 Playwright 自动化验证）|

---

### 五、Worklog 工作流（每次 push / 功能阶段完成后自动）

| 步骤 | 动作 |
|------|------|
| 自动更新 | 追加到 `ai-hub-shanghai/projects/<project>/specs/<branch>/worklog.md` |
| 自动同步 | POST 新增条目到 Jira 评论（ADF 格式）|
| 自动同步 | 按时间戳推算用时，POST 到 Jira Work Log（无时间戳时询问用户）|
| 输出 | `✅ 工作日志已更新，已同步 Jira 评论 & Work Log（用时：Xh Ym）` |

---

### 六、对话启动自检（每次新会话自动静默执行）

| 步骤 | 动作 |
|------|------|
| A1 | `CronList` 检查 PR 监控 cron → 不存在则重建（每 10 分钟）|
| A2 | `RemoteTrigger` 检查 remote trigger enabled → 失效则重启 |
| B | 执行完整 PR 静默检查：状态 / CI / 未回复评论（有问题才通知用户）|

---

## 新项目快速接入

> **最快方式（推荐）**：使用一键初始化脚本：
> ```bash
> # 在 ai-hub-shanghai 目录下执行
> ./scripts/project-init.sh kkday-ota-api-84
> ```
> 脚本会自动完成 Step 1–6，完成后在 Claude Code 中执行 `/speckit.constitution` 即可。
>
> 或者在新项目目录中打开 Claude Code，说「初始化项目配置」，Claude 会自动引导。
>
> 以下是各步骤的详细说明：

### 前置条件

- Claude Code CLI 已安装（`claude` 命令可用，若没有：`npm install -g @anthropic-ai/claude-code`）
- `gh` CLI 已安装并已登录 GitHub
- Jira API token 已获取（`https://id.atlassian.com/manage-profile/security/api-tokens`）
- 两个仓库已 clone 到同级目录：
  ```bash
  git clone git@github.com:<your-org>/<new-project>.git
  git clone git@github.com:<your-org>/ai-hub-shanghai.git
  ```

---

### Step 1 — 初始化 ai-hub-shanghai 项目目录

```bash
AI_HUB=/Applications/ServBay/www/ai-hub-shanghai   # 修改为实际路径
PROJECT_NAME=<new-project>                           # 与仓库名一致

mkdir -p $AI_HUB/projects/$PROJECT_NAME/memory
mkdir -p $AI_HUB/projects/$PROJECT_NAME/specs

cat > $AI_HUB/projects/$PROJECT_NAME/memory/MEMORY.md << 'EOF'
# Memory Index

| 文件 | 类型 | 摘要 |
|------|------|------|
EOF

cd $AI_HUB && git add projects/$PROJECT_NAME/ && git commit -m "init: add $PROJECT_NAME project directory"
```

---

### Step 2 — 在新项目创建 `.claude/settings.local.json`

```bash
PROJECT_DIR=/path/to/<new-project>

mkdir -p $PROJECT_DIR/.claude

cat > $PROJECT_DIR/.claude/settings.local.json << EOF
{
  "autoMemoryDirectory": "$AI_HUB/projects/$PROJECT_NAME/memory/",
  "permissions": {
    "additionalDirectories": ["$AI_HUB/projects/$PROJECT_NAME/"]
  }
}
EOF

# 加入 .gitignore（避免本地绝对路径泄露到 git）
echo ".claude/settings.local.json" >> $PROJECT_DIR/.gitignore
```

> Jira 认证（`JIRA_EMAIL` / `JIRA_TOKEN`）和 Jenkins 认证统一配置在 `~/.claude/settings.json` 的 `env` 段，不放在 settings.local.json。

---

### Step 3 — 配置 Jenkins 认证（若有 CI/CD）

在 `~/.claude/settings.json` 的 `env` 段追加（若复用已有变量则跳过）：

```json
"JENKINS_USER_<ENV>": "<your-jenkins-user>",
"JENKINS_TOKEN_<ENV>": "<your-jenkins-api-token>"
```

---

### Step 4 — 安装 speckit 并执行 constitution

```bash
cd $PROJECT_DIR
npx speckit@latest init
# 交互选项：AI=claude, mode=here, script=sh
```

安装完成后，在 Claude Code 对话中执行 `/speckit.constitution`，建立项目代码规范原则（仅首次，或规范变更时重新执行）。

---

### Step 5 — 编写 CLAUDE.md

复制 `global/templates/CLAUDE-template.md`（若存在）或参考 `projects/kkday-kkpartners-api/` 的 CLAUDE.md，必须包含以下章节：

| 章节 | 说明 |
|------|------|
| Project Overview | 项目目标、用户、技术栈 |
| Common Development Commands | 安装/运行/测试/Lint 命令 |
| Codebase Architecture | 关键目录、API 结构 |
| 变量命名 & 配置项管理规范 | snake_case + 禁止 hardcode |
| 统一错误/成功响应格式 | `metadata.status` + `data` |
| **需求规划工作流**（参考下方「工作流一」）| 修改 Jira project key 和 issuetype id |
| **提交前检查工作流**（参考下方「工作流二」）| 替换为项目实际 Lint/Test 命令 |
| **PR 行为准则**（参考下方「工作流三」）| 修改 fork 账号和 repo |
| **Worklog 同步 Jira 规则**（参考下方「工作流五」）| |
| **对话启动自检**（参考下方「工作流六」）| 替换 PR 编号和 repo |
| Claude 自我进化准则 | memory 写入规则 |

---

### Step 6 — 验证配置

```bash
# 1. Claude 已安装
claude --version

# 2. settings.local.json 格式正确
python3 -m json.tool $PROJECT_DIR/.claude/settings.local.json

# 3. ai-hub-shanghai 目录已创建
ls $AI_HUB/projects/$PROJECT_NAME/memory/MEMORY.md

# 4. speckit 已安装
ls $PROJECT_DIR/.specify/

# 5. constitution 已生成
ls $PROJECT_DIR/.specify/constitution.md

# 6. CLAUDE.md 包含关键章节
grep -c "需求规划工作流\|PR 行为准则\|Worklog" $PROJECT_DIR/CLAUDE.md

# 7. .gitignore 包含 settings.local.json
grep "settings.local.json" $PROJECT_DIR/.gitignore
```

全部通过后，在 `global/initialized_projects.md` 追加记录。

---

### Step 7 — 记录初始化完成

在本仓库 `global/initialized_projects.md` 追加一行：

```markdown
| `<REPO_SLUG>` | `<PROJECT_ROOT>` | <TODAY> | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
```

提交到 ai-hub-shanghai：

```bash
cd $AI_HUB && git add global/initialized_projects.md && git commit -m "init: mark <REPO_SLUG> as fully initialized"
```

---

## 已接入项目

| 项目 | 说明 | 技术栈 |
|------|------|------|
| `kkday-kkpartners-api` | KKpartners 大联盟行销 API Gateway | Laravel 7.3 / PHP 7.3 |

---

## 常用 Jira API 速查

```bash
# 创建任务（issuetype 10005=任务, 10006=子任务）
curl -u "$JIRA_EMAIL:$JIRA_TOKEN" -X POST "https://kkday.atlassian.net/rest/api/3/issue" \
  -H "Content-Type: application/json" \
  -d '{"fields":{"project":{"key":"KKPAR"},"summary":"标题","issuetype":{"id":"10005"}}}'

# 创建子任务
curl -u "$JIRA_EMAIL:$JIRA_TOKEN" -X POST "https://kkday.atlassian.net/rest/api/3/issue" \
  -H "Content-Type: application/json" \
  -d '{"fields":{"project":{"key":"KKPAR"},"parent":{"key":"KKPAR-XXXX"},"summary":"子任务标题","issuetype":{"id":"10006"}}}'

# 查询可用 transitions
curl -u "$JIRA_EMAIL:$JIRA_TOKEN" \
  "https://kkday.atlassian.net/rest/api/3/issue/KKPAR-XXXX/transitions"

# 执行 transition
curl -u "$JIRA_EMAIL:$JIRA_TOKEN" -X POST \
  "https://kkday.atlassian.net/rest/api/3/issue/KKPAR-XXXX/transitions" \
  -H "Content-Type: application/json" \
  -d '{"transition":{"id":"241"}}'

# 添加评论（ADF 格式）
curl -u "$JIRA_EMAIL:$JIRA_TOKEN" -X POST \
  "https://kkday.atlassian.net/rest/api/3/issue/KKPAR-XXXX/comment" \
  -H "Content-Type: application/json" \
  -d '{"body":{"version":1,"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"评论内容"}]}]}}'

# 添加 work log
curl -u "$JIRA_EMAIL:$JIRA_TOKEN" -X POST \
  "https://kkday.atlassian.net/rest/api/3/issue/KKPAR-XXXX/worklog" \
  -H "Content-Type: application/json" \
  -d '{"timeSpent":"2h 30m","started":"2026-03-27T10:00:00.000+0800"}'
```

### KKPAR 项目 Transition ID 对照

| 目标状态 | ID |
|---------|-----|
| To Do | 11 |
| In Progress（In Development）| 21 |
| Review/Demo | 61 |
| Pull Request (PR) | 71 |
| Done | 31 |
| Closed | 211 |
| 规划中 | 231 |
| Waiting for Development | 241 |
| 待测试 | 81 |
