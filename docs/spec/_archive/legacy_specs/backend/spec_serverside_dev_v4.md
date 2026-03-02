# spec_serverside_dev_v4.md
（サーバサイド構築：ローカル開発環境構築・検証手順 / Windows + PowerShell）

本ファイルは `spec_serverside_dev_v3.md` を拡張し、**現在のフォルダ構成・主要ファイル一覧**と、
実装チャット（serverside_impl_dev）へ引き継ぐための「構築観点の確定情報」を追記する。

- 対象：Windows 11 / PowerShell（Windows PowerShell 5.x 想定）
- バックエンド：Python + FastAPI（Uvicorn）
- 重要：会話本文/生成本文は永続保存しない（Spec準拠）
- 重要：Redis未導入の当面運用（メモリRedisモード）

---

## 0. SSOT参照順
rule → product spec → serverside spec → serverside_dev

---

## 1. 前提
- Python 3.11+
- 配置例：`C:\dev\talk_assist\backend`
- 以降のコマンドは PowerShell 前提（cmd/bashと混ぜない）

---

## 2. 現在のフォルダ構成（実例）
```
backend/
  app/
    main.py                … FastAPIエントリ
    config.py              … Settings（.env/環境変数）
    db.py                  … SQLAlchemy(Async) engine / Base / get_db
    models.py              … users/user_settings/plan_status/usage_daily
    schemas.py             … Pydanticスキーマ（Generate/Settings等）
    security.py            … AuthContext / セッション（Bearer Opaque）
    redis_client.py         … Redisクライアント（REDIS_DISABLEDでメモリ運用）
    ratelimit.py           … fixed window 等
    errors.py              … 共通エラーモデル生成（err）
    safety_gate.py         … 中ゲート（明確NG）判定
    utils_time.py          … JST日付（ZoneInfo） ※tzdata必須
    routes/
      auth.py              … POST /auth/anonymous
      settings.py          … GET/PUT /me/settings（ETag/If-Match）
      generate.py          … POST /generate（中ゲート代替A/B/C、日次カウント等）
      migration.py         … /migration/*（実装済みの場合）
      health.py            … /health
    services/
      usage.py             … usage_daily（JST境界）
      idempotency.py       … Idempotency-Key（24h）
      migration.py         … 移行コード（12桁/10分/1回 等）
  start_radius_memory.ps1  … 開発起動（REDIS_DISABLED=true）
  requirements.txt         … 依存
  .env.example             … 設定例
  .env                     … ローカル設定（要秘匿）
  permy.db                 … SQLite（ローカル検証用）
  body.json                … curlで叩くための一時ファイル（運用で生成）
```

> 注意：上記は「このチャットで確定した構成」。手元のフォルダに差異がある場合は、実装チャット側で最新状態を再確認する。

---

## 3. 構築で確定した重要事項（再発防止）
### 3.1 PowerShell注意
- PowerShell の `curl` は alias → **`curl.exe` を使う**
- cmdの継続 `^` はPowerShellでは使わない（` を使う or 1行）

### 3.2 tzdata必須（Windows）
- `ZoneInfo("Asia/Tokyo")` で落ちる → `pip install tzdata`

### 3.3 DB初期化（空DB事故）
- `app/scripts/init_db.py` に `import app.models` が無いと `create_all()` が空実行になる
- `permy.db` はカレントディレクトリ依存 → 必ず `backend` 直下で初期化

### 3.4 OpenAIキー競合
- `.env` と環境変数 `OPENAI_API_KEY` が競合しやすい
- prefix/len/tailでサーバが読んでるキーを検証し、環境変数が犯人なら消す

### 3.5 OpenAI SDKの混在対策
- ImportErrorが出たら、**.venv作り直し**が最短
- 依存固定：`openai==1.99.0` を確認（1つだけ）

---

## 4. 起動方法（構築チャットの最終確定）
### 4.1 起動スクリプト（推奨）
`start_radius_memory.ps1`
```powershell
cd C:\dev\talk_assist\backend
.\.venv\Scripts\Activate.ps1
$env:REDIS_DISABLED = "true"
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

---

## 5. 疎通（構築観点の正解）
### 5.1 token取得
```powershell
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/auth/anonymous"
$token = $r.access_token
```

### 5.2 settings更新→generate（ファイル経由でJSON崩れ回避）
```powershell
$base = "http://127.0.0.1:8000"
$r = Invoke-RestMethod -Method Post -Uri "$base/auth/anonymous"
$token = $r.access_token

$resp = Invoke-WebRequest -UseBasicParsing -Method Get -Uri "$base/me/settings" -Headers @{ Authorization = "Bearer $token" }
$etag = $resp.Headers["ETag"]

$settingsObj = @{
  settings = @{
    settings_schema_version = 1
    persona_version = 2
    relationship_type = "customer"
    reply_length_pref = "long"
    ng_tags = @()
    ng_free_phrases = @("会いたい", "今すぐ")
  }
}
$settingsJson = $settingsObj | ConvertTo-Json -Depth 10 -Compress

Invoke-RestMethod -Method Put -Uri "$base/me/settings" `
  -Headers @{ Authorization = "Bearer $token"; "If-Match" = $etag } `
  -ContentType "application/json" `
  -Body $settingsJson

$genObj = @{ history_text = "おつかれ！今日どう？"; combo_id = 0 }
$genObj | ConvertTo-Json -Depth 10 -Compress | Out-File -Encoding utf8 body.json

curl.exe -s -X POST "$base/generate" `
  -H "Authorization: Bearer $token" `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: flow-1" `
  --data-binary "@body.json"
```

---

## 6. 実装チャットへの引き継ぎ（構築スコープ）
- ここまでで「OpenAI接続まで含めたローカル疎通」が通ることを確認済み
- Redis未導入（メモリ運用）で進行中。再起動でtoken無効になる前提
- 実装チャットでは、**コード改修・品質チューニング・安全制御**等を扱う（本チャットでは扱わない）

---
