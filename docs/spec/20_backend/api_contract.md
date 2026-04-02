# api_contract.md — Permy Backend API Contract（/api/v1）

**Scope:** 本ドキュメントは「外部公開APIの契約」を固定するためのもの。  
世界観・価格・回数上限の数値・UI文言などは別Specを正とし、ここでは **APIの入出力・意味論・エラー** のみを定義する。

---

## 0. 共通

### 0.1 Base URL / Versioning
- Base Path: `/api/v1`
- バージョンはパスで固定し、破壊的変更は `/api/v2` を追加して行う。

### 0.2 Authentication
- 認証方式: Bearer Token
- Header: `Authorization: Bearer <token>`
- 未認証/無効トークンは `401` + `AUTH_INVALID`

### 0.3 Content Type
- Request/Response: `application/json; charset=utf-8`

### 0.4 本文非保存（最重要・契約上の注意）
- サーバは入力本文・生成本文を永続化しない。
- ログ/テレメトリにも request/response body を記録しない（運用ポリシー）。

### 0.5 Error Response（共通フォーマット）
```json
{
  "error_code": "AUTH_INVALID",
  "message": "human readable short message",
  "request_id": "optional"
}
```

- `message` は短文。機微情報を含めない。
- `request_id` は任意（本文を含まない識別子のみ）。

### 0.6 HTTP Status Mapping（原則）
- `200` OK
- `201` Created（必要な場合のみ）
- `400` 入力不正（VALIDATION_ERROR など）
- `401` 認証不正（AUTH_INVALID）
- `403` 権限不足/プラン要件（PLAN_REQUIRED）
- `409` 競合（ETAG_MISMATCH / IDEMPOTENCY_CONFLICT）
- `429` 制限超過（RATE_LIMITED / DAILY_LIMIT_EXCEEDED）
- `500` 内部エラー（INTERNAL_ERROR）
- `503` 依存サービス不調（UPSTREAM_UNAVAILABLE など）

---

## 1. Data Types（共通）

### 1.1 Plan（外部契約）
- `plan`: `"free" | "pro" | "premium"`

**ルール**
- 機能判定はバックエンド内部では `feature_tier` を持ち、外部契約でも `plan` は3値で返す。
- `feature_tier=pro` は `plan="pro"`、`feature_tier=premium` は `plan="premium"` として返す。

### 1.2 Followup（聞き返し）
- `Followup` オブジェクト（nullable）
  - `key`: `"relationship_type" | "reply_length_pref" | "ng_tags" | "ng_free_phrases"`
  - `question`: string
  - `choices`: array of `{id: string, label: string}` (1..3個)
- 設定不足があれば返し、なければ `null`
- A/B/C は仮で出した上で、不足1点を聞く（離脱防止）

### 1.3 ETag
- `GET /me/settings` は `ETag` を返す。
- `PUT /me/settings` は `If-Match` を必須とし、競合時は `409 ETAG_MISMATCH`。

### 1.4 Idempotency-Key
- `POST /generate` は `Idempotency-Key` を必須とする。
- 目的は「二重実行の抑止」。本文非保存のため、同一レスポンス本文の再現は必須要件にしない（抑止優先）。

---

## 2. Endpoints

## 2.0 GET /version
アプリのバージョン情報と更新判定情報を返す。

### Request
- 認証不要

### Response 200
```json
{
  "app": "permy-serverside",
  "version": "1.2.0",
  "latest_version": "1.2.0",
  "min_supported_version": "1.1.0",
  "android_store_url": "https://play.google.com/store/apps/details?id=...",
  "ios_store_url": "https://apps.apple.com/app/id...",
  "commit": "abc1234",
  "env": "production"
}
```

**Notes**
- `latest_version`: 任意更新の判定に使用する。
- `min_supported_version`: 強制更新の判定に使用する。
- `android_store_url` / `ios_store_url`: ストア誘導先。未設定時は空文字を許容。

### Errors
- `500 INTERNAL_ERROR`

---

## 2.1 POST /auth/anonymous
匿名ユーザーとして開始し、トークンを発行する。

### Request
Body: `{}`（空JSONでよい）

### Response 200
```json
{
  "token": "string",
  "user_id": "string"
}
```

### Errors
- `500 INTERNAL_ERROR`

---

## 2.2 GET /me/settings
ユーザー設定を取得する。本文を含む設定は不可（別Specで制約）。

### Request
Headers:
- `Authorization: Bearer <token>`

### Response 200
Headers:
- `ETag: "<opaque-etag>"`

Body:
```json
{
  "settings": {
    "forbidden_type_ids": [1, 2, 3],
    "purpose_id": 1,
    "combo_id": 0
  }
}
```
※ `settings` の具体フィールドはフロント/プロダクトSpecを正とし、ここでは「JSONで返す」ことのみを契約とする（破壊的変更はv2）。

