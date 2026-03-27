# Feature Specification: 赞助商品列表新增目的地欄位 + 下载 CSV

**Feature Branch**: `task/KKPAR-1063_add_sponsor_application_prod_download`
**Jira**: KKPAR-1063
**Created**: 2026-03-23
**Status**: Draft

---

## Clarifications

### Session 2026-03-23

- Q: `destinations` 字段的值格式应该是什么？ → A: 仅目的地名称，如 `"台灣,日本"`（无 code，locale 对应语系）
- Q: Redis 缓存粒度应该如何设计？ → A: 每个 locale 独立一张 hash table（`kkpar:geo:{locale}`），field 为 `country:{code}`，value 为名称字符串
- Q: Redis 缓存 TTL 应该是多少？ → A: 7 天（604800s）
- Q: geo-svc API 不可用且缓存未命中时的降级策略？ → A: 返回 code 本身（如 `"TW,JP"`），写 error log

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 列表展示商品目的地 (Priority: P1)

运营人员在管理端查看「赞助商品列表」时，每条记录能直接看到该商品的目的地名称（如「台灣、日本」），无需跳转至商品详情页，从而在审核时快速判断商品适用地区。

**Why this priority**: 目的地字段是后续下载 CSV 的数据基础，且属于列表查询功能增强，独立可测，风险低。

**Independent Test**: 调用赞助商品列表接口，响应的每条 item 中出现 `destinations` 字段，且值为对应 locale 的目的地名称字符串，与下载功能无依赖。

**Acceptance Scenarios**:

1. **Given** 商品有目的地数据，**When** 以 `locale=zh-tw` 查询赞助商品列表，**Then** 每条记录包含 `destinations` 字段，值为逗号拼接的目的地名称字符串（如 `"台灣,日本"`）
2. **Given** 商品无目的地数据或目的地数组为空，**When** 查询赞助商品列表，**Then** `destinations` 字段返回空字符串
3. **Given** Product API 服务不可用或超时，**When** 查询赞助商品列表，**Then** 列表正常返回，`destinations` 降级为空字符串，不影响主流程
4. **Given** geo-svc 不可用且 Redis 缓存未命中，**When** 查询赞助商品列表，**Then** `destinations` 降级返回 code 字符串（如 `"TW,JP"`），写入 error log，不阻断列表返回

---

### User Story 2 - 同步下载赞助商品列表 CSV (Priority: P2)

运营人员在管理端对赞助商品列表施加筛选条件后，点击「下载 CSV」，若数据量在限制内则直接下载文件，文件包含目的地名称欄位及所有定义字段，表头语系跟随界面语系设置。

**Why this priority**: 同步下载适用于日常小批量导出场景，是运营最常用的数据提取方式。

**Independent Test**: 以 `action=SPONSOR_APPLICATION_PROD` 调用下载接口，返回 CSV 文件，表头与数据字段均符合定义，「商品目的地」列显示目的地名称而非代码。

**Acceptance Scenarios**:

1. **Given** 筛选结果在同步上限内，**When** 请求同步下载（`action=SPONSOR_APPLICATION_PROD`），**Then** 直接返回 CSV 文件，表头含 11 个字段，数据行对应列表记录
2. **Given** 筛选结果超过同步上限，**When** 请求同步下载，**Then** 返回错误，提示使用异步下载
3. **Given** 请求携带 `locale=zh-tw`，**When** 下载 CSV，**Then** 表头为繁体中文，「商品目的地」列显示繁体中文目的地名称
4. **Given** 请求携带 `locale=en`，**When** 下载 CSV，**Then** 表头为英文，「商品目的地」列显示英文目的地名称

---

### User Story 3 - 异步下载赞助商品列表 CSV (Priority: P3)

运营人员在数据量较大时，提交异步下载任务，系统在后台处理并生成 CSV 文件，用户可轮询任务状态，完成后下载文件。

**Why this priority**: 异步下载解决大数据量场景，但依赖同步下载的业务逻辑，故优先级稍低。

**Independent Test**: 调用异步下载接口后，再轮询任务状态接口，任务最终完成，文件可获取。

**Acceptance Scenarios**:

1. **Given** 无同类型进行中任务，**When** 提交异步下载（`action=SPONSOR_APPLICATION_PROD`，含 `download_username`），**Then** 返回任务创建成功，包含任务信息
2. **Given** 已有同 `action` 进行中任务，**When** 再次提交异步下载，**Then** 返回「任务处理中」错误，拒绝新建
3. **Given** 异步任务创建成功，**When** 轮询任务状态接口（`action=SPONSOR_APPLICATION_PROD`），**Then** 返回当前任务状态（处理中 / 完成 / 失败）
4. **Given** 数据量超过异步上限，**When** 提交异步下载，**Then** 返回「数据超过异步下载上限」错误

---

### Edge Cases

