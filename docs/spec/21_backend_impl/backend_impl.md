# backend_impl.md — Permy バックエンド実装Spec（FastAPI / 本文非保存 / 入口固定）

**Scope:** 本ドキュメントはバックエンドの「実装」方針・構造・具体的な実装ルールを定義する。  
API契約は `api_contract.*` を正とし、ここでは実装詳細（モジュール構成、DB/キャッシュ、ミドルウェア、運用CLI等）を定める。

---

## 0. 実装の大原則（MUST）
1) **本文非保存**：入力本文・生成本文をDB/ログ/テレメトリに残さない  
2) **入口固定**：`/api/v1/*` とスキーマ・エラーコードの意味論を壊さない  
3) **小さく始める**：Render（Phase 1）で動く最小構成をまず作り、必要になってから分割・キュー化  
4) **差し替え容易**：LLM/DB/キャッシュ/実行基盤を入替しやすい抽象化（インターフェース化）

---

## 1. 技術スタック（Phase 1 基準）
- Python 3.12+（固定するならプロジェクト標準に合わせる）
- FastAPI + Uvicorn
- DB: SQLite（開発/最小）→ Postgres（運用/移行）
- Cache/Rate limit: まずはDB or メモリ（単一インスタンス前提）→ Redis（Phase 2）
- OpenAI SDK（LLM呼び出し）
- Migrations: Alembic（Postgres移行を前提）
- Observability: 構造化ログ（本文ゼロ） + Prometheus互換メトリクス（任意）

※「価格/回数上限の数値」は別Specを正とする。本実装は **limit_profile** を見て判定する。

---

## 2. リポジトリ構成（推奨）
```
backend/
  app/
    main.py
    api/
      v1/
        routes_auth.py
        routes_settings.py
        routes_generate.py
        routes_migration.py
    core/
      config.py
      security.py
      errors.py
      middleware.py
      logging.py
      metrics.py
    domain/
      plans.py
      limits.py
      idempotency.py
      migration.py
    infra/
      db.py
      repositories/
        users_repo.py
        settings_repo.py
        usage_repo.py
        migration_repo.py
      llm/
        client.py
        prompt_builder.py
    schemas/
      auth.py
      settings.py
      generate.py
      migration.py
      common.py
  tools/
    grant_comp_user.py
  tests/
    test_auth.py
    test_settings.py
    test_generate_limits.py
    test_migration.py
  alembic/
  pyproject.toml
  Dockerfile
  render.yaml (任意)
```

---

## 3. 設定（Config）実装（MUST）
### 3.1 環境変数
- `ENV` : `dev|staging|prod`
- `DATABASE_URL` : SQLite/Postgres
- `REDIS_URL` : 任意（無ければ未使用）
- `OPENAI_API_KEY` : LLM用（CIでは未設定または無効）
- `OPENAI_DISABLED` : `true|false`（CIで true）
- `LOG_LEVEL` : `INFO` など
- `TOKEN_SECRET` : 署名用
- `TOKEN_EXPIRES_MIN` : 任意（匿名運用）
- `MIGRATION_CODE_TTL_MIN` : 移行コード期限（数値は別Specでもよい）
- `RATE_LIMIT_MODE` : `memory|db|redis`
- `REQUEST_ID_HEADER` : 例 `X-Request-Id`（任意）

### 3.2 Pydantic Settings
- `app/core/config.py` に `BaseSettings` を置き、環境変数を型付きで読む。
- `OPENAI_DISABLED=true` の場合、LLM呼び出しは禁止（強制）。

---

## 4. ロギング/テレメトリ（本文ゼロ）（MUST）
### 4.1 絶対禁止
- request body / response body をログに出す
- 例外スタックに本文が混入する形で dump する（例：バリデーションエラーに本文が含まれる場合に注意）

### 4.2 許可（ログ）
- `request_id`（生成）
- endpoint / method
- status_code
- error_code
- latency_ms
- user_id（ハッシュ化/短縮も可。本文ではない）
- plan（free/pro）や tier（feature_tier）は可（本文ではない）

### 4.3 実装
- `middleware` で request_id を採番（ヘッダがあれば採用）し、contextに格納
- 構造化ログ（JSON）で出す（フィールド固定）
- 例外ハンドラで `error_code` を必ず返す

---

