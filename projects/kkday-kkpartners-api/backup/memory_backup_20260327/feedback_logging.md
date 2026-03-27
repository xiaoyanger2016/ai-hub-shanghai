---
name: 日志使用规范
description: 本项目统一使用 KkdayLogHelper，禁止直接使用 Illuminate\Support\Facades\Log
type: feedback
---

所有新增或修改的代码中，日志调用必须使用 `KkdayLogHelper`，禁止直接使用 Laravel 的 `Log` Facade。

**Why:** 项目统一日志规范，`KkdayLogHelper` 在标准日志之上额外做了脱敏处理、request_uuid 注入，以及 Slack 告警推送，直接用 `Log::` 会绕过这些机制。

**How to apply:**
- 新增文件：`use App\Helper\KkdayLogHelper;`，调用 `KkdayLogHelper::error()`、`KkdayLogHelper::info()`、`KkdayLogHelper::notice()`
- 修改已有文件：发现 `Log::` 调用一并替换，移除 `use Illuminate\Support\Facades\Log;`
- 测试文件：`KkdayLogHelper` 非 Facade，不能用 `Log::shouldReceive()` 拦截；若需验证日志行为，改为只断言业务行为结果，不断言 log 调用
