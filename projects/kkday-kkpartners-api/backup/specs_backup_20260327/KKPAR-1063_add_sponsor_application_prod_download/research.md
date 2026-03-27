# Research: KKPAR-1063 赞助商品列表新增目的地欄位 + 下载 CSV

**Date**: 2026-03-23 (updated with geo-svc clarifications)
**Branch**: `task/KKPAR-1063_add_sponsor_application_prod_download`

---

## Decision 1: destinations 数据注入位置

**Decision**: 在 `SponsorApplicationService::getProdList()` 中，获取列表后批量调用 Product API，再经 geo-svc 转换为目的地名称，注入 `destinations` 字段。

**Rationale**: Controller 不含业务逻辑（Constitution I）；Service 层已持有列表数据，可一次性提取所有 prod_oid 批量查询，避免 N+1 调用。

**Alternatives considered**:
- Controller 层注入：违反 Constitution I，拒绝。
- 每条记录单独调用 Product API：N+1 问题，性能不可接受。

---

## Decision 2: Product API 调用方式

**Decision**: 使用 `ProductService::getProductInfo(['prod_oids' => [...], 'locale' => getLocaleProperty()])` 批量查询，取 `data.{prod_oid}.destinations.destinations.*.code`。

**Rationale**: `ProductService::getProductInfo()` 已支持 `prod_oids` 参数，无需修改。

**Error handling**: try-catch `\Throwable`；失败时所有 item 的 `destinations` 置为 `''`，写 `Log::error()`，不中断列表返回。

---

## Decision 3: destinations 字段值格式

**Decision**: 字段值为对应 locale 的目的地**名称**逗号拼接字符串（如 `"台灣,日本"`），不含 code。

**Rationale**: 目的是人类可读展示，code 是实现细节不应暴露给消费方。由 clarification Q1 确认。

---

## Decision 4: geo-svc 集成 — 使用现有 GeoService adapter

**Decision**: 使用 `app/Services/Gateways/Geo/GeoService.php` 中的现有 geo-svc adapter，并新增 `getCountryCodeList(string $locale)` 方法调用 ISO 3166-1 alpha-2 国家/地区代码列表端点。

**Rationale**: GeoService 已封装 `CurlHelper`，配置在 `config/gateway.php` 的 `geo` 区段（`KK_SVC_GEO_BASE_URL`），符合项目统一外部调用策略（Constitution IV）。重用现有 adapter 无需引入新第三方库。

**API**: `(v2) 國家/地區代碼列表 (ISO 3166-1 alpha-2)` — 返回结构：
```json
{
  "data": [
    { "code": "TW", "languages": { "zh-tw": { "value": "台灣" }, "en": { "value": "Taiwan" } } },
    ...
  ]
}
```
名称取值路径：`data[].languages.{locale}.value`，匹配字段：`data[].code`。

**Alternatives considered**:
- CommonService::getIsoCountries()：属于不同 svc 数据源，且不提供按 locale 的名称字段，拒绝。
- 直接 GuzzleHttp 调用：违反 Constitution IV 禁止 raw Guzzle 在 controller/service，拒绝。

---

## Decision 5: Redis 缓存架构 — 按 (locale, code) 缓存单个名称

**Decision**: 使用 `RedisHelper::hset/hget`，以 hash table `kkpar:geo` 为 Redis hash 名，field key 为 `country:{locale}:{code}`，value 为目的地名称字符串，TTL 604800s（7 天）。

**Rationale**:
- 与项目现有 `RedisHelper` 模式一致（CommonService 用 `common-svc` hash table 缓存 iso_country，TTL 14 天）。
- 按 (locale, code) 存储粒度允许按需查找，无需每次加载全量列表。
- geo-svc 返回全量列表，首次 miss 时一次性填充当前 locale 所有 code，后续命中率极高（SC-006: 95%+）。
- 由 clarification Q2/Q3 确认。

**Key format**:
```
hash table : kkpar:geo
field key  : country:{locale}:{code}   e.g. "country:zh-tw:TW"
value      : 目的地名称字符串            e.g. "台灣"
TTL        : 604800 秒（7 天）
```

**Cache warm-up strategy**: Lazy — 首次 miss 时调用 geo-svc 获取该 locale 全量列表，批量写入 Redis（所有 code），后续请求直接命中。

---

## Decision 6: geo-svc 失败降级策略

