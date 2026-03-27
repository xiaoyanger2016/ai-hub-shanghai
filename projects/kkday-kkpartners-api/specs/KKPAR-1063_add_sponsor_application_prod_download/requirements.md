# 需求填写模板 — KKpartners API



---

## 基本信息


| 字段              | 内容                                             |
| --------------- | ---------------------------------------------- |
| **Jira Ticket** | KKPAR-1063                                |
| **分支名称**        | task/KKPAR-1063_add_sponsor_application_prod_download |
| **PRD 链接**      | 无                                           |
| **SA/SD 文档链接**  | 无                                           |
| **优先级**         | P1                                        |
| **预计上线日期**      | —                                |


---

## 需求描述 [必填]

管理端「赞助商品列表」需新增「商品目的地」栏位展示（目的地名称，支持多语系），并新增支持以 `action=SPONSOR_APPLICATION_PROD` 触发同步/异步 CSV 下载功能，CSV 包含 11 个字段，表头随 locale 切换语系，「商品目的地」列显示对应语系目的地名称而非代码。

---

## 影响范围 [必填]

- **API 接口**（新增/修改/删除）：
  - 修改接口（新增 destinations 字段）：`GET /api/v3/sponsor-applications/products`
  - 修改接口（新增 SPONSOR_APPLICATION_PROD action）：`POST /api/v3/download/csv`
  - 修改接口（新增 SPONSOR_APPLICATION_PROD action）：`POST /api/v3/download/asyncDownload`
  - 修改接口（新增 SPONSOR_APPLICATION_PROD action）：`GET /api/v3/download/asyncDownloadStatus`
- **涉及模块**：
  - Controller：`app/Http/Controllers/Api/v3/DownloadCsvController.php`
  - Service：`app/Services/v3/Api/DownloadSponsorApplicationProdService.php`（新增）
  - Service：`app/Services/v3/Api/ProductInfoService.php`（新增，商品信息 Redis 缓存）
  - Service：`app/Services/v3/Api/GeoCountryNameService.php`（新增，目的地名称 Redis 缓存）
  - Service：`app/Services/v3/Api/CommonService.php`（修改，getMarketRegions 加缓存）
  - Service：`app/Services/v3/Api/DownloadCsvService.php`（修改，修复 json.page / end_date fallback）
  - Gateway：`app/Services/Gateway/Geo/`（现有 GeoService adapter）
  - Config：`config/common.php`（sponsor_application_prod 配置）、`config/redis_keys.php`（TTL 常量）
- **下游依赖**：
  - KKpartners Service API：`ManageSponsorApplicationService::getProdList()`（现有）
  - Product API：批量商品信息查询（`prod_oids`）
  - geo-svc：国家/地区代码列表 API（ISO 3166-1 alpha-2，v2 destinations 端点）

---

## 接口设计（若有新增/修改接口）[条件必填]

### 1. 赞助商品列表（新增 destinations 字段）

```
GET /api/v3/sponsor-applications/products
Header: x-auth-token: required
Query:
  locale: string, optional, 语系（en/zh-tw/zh-hk/ja/ko），影响 destinations 名称语系
  extra.channel: string, required, MANAGE
  ...其他现有筛选参数
```

Response 新增字段：
```json
{
  "metadata": { "status": "0000", "desc": "success" },
  "data": {
    "list": [
      {
        "...": "现有字段",
        "destinations": "台灣,日本"
      }
    ]
  }
}
```

### 2. 同步下载（新增 action）

```
POST /api/v3/download/csv
Header: x-auth-token: required
Body:
  json.action: string, required, SPONSOR_APPLICATION_PROD
  json.locale: string, optional, en/zh-tw/zh-hk/ja/ko
  json.start_date: string, optional, YYYY-MM-DD
  json.end_date: string, optional, YYYY-MM-DD
  json.status: string, optional, 审查状态筛选
  extra.channel: string, required, MANAGE
```

### 3. 异步下载（新增 action）

```
POST /api/v3/download/asyncDownload
Body:
  json.action: string, required, SPONSOR_APPLICATION_PROD
  json.download_username: string, required
  ...其他同同步下载筛选参数
```

### 4. 异步任务状态查询

```
GET /api/v3/download/asyncDownloadStatus
Query:
  action: SPONSOR_APPLICATION_PROD
  extra.channel: MANAGE
```

---

## 测试方法 [必填]

### 本地单元/集成测试

- Unit Test：`tests/Unit/Services/v3/Api/DownloadSponsorApplicationProdServiceTest.php`
  - 场景1：destinations 正常注入（名称正确）
  - 场景2：Product API 失败降级（destinations 为空字符串）
  - 场景3：geo-svc 失败缓存未命中降级（destinations 返回 code）
  - 场景4：destinations 为空数组时输出空字符串
  - 场景5：member_level 枚举转换（01/02/03/04 → 各语系文字）
  - 场景6：同步下载超出限制返回错误
  - 场景7：异步下载重复任务返回错误
  - 场景8：CSV 表头随 locale 变化
  - 场景9：end_date fallback（ended_date 兼容）
  - 场景10：json.page 正确传递（非顶层 page）
- Unit Test：`tests/Unit/Services/v3/Api/ProductInfoServiceTest.php`
  - T030–T034：Redis 缓存命中/未命中/失效场景
- Feature Test：`tests/Feature/Api/SponsorApplicationProdDownloadApiTest.php`（`@group integration`，CI 排除）
  - 8 cases：完整 API 请求验证

### SIT 环境验证

- **API 测试**：
  ```
  # 同步下载
  curl -X POST https://sit.kkday.com/api/v3/download/csv \
    -H "x-auth-token: xxx" \
    -d '{"json":{"action":"SPONSOR_APPLICATION_PROD","locale":"zh-tw"},"extra":{"channel":"MANAGE"}}'

  # 赞助商品列表（验证 destinations 字段）
  curl -X GET "https://sit.kkday.com/api/v3/sponsor-applications/products?extra[channel]=MANAGE&locale=zh-tw" \
    -H "x-auth-token: xxx"
  ```
- **Web 界面测试**（若有）：
  - 测试页面 URL：SIT 管理后台「赞助商品列表」页

---

## 验收标准 [必填]

- SC-001：赞助商品列表在 Redis 缓存命中时，P95 响应增幅 ≤ 500ms
- SC-002：Product API 或 geo-svc 不可用时，列表降级成功率 100%，不出现 500 错误
- SC-003：同步下载 CSV 包含正确的 11 列，表头语系与 locale 一致，destinations 列显示名称而非代码
- SC-004：异步下载任务创建后，状态轮询正确反映处理中/完成/失败
- SC-005：同一 action 并发异步任务，保证同时只有一个进行中（重复提交返回错误）
- SC-006：geo-svc Redis 缓存命中率首次预热后 ≥ 95%（TTL 7 天内相同 code+locale 均命中）

---

## 风险与注意事项 [可选]

- geo-svc destinations API 首次调用需预热，冷启动时有额外延迟
- Product API 批量查询 `prod_oids` 数量过大时需注意 URL 长度限制
- PHP 7.3 不支持 named args / nullsafe `?->` / union types，所有新代码需兼容 7.3
- DownloadCsvService 已有逻辑较复杂，修改需注意 json.page vs 顶层 page 的区别（已修复）
- member_level 各语系翻译：01:探険家/Explorer、02:冒険家/Adventurer、03:遠航家/Voyager、04:開拓者/Pioneer
