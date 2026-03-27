# API Contracts: KKPAR-1063

**Date**: 2026-03-23 (updated: destinations 字段值改为目的地名称)

所有接口均使用统一响应格式：
- **成功**: `{ "metadata": { "status": "0000", "desc": "success" }, "data": {...} }`
- **错误**: `{ "metadata": { "status": "KKPAR-API-XXXX", "desc": "..." }, "data": null }`

---

## 1. 赞助商品列表（修改）

**Route**: `GET /api/v3/manage/sponsor-application/get-prod-list`
**Auth**: `v3.check.auth.login` + `v3.check.manage.permissions`
**Change**: 响应每条 item 新增 `destinations` 字段，值为对应 locale 的目的地名称逗号拼接字符串

### Request（无变化）

```json
{
  "sponsor_application_oid": 123,
  "cid": "abc",
  "prod_oid": 456,
  "status": "Start",
  "member_level": "01",
  "main_promotion_region": "TW",
  "prod_use_date_start": "2026-01-01",
  "prod_use_date_end": "2026-12-31",
  "page": 1,
  "page_size": 20,
  "extra": { "locale": "zh-tw" }
}
```

### Response（变化：item 新增 destinations，值为目的地名称）

```json
{
  "metadata": { "status": "0000", "desc": "success" },
  "data": {
    "list": [
      {
        "sponsor_application_oid": 123,
        "prod_oid": 456,
        "prod_name": "台北101半日遊",
        "status": "Start",
        "destinations": "台灣,日本",
        "cid": "abc",
        "site_name": "My Blog",
        "affiliate_member": { "member_level": "02" },
        "main_promotion_region": "TW",
        "prod_use_date": "2026-06-01",
        "create_time": "2026-03-01 10:00:00",
        "update_time": "2026-03-20 15:30:00"
      }
    ],
    "pagination": {
      "total": 50,
      "page": 1,
      "page_size": 20
    }
  }
}
```

**降级场景 1（Product API 失败）**: `destinations` = `""`，HTTP 200。
**降级场景 2（geo-svc 失败 + 缓存未命中）**: `destinations` = `"TW,JP"`（code 字符串），HTTP 200。
**降级场景 3（geo-svc Redis 命中）**: 正常返回名称，无 API 调用开销。

---

## 2. 同步下载 CSV（新增路由）

**Route**: `POST /api/v3/manage/sponsor-application/download-csv`
**Controller**: `DownloadCsvController@download`
**Auth**: `v3.check.auth.login` + `v3.check.manage.permissions`

### Request

```json
{
  "json": {
    "action": "SPONSOR_APPLICATION_PROD",
    "sponsor_application_oid": 123,
    "cid": "abc",
    "status": "Start",
    "page": 1,
    "page_size": 100
  },
  "extra": {
    "locale": "zh-tw"
  }
}
```

### Response — 成功（数据量 ≤ 1000）

HTTP 200 with headers:
```
Content-Type: text/csv; charset=utf-8
Content-Disposition: attachment; filename="sponsor_application_prod_20260323.csv"
```

CSV 内容（11列，表头为 locale 对应语系，「商品目的地」列为目的地名称）：
```
商品贊助單申請編號,商品OID,商品名稱,商品目的地,審查結果,網站名稱(CID),聯盟等級,主要推廣地區,出發日期,申請日期,最後更新日期
123,456,台北101半日遊,"台灣,日本",Start,My Blog(abc),冒險家,TW,2026-06-01,2026-03-01 10:00:00,2026-03-20 15:30:00
```

### Response — 超过同步上限（> 1000）

```json
{
  "metadata": {
    "status": "KKPAR-API-XXXX",
    "desc": "数据量超过同步下载上限，请使用异步下载"
  },
  "data": null
}
```

---

## 3. 异步下载 CSV（新增路由）

**Route**: `POST /api/v3/manage/sponsor-application/async-download-csv`
**Controller**: `DownloadCsvController@asyncDownload`
**Auth**: `v3.check.auth.login` + `v3.check.manage.permissions`

### Request

```json
{
  "json": {
    "action": "SPONSOR_APPLICATION_PROD",
    "download_username": "admin@kkday.com",
    "sponsor_application_oid": 123,
    "status": "Start"
  },
  "extra": {
    "locale": "zh-tw"
  }
}
```

### Response — 任务创建成功

```json
{
  "metadata": { "status": "0000", "desc": "success" },
  "data": {
    "task_id": "abc123",
    "action": "SPONSOR_APPLICATION_PROD",
    "status": "UNPROCESSED",
    "file_name": "sponsor_application_prod_20260323.csv"
  }
}
```

### Response — 已有进行中任务

```json
{
  "metadata": { "status": "KKPAR-API-XXXX", "desc": "任务处理中，请勿重复提交" },
  "data": null
}
```

---

## 4. 查询异步任务状态（新增路由）

**Route**: `GET /api/v3/manage/sponsor-application/check-download-task`
**Controller**: `DownloadCsvController@checkDownloadTask`

### Request

```
GET /api/v3/manage/sponsor-application/check-download-task?json[action]=SPONSOR_APPLICATION_PROD
```

### Response

```json
{
  "metadata": { "status": "0000", "desc": "success" },
  "data": {
    "task_id": "abc123",
    "action": "SPONSOR_APPLICATION_PROD",
    "status": "PROCESSING",
    "current_page": 3,
    "total_page": 10,
    "file_url": null
  }
}
```

---

## Internal Contract: GeoCountryNameService

**Class**: `App\Services\v3\Api\GeoCountryNameService`

```php
// Input: ISO codes + locale
// Output: map of code → name (fallback: code itself)
public function resolveNames(array $codes, string $locale): array
// e.g. resolveNames(['TW','JP'], 'zh-tw') → ['TW'=>'台灣','JP'=>'日本']
```

**Redis**: hash=`kkpar:geo`, field=`country:{locale}:{code}`, TTL=604800s
**Upstream**: `GeoService::getCountryCodeList(string $locale): array`（新增方法）

---

## Error Codes

All error scenarios reuse existing codes in `config/api_status.php` via existing `DownloadCsvService`/`DownloadCsvController` logic — no new codes needed for download actions.
