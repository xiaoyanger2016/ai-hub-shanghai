# Implementation Plan: 赞助商品列表新增目的地欄位 + 下载 CSV

**Branch**: `task/KKPAR-1063_add_sponsor_application_prod_download` | **Date**: 2026-03-23 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/KKPAR-1063_add_sponsor_application_prod_download/spec.md`

---

## Summary

在赞助商品列表接口中注入 `destinations` 字段（来自 Product API destinations codes → geo-svc `getDestinations()` 名称转换，Redis 按 (locale, code) 缓存 7 天），并新增 `DOWNLOAD_REPORT_SPONSOR_APPLICATION_PROD` action 支持同步/异步 CSV 下载，复用现有 `DownloadCsvController` 三接口。核心新增：`GeoCountryNameService`（code→名称，调用 geo-svc destinations API，含 Redis 缓存）、`DownloadSponsorApplicationProdService`（CSV 下载 client，复用 `ManageSponsorApplicationService::getProdList()`）、GeoService 修正 `getCountryCodeList()` endpoint 并新增 `getDestinations()` 调用。

---

## Technical Context

**Language/Version**: PHP 7.3（Laravel 7.3，EOL 但当前生产版本）
**Primary Dependencies**: Laravel 7.x, GuzzleHttp（通过现有 adapter 间接使用），Redis（RedisHelper），GeoService（现有 adapter，调用 `destinations` 端点）
**Storage**: Redis（`kkpar:geo:destination:{locale}` hash，TTL 7 天）；KKpartners Service 管理任务记录；`storage/app/public/` 存放异步 CSV 文件
**Testing**: PHPUnit（Feature + Unit）
**Target Platform**: Linux server（API Gateway）
**Project Type**: API Gateway / web-service
**Performance Goals**: P95 响应增幅 ≤ 500ms（Redis 命中时 geo-svc 零额外开销）
**Constraints**: PHP 7.3 兼容（无 named args / nullsafe `?->` / match expr / union types）；复用现有 Redis/GeoService/DownloadCsv 架构
**Scale/Scope**: 同步上限 1000 行；异步上限 30000 行；Redis 缓存预计 < 300 个 code × 5 locale = 1500 keys，极轻量

---

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. 无业务逻辑在 Controller | ✅ PASS | destinations 注入、geo-svc 调用、Redis 缓存均在 Service 层 |
| II. v3-Only 新开发 | ✅ PASS | 新 Service 类在 `app/Services/v3/Api/`；GeoService 扩展在已有 Gateway adapter |
| III. 统一响应格式 | ✅ PASS | 复用 DownloadCsvController，错误码来自 api_status.php |
| IV. 外部调用策略 | ✅ PASS | geo-svc 通过现有 GeoService adapter（CurlHelper，40s timeout）；Redis 命中时无外部调用；失败时降级 |
| V. 测试要求 | ⚠️ REQUIRED | Feature + Unit tests 见 Phase E |
| VI. PHP 7.3 兼容 | ✅ PASS | 无禁用语法；`\Throwable` PHP 7.0+ 可用 |

---

## Project Structure

### Documentation (this feature)

```text
specs/KKPAR-1063_add_sponsor_application_prod_download/
├── spec.md              # Feature specification (updated with geo-svc clarifications)
├── plan.md              # This file
├── research.md          # Phase 0 research decisions
├── data-model.md        # Entities, GeoCountry, Redis cache schema
├── contracts/
│   └── api.md           # API + internal service contracts
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (affected files)

