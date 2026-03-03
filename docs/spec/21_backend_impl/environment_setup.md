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

## 5. Render でのテスト運用（Phase 1）
### 5.1 目的
- 知人テスト用の最小運用（少数ユーザー）
- 自動デプロイは行わない（CIのみ）

### 5.2 Render Web Service の作成
- ランタイム: Docker もしくは Python
- Start Command:
  - Docker: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
  - Python: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

### 5.3 Render 環境変数（例）
- `ENV=staging`
- `DATABASE_URL=sqlite:///./permy.db`（※永続性が必要ならPostgresへ）
- `TOKEN_SECRET=<render-secret>`
- `OPENAI_DISABLED=false`（テスト運用で生成する場合）
- `OPENAI_API_KEY=<secret>`（RenderのSecretに設定）
- `LOG_LEVEL=INFO`

### 5.4 ログ運用（本文ゼロ）
- Renderログに本文が出ないことを確認
- 例外ログにも本文が混入しないことを確認

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

---

## 8. 追加メモ（将来移行を見据えた最小）
- `DATABASE_URL` を差し替えるだけでSQLite→Postgresに移行できるようにする
- Redis導入は `RATE_LIMIT_MODE=redis` を実装し、差し替え可能にしておく
- Docker化しておけば、Render→クラウド（Cloud Run/GKE等）移行が容易
