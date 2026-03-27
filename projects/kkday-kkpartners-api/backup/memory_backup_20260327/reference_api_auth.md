---
name: KKpartners API 登录鉴权流程
description: 自动化测试或本地调试时获取 x-auth-token 的两步登录方式，含账号、密码存放位置、channel 值
type: reference
---

## 获取 x-auth-token（两步）

### 账号信息
- 账号：`eric.yang@kkday.com`
- 密码：存放在 `~/.claude/settings.json` → `env.KKPARTNER_API_LOGIN_PASSWORD`（当前值 `123456`）
- manage channel：`MANAGE`（来自 `config/common.php` → `account.channel.manage`）

### Step 1 — 获取 authorizationCode

```bash
curl -s -X POST "https://kkday-kkpartners-api.local/api_test/v2/kkday-auth-login" \
  -H "Content-Type: application/json" -k \
  -d '{
    "json": {"account": "eric.yang@kkday.com", "password": "123456"},
    "extra": {"channel": "KKPARTNERS"}
  }'
# 取 response.data.authorizationCode
```

### Step 2 — 换取 token

```bash
curl -s -X POST "https://kkday-kkpartners-api.local/api/v3/manage/account/login" \
  -H "Content-Type: application/json" -k \
  -d "{
    \"json\": {\"authorization_code\": \"<authorizationCode>\"},
    \"extra\": {\"channel\": \"MANAGE\"}
  }"
# 取 response.data.token → 即 x-auth-token
```

## 环境 Host 对照表

| 变量 | Host |
|------|------|
| KKPAR_HOST_LOCAL | https://kkday-kkpartners-api.local |
| KKPAR_HOST_SIT-00 | https://api-kkpartners.sit.kkday.com |
| KKPAR_HOST_SIT-03 | https://api-kkpartners-03.sit.kkday.com |
| KKPAR_HOST_SIT-05 | https://api-kkpartners-05.sit.kkday.com |
| KKPAR_HOST_STAGE-05 | https://api-kkpartners.stage.kkday.com |

**默认打本地（LOCAL），只有用户明确要求才打 SIT/STAGE。**

## 注意
- token 有效期约 5 分钟（JWT exp 字段），过期后重走两步流程
- 测试文件中建议封装为 `getAuthToken()` 方法，自动判断过期后重获取
