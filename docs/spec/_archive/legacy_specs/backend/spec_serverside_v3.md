# 【Spec】ペルミィ - サーバサイド設計Spec（唯一の正）

**Version:** v3  **Last Updated (JST):** 2026-02-28

---

## 0. 位置づけ（SSOT階層）

本ファイルは「サーバサイド設計」を決定するSpecであり、推論・設計時は必ず以下の順に従う。

1. **spec_rule.md（運用ルールSSOT）**
2. **最新プロダクトSpec（spec_v{max}.md / 現在: spec_v5.md）**
3. **本サーバサイド設計Spec（spec_serverside_v{version}.md）**

> rule / product Spec と矛盾する内容は採用しない。矛盾が発生した場合は、設計を進めず矛盾点を報告する。

---

## 1. スコープ

### 1.1 対象

- サーバサイドの**設計**（API境界、責務、データ保持方針、認証、レート制限、移行、監視の設計レベル）
- 実装詳細（フレームワーク選定、コード構造、ORM、デプロイ手順等）は **serverside_impl_dev** のSpecで扱う。

### 1.2 最重要事項（MUST）

- **AndroidだけでなくiPhoneも視野に入れたクロスプラットフォーム前提で設計する。**
  - 端末依存の仕様（OS固有のキー/認証方式等）に寄せず、共通プロトコルと共通I/Fを基本とする。

---

## 2. プライバシー/データ保持（MUST）

### 2.1 保存してはいけない

- 会話本文（入力テキスト/履歴/トーク履歴）
- 生成依頼の原文
- 生成結果本文
- 移行コードの平文（保存する場合はハッシュのみ）

### 2.2 保存してよい（必要最小限）

- `/me/settings` の **settings.json（SSOT）**
- `usage_daily`（日次回数制限のカウンタ）
- `plan_status`（Free/Pro判定の最小情報）
- セッション管理情報（token失効/期限など、本文無し）
- 移行チケット状態（期限/1回限り/試行回数等）

---

## 3. 通信・セキュリティ（MUST）

- 通信は **TLS（HTTPS）必須**
- アプリ層暗号化は将来視野だが、現時点はTLSのみで良い（将来変更可能）

---

## 4. 認証・識別（MUST）

### 4.1 匿名開始

- 初回は匿名ユーザーとして開始する（敷居を下げる）
- 端末が最初に呼ぶAPI：
  - `POST /auth/anonymous` → `user_id` と `access_token`（opaque）を発行

### 4.2 Bearer（Opaque）トークン

- 以降の保護APIは `Authorization: Bearer <opaque_token>` を必須とする。
- トークンは意味を持たないランダム値（**opaque**）
- サーバ側で**セッションストア**をSSOTとして保持し、失効・期限・プラン等を制御する。

### 4.3 セッション期限

- `access_token` は **30日固定**
- サーバ側で **即時失効** 可能（移行完了、不正検知、BAN、手動失効）

---

## 5. ストレージ構成（MUST）

### 5.1 Redis（セッション/レート/移行/冪等）

- **Redisを採用**（スケール・性能・実装容易性のバランス）
- 用途：
  - セッション（opaque token → user/plan/期限/失効）
  - 短時間レート制限
  - 移行チケット（migration code）
  - Idempotency-Key（/generate の冪等性）

### 5.2 RDB（settings SSOT）

- **RDB（例：PostgreSQL）を採用**
- settings.json は JSON（JSONB想定）で永続化（SSOT）
- RDB最小テーブル：
  - `users`
  - `user_settings`（settings_json, schema_version, etag/version, updated_at）
  - `plan_status`（plan, updated_at）

### 5.3 開発用の暫定構成（MAY / ローカルのみ）

- ローカル開発では、以下を**一時的に許可**する（本番は 5.1/5.2 を正とする）。
  - RDBの代わりに SQLite（`aiosqlite`）を使用
  - Redisが無い環境では `REDIS_DISABLED=true` により「メモリ実装」で代替
- ただし **APIの意味論（認証/日次加算/冪等/プラン制御）** は本番と一致させる（MUST）。

---

## 6. settings.json（/me/settings）設計（MUST）

### 6.1 SSOT

- 診断結果や各種設定は **/me/settings の settings.json** をSSOTとして保存する（端末ローカル保存はしない）

### 6.2 競合制御（ETag）

- `GET /me/settings` は ETag を返す
- `PUT /me/settings` は `If-Match` 必須
- 不一致時は `409 CONFLICT`（`SETTINGS_VERSION_CONFLICT`）を返す

### 6.3 スキーマ方針

- `settings_schema_version` を必須
- 既知フィールドの検証は行う
- **未知フィールドは許容**し、保存・返却する（将来拡張に強い）

---

## 7. 生成API（MUST）

### 7.1 エンドポイント

- `POST /generate` を唯一の生成APIとして統一する（サーバ分岐を増やさない）

### 7.2 入力（本文非保存）

- 入力は「共有された履歴テキスト（原文）」を受け取る
- サーバは本文を**保存しない**（DB/ログに残さない）
- サーバは最小限の検証のみ（サイズ上限、危険入力ゲート）

### 7.3 入力サイズ上限

- 上限を設け、超過は `422 VALIDATION_FAILED` で拒否
- **上限：20,000文字**
- 自動要約/切り詰めはしない（意図改変・責任境界を避ける）

### 7.4 出力（A/B/C + 最小メタ）

