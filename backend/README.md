# Permy Backend

接客返信文生成API（本文非保存・privacy-first）

## 技術スタック

- Python 3.11+
- FastAPI + Uvicorn
- SQLAlchemy (async)
- SQLite (開発) / PostgreSQL (本番想定)
- OpenAI API

## 開発環境セットアップ

```powershell
# 依存関係インストール
cd backend
pip install -r requirements.txt

# 環境変数設定（.env ファイル作成）
# OPENAI_API_KEY=sk-...
# DATABASE_URL=sqlite:///./permy.db
# など

# DB 初期化
python -m app.scripts.init_db

# サーバー起動
cd ..
.\start_fastapi.ps1
# または
cd backend
python -m app.main
```

## API ドキュメント

### OpenAPI Specification

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/api/v1/openapi.json
- **静的ファイル**: [docs/api/openapi.json](../docs/api/openapi.json)

### OpenAPI スキーマの更新

コード変更後に OpenAPI スキーマを再生成：

```powershell
cd backend
python tools\export_openapi.py
```

これにより `docs/api/openapi.json` が更新されます。

## テスト

### 手動テスト（PowerShell）

```powershell
cd tools

# コア API テスト
.\manual_api_test.ps1

# Telemetry API テスト
.\test_telemetry.ps1

# Followup 機能テスト
.\test_followup.ps1

# Pro_comp tier テスト
.\test_pro_comp.ps1
```

### ユニットテスト（pytest）

```powershell
cd backend
pytest
```

**注意**: CI 環境では `OPENAI_DISABLED=true` を設定し、OpenAI API を呼び出さないこと。

## プロジェクト構成

```
backend/
  app/
    main.py              # FastAPI アプリケーション
    config.py            # 設定管理
    models.py            # SQLAlchemy モデル
    schemas.py           # Pydantic スキーマ
    security.py          # 認証・認可
    errors.py            # エラーハンドリング
    api/v1/              # API エンドポイント
      auth.py            # 匿名認証
      settings.py        # ユーザー設定
      generate.py        # 返信文生成
      telemetry.py       # テレメトリ
      migration.py       # データ移行
    middleware/          # ミドルウェア
    services/            # ビジネスロジック
    scripts/             # ユーティリティスクリプト
  tools/
    export_openapi.py    # OpenAPI スキーマ出力
    grant_comp_user.py   # Pro_comp 権限付与
  tests/                 # テスト
```

## 重要な原則

### 本文非保存（MUST）

- ユーザーが入力した本文（history_text）や生成された返信文を DB/ログ/テレメトリに保存しない
- プライバシー保護のため、ログには本文を含めない
- テレメトリには event_data のみ（本文なし）

### 認証

- 匿名認証: JWT トークンベース
- トークンに user_id を含む（署名検証必須）

### プラン・Tier 構造

- **feature_tier**: `free` / `plus`（機能レベル）
- **billing_tier**: `free` / `pro_store` / `pro_comp`（課金状態）
- API レスポンスの `plan` フィールド: `free` / `pro`（feature_tier から計算）

### 制限

- **日次制限**: free=3回/日, pro=100回/日
- **レート制限**: 1分あたりの最大リクエスト数
- **Idempotency**: 重複実行防止（Idempotency-Key ヘッダー）

## 開発ガイドライン

詳細は [docs/spec/21_backend_impl/backend_impl.md](../docs/spec/21_backend_impl/backend_impl.md) を参照。

### Development Workflow

1. コード修正
2. TestClient でロジック確認
3. **サーバー再起動**（手動）
4. HTTP リクエストでテスト

### 変数名規則

- 設定オブジェクト: `from app.config import settings as config_settings`
- ローカル変数と区別を明確に

### 関数実装チェックリスト

- すべての条件分岐で明示的な return 文
- グローバル変数と local 変数の名前競合なし
- Pylance 警告なし

## License

Private
