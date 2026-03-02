# 【Spec】ペルミィ - サーバサイド設計・構築統合仕様書（最終版 v4）
**Version:** v4 (Full Integrated SSOT)  
**Last Updated (JST):** 2026-03-01 13:05:00 +0900

---

## 0. 位置づけと運用ルール（MUST）
- **SSOT階層**: 1. spec_rule, 2. 最新プロダクトSpec, 3. 本サーバサイド統合Spec。
- **設計思想**: Android/iOS共通I/Fのクロスプラットフォーム前提。端末依存を排除する。
- **禁止事項**: 会話本文（入力/履歴/生成結果）および移行コード平文の保存・ログ出力は、いかなる理由があっても厳禁とする。

---

## 1. 認証・識別・セッション（MUST）
- **匿名認証**: `POST /auth/anonymous` にて `user_id` と `access_token` (Opaque) を発行。
- **Bearerトークン**: `Authorization: Bearer <opaque_token>` 必須。
- **有効期限**: 30日間固定（RedisセッションTTLも30日固定）。
- **識別**: すべてのレスポンス（例外含む）に `X-Request-Id` を付与する。

---

## 2. ストレージ・データ構造（MUST）

### 2.1 Redis（セッション/レート/移行/冪等）
- **sess:{token}**: `{user_id, exp}`
- **rl:{route}:{scope}:{key}:{window}**: カウンタ
- **mig:code:{code}**: `{from_user_id, ticket_id, exp, used}`
- **mig:ticket:{ticket_id}**: `{from_user_id, to_user_id, status, exp}`
- **mig:lock:{code}**: 試行ロック用
- **idem:gen:{user_id}:{key}**: 冪等性（24時間保持）

### 2.2 RDB（PostgreSQL / 開発時SQLite）
- **users**: `user_id` (UUID), `plan` (free/pro)。
- **user_settings**: `settings_json` (JSONB), `etag` (sha256), `updated_at`。
- **usage_daily**: `user_id`, `date` (YYYY-MM-DD), `generate_count`。

---

## 3. API詳細仕様（MUST）

### 3.1 /generate（生成API）
- **入力上限**: 20,000文字（Unicodeコードポイント数でカウント）。超過は `422`。要約・切り詰め禁止。
- **日次制限**: JST 00:00リセット。Free 3回 / Pro 100回。成功時のみ加算。
- **冪等性**: `Idempotency-Key` 必須。24時間保持。
- **安全ゲート**: 軽量ルールベースの事前チェック。明確NG時はAIへ送らず安全案(A/B/C)を回答。

### 3.2 /me/settings（設定API）
- **競合制御**: `GET`で `ETag` 返却。`PUT`は `If-Match` 必須。不一致は `409`。
- **スキーマ**: `settings_schema_version` 必須。未知フィールドは保存・返却を許容。

### 3.3 /migration（アカウント移行）
- **仕様**: 移行コード12桁。有効期限10分。移行チケット寿命15分。
- **制限**: IP単位 5回/min。コード失敗10回でそのコードを無効化（1時間ロック）。

---

## 4. レート制限（初期値）
- **匿名認証**: IP単位 10回/10min。デバイス単位（可能なら） 3回/10min。
- **生成**: 瞬間制限 5回/min。
- **移行開始**: user_id単位 3回/day。IP単位 10回/day。

---

## 5. ローカル開発・検証（Windows / PowerShell環境）

### 5.1 環境構築（MUST）
- **Python**: 3.11+。
- **依存**: `pip install tzdata` (WindowsのJST対応)。
- **DB初期化**: `app/scripts/init_db.py` 内で **`import app.models` を必須**とする（Metadata空実行防止）。
- **Redis代替**: 当面は `REDIS_DISABLED=true` によるメモリ内運用を許容。

### 5.2 検証コマンド（PowerShell）
- `curl.exe` を明示（エイリアス回避）。
- JSON崩れ防止のため `ConvertTo-Json -Depth 10` を使用し、`--data-binary "@body.json"` で送信する。

### 5.3 疎通順序
1. `/health` (ok:true)
2. `/auth/anonymous` (token取得)
3. `GET /me/settings` (ETag取得)
4. `PUT /me/settings` (If-Match付与)
5. `/generate` (生成・日次加算確認)

---

## 6. リポジトリ・衛生（MUST）
- **Git**: `.env`, `.venv`, `permy.db`, `body.json` はコミット禁止。
- **改行**: `.gitattributes` で固定し、OS差による差分嵐を防止する。

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

# 付録B: 課金に伴う今後の課題（未確定 / MUSTではない）
**Added (JST):** 2026-03-01 15:25:00 +0900

## B-1. バックエンド常設（Azure等）
- バックエンドのホスティングをAzure等へ移す方針は **未確定**。
- ただし、Android/iPhoneの購読課金（Pro）を正しく運用する場合、サーバ常設＋購入検証が必要になる可能性が高いため、今後の課題として記載する。

## B-2. 追加で必要になり得るAPI（将来）
- `POST /billing/verify`（購入トークン/レシート検証）
- `GET /me/plan`（購読状態の参照）
※未確定。実装前にSSOTで確定する。

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


# 付録Y: /generate followup（聞き返し）仕様（MUST）
**Added (JST):** 2026-03-01 18:25:00 +0900

## Y-1. 入力不足時の聞き返し（followup）レスポンス（SSOT / MUST）
/generate は通常の A/B/C に加え、**不足情報が1点だけある場合**に限り followup を同一レスポンスで返してよい（二段APIは禁止）。

### Y-1.1 条件（MUST）
- followup は **0または1件**。
- 質問は **1問のみ**、選択肢は **最大3**。
- followup が返った場合でも、A/B/C は必ず返す（UIを止めない）。

### Y-1.2 形式（json_schemaの出力仕様と一致させる）
```json
{
  "candidates": {
    "A": {"text": "..."},
    "B": {"text": "..."},
    "C": {"text": "..."}
  },
  "followup": {
    "key": "relationship_type",
    "question": "どんな関係性？",
    "choices": [
      {"id": "new", "label": "新規"},
      {"id": "regular", "label": "常連"},
      {"id": "vip", "label": "太客"}
    ]
  }
}
```
- `followup` は不要なら `null`。
- `key` は settings のフィールド名（例: `relationship_type` / `reply_length_pref` 等）。
- ユーザー選択後は `settings_snapshot` を更新して **次の生成**を行う（自動再生成はしない）。

---

# 付録AB: 夜職タイプ診断（確定）に伴うAPI要件（MUST）
**Added (JST):** 2026-03-01 23:05:00 +0900

## AB-1. /me/settings スキーマ更新
- `real_self_type`（必須）を追加し、`true_self_type` を非推奨とする（返却しない）。
- `night_self_type` は `MamePush/Heal/LittleDevil/BigClient/Balance` のみ許可。
- 互換変換（受理）:
  - 受信 `true_self_type` → `real_self_type` へ変換
  - 受信 `VisitPush` → `MamePush`
  - 受信 `Flow` → `Balance`

## AB-2. /generate 入力（追加）
- `client_now`（ISO8601, JST推奨）を受け取れるようにする（時間整合性に使用）。  
  - 省略時はサーバ時刻のみで推定（挨拶は任意）。