## 5. エラー処理（MUST）
- `app/core/errors.py` に `ApiError`（`http_status`, `error_code`, `message`）を定義
- 例外ハンドラで共通フォーマットへ変換（`error_codes.*` を正とする）
- `message` は短文。本文/断片は禁止。

---

## 6. 認証（Auth）実装
### 6.1 トークン
- `POST /auth/anonymous` で `user_id` を作成し、JWT等で token を発行
- 署名は `TOKEN_SECRET`
- 検証は依存注入（`Depends(get_current_user)`）

### 6.2 user_id
- ULID/UUIDなど衝突しにくいもの
- user_id自体は本文ではないため保持可

---

## 7. プラン/ティア（feature_tier / billing_tier）実装（MUST）
### 7.1 データ
`users` に以下を保持：
- `feature_tier`: `free|plus`
- `billing_tier`: `free|pro_store|pro_comp`

### 7.2 返却 plan（外部互換）
- APIレスポンスの `meta.plan` は `free/pro` の2値のみ
  - `feature_tier=free` → plan=free
  - `feature_tier=plus` → plan=pro

### 7.3 永続無料付与（pro_comp）
- 管理画面は作らない
- `tools/grant_comp_user.py` で `user_id` を指定し DB更新
  - `feature_tier=plus`
  - `billing_tier=pro_comp`
- 公開HTTPの管理APIは増やさない（攻撃面を増やさない）

---

## 8. Settings（ETag/If-Match）実装
### 8.1 ETag生成
- `user_settings.etag` を保持（例：更新ごとにUUID、または更新時刻+hash）
- GETで `ETag` を返し、PUTは `If-Match` 必須

### 8.2 競合
- `If-Match` が一致しない → `409 ETAG_MISMATCH`

---

## 9. Generate（/generate）実装（本文非保存 + 制限）
### 9.1 入力
- `text`（本文）を受け取るが、以下を徹底：
  - DB保存しない
  - ログに出さない
  - 例外メッセージに混入させない（バリデーション含む）

### 9.2 制限チェック順
1) 認証
2) プラン要件（Pro専用のpurpose/combo等がある場合）
3) レート制限（429 RATE_LIMITED）
4) 日次回数制限（429 DAILY_LIMIT_EXCEEDED）
5) 冪等キー抑止（Idempotency-Key）
6) LLM呼び出し（OPENAI_DISABLEDなら 503 OPENAI_DISABLED）

### 9.3 日次回数カウント
- `usage_daily (user_id, date_yyyymmdd, generate_count)` を更新
- 上限値は別Specから設定（例：環境変数 or DBの limit_profile）
- 実装は「原子的更新」が必要（DBトランザクションで `SELECT ... FOR UPDATE` 相当 or UPSERT+条件）

### 9.4 レート制限（Phase 1）
- `RATE_LIMIT_MODE=memory|db` を用意
- memory: 単一インスタンス前提の簡易バケット（テスト用）
- db: `rate_limits` テーブル or `usage_minute` 的な集計（実装コストと相談）
- Phase 2で Redis に切替可能なインターフェースにする（`domain/limits.py`）

### 9.5 冪等性（Idempotency）
- 目的は「二重実行防止」。
- 本文非保存のため、**生成結果本文を保存して再返却はしない**（原則）。
- 実装案（推奨）：
  - `idempotency_keys` に `user_id + key` を短TTLで保持し、並行/連打を拒否
  - 成功/失敗の状態だけ保持（本文なし）
- 競合時は `409 IDEMPOTENCY_CONFLICT`

### 9.6 LLM呼び出し
- `infra/llm/client.py` に薄いラッパを置く（差し替え容易）
- タイムアウト/リトライ方針は固定しすぎず、設定可能にする
- 失敗は `503 UPSTREAM_UNAVAILABLE` / `UPSTREAM_TIMEOUT`

---

## 10. Migration（移行コード）実装
### 10.1 仕様（実装観点）
- 12桁コード（表示用）
- DBには **ハッシュ** を保存（平文保存しない）
- 期限 `expires_at`
- 1回限り：`used_at` をセットして再利用不可

### 10.2 発行（/migration/issue）
- 認証必須
- 既存未使用コードを上書き/再発行するかは実装都合（推奨：再発行で旧コード無効化）
- レート制限（MIGRATION_RATE_LIMITED）

