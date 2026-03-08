# api_contract.md — [ProjectName] Backend API Contract（/api/v1）

**Scope:** 本ドキュメントは「外部公開APIの●●」を固定するためのもの。  
世界観・●●・回数上限の数値・UI文言などは別Specを正とし、ここでは **APIの入出力・意味論・エラー** のみを定義する。

---

## 0. 共通

### 0.1 Base URL / Versioning
- Base Path: `/api/v1`
- バージョンはパスで固定し、破壊的変更は `/api/v2` を追加して行う。

### 0.2 Authentication
- 認証方式: Bearer Token
- Header: `Authorization: Bearer <token>`
- 未認証/無効●●ンは `401` + `AUTH_INVALID`

### 0.3 Content Type
- Request/Response: `application/json; charset=utf-8`

### 0.4 ●●非保存（最重要・●●上の注意）
- サーバは●●●●・●●●●を永続化しない。
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
- `request_id` は任意（●●を含まない識別子のみ）。

### 0.6 HTTP Status Mapping（原則）
- `200` OK
- `201` Created（必要な場合のみ）
- `400` ●●不正（VALIDATION_ERROR など）
- `401` 認証不正（AUTH_INVALID）
- `403` 権限不足/●●要件（PLAN_REQUIRED）
- `409` 競合（ETAG_MISMATCH / IDEMPOTENCY_CONFLICT）
- `429` 制限超過（RATE_LIMITED / DAILY_LIMIT_EXCEEDED）
- `500` 内部エラー（INTERNAL_ERROR）
- `503` 依存サービス不調（UPSTREAM_UNAVAILABLE など）

---

## 1. Data Types（共通）

ここもアプリの中核になるので秘密

### 1.3 ETag
- `GET /me/settings` は `ETag` を返す。
- `PUT /me/settings` は `If-Match` を必須とし、競合時は `409 ETAG_MISMATCH`。

### 1.4 Idempotency-Key
- `POST /generate` は `Idempotency-Key` を必須とする。
- 目的は「二重実行の抑止」。●●非保存のため、同一レスポンス●●の再現は必須要件にしない（抑止優先）。

---

## 2. Endpoints

ここもアプリの中核になるので秘密
これ以降500行くらいAPIの定義