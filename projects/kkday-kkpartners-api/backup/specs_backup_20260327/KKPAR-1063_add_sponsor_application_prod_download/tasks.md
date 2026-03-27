# Tasks: 赞助商品列表新增目的地欄位 + 下载 CSV

**Input**: Design documents from `specs/KKPAR-1063_add_sponsor_application_prod_download/`
**Prerequisites**: plan.md ✓ | spec.md ✓ | research.md ✓ | data-model.md ✓ | contracts/api.md ✓

**Organization**: Tasks grouped by user story for independent implementation and delivery.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story this task belongs to (US1/US2/US3)
- Exact file paths in every description

---

## Phase 1: Setup & Registration

**Purpose**: 注册新 action 到现有基础设施，所有 User Story 的前置条件（对应 plan.md Phase A）

- [X] T001 在 `config/common.php` 的 `report` 区段追加 `'sponsor_application_prod' => ['action' => 'SPONSOR_APPLICATION_PROD']`
- [X] T002 [P] 在 `app/Http/Controllers/Api/v3/DownloadCsvController.php` 的 `getValidateDownLoadAction()` 追加 `config('common.report.sponsor_application_prod.action')`
- [X] T003 [P] 在 `app/Services/v3/Api/DownloadCsvService.php` 的 `setClient()` switch-case 追加 `SPONSOR_APPLICATION_PROD` → `DownloadSponsorApplicationProdService::class`（需在文件顶部加 `use` 引入该类）
- [X] T004 [P] 在 `routes/api_v3.php` 的 manage/sponsor-application 路由组内新增 3 条路由：`POST sponsor-application/download-csv` → `DownloadCsvController@download`；`POST sponsor-application/async-download-csv` → `DownloadCsvController@asyncDownload`；`GET sponsor-application/check-download-task` → `DownloadCsvController@checkDownloadTask`

**Checkpoint**: config + controller + service + routes 全部注册完成，后续各阶段可开始

---

## Phase 2: Foundational — GeoService 扩展 + GeoCountryNameService（对应 plan.md Phase B + C）

**Purpose**: 核心 code→名称转换基础设施，US1 和 US2 均依赖，必须先于任何 User Story 完成

**⚠️ CRITICAL**: US1、US2 的 destinations 注入均依赖此阶段

- [X] T005 在 `app/Services/Gateways/Geo/GeoService.php` 中新增方法 `getCountryCodeList(string $locale): array`，调用 geo-svc v2 ISO 3166-1 alpha-2 端点，遍历 `response['data']` 取 `languages.{$locale}['value']`；某 code 无对应 locale 名称时 fallback 为 code 本身；失败时抛出异常（由调用方捕获）
- [X] T006 新建 `app/Services/v3/Api/GeoCountryNameService.php`，实现 `resolveNames(array $codes, string $locale): array`：(1) 批量 `RedisHelper::hget('kkpar:geo', "country:{$locale}:{$code}")` 检查命中；(2) miss 时调用 `GeoService::getCountryCodeList($locale)`；(3) 批量 `RedisHelper::hset('kkpar:geo', "country:{$locale}:{$code}", $name, 604800)` 写入全量 locale 列表；(4) miss 的 code 使用查询结果填充，无对应 locale 值时 fallback 为 code；(5) catch `\Throwable` 写 `Log::error('GeoCountryNameService: geo-svc failed', [...])` 并将 miss 的 code 降级为 code 本身（参考 plan.md Phase C 完整实现）

**Checkpoint**: `GeoService::getCountryCodeList()` 和 `GeoCountryNameService::resolveNames()` 实现完毕，可独立单测

---

## Phase 3: User Story 1 — 列表展示商品目的地 (Priority: P1) 🎯 MVP

**Goal**: `GET /api/v3/manage/sponsor-application/get-prod-list` 响应中每条记录新增 `destinations` 字段，值为对应 locale 的目的地名称逗号字符串（如 `"台灣,日本"`）；Product API 或 geo-svc 失败时优雅降级。

**Independent Test**: 调用 getProdList 接口，响应 item 包含 `destinations` 键；Redis 命中时值为名称字符串；Product API 失败时值为 `""`，HTTP 200；geo-svc 失败 + 缓存未命中时值为 code 字符串（如 `"TW,JP"`），HTTP 200。

### Implementation for User Story 1