### 10.3 消費（/migration/consume）
- 認証不要（コード+本人操作で成立させる）
- コード検証→期限→未使用→新token発行
- 失敗：
  - 無効 `404 MIGRATION_CODE_INVALID`
  - 期限切れ `410 MIGRATION_CODE_EXPIRED`
  - 使用済み `409 MIGRATION_CODE_ALREADY_USED`

---

## 11. DB実装（SQLite→Postgres移行前提）
### 11.1 Alembic
- マイグレーションでスキーマ管理（Phase 2以降で必須）
- Phase 1はSQLiteで始めても、なるべく同じDDLで運用する

### 11.2 最小DDL（概略）
- `users (user_id PK, feature_tier, billing_tier, created_at, updated_at)`
- `user_settings (user_id PK/FK, settings_json, etag, updated_at)`
- `usage_daily (user_id, date_yyyymmdd, generate_count, updated_at, PK(user_id,date))`
- `migration_tokens (code_hash PK, source_user_id, expires_at, used_at)`
- `idempotency_keys (user_id, key, expires_at, status, PK(user_id,key))` ※本文なし
- （必要なら）`rate_limit_buckets (...)` ※後回し可

---

## 12. テスト（MUST）
### 12.1 CIではOpenAIを叩かない
- `OPENAI_DISABLED=true` を必須にする
- `/generate` は 503 `OPENAI_DISABLED` を返すことをテスト

### 12.2 最低限のユニット/統合テスト
- auth: token発行/検証
- settings: ETag一致/不一致
- generate: 日次制限、レート制限、冪等キー競合
- migration: 発行→消費→再利用不可、期限切れ

---

## 13. Docker/Render（Phase 1）
### 13.1 Docker
- `Dockerfile` でFastAPIを起動可能にする
- 実行コマンド例：
  - `uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}`

### 13.2 Render
- 環境変数をRender側で設定
- `OPENAI_DISABLED` は環境別に設定（CI true / staging, prod false）
- ログはJSON（本文ゼロ）

---

## 14. 将来の分割（Phase 2+）
- 生成をワーカー化する場合：
  - `POST /generate` はジョブ投入→結果ポーリング or WebSocket へ拡張（契約追加が必要）
- ただし現行契約（同期応答）を維持するなら、まずはAPIの水平スケールで対応し、必要になったらv2で非同期APIを追加する。

---

## 15. Development Workflow（効率化・品質保証）

### 15.1 変数名規則
- **設定オブジェクトの統一**
  - `from app.config import settings as config_settings` で統一
  - ローカル変数名（`settings = st.settings_json` など）と明確に区別
  - 同一スコープ内で `settings` という複数の意味の変数を混在させない

### 15.2 関数実装チェックリスト（Acceptance Criteria）
すべての関数実装は以下をチェック：
- [ ] すべての条件分岐で **明示的な return 文** を記述（末尾の暗黙 `None` return を避ける）
- [ ] グローバル変数と local 変数の名前競合がないか確認
- [ ] Pylance の「unbound local variable」警告がないか確認
- [ ] 関数の戻り値型が関数シグネチャと一致しているか確認

### 15.3 テスト実行フロー
開発中のテスト実行は必ずこの順序に従う：

```
[Step 1] コード修正

[Step 2] ロジック正当性確認（サーバー起動なし）
  → from fastapi.testclient import TestClient
  → TestClient(app) でローカルテスト

[Step 3] サーバー再起動（ユーザー手動）
  ⚠️ Agent からサーバー再起動を依頼したが反映されない場合は、
     ユーザーが手動でターミナルで Ctrl+C → 再起動を完了するまで待機

[Step 4] HTTP リクエストでテスト（サーバー起動後）
  → PowerShell テストスクリプトで API テスト実行
  → 200/4xx/5xx の結果確認
```

### 15.4 サーバー再起動は手動必須（制約）
- Agent からサーバーをバックグラウンド起動できるが、**確実な再起動制御はできない**
- コード修正後の HTTP テスト実行前には、**必ずユーザーがターミナルで手動に再起動** する必要がある
- 推奨再起動方法：
  ```powershell
  # ターミナルで実行
  cd c:\dev\permy
  .\start_fastapi.ps1
  # または明示的に
  # cd c:\dev\permy\backend && python -m app.main
  ```

### 15.5 エラーハンドリング（開発環境 vs 本番環境）
- **開発環境**（localhost, ENVIRONMENT=dev）
  - 例外 traceback を JSON レスポンスに含める
  - デバッグに必要な詳細情報を返す
  