```text
app/
├── Http/Controllers/Api/v3/
│   └── DownloadCsvController.php                          [MODIFY] getValidateDownLoadAction()
├── Services/
│   ├── Gateways/Geo/
│   │   └── GeoService.php                                 [MODIFY] 新增 getCountryCodeList()
│   └── v3/Api/
│       ├── Manage/
│       │   └── SponsorApplicationService.php              [MODIFY] getProdList()
│       ├── GeoCountryNameService.php                      [NEW] code→名称转换 + Redis 缓存
│       ├── DownloadCsvService.php                         [MODIFY] setClient()
│       └── DownloadSponsorApplicationProdService.php      [NEW] CSV 下载 client

config/
└── common.php                                             [MODIFY] report section

resources/lang/
├── en/download.php                                        [MODIFY]
├── zh-tw/download.php                                     [MODIFY]
├── zh-hk/download.php                                     [MODIFY]
├── ja/download.php                                        [MODIFY]
└── ko/download.php                                        [MODIFY]

routes/
└── api_v3.php                                             [MODIFY] sponsor-application group

tests/
├── Feature/
│   ├── SponsorApplicationProdListTest.php                 [NEW] US1 列表接口
│   └── SponsorApplicationProdDownloadTest.php             [NEW] US2/US3 下载接口
└── Unit/
    ├── GeoCountryNameServiceTest.php                      [NEW]
    └── DownloadSponsorApplicationProdServiceTest.php      [NEW]
```

---

## Implementation Phases

### Phase A — Config & Registration（无业务风险，先行）

**A1. config/common.php** — 新增 action 常量：
```php
'report_sponsor_application_prod' => 'DOWNLOAD_REPORT_SPONSOR_APPLICATION_PROD',
```
> **实现偏差**：原计划结构 `sponsor_application_prod.action`；实际放在 `send_mail.type` 下的 `report_sponsor_application_prod` key。

**A2. DownloadCsvController** — `getValidateDownLoadAction()` 追加新 action：
```php
config('common.report.sponsor_application_prod.action'),
```

**A3. DownloadCsvService** — `setClient()` 追加 case：
```php
case config('common.report.sponsor_application_prod.action'):
    $this->client = app()->make(DownloadSponsorApplicationProdService::class);
    break;
```

**A4. routes/api_v3.php** — manage/sponsor-application 路由组追加：
```php
Route::post('sponsor-application/download-csv', 'DownloadCsvController@download');
Route::post('sponsor-application/async-download-csv', 'DownloadCsvController@asyncDownload');
Route::get('sponsor-application/check-download-task', 'DownloadCsvController@checkDownloadTask');
```

---

### Phase B — GeoService 扩展

**B1. GeoService::getCountryCodeList()** — 修正已有方法，endpoint 从错误的 `v2/country-codes` 改为 `v2/iso-countries`：

```php
public function getCountryCodeList(string $locale, array $headers = []): array
```

- 调用 `v2/iso-countries`，参数 `lang={locale}&withAllLang=true`
- 遍历 `response.data`，取 `languages.{locale}.value`
- 若某 code 无对应 locale 名称，**直接跳过**（不再 fallback 为 code 本身）
- 失败时抛出异常（由调用方捕获处理）

> **实现偏差**：原计划调用 `v2/country-codes`；实际确认正确 endpoint 为 `v2/iso-countries`，并新增 `headers` 参数支持透传。空名称处理改为跳过（原计划降级为 code 本身）。

---

### Phase C — GeoCountryNameService（核心新类）

**文件**: `app/Services/v3/Api/GeoCountryNameService.php`

> **实现偏差（重要）**：原计划调用 `GeoService::getCountryCodeList()` 获取全量 ISO 国家列表再过滤。实际确认应使用 `GeoService::getDestinations()` + `destinationCodeList` 参数**按需查询**，原因是 Product API 返回的 destinations code 是目的地 code（非 ISO 国家 code），需对应 geo-svc 的 `destinations` 端点。

**实际设计**：
- Redis key prefix 改为 `kkpar:geo:destination:{locale}`（原计划 `kkpar:geo`）
- `resolveNames()` 内部：
  - Step 1: 检查 Redis 缓存（key = `{redis_table}` hash，field = `{code}`）
  - Step 2: cache miss → 调用 `GeoService::getDestinations(['lang'=>locale, 'destinationCodeList'=>implode(',', codes)])`
  - Step 3: 解析响应 `data.{code}.languages.{locale}.value` 或 `data.{code}.name`
  - Step 4: 批量写入 Redis，TTL = 7 天
  - Step 5: geo-svc 失败 → 降级，写 `geo_country_name_service: geo-svc failed` error log
