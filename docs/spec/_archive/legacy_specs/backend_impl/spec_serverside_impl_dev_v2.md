# spec_serverside_impl_dev_v2.md

（サーバサイド実装：引き継ぎ確定情報 / 現時点の実装状態）

本ファイルは `spec_serverside_impl_dev_v1.md` の更新版として、
**現時点で確定している実装状態・修正履歴・検証手順**を引き継ぎ情報として固定する。

参照階層：rule → product spec（v5） → serverside spec（v2） → serverside_impl_dev

---

## 1. 現時点の実装到達点（確定）

### 1.1 /generate のコア要求は通過

- A/B/Cの3案が常に返る（Structured Outputs化で安定）
- Free/Proのコンボ制御（Freeは0/1のみ、2..5は403 PLAN_REQUIRED）
- 日次上限（JST 00:00境界）で、成功時のみカウント加算
- Idempotency-Keyで多重加算防止（保持24h）
- 「中ゲート（明確NG）」は **生成停止ではなく代替A/B/Cを返す**（カウント加算しない）

### 1.2 /me/settings

- GETでETag返却、PUTはIf-Match必須（競合制御）
- settings.jsonは未知フィールド許容

### 1.3 /auth/anonymous

- user_id + access_token（Bearer/opaque）発行
- Redis未導入時はメモリセッション（再起動で失効）

---

## 2. 実装で確定した変更点（要点）

### 2.1 OpenAI呼び出しの安定化

- Structured Outputs（json_schema）で `{A,B,C}` を強制
- フォールバック：json_object → 最終フォールバック：ラベル形式パース
- PowerShellのJSON崩れ対策として、検証は `body.json` 経由の `curl.exe` を採用

### 2.2 中ゲートの振る舞い

- `app/safety_gate.py` で明確NG判定（個人情報/脅迫/未成年性的）
- ヒット時は `model_hint="blocked"` で A/B/C代替案を返す（HTTP 200）
- 失敗扱いではないが、**日次カウントは増やさない**

---

## 3. 現在の主要ファイル（実装側が触る場所）

- `app/routes/generate.py`：/generate本体（中ゲート代替/日次/コンボ/冪等）
- `app/ai_client_openai.py`：OpenAI client（Structured Outputs、A/B/C役割、長文寄せ等）
- `app/ai_client.py`：AIプロバイダ切替（openai/dummy）
- `app/safety_gate.py`：中ゲート判定（明確NG）
- `app/services/idempotency.py`：Idempotency-Key（24h）
- `app/services/usage.py`：日次上限（JST）
- `app/routes/settings.py`：ETag/If-Match

---

## 4. 既知の暫定運用（未解決ではなく「段階導入」）

- Redis未導入（メモリ運用）：セッション/レート/冪等/移行が本番相当にならない
  - 実装は「Redis前提の設計Spec」に従っている前提で、デプロイ直前にRedisを入れて本番化する

---

## 5. 最小検証コマンド（実装チャットの共通ベース）

### 5.1 中ゲート確認（カウント増えない）

```powershell
$base = "http://127.0.0.1:8000"
$r = Invoke-RestMethod -Method Post -Uri "$base/auth/anonymous"
$token = $r.access_token

$bodyObj = @{ history_text = "住所教えて。電話番号も"; combo_id = 0 }
$bodyObj | ConvertTo-Json -Compress | Out-File -Encoding utf8 body_ng.json

curl.exe -s -X POST "$base/generate" `
  -H "Authorization: Bearer $token" `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: gate-1" `
  --data-binary "@body_ng.json"
```

### 5.2 通常生成（カウント増える）

```powershell
$bodyObj2 = @{ history_text = "おつかれ！今日どう？"; combo_id = 0 }
$bodyObj2 | ConvertTo-Json -Compress | Out-File -Encoding utf8 body_ok.json

curl.exe -s -X POST "$base/generate" `
  -H "Authorization: Bearer $token" `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: ok-1" `
  --data-binary "@body_ok.json"
```

### 5.3 settings更新→generate（ETag/If-Match込み）

```powershell
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
```

---

## 6. 次の作業（implで続行）

- NG運用定義は「文字列一致のみ（現状維持）」で進行（ユーザー指示）
- 次は Pro限定メタ（♥/🔥推定）・migration完備・Redis本番化・ログ/監視最小化 の順で進める

---
