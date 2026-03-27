---
name: Jenkins SIT
description: kkday-kkpartners-api 项目所有 SIT 测试环境的 Jenkins 部署信息
type: reference
---

## 认证信息

- **用户名**: `eric.yang@kkday.com`（存于 `~/.claude/settings.json` → `env.JENKINS_USER_SIT`）
- **Token**: 存于 `~/.claude/settings.json` → `env.JENKINS_TOKEN_SIT`

### ⚠️ 环境变量注入问题

`$JENKINS_USER_SIT` / `$JENKINS_TOKEN_SIT` 在 Claude Code 的 Bash shell 中**不会自动注入**，需直接硬编码读取：

```bash
JENKINS_USER="eric.yang@kkday.com"
JENKINS_TOKEN="$(cat ~/.claude/settings.json | python3 -c "import sys,json; print(json.load(sys.stdin)['env']['JENKINS_TOKEN_SIT'])")"
```

或直接使用 `~/.claude/settings.json` 中的值（`env.JENKINS_TOKEN_SIT`）硬编码到 curl 命令中。

## 测试环境列表

| 环境 | 用途 | Jenkins Job URL |
|------|------|-----------------|
| **sit-00** | 对外测试（默认 develop） | https://jenkins.sit.kkday.com/view/ap-00-develop(%E5%B0%8D%E5%A4%96%E6%B8%AC%E9%A9%97)/job/sit-ap-00-kkday-kkpartners-api/ |
| **sit-03** | FA 财务模块测试 | https://jenkins.sit.kkday.com/view/ap-03-FA/job/sit-ap-03-kkday-kkpartners-api/ |
| **sit-05** | WWW_M 模块测试 | https://jenkins.sit.kkday.com/view/ap-05-WWW_M/job/sit-ap-05-kkday-kkpartners-api/ |

## Jenkins 参数（正确参数名）

Jenkins Job 使用两个参数，**不是 `BRANCH`**：

| 参数名 | 说明 | 格式示例 |
|--------|------|---------|
| `DEPLOY_GIT_NAME` | 分支名，需加 `branches/` 前缀 | `branches/task/KKPAR-1063_xxx` |
| `DEPLOY_GIT_ACCOUNT` | Git 账号 | `xiaoyanger2016` 或 `kkday-it` |

## 部署 Branch 规则（PR merge 前后不同）

| 时机 | DEPLOY_GIT_ACCOUNT | DEPLOY_GIT_NAME |
|------|-------------------|-----------------|
| **PR open（未 merge）** | `xiaoyanger2016` | `branches/<branch名>` |
| **PR merge 后** | `kkday-it` | `branches/<branch名>` |

## 触发命令模板

```bash
# PR 未 merge（fork 分支）
curl -X POST "{JOB_URL}buildWithParameters" \
  -u "$JENKINS_USER_SIT:$JENKINS_TOKEN_SIT" \
  --data-urlencode "DEPLOY_GIT_NAME=branches/<branch名>" \
  --data-urlencode "DEPLOY_GIT_ACCOUNT=xiaoyanger2016"

# PR merge 后（kkday-it 分支）
curl -X POST "{JOB_URL}buildWithParameters" \
  -u "$JENKINS_USER_SIT:$JENKINS_TOKEN_SIT" \
  --data-urlencode "DEPLOY_GIT_NAME=branches/<branch名>" \
  --data-urlencode "DEPLOY_GIT_ACCOUNT=kkday-it"
```

## 询问部署时的格式要求

询问时必须注明将部署的 account 和 branch，例如（PR 未 merge）：

> 「PR CI 已通过，是否需要部署到 SIT？
> 将部署：`xiaoyanger2016:task/KKPAR-1063_xxx`（PR 未 merge，使用 fork 分支）
> - sit-00 / sit-03 / sit-05 / 不需要」

PR merge 后：

> 「PR 已 merge，是否需要部署到 SIT？
> 将部署：`kkday-it:task/KKPAR-1063_xxx`
> - sit-00 / sit-03 / sit-05 / 不需要」