- [X] T007 [US1] 在 `app/Services/v3/Api/Manage/SponsorApplicationService.php` 的 `getProdList()` 中，在获取 `$list` 后按 plan.md Phase D 完整实现 destinations 注入：提取 `$prodOids`（array_values/unique/filter/array_column）→ try-catch 调用 `ProductService::getProductInfo(['prod_oids'=>$prodOids,'locale'=>getLocaleProperty()])` → `data_get($response,"data.{$prodOid}.destinations.destinations.*.code",[])` 构建 `$codesPerProd` → 收集 `$allCodes` 调用 `GeoCountryNameService::resolveNames($allCodes, getLocaleProperty())` → `implode(',', $names)` 构建 `$destinationsMap` → 遍历 `$list` 注入 `$item['destinations']`；Product API 异常写 `Log::error` 并 destinations 全部降级为 `""`

### Tests for User Story 1

- [X] T008 [P] [US1] 在 `tests/Feature/SponsorApplicationProdListTest.php` 中新增 Feature test：mock `KkpartnerServiceGatewayV3`、`ProductService`（返回带 destinations.code 的数据）、`GeoCountryNameService`（返回名称 map），断言响应 item 的 `destinations` 为逗号拼接名称字符串（如 `"台灣,日本"`）；HTTP 200
- [X] T009 [P] [US1] 在 `tests/Feature/SponsorApplicationProdListTest.php` 中新增 Feature test（2 个 case）：(1) mock `ProductService` 抛出异常 → destinations 为 `""`；(2) mock `ProductService` 正常但 `GeoCountryNameService` 返回 code 本身（geo-svc 失败场景）→ destinations 为 code 字符串；两个 case 均断言 HTTP 200 主流程不中断
- [X] T010 [P] [US1] 在 `tests/Unit/GeoCountryNameServiceTest.php` 中新增 Unit tests（4 个 case）：(1) 全部 Redis 命中 → 返回缓存名称，无 `GeoService::getCountryCodeList` 调用；(2) 部分 miss + geo-svc 成功 → 返回名称，Redis 被批量写入（断言 `RedisHelper::hset` 被调用）；(3) miss + geo-svc 失败 → miss 的 code 降级为 code 本身，写 error log；(4) `resolveNames([], 'zh-tw')` → 返回空数组

**Checkpoint**: getProdList destinations 字段正常（名称/code 降级/空字符串），US1 可独立验证

---

## Phase 4: User Story 2 — 同步下载赞助商品列表 CSV (Priority: P2)

**Goal**: `POST /api/v3/manage/sponsor-application/download-csv` 以 `action=SPONSOR_APPLICATION_PROD` 触发同步 CSV 下载，返回 11 列 CSV 文件，「商品目的地」列为 locale 名称字符串，表头跟随 `extra.locale`。

**Independent Test**: 以 `action=SPONSOR_APPLICATION_PROD` 调用同步下载接口，返回 HTTP 200 + Content-Type: text/csv，11 列表头语系与 locale 一致，「商品目的地」列显示名称而非 code。

### Implementation for User Story 2

- [X] T011 [US2] 新建 `app/Services/v3/Api/DownloadSponsorApplicationProdService.php`，实现 5 个方法：`getList(array $params): array`（调用 `KkpartnerServiceGatewayV3::getSponsorApplicationProdList($params)` + 私有 `injectDestinations()` 注入 destinations，返回 `['list'=>...,'pagination'=>...]`）；`setCsvTitle(): array`（return `trans('download.sponsor_application_prod.csv_title')`）；`setCsvData(array $row): array`（11 列，`member_level` 经 `trans('download.sponsor_application_prod.csv_data.member_level.'.$row['affiliate_member']['member_level'])` 枚举转换，日期空时输出 `""`，`site_name . '(' . cid . ')'` 拼接）；`setFileName(array $params): string`（`'sponsor_application_prod_'.date('YmdHis').'.csv'`）；`sendEmail(array $taskInfo): array`（`return []`）；私有 `injectDestinations(array $list, string $locale): array`（与 plan.md Phase D 逻辑一致，try-catch 调用 `ProductService` + `GeoCountryNameService::resolveNames()`，降级为 `""`）
- [X] T012 [P] [US2] 在 `resources/lang/zh-tw/download.php` 追加 `'sponsor_application_prod'` 区段：`'csv_title'` => 11 项繁中标题（商品贊助單申請編號/商品OID/商品名稱/商品目的地/審查結果/網站名稱(CID)/聯盟等級/主要推廣地區/出發日期/申請日期/最後更新日期）；`'csv_data'` => `['member_level' => ['01'=>'探險家','02'=>'冒險家','03'=>'遠航家','04'=>'開拓者']]`
- [X] T013 [P] [US2] 在 `resources/lang/zh-hk/download.php` 追加 `'sponsor_application_prod'` 区段：内容与 zh-tw 相同（同为繁体中文）
- [X] T014 [P] [US2] 在 `resources/lang/en/download.php` 追加 `'sponsor_application_prod'` 区段：`'csv_title'` => 11 项英文标题（Application OID/Product OID/Product Name/Destinations/Review Result/Website(CID)/Affiliate Level/Primary Promotion Region/Departure Date/Application Date/Last Updated Date）；`'csv_data'` => `['member_level' => ['01'=>'Explorer','02'=>'Adventurer','03'=>'Voyager','04'=>'Pioneer']]`
- [X] T015 [P] [US2] 在 `resources/lang/ja/download.php` 追加 `'sponsor_application_prod'` 区段：`'csv_title'` => 11 项日文标题（商品スポンサー申請番号/商品OID/商品名/目的地/審査結果/ウェブサイト名(CID)/アフィリエイトレベル/主要プロモーション地域/出発日/申請日/最終更新日）；`'csv_data'` => `['member_level' => ['01'=>'エクスプローラー','02'=>'アドベンチャラー','03'=>'ボイジャー','04'=>'パイオニア']]`
- [X] T016 [P] [US2] 在 `resources/lang/ko/download.php` 追加 `'sponsor_application_prod'` 区段：`'csv_title'` => 11 项韩文标题（상품 스폰서 신청 번호/상품 OID/상품명/목적지/심사 결과/웹사이트명(CID)/제휴 등급/주요 홍보 지역/출발일/신청일/최종 업데이트일）；`'csv_data'` => `['member_level' => ['01'=>'탐험가','02'=>'모험가','03'=>'항해자','04'=>'개척자']]`