**Decision**: geo-svc 不可用且 Redis 缓存未命中时，`destinations` 降级返回 code 字符串（如 `"TW,JP"`），写 `Log::error()`，不阻断主流程。

**Rationale**: ISO code 对运营人员仍有意义（优于空字符串）；与 clarification Q4 确认。

**降级层次**:
1. Redis 命中 → 直接返回缓存名称 ✓
2. Redis 未命中 + geo-svc 成功 → 写 Redis + 返回名称 ✓
3. Redis 未命中 + geo-svc 失败 → 写 error log + 返回 code 字符串 ⚠️
4. Product API 失败（取不到 code）→ destinations = `""` ⚠️

---

## Decision 7: 下载架构

**Decision**: 复用 `DownloadCsvController` 的三个方法，通过新增 `action=SPONSOR_APPLICATION_PROD` 路由匹配到新的 `DownloadSponsorApplicationProdService` client。destinations 字段的名称转换逻辑封装在私有 `injectDestinations()` 中，被列表接口和下载 client 共同使用（避免重复）。

**Rationale**: FR-012 明确要求复用现有下载控制器；destinations 名称逻辑集中一处维护。

---

## Decision 8: GeoCountryNameService — 新的独立 Service 类

**Decision**: 新建 `app/Services/v3/Api/GeoCountryNameService.php`，封装"code → 名称"的完整查找逻辑（Redis 检查 → geo-svc 调用 → 批量缓存 → 降级）。

**Rationale**: `injectDestinations()` 逻辑需同时在 `SponsorApplicationService`（列表）和 `DownloadSponsorApplicationProdService`（下载）中使用。将其提取为独立 Service 类避免代码重复，且职责单一，易于单独测试。

**Interface**:
```php
// 查找单组 code 的名称（批量，同一 locale）
public function resolveNames(array $codes, string $locale): array
// 返回: ['TW' => '台灣', 'JP' => '日本', ...]
// 失败时某 code 降级为 code 本身
```

---

## Decision 9: 路由位置

**Decision**: 在 `routes/api_v3.php` 中 manage/sponsor-application 路由组内追加 3 条下载路由，指向 `DownloadCsvController`。

---

## Decision 10: 同步/异步下载上限

**Decision**: 沿用现有配置，不新增配置项。
- 同步上限：`config('common.report.max_total')` = 1000
- 异步上限：`config('common.report.async_max_total')` = 30000

---

## Existing Patterns Summary

| Pattern | Location | Notes |
|---------|----------|-------|
| Redis hget/hset | `RedisHelper.php` | hash_table + field_key + value + ttl |
| ISO country 缓存范例 | `CommonService.php` | hash=`common-svc`, field=`iso_country:.{locale}`, TTL=1209600s (14天) |
| GeoService adapter | `GeoService.php` + `GeoServiceApi.php` | CurlHelper, base_url=`KK_SVC_GEO_BASE_URL`, timeout=40s |
| Product API call | `SponsorApplicationService::getProdInfo()` | `ProductService::getProductInfo(['prod_mids',...])` |
| Download client interface | `DownloadSettlementToolService` | `getList / setCsvTitle / setCsvData / setFileName / sendEmail` |
| Switch-case action routing | `DownloadCsvService::setClient()` | 现有 3 cases |
| Lang file structure | `resources/lang/zh-tw/download.php` | `csv_title[]` + `csv_data.{enum}[]` |

---

## Open Items / Assumptions to Verify at Implementation

1. **geo-svc ISO 3166-1 alpha-2 端点路径**: 需确认 endpoint URL（如 `/v2/countries`），参考 Jira wiki 文档或 GeoServiceApi 已有调用。
2. **GeoService::getCountryCodeList() 端点**: 若 GeoService 已有对应方法则直接使用，否则新增方法。
3. **geo-svc languages key 格式**: 确认 locale key 是否与项目 locale（`zh-tw`, `en`, `ja`, `ko`, `zh-hk`）完全匹配，还是需要映射（如 `zh-tw` → `zh_TW`）。
4. **Redis hash TTL**: `RedisHelper::hset()` 的 TTL 参数实际调用的是 `Redis::expire(hash_table, ttl)`（hash 级别），而非单个 field 级别。需确认是否需要按 field 过期，或接受整个 hash 级别的 TTL。
5. **`RedisHelper::hset` TTL 行为**: 检查实际实现，确认 TTL 是 hash 整体还是每次 hset 刷新整个 hash 的 TTL。
