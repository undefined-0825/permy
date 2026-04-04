# environment_setup.md — Permy Backend 環境セットアップ（開発 / CI / Render）

**Scope:** バックエンド（FastAPI）の開発環境・CI・Renderテスト運用のセットアップ手順を定義する。  
本文非保存ポリシーにより、ログ/テストデータの取り扱いに注意する。

---

## 0. 前提

- OS: Windows 10/11（PowerShell 5系での運用を想定する場合は別途プロジェクト標準に従う）
- Python: 3.12+（プロジェクト標準に合わせる）
- Git: 最新安定版
- エディタ: VS Code（推奨）

---

## 1. ローカル開発環境（venv）

### 1.1 仮想環境作成

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
```

### 1.2 依存インストール

- `pyproject.toml` を採用する場合（推奨）：

```powershell
pip install -e .
```

- `requirements.txt` を採用する場合：

```powershell
pip install -r requirements.txt
```

### 1.3 ローカル実行

```powershell
setx ENV "dev"
setx DATABASE_URL "sqlite:///./permy.db"
setx TOKEN_SECRET "dev-only-secret"
setx OPENAI_DISABLED "true"
# OPENAI_API_KEY は dev で手動テスト時のみ設定（コミット禁止）
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

- ブラウザ: `http://127.0.0.1:8000/docs`（Swagger UI）

---

## 2. 環境変数（共通）

### 2.1 必須（最低限）

- `ENV`: `dev|staging|prod`
- `DATABASE_URL`: SQLite/Postgres
- `TOKEN_SECRET`: トークン署名用
- `OPENAI_DISABLED`: `true|false`

### 2.2 任意（推奨）

- `OPENAI_API_KEY`: LLM呼び出し用（CIでは設定しない）
- `LOG_LEVEL`: `INFO|DEBUG|WARNING|ERROR`
- `REDIS_URL`: Phase 2以降（任意）
- `APP_VERSION`: 最新アプリバージョン（例 `1.2.0`）
- `APP_MIN_SUPPORTED_VERSION`: 強制更新の最小サポート版（例 `1.1.0`）
- `APP_ANDROID_STORE_URL`: Google Play のストアURL
- `APP_IOS_STORE_URL`: App Store のストアURL
- `MIGRATION_CODE_TTL_MIN`: 移行コード期限（数値は別Specに従う）
- `RATE_LIMIT_MODE`: `memory|db|redis`
- `REQUEST_ID_HEADER`: `X-Request-Id` 等

### 2.3 秘匿情報のルール（MUST）

- `OPENAI_API_KEY` は **ソース管理に絶対入れない**（.envのコミット禁止）
- CIでもOpenAIを叩かない（`OPENAI_DISABLED=true`）

---

## 3. データベース

### 3.1 SQLite（Phase 1 / ローカル）

- `DATABASE_URL=sqlite:///./permy.db`
- テーブルはアプリ起動時に作成しても良いが、将来Postgres移行するならAlembicを推奨。

### 3.2 Postgres（Phase 2以降）

- マネージドPostgresへ移行（クラウド/Render有償等）
- `DATABASE_URL=postgresql+psycopg://user:pass@host:5432/dbname`

### 3.3 マイグレーション（Alembic）

```powershell
alembic init alembic
alembic revision --autogenerate -m "init"
alembic upgrade head
```

---

## 4. CI セットアップ（OpenAI呼び出し禁止）

### 4.1 ルール

- CIでは `OPENAI_DISABLED=true` を必須
- `OPENAI_API_KEY` はCIに登録しない（本番相当のキー露出を避ける）

### 4.2 CIでのテスト実行例

```powershell
setx OPENAI_DISABLED "true"
pytest -q
```

### 4.3 テストが満たすべき要件

- `/generate` は `OPENAI_DISABLED=true` のとき `503 OPENAI_DISABLED` を返すこと
- request/response body をログしない（本文ゼロ）
- 主要エンドポイントの契約テスト（status/error_code）

---

## 5. Render でのテスト運用（本番構成 / PostgreSQL + Redis）

### 5.1 目的・方針

- 本番環境テスト用の構成（PostgreSQL + Redis + Web Service）
- **自動デプロイは行わない**（`deploy_strategy.md` に準拠、手動デプロイのみ）
- Blueprint（`render.yaml`）を使用した一括セットアップ

### 5.2 前提条件

- Renderアカウント作成済み
- GitHubリポジトリがRenderに接続済み
- プロジェクトルートに `render.yaml` が存在

### 5.3 Blueprint デプロイ手順

#### Step 1: Render Dashboard でBlueprint作成

1. Render Dashboard → 「New」→ 「Blueprint」を選択
2. GitHubリポジトリを選択（`permy`）
3. ブランチを選択（例：`add_frontend` または `main`）
4. Render が `render.yaml` を自動検出
5. 「Apply」をクリック（3コンポーネントが作成される）

   - `permy-backend` (Web Service)
   - `permy-db` (PostgreSQL)
   - `permy-redis` (Redis)

#### Step 2: 環境変数の手動設定（必須）

Blueprint適用後、以下の環境変数を**手動設定**（`sync: false` のため自動設定されない）：

1. **OPENAI_API_KEY**（必須）

   - `permy-backend` サービス → Environment タブ
   - Key: `OPENAI_API_KEY`
   - Value: OpenAI Platform で発行したAPIキー（`sk-proj-...`）