**Plan フィールド注入（MUST）**  
`settings` 内の `feature_tier`, `billing_tier`, `plan` は、クライアントが保持する値に依らず、  
サーバが `AuthContext`（`users` テーブル）の最新値で **必ず上書き** して返す。  
フロントエンドはこれらの値を唯一の正として扱い、ローカルキャッシュより優先すること。

### Errors
- `401 AUTH_INVALID`
- `500 INTERNAL_ERROR`

---

## 2.3 PUT /me/settings
ユーザー設定を更新する。楽観ロック必須。

### Request
Headers:
- `Authorization: Bearer <token>`
- `If-Match: "<etag>"`

Body:
```json
{
  "settings": {
    "forbidden_type_ids": [1, 2, 3],
    "purpose_id": 1,
    "combo_id": 0
  }
}
```

### Response 200
Headers:
- `ETag: "<new-etag>"`

Body:
```json
{
  "settings": {
    "forbidden_type_ids": [1, 2, 3],
    "purpose_id": 1,
    "combo_id": 0
  }
}
```

### Errors
- `400 VALIDATION_ERROR`
- `401 AUTH_INVALID`
- `409 ETAG_MISMATCH`
- `500 INTERNAL_ERROR`

**Note**: レスポンスの `feature_tier`, `billing_tier`, `plan` は GET と同様に AuthContext の値で上書きされる（リクエストボディの值を無視）。

---

## 2.3.1 POST /me/diagnosis
診断回答（7問）を受け取り、タイプ判定と生成用パラメータを返す。

### Request
Headers:
- `Authorization: Bearer <token>`

Body:
```json
{
  "answers": [
    {"question_id": "true_priority", "choice_id": "life_balance"},
    {"question_id": "true_decision_axis", "choice_id": "low_stress"},
    {"question_id": "night_goal_primary", "choice_id": "next_visit"},
    {"question_id": "night_temperature", "choice_id": "adaptive"},
    {"question_id": "night_game_tolerance", "choice_id": "light_game"},
    {"question_id": "night_customer_allocation", "choice_id": "care_existing"},
    {"question_id": "night_risk_response", "choice_id": "adaptive_landing"}
  ]
}
```

### Response 200
```json
{
  "persona_version": 3,
  "true_self_type": "Stability",
  "night_self_type": "Balance",
  "persona_goal_primary": "relationship_keep",
  "persona_goal_secondary": "next_visit",
  "style_assertiveness": 42,
  "style_warmth": 71,
  "style_risk_guard": 68
}
```

### Errors
- `400 VALIDATION_ERROR`
- `401 AUTH_INVALID`
- `500 INTERNAL_ERROR`

---

## 2.4 POST /generate
返信案（A/B/C）を生成して返す。

### Request
Headers:
- `Authorization: Bearer <token>`
- `Idempotency-Key: "<uuid-like-string>"`

Body:
```json
{
  "history_text": "string (LINE txt content)",
  "combo_id": 0,
  "tuning": null
}
```

**Notes**
- `history_text` は入力本文。サーバは保存しない（ログにも残さない）。
- `combo_id`: 0..5（コンボID、有料プランは2以上利用可能）
- `tuning`: 有料プランのみ利用可能（nullable）
- 生成スタイルは `/me/settings` 内の診断派生パラメータ（`persona_goal_primary` など）を利用してよい。

### Response 200
```json
{
  "request_id": "string",
  "plan": "free",
  "daily": {
    "date": "2026-03-05",
    "limit": 3,
    "used": 1,
    "remaining": 2
  },
  "candidates": [
    {"label": "A", "text": "返信案A"},
    {"label": "B", "text": "返信案B"},
    {"label": "C", "text": "返信案C"}
  ],
  "followup": {
    "key": "relationship_type",
    "question": "お客様との関係を教えてね",
    "choices": [
      {"id": "new", "label": "新規（初めて）"},
      {"id": "regular", "label": "常連（何度も来てる）"},
      {"id": "big_client", "label": "太客（大切なお客様）"}
    ]
  },
  "model_hint": "gpt-4o-mini",
  "timestamp": "2026-03-05T01:30:00+00:00",
  "meta_pro": null
}
```

**Response フィールド説明**
- `followup`: 設定不足があれば返す（nullable）。なければ `null`
- `daily`: 日次制限情報（limit/used/remaining）
- `model_hint`: 使用モデルのヒント（nullable）
- `meta_pro`: Pro/Premium専用情報（Freeでは常に `null`）

### Errors
- `400 VALIDATION_ERROR`
- `401 AUTH_INVALID`
- `403 PLAN_REQUIRED`（有料専用機能をFreeが要求した等）
- `409 IDEMPOTENCY_CONFLICT`
- `429 RATE_LIMITED`
- `429 DAILY_LIMIT_EXCEEDED`
- `503 UPSTREAM_UNAVAILABLE`（LLM不調等）
- `503 OPENAI_DISABLED`（CI/無効化時）
- `500 INTERNAL_ERROR`

