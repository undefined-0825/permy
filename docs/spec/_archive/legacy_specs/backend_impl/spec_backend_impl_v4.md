# 【Spec】ペルミィ - サーバサイド実装統合Spec（SSOT v3）
**Version:** v3 (Integrated Implementation SSOT)
**Last Updated (JST):** 2026-03-01 13:20:00 +0900

---

## 0. 位置づけ（SSOT階層）
本ファイルはサーバサイドの「実装」における唯一の正（SSOT）である。
1. **spec_rule.md**（運用ルール）
2. **最新プロダクトSpec**（v10+：夜職完振り）
3. **サーバサイド設計Spec**（v4：本文非保存/共通設計）
4. **本サーバサイド実装Spec**（v3：具体的コード・パラメータ・タスク）

---

## 1. 現時点の実装到達点（確定事項）

### 1.1 /generate（生成基盤）
- **Structured Outputs (json_schema)**: OpenAI APIを利用し、`{A, B, C}` の3案構造を強制。
- **フォールバック**: json_object → ラベル形式パース の順で制御し、生成失敗を極小化。
- **日次上限制御**: JST 00:00境界。生成成功時のみカウント加算。
- **冪等性**: `Idempotency-Key`（24h保持）による多重実行・多重カウント防止。
- **中ゲート（安全制御）**: `app/safety_gate.py` で明確NG（個人情報/脅迫等）を判定。
  - ヒット時はAIを呼ばず、**代替A/B/C案を回答（HTTP 200）**。
  - **日次カウントは増やさない**。`model_hint="blocked"` を付与。

### 1.2 /me/settings（設定管理）
- **競合制御**: GETで `ETag` 返却、PUTで `If-Match` 必須。不一致時は `409` を返す。
- **柔軟性**: `settings.json` は未知のフィールドを許容し、将来拡張に対応。

### 1.3 /auth/anonymous（認証）
- `user_id` + `access_token`（Bearer/Opaque）発行。
- Redis未導入時はメモリセッションで運用（再起動で失効）。

---

## 2. API詳細・定数SSOT（MUST）

### 2.1 営業目的（combo_id）の再定義
プロダクトSpec v10に従い、以下のIDを実装上の正とする。旧ID(0..5)は廃止。
- **10**: 来店確定（Free/Pro）
- **11**: 同伴獲得（Pro限定）
- **12**: 休眠復活（Free/Pro）
- **制御**: Freeユーザーが 11 を指定した場合は `403 PLAN_REQUIRED` を返す。

### 2.2 入力制約
- **上限**: 20,000文字（Unicodeコードポイントカウント）。
- **処置**: 超過時は `422`。要約や切り詰めはサーバ側では行わない。

### 2.3 TTL・レート制限（初期値）
- **セッション**: 14日間。
- **移行コード**: 有効10分 / 試行10回でロック。
- **生成制限**: 瞬間 5回/1min。

---

## 3. 技術スタックとファイル構成（MUST）

### 3.1 構成
- `app/routes/generate.py`: 生成ロジック、中ゲート、日次、冪等。
- `app/ai_client_openai.py`: OpenAI連携（A/B/C役割固定、長文寄せプロンプト）。
- `app/safety_gate.py`: 明確NG判定ロジック。
- `app/services/usage.py`: JST境界の日次上限管理。

### 3.2 ログ・プライバシー
- **保存禁止**: 会話本文、生成本文、移行コード平文、外部AIへの送信本文。
- **リクエスト識別**: 全レスポンスに `X-Request-Id` を付与。例外ハンドラでも必須。

---

## 4. 運用・検証手順（MUST）

### 4.1 NGタグ/フレーズ運用
- 現状維持：**単純な文字列一致**（ng_free_phrases等）で判定。

### 4.2 検証用PowerShellスクリプト
JSON崩れ防止のため、必ず一時ファイルを経由する。
```powershell
# 1. トークン取得
$r = Invoke-RestMethod -Method Post -Uri "[http://127.0.0.1:8000/auth/anonymous](http://127.0.0.1:8000/auth/anonymous)"
$token = $r.access_token

# 2. 中ゲートテスト（カウント加算なし）
$bodyObj = @{ history_text = "住所教えて。電話番号も"; combo_id = 10 }
$bodyObj | ConvertTo-Json -Compress | Out-File -Encoding utf8 body_ng.json
curl.exe -s -X POST "[http://127.0.0.1:8000/generate](http://127.0.0.1:8000/generate)" `
  -H "Authorization: Bearer $token" `
  -H "Content-Type: application/json" `
  -H "Idempotency-Key: gate-test" `
  --data-binary "@body_ng.json"

---

# 付録A: 追加で明記する決定事項（MUST）
**Added (JST):** 2026-03-01 14:20:00 +0900

## A-1. 匿名開始（アカウント登録なし）
- 本プロダクトは **アカウント登録（メール/電話番号/パスワード等）を提供しない**。
- 認証は `POST /auth/anonymous` のみで開始し、Bearerで以後のAPIにアクセスする。

## A-2. 移行方式（QR廃止を明記）
- 端末移行のQRコード方式は廃止。
- 12桁移行コード方式（期限/1回限り/レート制限）を唯一の方式とする。