- **注**：Redis 缓存读取在 SIT 验证期间临时禁用（改为始终 miss），待验证正确后恢复

**Redis schema（实际）**：
```
hash key : kkpar:geo:destination:zh-tw
field    : {destination_code}   (e.g. "TW", "JP", "SG")
value    : "台灣" / "日本" / "新加坡"
TTL      : 7 天（hash 级别）
```

---

### Phase D — SponsorApplicationService 修改（列表注入）

**D1. SponsorApplicationService::getProdList()** — 注入 destinations（含 geo-svc 名称转换）：

核心流程不变，以下为实际实现与原计划的偏差：

| 项目 | 原计划 | 实际实现 |
|------|--------|---------|
| Product API 参数名 | `prod_oids` (array) | `prod_mids` (逗号拼接字符串) |
| destinations code 提取 | `data_get($response, "data.{$prodOid}.destinations.destinations.*.code", [])` | `collect(data_get($prodInfo, 'destinations.destinations', []))->pluck('code')->unique()->values()->all()` |
| all_codes 去重 | `array_unique(array_merge(...))` | `collect(array_merge(...))->unique()->values()->all()` |
| code→name fallback | 返回 code 本身 | 跳过该 code（不加入 names 数组） |
| `foreach (&$item)` | `unset($item)` 收尾 | 去掉 `unset($item)` |
| 调试日志 | 无 | 移除临时 `KkdayLogHelper::info` debug log |

---

### Phase E — DownloadSponsorApplicationProdService（CSV 下载 client）

**文件**: `app/Services/v3/Api/DownloadSponsorApplicationProdService.php`

> **实现偏差（重要）**：原计划在此服务内部重复 destinations 注入逻辑。实际重构为直接复用 `ManageSponsorApplicationService::getProdList()`，消除代码重复，destinations 注入统一由 `SponsorApplicationService::injectDestinations()` 处理。

| 方法 | 原计划 | 实际实现 |
|------|--------|---------|
| `getList()` | 调用 `KkpartnerServiceGatewayV3::getSponsorApplicationProdList()` + 自己注入 destinations | 委托 `ManageSponsorApplicationServiceV3::getProdList()`，destinations 统一由后者注入 |
| `setCsvTitle()` | `trans('download.sponsor_application_prod.csv_title')` | 同原计划 |
| `setCsvData()` | 11 列 | 11 列；`site_name`/`cid` 取值路径改为 `sponsor_application.site_name` / `sponsor_application.cid` |
| `setFileName()` | `'sponsor_application_prod_' . date('YmdHis') . '.csv'` | 同原计划 |
| `setEmailFileName()` | **未计划** | **新增**：从 task file_name 去掉时间戳后缀，生成邮件附件名 |
| `sendEmail()` | 返回 `[]` | **完整实现**：调用 `KkpartnerServiceGatewayV3::sendEmail()`，传入附件 base64、模板数据（收件人、日期、schedule） |

---

### Phase F — 多语系 Lang 文件

在 5 个 locale 的 `resources/lang/{locale}/download.php` 中追加 `sponsor_application_prod` 区段。

**各 locale csv_title（11 列顺序）**:

| # | zh-tw/zh-hk | en | ja | ko |
|---|------------|----|----|-----|
| 1 | 商品贊助單申請編號 | Application OID | 商品スポンサー申請番号 | 상품 스폰서 신청 번호 |
| 2 | 商品OID | Product OID | 商品OID | 상품 OID |
| 3 | 商品名稱 | Product Name | 商品名 | 상품명 |
| 4 | 商品目的地 | Destinations | 目的地 | 목적지 |
| 5 | 審查結果 | Review Result | 審査結果 | 심사 결과 |
| 6 | 網站名稱(CID) | Website(CID) | ウェブサイト名(CID) | 웹사이트명(CID) |
| 7 | 聯盟等級 | Affiliate Level | アフィリエイトレベル | 제휴 등급 |
| 8 | 主要推廣地區 | Primary Promotion Region | 主要プロモーション地域 | 주요 홍보 지역 |
| 9 | 出發日期 | Departure Date | 出発日 | 출발일 |
| 10 | 申請日期 | Application Date | 申請日 | 신청일 |
| 11 | 最後更新日期 | Last Updated Date | 最終更新日 | 최종 업데이트일 |