- **本番環境**（staging, prod）
  - エラー詳細を非表示
  - ユーザーに見せる最小限のメッセージのみ
  - 内部 traceback はサーバーログに記録（本文なし）


---

## 15. 実装チェックリスト（本文ゼロ監査）
- [ ] request/response body をログしていない
- [ ] 例外ログに本文が混入しない（バリデーション含む）
- [ ] DBに本文/生成文が存在しない
- [ ] メトリクスに本文由来情報がない
- [ ] OPENAI_DISABLED=true で外部呼び出しされない

---

## 16. 実装状況（Implementation Status）

**最終更新**: 2026-03-05

### 16.1 完了済み機能（✅）

#### Core APIs
- ✅ **匿名認証** (`POST /api/v1/auth/anonymous`)
  - JWT トークン発行
  - user_id 生成
  
- ✅ **ユーザー設定** (`GET/PUT /api/v1/me/settings`)
  - ETag による楽観的ロック
  - settings_json (診断結果、NG設定等) 管理
  
- ✅ **返信文生成** (`POST /api/v1/generate`)
  - OpenAI API 連携
  - A/B/C 候補生成
  - NG ゲート（safety_gate）
  - 日次制限・レート制限
  - Idempotency-Key 対応
  - **Followup 機能**（優先順位付き聞き返し）
  
- ✅ **データ移行** (`POST /api/v1/migration/issue`, `POST /api/v1/migration/consume`)
  - 12桁移行コード発行
  - ハッシュ化保存（平文なし）
  - 期限・使用済みチェック

- ✅ **Telemetry API** (`POST /api/v1/telemetry/events`)
  - 5種イベント（generate_requested, generate_succeeded, generate_failed, candidate_copied, app_opened）
  - バッチ送信対応（1-100 イベント）
  - UTC 時間バケット（hour_bucket_utc 0..23, dow_utc 0..6）
  - HMAC-SHA256 による user_id ハッシュ（復元不可能、privacy-first）

#### Tier System
- ✅ **Feature Tier / Billing Tier 分離**
  - feature_tier: `free` / `plus`（機能レベル）
  - billing_tier: `free` / `pro_store` / `pro_comp`（課金状態）
  - AuthContext で tier 情報管理
  - Pro_comp（永続無料）サポート

#### Management Tools
- ✅ **Pro_comp 権限付与ツール** (`backend/tools/grant_comp_user.py`)
  - CLI で user_id 指定して pro_comp 付与/解除/確認

#### Documentation & Tooling
- ✅ **OpenAPI Specification 自動生成**
  - FastAPI から OpenAPI 3.1.0 スキーマ出力
  - エクスポートツール (`backend/tools/export_openapi.py`)
  - 静的ファイル (`docs/api/openapi.json`)
  - Swagger UI: `/docs`, ReDoc: `/redoc`

- ✅ **Development Workflow ガイドライン** (section 15)
  - 変数名規則
  - 関数実装チェックリスト
  - テスト実行フロー
  - サーバー再起動の制約明記

### 16.2 テスト状況

#### PowerShell テストスクリプト（全て合格 ✅）
- ✅ `tools/manual_api_test.ps1`: コア API テスト（6/6 合格）
- ✅ `tools/test_telemetry.ps1`: Telemetry API テスト（5 イベント検証）
- ✅ `tools/test_followup.ps1`: Followup 機能テスト（優先順位確認）
- ✅ `tools/test_pro_comp.ps1`: Pro_comp tier 機能テスト

### 16.3 未実装・残作業（🔜）

#### Phase 1 完了目標
- 🔜 本文ゼロ最終監査（ログ・DB・例外メッセージ）
- 🔜 Alembic マイグレーション設定（Phase 2 での PostgreSQL 移行準備）
- 🔜 本番環境設定（環境変数、Render デプロイ準備）
- 🔜 全 acceptance test クリア（backend_impl, frontend_impl）

#### Phase 2 以降
- Redis 対応（レート制限）
- PostgreSQL 移行
- WebSocket 対応（生成進捗通知）

### 16.4 進捗率

- **Phase 1 実装進捗**: ~95%
- **Core API**: 100% 完了
- **Telemetry**: 100% 完了
- **Followup**: 100% 完了
- **Documentation**: 100% 完了
- **残作業**: 本番デプロイ準備、最終監査

