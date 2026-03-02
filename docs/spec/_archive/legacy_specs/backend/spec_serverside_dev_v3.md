# spec_serverside_dev_v3.md
（サーバサイド構築：ローカル開発環境構築・検証手順 / Windows + PowerShell）

このドキュメントは、`spec_serverside_dev_v2.md` の派生として、**実際に動作確認が取れた「正しい環境構築」**を固定しつつ、
本チャット（serverside_dev）のスコープを「構築専用」に明確化する。

- 対象：Windows 11 / PowerShell（主に Windows PowerShell 5.x 想定）
- バックエンド：Python + FastAPI（Uvicorn）
- 重要：会話本文/生成本文は永続保存しない（既存Spec準拠）
- 重要：Redis未導入の当面運用（メモリRedisモード）

---

## 1. 前提
- Python 3.11+（例：`Python311`）
- 本プロジェクト配置（例）：`C:\dev\talk_assist\backend`
- 以降のコマンドは PowerShell 前提（cmd.exe と混ぜない）

---

## 2. よくあるハマり（結論）
- PowerShell では `source` や `deactivate` は使えない（bash文法）。
- PowerShell の `curl` は別名（Invoke-WebRequest）なので **`curl.exe`** を明示する。
- SQLite の `DATABASE_URL=sqlite+aiosqlite:///./permy.db` は **カレントディレクトリ依存**。`backend` 直下で実行する。
- Windowsの `ZoneInfo("Asia/Tokyo")` は `tzdata` が無いと落ちる。
- `init_db` は **モデル import しないとテーブルが作られない**（SQLAlchemyのmetadataが空になる）。
- OpenAI SDK はバージョン混在で ImportError が起きやすい。**venvを作り直して固定**が最短。
- OpenAIキーは `.env` と環境変数が競合しやすい（意図しないキーを読む）。**prefix/len/tailで検証**する。

---

## 3. venv 作成（クリーン構築）
**ImportError等が出たら、まず `.venv` を作り直す。**

```powershell
cd C:\dev\talk_assist\backend
Remove-Item -Recurse -Force .\.venv

python -m venv .venv
.\.venv\Scripts\Activate.ps1

pip install -r requirements.txt
pip install "openai==1.99.0" tzdata
```

インストール確認：

```powershell
python -c "import openai; print(openai.__version__); print(openai.__file__)"
pip freeze | findstr /i openai
```

期待：
- `openai==1.99.0` が **1行だけ**
- `...\.venv\Lib\site-packages\openai\__init__.py`

---

## 4. DB 初期化（SQLite）
症状：
- `sqlite3.OperationalError: no such table: users`

原因：
- `init_db.py` がモデルを import しておらず、`create_all()` が空実行になる。

対策：`app\scripts\init_db.py` に **必ず** 1行追加

```python
import app.models  # ← 追加（モデル登録）
```

初期化実行（backend直下で）：

```powershell
cd C:\dev\talk_assist\backend
del .\permy.db -ErrorAction SilentlyContinue
python -m app.scripts.init_db
```

テーブル定義が載っているか確認：

```powershell
python -c "from app.db import Base; import app.models; print(sorted(Base.metadata.tables.keys()))"
```

期待：
`['plan_status', 'usage_daily', 'user_settings', 'users']`

---

## 5. Redisなしモード（当面運用）
Docker/redis-cli が無い環境向けに、メモリRedisモードで起動する。

### 5.1 起動スクリプト（推奨）
`start_radius_memory.ps1`（backend直下）

```powershell
cd C:\dev\talk_assist\backend
.\.venv\Scripts\Activate.ps1
$env:REDIS_DISABLED = "true"
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

注意：
- メモリRedisのため **再起動するとセッショントークンは無効**（毎回`/auth/anonymous`が必要）

---

## 6. OpenAI 接続（鍵の競合に注意）
`.env`（backend直下）に設定：

```text
AI_PROVIDER=openai
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-5.2
```

### 6.1 「サーバが読んでいるキー」を検証（重要）
意図と異なるキーを読んで 401 になることがある。**末尾4桁で確認**する。

```powershell
python -c "from app.config import settings; k=(settings.openai_api_key or ''); print('prefix=',k[:7],'len=',len(k),'tail=',k[-4:])"
```

環境変数の競合が疑わしい場合：

```powershell
gci env:OPENAI_API_KEY
Remove-Item Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
```

---

## 7. 疎通確認（推奨手順）
### 7.1 health
```powershell
curl.exe http://127.0.0.1:8000/health
```

### 7.2 token取得（再起動したら毎回）
```powershell
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/auth/anonymous"
$token = $r.access_token
```

### 7.3 generate（PowerShellのJSON崩れ対策：ファイル経由が最強）
PowerShellで変数を `curl.exe --data-binary` に渡すと崩れる場合があるため、**body.jsonに出して渡す**。

```powershell
$bodyObj = @{ history_text = "おつかれ！今日どう？"; combo_id = 0 }
$bodyObj | ConvertTo-Json -Compress | Out-File -Encoding utf8 body.json

curl.exe -s -X POST "http://127.0.0.1:8000/generate" `
  -H "Authorization: Bearer $token" `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: openai-ok-1" `
  --data-binary "@body.json"
```

---

## 8. トラブルシュート（症状→対策）
### 8.1 `No time zone found with key Asia/Tokyo`
- 対策：`pip install tzdata`（requirementsにも追加推奨）

### 8.2 `no such table: users`
- 対策：`init_db.py` に `import app.models` を追加し、`permy.db` を作り直す

### 8.3 `AI_UPSTREAM_ERROR ImportError ... ResponseReasoningSummaryDoneEvent`
- 対策：`.venv` を作り直し、`openai==1.99.0` に固定（混在除去が最短）

### 8.4 `AuthenticationError 401 Incorrect API key`
- 対策：`.env` のキー確認 + **環境変数競合除去** + prefix/len/tailで検証

### 8.5 PowerShellで `curl -X` が効かない
- 対策：PowerShellの `curl` は alias。**`curl.exe`** を明示する。

---

## 9. 運用上の注意（メモリRedis）
- `REDIS_DISABLED=true` の間：
  - 再起動でセッションが消える（トークンは毎回取り直し）
  - レート制限/移行/冪等は「開発用の簡易動作」になる
- 本番運用は Redis 導入前提（将来タスク）

---

## 10. チャットスコープと分離ルール（重要）
### 10.1 本チャット（serverside_dev）のスコープ
本チャットは「サーバサイド構築」専用とする。対象は以下に限定する。
- ローカル環境構築、依存導入、venv、起動、疎通確認
- .env運用、OpenAI接続、キー競合対策、PowerShell運用
- SQLite初期化、カレントディレクトリ問題、tzdata等のOS依存
- （将来）Redis導入の手順・運用切替の段取り
- ログ最小化（本文非保存）を壊さないための運用手順

本チャットでは API実装・コード改修・仕様追加（generate等の挙動変更）を扱わない。

### 10.2 実装チャットの新設（serverside_impl_dev）
実装は別チャット「【Spec】サーバサイド実装（実装専用）」で行う。
SSOT階層は以下：
rule → product spec → serverside spec → serverside_impl_dev

実装Specファイルのプレフィックス：
- `spec_serverside_impl_dev_`

version運用：
- `spec_serverside_impl_dev_v1.md`, `v2...`（既存versionの上書き禁止）

### 10.3 混在防止
本チャットで実装の相談が出た場合、実装チャットへ誘導し、本チャットでは以後扱わない。