**各 locale member_level 翻译**：

| Code | zh-tw/zh-hk | en | ja | ko |
|------|------------|----|----|-----|
| 01 | 探險家 | Explorer | エクスプローラー | 탐험가 |
| 02 | 冒險家 | Adventurer | アドベンチャラー | 모험가 |
| 03 | 遠航家 | Voyager | ボイジャー | 항해자 |
| 04 | 開拓者 | Pioneer | パイオニア | 개척자 |

---

### Phase G — 测试

**G1. Feature Test** — `tests/Feature/SponsorApplicationProdListTest.php` (US1)

| 场景 | 验证重点 |
|------|---------|
| destinations 正常（Redis 命中） | destinations = 目的地名称字符串 |
| destinations 正常（geo-svc 调用） | destinations = 名称，Redis 被写入 |
| Product API 失败降级 | destinations = `""`, HTTP 200 |
| geo-svc 失败 + 缓存未命中 | destinations = code 字符串（如 `"TW,JP"`）, HTTP 200 |

**G2. Feature Test** — `tests/Feature/SponsorApplicationProdDownloadTest.php` (US2/US3)

| 场景 | 验证重点 |
|------|---------|
| sync download 成功 | HTTP 200, Content-Type: text/csv |
| sync download 非法 action | 统一错误格式 |
| async download 成功 | response.data.action = SPONSOR_APPLICATION_PROD |
| check-download-task | response 含 status 字段 |

**G3. Unit Test** — `tests/Unit/GeoCountryNameServiceTest.php`

| 场景 | 验证重点 |
|------|---------|
| 全部 Redis 命中 | 返回缓存名称，无 geo-svc 调用 |
| 部分 miss → geo-svc 成功 | 正确名称，Redis 被批量写入 |
| geo-svc 失败 | miss 的 code 降级为 code 本身，写 error log |
| resolveNames([], locale) | 返回空数组 |

**G4. Unit Test** — `tests/Unit/DownloadSponsorApplicationProdServiceTest.php`

| 场景 | 验证重点 |
|------|---------|
| setCsvTitle() | 返回 11 元素数组 |
| setCsvData() 正常行 | 各列格式正确 |
| setCsvData() member_level 枚举 | '01' → '探險家'（zh-tw） |
| setCsvData() 未知 member_level | 输出原始值 |
| setCsvData() 空日期 | 输出 `""` |

---

## Complexity Tracking

无 Constitution 违规。GeoCountryNameService 作为独立 Service 类符合单一职责，不违反任何约束。

---

## Implementation Order

```
A1~A4 (config + routes，可并行)
B1    (GeoService 扩展)
C     (GeoCountryNameService，依赖 B1)
D     (SponsorApplicationService 修改，依赖 C)
E     (DownloadSponsorApplicationProdService，依赖 C)
F     (lang 文件 × 5，可与 B/C/D/E 并行)
G     (测试，依赖 A~F 全部完成)
```

---

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|-----------|
| Redis hset TTL 是 hash 级别（非 field 级别） | Medium | 实现时验证 `RedisHelper::hset` 实际行为；若无 field 级 TTL，则接受整个 hash 7 天过期 |
| geo-svc languages locale key 格式不匹配 | Low | 实现时验证（如 `zh-tw` vs `zh_TW`），必要时加映射表 |
| geo-svc endpoint 路径未确认 | Low | 查阅 Jira wiki 或现有 GeoServiceApi 调用记录，确认端点 path |
| Product API 超时增加列表延迟 | Medium | try-catch 降级（destinations=`""`），现有 3s timeout |
| PHP 7.3 兼容 | Low | 已检查语法，`\Throwable` PHP 7.0+ 可用 |
| 5 个 lang 文件漏加 locale | Medium | tasks.md 中每个 locale 独立 task |
