# Data Model: KKPAR-1063

**Date**: 2026-03-23 (updated with geo-svc + Redis)

---

## Entities

### SponsorApplicationProd（赞助商品记录，来自 KKpartners Service）

| Field | Type | Source | Notes |
|-------|------|--------|-------|
| `sponsor_application_oid` | int | KKpartners Service | 赞助单申请编号 |
| `prod_oid` | int | KKpartners Service | 商品 OID |
| `prod_name` | string | KKpartners Service | 商品名称 |
| `status` | string | KKpartners Service | 审查结果枚举 |
| `cid` | string | KKpartners Service | 网站 CID |
| `site_name` | string | KKpartners Service | 网站名称 |
| `main_promotion_region` | string | KKpartners Service | 主要推广地区 |
| `prod_use_date` | string\|null | KKpartners Service | 出发日期，格式 Y-m-d |
| `create_time` | string\|null | KKpartners Service | 申请日期，格式 Y-m-d H:i:s |
| `update_time` | string\|null | KKpartners Service | 最后更新日期，格式 Y-m-d H:i:s |
| `affiliate_member.member_level` | string | KKpartners Service | 联盟等级，枚举 01/02/03/04 |
| `destinations` | string | **Product API + geo-svc（新增）** | 目的地名称逗号拼接（locale 对应语系），如 `"台灣,日本"`；降级层次见下 |

---

### ProductDestination（来自 Product API，提供目的地 code）

| Field | Type | Path in Response | Notes |
|-------|------|-----------------|-------|
| `code` | string | `data.{prod_oid}.destinations.destinations[].code` | ISO 3166-1 alpha-2 代码，如 "TW" |

**查询参数**：
```php
ProductService::getProductInfo([
    'prod_oids' => [1001, 1002, ...],
    'locale'    => getLocaleProperty(),
])
```

---

### GeoCountry（来自 geo-svc API，ISO 3166-1 alpha-2 国家/地区列表）

| Field | Type | Path in Response | Notes |
|-------|------|-----------------|-------|
| `code` | string | `data[].code` | ISO 3166-1 alpha-2，如 "TW" |
| `name` | string | `data[].languages.{locale}.value` | 对应 locale 的目的地名称 |

**geo-svc API**: `(v2) 國家/地區代碼列表 (ISO 3166-1 alpha-2)`
**Adapter**: `GeoService::getCountryCodeList(string $locale): array`（新增方法）
**Response 示例**:
```json
{
  "data": [
    { "code": "TW", "languages": { "zh-tw": { "value": "台灣" }, "en": { "value": "Taiwan" } } },
    { "code": "JP", "languages": { "zh-tw": { "value": "日本" }, "en": { "value": "Japan" } } }
  ]
}
```

---

### GeoCountryCache（Redis 缓存条目）

| Dimension | Value |
|-----------|-------|
| Redis 类型 | Hash（通过 `RedisHelper::hget/hset`） |
| Hash Table | `kkpar:geo` |
| Field Key | `country:{locale}:{code}`，如 `country:zh-tw:TW` |
| Value | 目的地名称字符串，如 `"台灣"` |
| TTL | 604800 秒（7 天），设在 hash table 级别 |
| 写入时机 | geo-svc 首次调用成功后，批量写入当前 locale 所有 code |

---

### ReportDownloadTask（异步任务记录，由 KKpartners Service 管理）

此实体已存在，无需修改。新增 `SPONSOR_APPLICATION_PROD` action 后，现有逻辑自动处理。

| Field | Value for this feature |
|-------|----------------------|
| `action` | `SPONSOR_APPLICATION_PROD` |
| `status` | UNPROCESSED → PROCESSING → PROCESSED / CANCELED |

---

## destinations 注入流程（含 geo-svc）

```
产品列表获取成功
    ↓
提取所有 prod_oid（去重、过滤空值）
    ↓
[空列表] → 跳过 Product API，所有 destinations = ""
    ↓
[非空] → 调用 ProductService::getProductInfo()
    ├─ 失败/超时 → Log::error()，destinations = ""，不中断
    └─ 成功 → 取 destinations.*.code 列表
               ↓
         调用 GeoCountryNameService::resolveNames(codes, locale)
             ↓
         对每个 code：RedisHelper::hget('kkpar:geo', "country:{locale}:{code}")
             ├─ 全部命中 → 直接使用缓存名称
             └─ 有 miss → 调用 GeoService::getCountryCodeList(locale)
                           ├─ 失败 → Log::error()，miss 的 code 降级为 code 本身
                           └─ 成功 → 批量 hset 写 Redis（全量 locale 列表，TTL 604800s）
                                     使用名称（若某 code 无 languages.{locale}.value → code 本身）
             ↓
         implode(',', $names)  →  destinations 字段值
```

---

## GeoCountryNameService 接口

```php
namespace App\Services\v3\Api;

class GeoCountryNameService
{
    /**
     * 将 ISO code 数组转换为对应 locale 的目的地名称数组
     *
     * @param  string[] $codes   ISO 3166-1 alpha-2 codes, e.g. ['TW', 'JP']
     * @param  string   $locale  e.g. 'zh-tw', 'en', 'ja', 'ko', 'zh-hk'
     * @return array<string,string>  ['TW' => '台灣', 'JP' => '日本']
     *                               降级时 code 本身作为 value
     */
    public function resolveNames(array $codes, string $locale): array;
}
```

---

## member_level 枚举映射

| Code | zh-tw/zh-hk | en | ja | ko |
|------|------------|----|----|-----|
| `01` | 探險家 | Explorer | エクスプローラー | 탐험가 |
| `02` | 冒險家 | Adventurer | アドベンチャラー | 모험가 |
| `03` | 遠航家 | Voyager | ボイジャー | 항해자 |
| `04` | 開拓者 | Pioneer | パイオニア | 개척자 |
| 其他 | 原始值 | 原始值 | 原始值 | 原始值 |

---

## CSV 字段顺序

| 序号 | CSV 标题 (zh-tw) | 数据来源 | 格式处理 |
|------|---------------|---------|---------|
| 1 | 商品贊助單申請編號 | `sponsor_application_oid` | 直接输出 |
| 2 | 商品OID | `prod_oid` | 直接输出 |
| 3 | 商品名稱 | `prod_name` | 直接输出 |
| 4 | 商品目的地 | `destinations` | 直接输出（已为 locale 名称逗号字符串） |
| 5 | 審查結果 | `status` | 直接输出 |
| 6 | 網站名稱(CID) | `site_name . '(' . cid . ')'` | 拼接 |
| 7 | 聯盟等級 | `affiliate_member.member_level` | trans() 枚举转换 |
| 8 | 主要推廣地區 | `main_promotion_region` | 直接输出 |
| 9 | 出發日期 | `prod_use_date` | Y-m-d，空时输出 `""` |
| 10 | 申請日期 | `create_time` | Y-m-d H:i:s，空时输出 `""` |
| 11 | 最後更新日期 | `update_time` | Y-m-d H:i:s，空时输出 `""` |

---

## Validation Rules（getList 参数）

与 `SponsorApplicationController::getProdList()` 一致（无变化）。