- 返信候補は常に3案（A/B/C）
- 成功応答には最小メタを含める：
  - `request_id`
  - `plan`
  - `daily: {limit, used, remaining}`
  - `model_hint`（固定化しすぎないヒント）
  - `timestamp`（任意）

### 7.5 Pro限定メタ（任意）

- Pro限定の ♥/🔥 表示は、Proのときのみ `meta.pro` 等に付与（Freeには出さない）
- 算出根拠や内部ロジックの露出は避ける（仕様拘束と情報漏えいを抑える）

### 7.6 冪等性（Idempotency-Key）

- `POST /generate` は `Idempotency-Key` を受け付ける
- `user_id + Idempotency-Key` で重複実行を防止し、日次カウント二重加算を防ぐ
- 保持期間は **24時間固定**（Redis）

### 7.7 日次カウント加算タイミング

- `usage_daily.used` は **生成成功時のみ**加算する
- 429/403/422/5xx 等の失敗は加算しない

---

## 8. プラン/回数制限（MUST）

### 8.1 プラン判定（SSOT）

- Free/Pro判定は**サーバがSSOT**
- クライアント申告は信頼しない（表示用に参照するのみ）

### 8.2 日次回数制限（SSOT）

- Free：3回/日、Pro：100回/日
- 日次境界は **JST（Asia/Tokyo） 00:00** でリセット

### 8.3 コンボ利用制御（サーバ強制）

- コンボIDは 0..5（SSOT）
- Freeで実行可能：0,1
- Proのみ：2,3,4,5
- FreeがPro専用を指定した場合、サーバは生成を実行せず
  - `403 PLAN_REQUIRED`（アップセル用エラーコード）を返す

---

## 9. 引き継ぎ（アカウント移行）設計（MUST）

### 9.1 方針

- QRコード移行は廃止
- 二段階承認は入れない
- **移行コード12桁**（期限あり/1回限り/レート制限あり）

### 9.2 フロー（Start/Complete：2段階）

- `POST /migration/start`（旧端末・Bearer必須）
- `POST /migration/complete`（新端末）

**固定値**
- 有効期限：**10分固定**
- 1回限り：成功時に `used_at` を付与し再利用不可

### 9.3 レート制限（設計レベル）

- `migration/complete`：
  - **IP単位：1分あたり5回まで（固定）**
  - **code単位：失敗10回でそのcodeを無効化（固定）**

---

## 10. レート制限（MUST）

- 目的：コスト防御、総当たり防止、連打防止
- 対象：
  - `/generate`（短時間レート + 日次上限）
  - `/migration/*`（総当たり防止）
  - `/auth/anonymous`（乱発防止）

---

## 11. 安全ゲート（MUST）

### 11.1 方針

- サーバでは**軽量ルールベースの事前ゲート**を必須化する（中ゲートの入口）

### 11.2 振る舞い（MUST）

- 明確にNGな要求は **AIへ送らない**
- 代替として「安全な断り方/言い換え」を **A/B/Cの3案** で返す（プロダクトSpec準拠）

---

## 12. エラーモデル（MUST）

失敗応答は以下の共通形式：

```json
{
  "error": {
    "code": "STRING_CODE",
    "message": "ユーザー向け短文",
    "detail": {}
  }
}
```

---

## 13. ログ/監視（本文無し）（MUST）

- ログに残す（最小）：`request_id`, `timestamp`, `endpoint/method`, `user_id(匿名)`, `status`, `latency_ms`, `error.code`, `plan`
- ログに残さない：会話本文、入力テキスト、生成結果本文、移行コード平文

---

## 14. 最小API一覧（設計）

- `POST /auth/anonymous`
- `GET /me/settings`
- `PUT /me/settings`
- `POST /generate`
- `POST /migration/start`
- `POST /migration/complete`
- `GET /health`
- `GET /version`

---

## 15. 開発/動作確認（設計の受け入れ条件 / MUST）

本節は「実装詳細」ではなく、**設計が守られていることを確認するための受け入れ条件**（本文非保存/日次加算/ゲート/冪等など）を列挙する。

### 15.1 ローカル起動（最低限）

- venv名は `.venv` に統一（Git管理しない）
- Windowsでは `tzdata` を含める（JSTのため）
- 起動スクリプトは **`backend/start_radius_memory.ps1`**（Redis無し運用時）

### 15.2 疎通チェック（順番固定）

1. `GET /health` → `{"ok":true}`
2. `POST /auth/anonymous` → `user_id, access_token`
3. `GET /me/settings` → `ETag` を返す
4. `PUT /me/settings`（If-Match一致）→ 更新成功
5. `POST /generate`（通常）→ A/B/C + daily加算（成功時のみ）
6. `POST /generate`（明確NG入力）→ A/B/C代替 + daily**非加算** + AIへ送らない
7. `POST /generate`（Freeでcombo 2..5）→ `403 PLAN_REQUIRED`（生成しない・非加算）
8. `POST /generate`（同一 Idempotency-Key）→ 二重加算しない

---

## 16. リポジトリ衛生（時間損失防止 / MUST）

- `.env` をコミットしない（`.env.example` のみ）
- venv（`.venv` / `venv`）・DB（`permy.db`）・検証用 `body*.json` はコミットしない
- 改行規則は `.gitattributes` で固定し、OS差の差分嵐を起こさない

---

**Last Updated (JST):** 2026-02-28