- Product API 返回部分商品数据缺失时，缺失项的 `destinations` 降级为空字符串，其他项正常处理
- `prod_oid` 列表为空时，跳过 Product API 调用，所有 item 的 `destinations` 返回空字符串
- geo-svc 不可用且 Redis 缓存未命中时，`destinations` 降级为 code 字符串（如 `"TW,JP"`），写 error log，不阻断主流程
- geo-svc 返回的某个 code 无对应语系名称时，该 code 降级输出 code 本身
- `affiliate_member.member_level` 值不在已知枚举（01/02/03/04）内时，CSV 直接输出原始值
- `prod_use_date`、`create_time`、`update_time` 为空时，对应 CSV 列输出空字符串
- 同步下载数据量过少时，补空行至最低行数（沿用现有同步下载行为）

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 赞助商品列表接口 MUST 在每条记录中包含 `destinations` 字段，值为对应 locale 的目的地名称逗号拼接字符串（如 `"台灣,日本"`）
- **FR-002**: `destinations` 数据 MUST 来源于 Product API，以 `prod_oid` 批量查询，取 `destinations.*.code`；再通过 geo-svc API 将 code 转换为对应 locale 的目的地名称
- **FR-003**: Product API 调用失败时 MUST 降级处理（`destinations` 返回空字符串），MUST NOT 阻断列表返回，MUST 写入 error log
- **FR-004**: 系统 MUST 支持以 `action=SPONSOR_APPLICATION_PROD` 触发同步 CSV 下载，接受与赞助商品列表相同的筛选参数
- **FR-005**: 同步下载 MUST 在数据量超出限制时返回错误，不超限时直接返回 CSV 文件流
- **FR-006**: 系统 MUST 支持以 `action=SPONSOR_APPLICATION_PROD` 触发异步 CSV 下载，需额外传入 `download_username`
- **FR-007**: 异步下载 MUST 检查同 action 是否已有进行中任务，有则拒绝新建并返回对应错误
- **FR-008**: 系统 MUST 支持以 `action=SPONSOR_APPLICATION_PROD` 轮询异步下载任务状态
- **FR-009**: CSV 表头 MUST 根据请求 locale 参数返回对应语系文本，支持 `en`、`zh-tw`、`zh-hk`、`ja`、`ko`
- **FR-010**: CSV MUST 包含以下 11 个字段（按顺序）：商品贊助單申請編號、商品OID、商品名稱、商品目的地、審查結果、網站名稱(CID)、聯盟等級、主要推廣地區、出發日期、申請日期、最後更新日期
- **FR-011**: CSV「聯盟等級」MUST 将枚举值转换为对应语系文字（01:探險家、02:冒險家、03:遠航家、04:開拓者）
- **FR-012**: 下载功能 MUST 复用现有下载控制器，不在赞助计划控制器中新增下载方法
- **FR-013**: 系统 MUST 调用 geo-svc API（v2 國家/地區代碼列表，ISO 3166-1 alpha-2），以 code 查询对应 locale 的目的地名称（`languages.{locale}.value`）
- **FR-014**: geo-svc 查询结果 MUST 按 (locale, code) 维度缓存至 Redis，key 格式为 `kkpar:geo:country:{locale}:{code}`，TTL 为 7 天（604800s）；读取时优先从 Redis 命中
- **FR-015**: geo-svc 调用失败且 Redis 缓存未命中时，MUST 降级返回 code 本身（如 `"TW,JP"`），MUST 写入 error log，MUST NOT 阻断列表或下载主流程

### Key Entities

- **赞助商品 (SponsorApplicationProd)**: 赞助计划下的单个商品申请记录，包含商品标识、名称、审查状态、关联会员信息、出发日期、申请时间、更新时间等
- **商品目的地 (ProductDestination)**: 来自 Product API，每个商品对应零至多个目的地，以 ISO 3166-1 alpha-2 代码（code）字段标识
- **地区名称 (GeoCountry)**: 来自 geo-svc API，以 code 为键，`languages.{locale}.value` 为对应语系的地区名称；数据变动极少，按 (locale, code) 缓存于 Redis，TTL 7 天
- **下载任务 (ReportDownloadTask)**: 异步下载的任务记录，包含操作类型（action）、任务状态、文件信息、分页进度等，由后端服务统一管理

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 赞助商品列表接口在 Product API 及 geo-svc 均正常、Redis 缓存命中情况下，P95 响应时间相较当前增加不超过 500ms
- **SC-002**: Product API 或 geo-svc 不可用时，列表接口降级成功率 100%，不出现 500 错误；geo-svc 缓存未命中时 `destinations` 降级为 code，缓存命中时正常显示名称
- **SC-003**: 同步下载生成的 CSV 文件包含正确的 11 列，表头语系与请求 locale 一致，「商品目的地」列显示对应 locale 的目的地名称，字段内容准确率 100%
- **SC-004**: 异步下载任务创建后，状态轮询接口能正确反映处理中 / 完成 / 失败状态
- **SC-005**: 同一 action 并发异步任务创建时，系统保证同时只有一个进行中任务（重复提交返回错误）
- **SC-006**: geo-svc Redis 缓存命中率在首次预热后达到 95% 以上（TTL 7 天内重复查询相同 code+locale 均命中）

---

## Assumptions

- 赞助商品列表项中已包含 `affiliate_member.member_level` 字段（现有逻辑已通过 `with.affiliate_member=true` 加载）
- Product API 的 `prod_oids` 参数已支持批量查询，无需修改 `ProductService::getProductInfo()`
- geo-svc API（v2 國家/地區代碼列表）已在项目中可访问，response 结构：`{ data: [{ code: "TW", languages: { "zh-tw": { value: "台灣" }, ... } }] }`
- geo-svc 地区数据变动极少（新增国家代码为极低频事件），7 天 TTL 满足数据时效性要求
- 异步下载的文件存储、后续任务续传等后置逻辑与现有下载服务行为一致，无需单独定制
- member_level 各语系翻译文字以繁中为基准，其他语系开发时补充
- `prod_use_date` 即为商品出发日期展示字段
- 同步下载上限及异步下载上限沿用现有配置，不新增配置项
