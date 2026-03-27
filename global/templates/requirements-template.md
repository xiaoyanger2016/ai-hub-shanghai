# 需求填写模板

> 使用说明：
> 1. 填充所有 `[必填]` 标记的内容
> 2. `[可选]` 内容如无则删除该行或填「无」
> 3. 填写完成后告知 Claude：「需求模板已填写完毕」
> 4. Claude 会检查完善、切换 Jira 状态，并询问是否进入 speckit.plan

---

## 基本信息

| 字段              | 内容                                                  |
| --------------- | --------------------------------------------------- |
| **Jira Ticket** | {{JIRA_PREFIX}}-XXXX [必填]                           |
| **分支名称**        | task/feature/fix-bug/hotfix/{{JIRA_PREFIX}}-XXXX_描述 [必填] |
| **PRD 链接**      | [可选]                                                |
| **SA/SD 文档链接**  | [可选] System Analysis / System Design                |
| **优先级**         | P0 / P1 / P2 / P3 [必填]                              |
| **预计上线日期**      | YYYY-MM-DD [可选]                                     |

---

## 需求描述 [必填]

> 简要描述本次需求的背景和目标，1-3 句话说清楚「为什么做」和「做什么」。

---

## 影响范围 [必填]

- **API 接口**（新增/修改/删除）：
  - 新增接口：`[METHOD] /api/...`
  - 修改接口：`[METHOD] /api/...`
  - 无接口变更
- **涉及模块**：
  - Controller：
  - Service：
  - Config：
  - 其他：
- **下游依赖**：
  - 内部服务 API：[描述依赖的接口，可选]
  - 第三方服务：[可选]

---

## 接口设计（若有新增/修改接口）[条件必填]

### Request

```
METHOD /api/...
Header: Authorization / x-auth-token: required
Body/Query:
  param1: string, required, 说明
  param2: integer, optional, 说明
```

### Response

```json
{
  "metadata": { "status": "0000", "desc": "success" },
  "data": {}
}
```

---

## 测试方法 [必填]

### 本地单元/集成测试

- Feature Test：`tests/Feature/...`
  - 场景1（正常）：___
  - 场景2（异常）：___
- Unit Test：`tests/Unit/...`
  - 场景1：___

### 测试环境验证

- **API 测试**：
  ```bash
  curl -X POST https://<env>.example.com/api/... \
    -H "Authorization: Bearer <token>"
  ```
- **Web 界面测试**（若有）：
  - 测试页面 URL：[可选]
  - 测试步骤：
    1. ___
    2. ___

---

## 验收标准 [必填]

- SC-001：___
- SC-002：___
- SC-003（异常处理）：___

---

## 风险与注意事项 [可选]

- ___
