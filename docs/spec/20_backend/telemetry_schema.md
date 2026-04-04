# Telemetry Schema（イベント定義 / MUST）

**Last Updated (JST):** 2026-03-02 04:35:00 +0900

本スキーマは `Telemetry Policy` の制約（本文ゼロ/個人情報ゼロ）を満たすこと。

---

## 1. Event共通フィールド（MUST）

- `event_id`: ULID/UUID
- `event_name`: string
- `server_time_utc`: ISO8601（サーバ付与）
- `hour_bucket_utc`: int 0..23（サーバ算出）
- `dow_utc`: int 0..6（サーバ算出）
- `user_id_hash`: string（HMAC-SHA256推奨）
- `plan`: "free" | "pro" | "premium"
- `app_version`: string
- `os`: "android" | "ios"
- `device_class`: "phone" | "tablet" | "unknown"

---

## 2. 主要イベント（MUST）

### 2.1 generate_requested

- `event_name`: "generate_requested"
- `daily_used`: int
- `daily_remaining`: int
- `has_ng_setting`: bool（ng設定が1件以上か）
- `persona_version`: int（例：3）

### 2.2 generate_succeeded

- `event_name`: "generate_succeeded"
- `latency_ms`: int
- `ng_gate_triggered`: bool
- `followup_returned`: bool

### 2.3 generate_failed

- `event_name`: "generate_failed"
- `latency_ms`: int（取得できる場合のみ）
- `error_code`: string（本文なし。コードのみ）

### 2.4 candidate_copied

- `event_name`: "candidate_copied"
- `candidate_id`: "A" | "B" | "C"（本文は保存しない）

### 2.5 app_opened（任意 / SHOULD）

- `event_name`: "app_opened"

---

## 3. 集計（hourly rollup / SHOULD）

サーバ移行判断のため、長期保持は集計のみとする。

- `date_utc`: YYYY-MM-DD
- `hour_bucket_utc`: 0..23
- `plan`: free/pro/premium
- `event_name`
- `count`
- `success_count` / `fail_count`（generate系）
- `p50_latency_ms` / `p95_latency_ms`（generate系）
