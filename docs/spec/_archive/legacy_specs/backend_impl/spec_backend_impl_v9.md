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
---

## 90. ステージング/検証デプロイ（Render等）（SHOULD）
**Added (JST):** 2026-03-01 15:00:00 +0900

目的：ローカル起動の摩擦を下げ、テスター検証・反復速度を上げる。fileciteturn2file1L21-L60

### 90.1 Render（例）設定の要点
- Root Directory が `backend/` の場合、Build/Start コマンドには `backend/` を二重指定しない（UI上の `backend/ $` は表示プレフィックス）。fileciteturn2file0L1-L37
- Build: `pip install -r requirements.txt`
- Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`（`$PORT` 必須）fileciteturn2file0L18-L33
- `backend/requirements.txt` が存在しないとビルド失敗する。fileciteturn2file0L71-L85
- 環境変数 `OPENAI_API_KEY` は Render 側の Environment に設定する（`.env` をアップロードしない）。fileciteturn2file1L12-L19

### 90.2 疎通
- `/health` で稼働確認（`{"status":"ok"}`）。fileciteturn2file0L44-L51
- `/docs`（FastAPI標準）で疎通確認（公開範囲は運用判断）。

### 90.3 Freeプラン前提の注意（SHOULD）
- Freeはスリープ/コールドスタートがある前提で、モバイル側のタイムアウトを長めに取る（例：30秒）。

---

# 付録C: 開発起動の固定（時間ロス削減 / SHOULD）
**Added (JST):** 2026-03-01 15:10:00 +0900

## C-1. リポジトリ構成（推奨）
- ルートに以下を配置する（例：`C:\dev\talk_assist`）
  - `backend/`（FastAPI）
  - `frontend/`（Flutter）
  - `dev_run.bat`（開発一括起動）

## C-2. Pythonバージョン固定（MUST: 再発防止）
- Windows環境では **Python 3.11.x を固定**して backend を運用する。
  - 理由：新しすぎるPython（例：3.14系）では標準ライブラリ差分によりuvicorn起動で不具合が出るケースがある。
- venvは `.venv` を推奨。

## C-3. start_api.bat（方針 / SHOULD）
- `activate` に依存せず、**venvのpython.exeをフルパス指定**して起動する（PATH事故を回避）。
- `.env` は読み込むが、キーの表示（echo）はデフォルト無効（機密対策）。

## C-4. dev_run.bat（方針 / SHOULD）
- backend起動 → 少し待つ → `adb reverse tcp:8000 tcp:8000` → `flutter run -d <deviceId>` を1回で実行できる形にする。
- 実装は “固定コマンドを一行ずつ” を原則とし、PowerShell/cmdの構文混在を避ける。

---

# 付録B: 開発環境の既知事故と固定手順（SHOULD / 手戻り防止）
**Added (JST):** 2026-03-01 17:05:00 +0900

## B-1. WindowsのJST（zoneinfo）事故
- Windows環境で `ZoneInfo("Asia/Tokyo")` が失敗する場合があるため、依存に `tzdata` を入れる（既定）。  
  ※本Specの「ローカル開発・検証」前提に従う。

## B-2. pipランチャ破損（venvパス混入）の回避
- `pip install ...` ではなく **`python -m pip ...` を原則**とする（パス混入事故を回避）。
- `Fatal error in launcher: Unable to create process ...` のように、別プロジェクトの `.venv` を指して壊れている場合は **`.venv` を作り直す**（最短復旧）。
  - 例: `deactivate` → `.venv` 削除 → `python -m venv .venv` → `python -m ensurepip --upgrade` → `python -m pip install -r requirements.txt`

## B-3. OpenAI SDK と httpx の互換性
- `TypeError: Client.__init__() got an unexpected keyword argument 'proxies'` が出る場合、**openai SDK と httpx の組合せ不整合**が疑わしい。
- 対応方針（推奨）:
  - `openai` を本Specで推奨するバージョンに固定
  - `httpx` を互換のあるバージョンに固定（例: `httpx==0.27.2`）
- 依存の固定は `requirements.txt`（または `pyproject.toml`）でSSOT化し、手元だけの偶然で動く状態を禁止する。

## B-4. OpenAI SDKのパラメータ互換
- `max_output_tokens` 等はSDKの世代差でエラーになり得るため、**利用するSDKバージョンを固定**し、本番/CI/新端末で再現可能にする。

---

# 付録X: TypeラベルSSOT（MUST）
**Added (JST):** 2026-03-01 18:25:00 +0900

## X-1. Type日本語ラベル（SSOT / MUST）
以下が唯一の正。**本ドキュメント内の過去表記（安定志向/流動 等）はすべて本表で上書き**する。

```kotlin
// 本当の私（価値観）
enum class TrueSelfType {
    Stability,     // 安定重視タイプ
    Independence,  // 自立タイプ
    Approval,      // 承認欲求タイプ
    Realism,       // 現実派タイプ
    Romance,       // ロマンタイプ
}