2. **TELEMETRY_HASH_SECRET**（必須）

   - `permy-backend` サービス → Environment タブ
   - Key: `TELEMETRY_HASH_SECRET`
   - Value: 以下のコマンドで生成

     ```powershell
     .\tools\generate_telemetry_secret.ps1
     ```

   - 出力された64文字の16進数文字列をコピー＆ペースト

3. 「Save Changes」をクリック → サービスが自動再起動

#### Step 3: デプロイ確認

- Render Logs で起動ログを確認
- Health Check エンドポイントを確認：

  ```powershell
  curl https://permy-backend.onrender.com/api/v1/health
  # Expected: {"status":"ok"}
  ```

- Version エンドポイントを確認：

  ```powershell
  curl https://permy-backend.onrender.com/api/v1/version
  # Expected: {"version":"1.0.0", ...}
  ```

### 5.4 データベース初期化

PostgreSQLテーブルは初回起動時に自動作成される（`app/db.py` の `init_db()` が実行）。
手動で確認したい場合：

```bash
# Render Shell から実行
python -c "from app.db import init_db; import asyncio; asyncio.run(init_db())"
```

### 5.5 環境変数一覧（render.yaml で自動設定）

以下は Blueprint で自動設定されるため手動設定不要：

- `APP_ENV=production`
- `AI_PROVIDER=openai`
- `DATABASE_URL`（PostgreSQL接続文字列、自動生成）
- `REDIS_URL`（Redis接続文字列、自動生成）
- レート制限設定（`RL_*`）
- 日次制限（最終固定値）
  - Free: 1日3回
  - Pro: 1日100回
  - Premium: 1日200回
  - 上記は運用確定値としてサーバコード内の固定定数で判定する（環境変数で上書きしない）

### 5.5.1 生成消費カウント運用（MUST）

- 通常のGenerate実行: 1回消費
- 「顧客あり/なし比較生成」: 同一履歴で2回生成するため2回消費
- 消費判定はすべてサーバ日次カウントを正とし、クライアント表示は参考情報とする

### 5.6 ログ運用（本文ゼロ）

- Render Logs に本文が出力されていないことを確認
- 例外ログにも本文が混入していないことを確認
- 必要に応じて `UVICORN_ACCESS_LOG=false` で詳細ログを抑制（既定値）

### 5.7 コスト試算（Render Starter Plan）

- Web Service: $7/月（512MB RAM、常時稼働）
- PostgreSQL: $7/月（256MB storage、1GB RAM）
- Redis: $10/月（1GB memory）
- **合計: 約 $24/月**（初期テスト運用）

### 5.8 ストア登録用 公開URL（法務ページ）

Render公開後、以下URLを Google Play / App Store Connect に登録する。

- 利用規約: `https://<your-service>.onrender.com/legal/terms`
- プライバシーポリシー: `https://<your-service>.onrender.com/legal/privacy`
- ヘルプ（使い方）: `https://<your-service>.onrender.com/legal/help`

登録先の例：

- Google Play Console: アプリのコンテンツ / プライバシーポリシー、ストア掲載情報
- App Store Connect: App Information / Privacy Policy URL

---

## 6. 手動ライブテスト（回数上限・安全運用）

- 開発/検証の「ライブ生成」は手動で行う（自動化しない）
- 回数上限は別Spec（プラン上限）に従う
- 生成テストに使う入力は、ユーザー同意のあるテストデータのみ（本文非保存）

---

## 7. トラブルシュート（よくある）

### 7.1 `ModuleNotFoundError`

- venvが有効化されているか確認
- `pip install -e .` / `pip install -r requirements.txt` を再実行

### 7.2 ポート競合

- `--port 8000` を変更

### 7.3 `OPENAI_DISABLED` なのに外部呼び出しが発生する

- 実装で `OPENAI_DISABLED` 判定が入口で強制されているか確認
- テストで `503 OPENAI_DISABLED` を担保

### 7.4 Render デプロイエラー「Build failed」

- Render Logs で詳細を確認
- `requirements.txt` の依存関係エラー → ローカルで `pip install -r backend/requirements.txt` を実行して検証
- `buildCommand` のパス間違い → `render.yaml` の `buildCommand` を確認

### 7.5 Render 起動エラー「psycopg.OperationalError」

- `DATABASE_URL` が正しく設定されているか確認（Blueprint で自動設定されるはず）
- PostgreSQL サービスが起動しているか確認
- Render Dashboard → `permy-db` → Status を確認

### 7.6 Redis 接続エラー

- `REDIS_URL` が正しく設定されているか確認（Blueprint で自動設定）
- Redis サービスが起動しているか確認
- 一時的に Redis を無効化してテストする場合：環境変数 `REDIS_DISABLED=true` を追加

---

## 8. 追加メモ（将来移行を見据えた最小）

- `DATABASE_URL` を差し替えるだけでSQLite→Postgresに移行できるようにする
- Redis導入は `RATE_LIMIT_MODE=redis` を実装し、差し替え可能にしておく
- Docker化しておけば、Render→クラウド（Cloud Run/GKE等）移行が容易
- **Blueprint 定義**: プロジェクトルートの `render.yaml` にインフラ構成を定義済み
- **環境変数管理**: 秘匿情報（`OPENAI_API_KEY`, `TELEMETRY_HASH_SECRET`）は手動設定（`sync: false`）