---

## 2.5 POST /migration/start
移行コード（12桁）を発行する。

### Request
Headers:
- `Authorization: Bearer <token>`

Body:
```json
{}
```

### Response 200
```json
{
  "migration_code": "string (12 digits)",
  "ticket_id": "string"
}
```

### Errors
- `401 AUTH_INVALID`
- `429 RATE_LIMITED`
- `500 INTERNAL_ERROR`

---

## 2.6 POST /migration/complete
移行コードを消費して、別端末でユーザーを引き継ぐ。認証不要（新端末から呼ばれるため）。

### Request
Body:
```json
{
  "migration_code": "string (12 digits)"
}
```

### Response 200
```json
{
  "user_id": "string",
  "access_token": "string"
}
```

### Errors
- `400 VALIDATION_ERROR`
- `400 MIGRATION_CODE_USED`
- `404 MIGRATION_CODE_INVALID`
- `410 MIGRATION_CODE_EXPIRED`
- `429 RATE_LIMITED`
- `500 INTERNAL_ERROR`

---

## 2.6.1 POST /billing/verify
ストア購入の検証結果を反映する。

### Request
Headers:
- `Authorization: Bearer <token>`

Body:
```json
{
  "platform": "ios",
  "product_id": "com.sukimalab.permy.premium_monthly",
  "purchase_token": "string"
}
```

**Rules**
- `platform`: `"ios" | "android"`
- 許可された `product_id` は以下のみ
  - Android: `permy_pro_monthly`, `permy_premium_monthly`
  - iOS: `com.sukimalab.permy.pro_monthly`, `com.sukimalab.permy.premium_monthly`
- 現時点の検証は mock mode。`purchase_token` 非空を最低条件として検証する。

### Response 200
```json
{
  "plan": "premium",
  "verified": true
}
```

### Errors
- `400 BILLING_PRODUCT_INVALID`
- `400 BILLING_RECEIPT_INVALID`
- `401 AUTH_INVALID`
- `503 BILLING_NOT_CONFIGURED`
- `500 INTERNAL_ERROR`

---

## 2.7 POST /telemetry/events
クライアントから複数のテレメトリイベントをバッチ送信する。

### Request
Headers:
- `Authorization: Bearer <token>`

Body:
```json
{
  "events": [
    {
      "event_name": "generate_requested",
      "app_version": "1.0.0",
      "os": "android",
      "device_class": "phone",
      "daily_used": 1,
      "daily_remaining": 2,
      "has_ng_setting": true,
      "persona_version": 2
    }
  ]
}
```

**Notes**
- `events`: 1..100 イベントをバッチ送信可能
- 本文/生成文は含めない（privacy-first）
- サーバ側で `user_id_hash`（HMAC-SHA256）、`server_time_utc`、`hour_bucket_utc`（0..23）、`dow_utc`（0..6）を自動付与

### イベントタイプ（5種）
1. **generate_requested**: 生成リクエスト開始
   - `daily_used`, `daily_remaining`, `has_ng_setting`, `persona_version`
2. **generate_succeeded**: 生成成功
   - `latency_ms`, `ng_gate_triggered`, `followup_returned`
3. **generate_failed**: 生成失敗
   - `latency_ms` (optional), `error_code`
4. **candidate_copied**: 候補コピー
   - `candidate_id`: "A" | "B" | "C"
5. **app_opened**: アプリ起動

詳細スキーマは `telemetry_schema.md` 参照。

### Response 200
```json
{
  "received": 1,
  "request_id": "optional"
}
```

### Errors
- `400 VALIDATION_ERROR`
- `401 AUTH_INVALID`
- `500 INTERNAL_ERROR`

---

## 3. Error Codes（一覧・最小セット）
- `AUTH_INVALID`
- `VALIDATION_ERROR`
- `PLAN_REQUIRED`
- `ETAG_MISMATCH`
- `IDEMPOTENCY_CONFLICT`
- `RATE_LIMITED`
- `DAILY_LIMIT_EXCEEDED`
- `MIGRATION_CODE_INVALID`
- `MIGRATION_CODE_EXPIRED`
- `MIGRATION_CODE_USED`
- `MIGRATION_CODE_ALREADY_USED`（後方互換用。`MIGRATION_CODE_USED` に統一推奨）
- `OPENAI_DISABLED`
- `UPSTREAM_UNAVAILABLE`
- `INTERNAL_ERROR`

---

## 4. Non-Goals（この契約で定義しない）
- 価格・回数上限の数値（別Spec）
- プロンプト内容や世界観文言（別Spec）
- `feature_tier` / `billing_tier` を独立した typed レスポンスフィールドとして定義すること（`settings_json` 内に注入する形のみ許容）