// 夜の私（営業スタイル）
enum class NightSelfType {
    VisitPush,   // 来店重視タイプ
    Heal,        // 癒しタイプ
    LittleDevil, // 小悪魔タイプ
    BigClient,   // 太客育成タイプ
    Balance,     // バランスタイプ
}
```

### X-2. 互換性ルール（MUST）
- API/設定のIDは上記 enum 名を使用する（表示名ではない）。
- `NightSelfType` は **`Flow` を廃止し `Balance` を採用**する。
  - 既存データが `Flow` を持つ場合、サーバは `Balance` に正規化して返す（クライアントは `Flow` を扱わない）。
- TrueSelfType の `Stability` の表示名は **「安定重視タイプ」** を唯一の正とする（安定志向タイプは使用しない）。
- 画像ファイル名のSSOT（例: `true_stability.png`）は変更しない。


# 付録Y: /generate followup（聞き返し）DTO/実装（MUST）
**Added (JST):** 2026-03-01 18:25:00 +0900

- OpenAI Structured Outputs の json_schema に `followup`（nullable）を含める。
- バリデーション:
  - `choices` は 1..3
  - `question` は 1..80文字
  - `key` は許可リスト（`relationship_type`, `reply_length_pref`, `ng_tags`, `ng_free_phrases` 等）
- 返却ポリシー:
  - `followup` があっても日次カウントは通常通り（生成は成立しているため）。
  - 中ゲートでAIを呼ばずに返す場合は `followup=null`（質問で誘導しない）。

---

# 付録Z: セッションTTLと /generate メタ返却（MUST）
**Added (JST):** 2026-03-01 19:05:00 +0900

## Z-1. セッションTTL（最終確定）
- Opaqueセッション（Redis `sess:{token}`）のTTLは **30日固定**。
- 14日等の暫定値は採用しない（本書内に残っていても本付録で上書き）。

## Z-2. /generate 成功レスポンスの共通メタ（SSOT / MUST）
- JSON本文に `meta` を含める（`X-Request-Id` ヘッダ付与は継続）。
- 返す `meta`（必須）:
  - `request_id`（`X-Request-Id` と同値でも可）
  - `plan`（free/pro）
  - `daily`: `limit`, `used`, `remaining`
  - `model_hint`（固定化しない “ヒント” 扱い）
  - `timestamp`（サーバ時刻、任意）
- Proのみ:
  - `meta.pro` に ♥/🔥（0-100）を含めてもよい（Freeでは出さない）

### 例
```json
{
  "candidates": {
    "A": {"text": "..."},
    "B": {"text": "..."},
    "C": {"text": "..."}
  },
  "followup": null,
  "meta": {
    "request_id": "01J....",
    "plan": "free",
    "daily": {"limit": 3, "used": 1, "remaining": 2},
    "model_hint": "gpt-5.x",
    "timestamp": "2026-03-01T19:05:00+09:00"
  }
}
```