### Tests for User Story 2

- [X] T017 [US2] 在 `tests/Feature/SponsorApplicationProdDownloadTest.php` 中新增 Feature tests：(1) POST `manage/sponsor-application/download-csv` 传 `action=SPONSOR_APPLICATION_PROD`，mock 服务层，断言 HTTP 200 + Content-Type 含 `text/csv`；(2) 传非法 action，断言返回统一错误格式（`metadata.status` 非 `"0000"`）；(3) POST `manage/sponsor-application/download-csv` 数据量超过 `config('common.report.max_total')` 时，断言返回错误响应而非 CSV
- [X] T018 [US2] 在 `tests/Unit/DownloadSponsorApplicationProdServiceTest.php` 中新增 Unit tests（5 个 case）：(1) `setCsvTitle()` 返回 11 元素数组；(2) `setCsvData()` 正常行各列格式正确（site_name+cid 拼接、日期格式）；(3) `setCsvData()` `member_level='01'` 在 zh-tw locale 输出 `'探險家'`；(4) `setCsvData()` 未知 `member_level='99'` 时输出原始值 `'99'`；(5) `setCsvData()` `prod_use_date`/`create_time`/`update_time` 为 null 时输出 `""`

**Checkpoint**: sync download 可独立测试，CSV 11 列、多语系表头、destinations 名称、字段格式均验证通过

---

## Phase 5: User Story 3 — 异步下载赞助商品列表 CSV (Priority: P3)

**Goal**: `POST /api/v3/manage/sponsor-application/async-download-csv` 提交异步任务；`GET /api/v3/manage/sponsor-application/check-download-task` 轮询任务状态；同 action 重复提交被拒绝。

**Independent Test**: POST async-download-csv 返回含 `action=SPONSOR_APPLICATION_PROD` 的任务信息；GET check-download-task 返回含 `status` 字段的任务状态。

> **注意**: US3 的底层实现（`DownloadSponsorApplicationProdService`、路由、config）已在 Phase 1 和 Phase 4 中完成，Phase 5 仅补充异步路径的测试覆盖。

### Tests for User Story 3

- [X] T019 [US3] 在 `tests/Feature/SponsorApplicationProdDownloadTest.php` 中新增 Feature test：POST `manage/sponsor-application/async-download-csv` 传 `action=SPONSOR_APPLICATION_PROD` + `download_username`，断言响应 HTTP 200，`data.action = 'SPONSOR_APPLICATION_PROD'`，`data.status` 为 `'UNPROCESSED'`
- [X] T020 [P] [US3] 在 `tests/Feature/SponsorApplicationProdDownloadTest.php` 中新增 Feature test（2 个 case）：(1) GET `manage/sponsor-application/check-download-task?json[action]=SPONSOR_APPLICATION_PROD`，断言响应包含 `data.status` 字段；(2) 已有进行中任务时再次 POST async-download-csv，断言返回错误（`metadata.status` 非 `"0000"`）

