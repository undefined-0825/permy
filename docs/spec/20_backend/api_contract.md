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

### 1.1 Plan（外部互換の2値）
- `plan`: `"free" | "pro"`

**ルール**
- 機能判定はバックエンド内部では `feature_tier` を持つが、外部互換のため `plan` は2値で返す。
- `feature_tier=plus`（課金Pro + 永続無料付与）はすべて `plan="pro"` として返す。

### 1.2 ETag
- `GET /me/settings` は `ETag` を返す。
- `PUT /me/settings` は `If-Match` を必須とし、競合時は `409 ETAG_MISMATCH`。

### 1.3 Idempotency-Key
- `POST /generate` は `Idempotency-Key` を必須とする。
- 目的は「二重実行の抑止」。本文非保存のため、同一レスポンス本文の再現は必須要件にしない（抑止優先）。

---

## 2. Endpoints

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
  "text": "string (LINE txt content)",
  "settings": {
    "forbidden_type_ids": [1, 2, 3],
    "purpose_id": 1,
    "combo_id": 0
  }
}
```

**Notes**
- `text` は入力本文。サーバは保存しない（ログにも残さない）。
- `settings` は省略可能とするかは実装都合で決めて良いが、契約としては送れるものとする。

### Response 200
```json
{
  "candidates": {
    "A": "string",
    "B": "string",
    "C": "string"
  },
  "meta": {
    "plan": "free",
    "request_id": "optional"
  }
}
```

### Errors
- `400 VALIDATION_ERROR`
- `401 AUTH_INVALID`
- `403 PLAN_REQUIRED`（Pro専用機能をFreeが要求した等）
- `409 IDEMPOTENCY_CONFLICT`
- `429 RATE_LIMITED`
- `429 DAILY_LIMIT_EXCEEDED`
- `503 UPSTREAM_UNAVAILABLE`（LLM不調等）
- `503 OPENAI_DISABLED`（CI/無効化時）
- `500 INTERNAL_ERROR`

---

## 2.5 POST /migration/issue
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
  "expires_at": "string (ISO-8601)"
}
```

### Errors
- `401 AUTH_INVALID`
- `429 RATE_LIMITED`
- `500 INTERNAL_ERROR`

---

## 2.6 POST /migration/consume
移行コードを消費して、別端末でユーザーを引き継ぐ。

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
  "token": "string",
  "user_id": "string"
}
```

### Errors
- `400 VALIDATION_ERROR`
- `404 MIGRATION_CODE_INVALID`
- `409 MIGRATION_CODE_ALREADY_USED`
- `410 MIGRATION_CODE_EXPIRED`
- `429 RATE_LIMITED`
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
- `MIGRATION_CODE_ALREADY_USED`
- `OPENAI_DISABLED`
- `UPSTREAM_UNAVAILABLE`
- `INTERNAL_ERROR`

---

## 4. Non-Goals（この契約で定義しない）
- 価格・回数上限の数値（別Spec）
- プロンプト内容や世界観文言（別Spec）
- 課金検証（`/billing/verify` など）は導入時に別途契約追加
- 内部の `feature_tier` / `billing_tier` の返却（外部APIには露出させない）
