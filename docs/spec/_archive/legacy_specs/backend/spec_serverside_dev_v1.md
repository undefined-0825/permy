# spec_serverside_dev_v1.md

（サーバサイド実装用 Spec / 派生Spec）

- 位置づけ: **rule → product spec → serverside spec → serverside_dev**
- 本Specは **serverside spec（設計SSOT）に従属**し、実装に必要な決定事項・具体パラメータ・タスク分解を固定する。
- 既存versionは上書きせず、新しいversionを作成する。

---

## 1. 実装スタック

- 言語/フレームワーク: **Python + FastAPI**
- 実行: Uvicorn
- ストレージ:
  - **RDB**（settings SSOT / usage）
  - **Redis**（セッション / レート制限 / 移行 / 冪等・ロック）

---

## 2. 共通方針（ログ/保存）

### 2.1 保存禁止（サーバ側）

- 会話本文、入力テキスト、生成結果本文、移行コード平文を**永続保存しない**。
- 障害解析に必要な最小メタデータのみを保持/出力する。

### 2.2 ログ最小

- 記録可（例）: `request_id`, `route`, `status_code`, `latency_ms`, `user_id(匿名ID)`, `plan`, `error_code`
- 記録禁止: リクエスト/レスポンス本文、移行コード平文、外部AIへの送信本文

### 2.3 request_id

- すべてのレスポンスに `X-Request-Id` を付与する。
- 例外ハンドラでも必ず付与する（生成できない場合は新規生成）。

---

## 3. エラー/HTTPステータス規約

- `401`: 認証なし/不正
- `409`: settings更新の競合（ETag不一致）
- `422`: 入力上限超過（要約しない・切り詰めしない）
- `429`: レート制限
- `5xx`: サーバ内部（本文ログ無し）

---

## 4. 入力制約

- `/generate` 入力上限: **20,000文字**
  - 超過時は `422` を返す。
  - **要約・切り詰めはしない**（サーバ都合で内容改変しない）。

---

## 5. レート制限（初期値）

Redis でカウントし `429` を返す。キーはユーザー単位が基本、補助でIPも使用する。

### 5.1 `/auth/anonymous`

- IP: **10 / 10min**
- device_fingerprint（取得できる場合）: **3 / 10min**

### 5.2 `/generate`

- user_id: **Free 3 / day**
- user_id: **Pro 100 / day**
- 追加（瞬間制限）: user_id **5 / 1min**

### 5.3 `/migration/start`

- user_id: **3 / day**
- IP: **10 / day**

### 5.4 `/migration/complete`

- migration_code: **最大試行 10回**
  - 超過時はロック（詳細はTTL参照）
- IP: **20 / hour**

---

## 6. TTL（初期値）

- セッション（Redis）: **14日**
- migration_code 有効期限: **10分**
- migration_ticket（start→complete状態）: **15分**
- migration_code 試行ロック（10回超過時）: **1時間**
- `/generate` 冪等キー保持: **24時間**

---

## 7. API最小セット（実装対象）

- `POST /auth/anonymous`
- `GET /me/settings`
- `PUT /me/settings`（ETag/If-Match必須）
- `POST /generate`
- `POST /migration/start`
- `POST /migration/complete`
- `GET /health`
- `GET /version`

---

## 8. 設定（settings）更新の競合制御

- `GET /me/settings` は `ETag` を返す。
- `PUT /me/settings` は `If-Match` を必須とする。
- ETag不一致は `409` を返す（本文は汎用エラーコードのみ）。

---

## 9. データモデル（RDB最小案）

### 9.1 users

- `user_id` (PK, UUID)
- `created_at` (timestamp)
- `plan` (enum: free/pro) ※課金連携は後で差替え

### 9.2 user_settings

- `user_id` (PK/FK -> users.user_id)
- `settings_json` (JSON)
- `etag` (TEXT) 例: sha256(settings_json)
- `updated_at` (timestamp)

### 9.3 usage_daily

- `user_id`
- `date` (YYYY-MM-DD)
- `generate_count` (int)
- `plan_at_time` (enum: free/pro)
- PK: (`user_id`, `date`)

---

## 10. Redisキー設計（命名規約）

- `sess:{session_token}` → `{user_id, exp}`
- `rl:{route}:{scope}:{key}:{window}` → counter
  - 例: `rl:generate:user:{user_id}:1m`
- `mig:code:{code}` → `{from_user_id, ticket_id, exp, used=false}`
- `mig:ticket:{ticket_id}` → `{from_user_id,to_user_id?, status, exp}`
- `mig:lock:{code}` → `{locked=true, exp}`
- `idem:gen:{user_id}:{idempotency_key}` → `{status, created_at, exp}`

> 注: 「本文保存なし」方針のため、冪等は**多重実行防止**が主目的。
> 同一Idempotency-Keyで再リクエストされた場合は `409` または `200`（同一結果再返却はしない）を採用し、実装で統一する。

---

## 11. 外部AI呼び出し

- 送信本文はオンメモリのみで処理し、永続化・ログ出力しない。
- 実装は差替え可能な抽象 `AiClient` を用意する。
- タイムアウト/リトライは「課金上限・二重生成」を踏まえて慎重に（冪等キー併用）。

---

## 12. 実装タスク（推奨順）

1. FastAPI骨格

   - request_id middleware
   - bodyログ禁止（logger filter）
   - 例外ハンドラ（標準エラー形式）
2. Redis/RDB接続と設定ロード
3. `POST /auth/anonymous`

   - user_id発行（RDB）
   - session token発行（Redis）
   - レート制限（IP/DF）
4. `/me/settings`（GET/PUT + ETag/If-Match）
5. `/generate`

   - 入力検証（20,000文字）
   - 日次上限（usage_daily）+ 瞬間制限（Redis）
   - AI呼び出し（本文保存なし）
6. migration系（start/complete）
7. health/version

---

## 13. 今後の検討（未確定だが実装に影響）

- 冪等の再返却方針（本文保存なしとの整合）
- plan判定の外部連携（Stripe等）と `plan_status` の持ち方
- 監視（メトリクス/トレース）で本文を含めない設計

---