**Checkpoint**: 全部 3 个 User Story 可独立验证，异步任务创建/重复拒绝/状态查询均覆盖

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T021 [P] 对本次新增/修改的所有文件执行 `./vendor/bin/phpcs`，使用 `./vendor/bin/phpcbf` 修复 PSR-2 违规，直至零错误（主要文件：GeoService.php、GeoCountryNameService.php、DownloadSponsorApplicationProdService.php、SponsorApplicationService.php、DownloadCsvService.php、DownloadCsvController.php、5 个 lang 文件）
- [X] T022 [P] 对照 `specs/KKPAR-1063_add_sponsor_application_prod_download/spec.md` 中的 FR-001 ~ FR-015 逐一确认实现覆盖（重点检查：FR-013 geo-svc 调用、FR-014 Redis 缓存策略、FR-015 geo-svc 失败降级、FR-002 destinations = 名称非 code）

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (T001-T004) ── 立即开始，无依赖
    │
    ├── Phase 2 (T005-T006) ── GeoService + GeoCountryNameService，可与 Phase 1 并行（不同文件）
    │       │
    │       ├── Phase 3 (T007-T010) ── US1，需要 Phase 2 完成
    │       │
    │       └── Phase 4 (T011-T018) ── US2，需要 Phase 2 完成 + T001 完成
    │               │
    │               └── Phase 5 (T019-T020) ── US3，需要 Phase 4 完成（service 已实现）
    │
    └── Phase 6 (T021-T022) ── 需要所有 US 完成
```

### User Story Dependencies

- **US1 (P1)**: 需要 Phase 2（GeoCountryNameService）完成，与 US2/US3 无依赖
- **US2 (P2)**: 需要 Phase 2（GeoCountryNameService）完成 + Phase 1 全部完成（路由/config）
- **US3 (P3)**: 需要 Phase 4（DownloadSponsorApplicationProdService）完成

### Parallel Opportunities

- **Phase 1**: T002、T003、T004 可在 T001 完成后并行（不同文件）
- **Phase 1 与 Phase 2**: Phase 2 的 T005（GeoService）可与 Phase 1 并行开始（无依赖）
- **Phase 2**: T005 完成后 T006 才能开始（T006 依赖 T005）
- **Phase 4**: T012～T016（5 个 lang 文件）可在 T011 完成后全部并行
- **Phase 4**: T017、T018 可在 T011 完成后并行

---

## Parallel Example: Phase 4 (US2)

```bash
# T011（DownloadSponsorApplicationProdService）完成后，并行执行所有 lang 文件：
Task T012: resources/lang/zh-tw/download.php
Task T013: resources/lang/zh-hk/download.php
Task T014: resources/lang/en/download.php
Task T015: resources/lang/ja/download.php
Task T016: resources/lang/ko/download.php

# T011 完成后，并行执行测试：
Task T017: Feature tests sync download
Task T018: Unit tests for service methods
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: T001（config 常量，最小前置）
2. Phase 2: T005 → T006（GeoService + GeoCountryNameService）
3. Phase 3: T007（SponsorApplicationService 注入）
4. **STOP and VALIDATE**: 调用 getProdList，验证 destinations 字段为目的地名称；Product API 失败降级为 `""`；geo-svc 失败降级为 code 字符串
5. Add tests T008 + T009 + T010

### Incremental Delivery

1. Phase 1 + Phase 2 → Phase 3 US1 → 验证列表接口 destinations **（MVP）**
2. Phase 4 US2 → 验证 sync download CSV（11 列、多语系、destinations 名称）
3. Phase 5 US3 → 验证 async download 任务创建/查询
4. Phase 6 → phpcs + FR checklist

---

## Notes

- [P] 任务 = 不同文件，无依赖，可并行
- [US1/US2/US3] 标签对应 spec.md 中的 User Story 1/2/3
- PHP 7.3 兼容：禁用 `?->`、`match`、named arguments、union types；`\Throwable` PHP 7.0+ 可用
- **geo-svc endpoint 路径**（Open Item）：实现 T005 时需查阅 GeoServiceApi 或 Jira wiki 确认具体路径
- **RedisHelper::hset TTL 行为**（Open Item）：TTL 是 hash 整体级别（非 field 级别），实现 T006 时确认实际行为
- **geo-svc locale key 格式**（Open Item）：确认 `zh-tw` 是否直接匹配 `languages` key，还是需要映射（如 `zh_TW`）
- destinations 数据路径 `data.{$prodOid}.destinations.destinations.*.code` 需实现时以实际 Product API 响应验证
- 所有错误码来自 `config/api_status.php`（现有 DownloadCsvService 已处理，无需新增）
- `trans()` 找不到 key 时返回 key 本身 → 未知 `member_level` 自动输出原始值，符合 Edge Case 要求
- `GeoCountryNameService` 完整实现参考 `specs/KKPAR-1063_add_sponsor_application_prod_download/plan.md` Phase C
