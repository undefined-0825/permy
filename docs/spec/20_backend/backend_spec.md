# backend.md — Permy バックエンド設計 Spec（入口固定 / 本文非保存 / 段階スケール）

**Scope:** 本Specはバックエンド設計のみを扱う。世界観・UI文言・価格・回数上限などのプロダクト仕様は別Specを正とし、本Specでは重複記載しない（ズレ防止）。

---

## 1. 設計ゴール（MUST）
### 1.1 入口固定（API契約固定）
- 外部公開APIの契約（パス体系、入出力スキーマ、エラー、意味論）を固定し、内部実装/基盤は差し替え可能にする。
- APIは原則 **`/api/v1/*`** 配下に集約し、バージョンで契約を固定する。
- OpenAPI（スキーマ）で契約を機械的に固定できる状態を目標とする（別作業でYAML化）。

### 1.2 本文非保存（最重要）
- 入力本文（共有受信txtの内容）および生成本文（返信案）は、以下を **すべて禁止**：
  - 永続化（DB/ストレージ）
  - ログ出力（リクエスト/レスポンスBodyを記録しない）
  - テレメトリ送信（本文由来のサマリ/特徴量含む）
- 障害解析は「本文ゼロ」で成立させる（エラーコード、集計メトリクス中心）。

### 1.3 最小運用 → 段階スケール
- Phase 1（知人テスト/プロトタイプ）：Renderで運用開始。
- ユーザー増加後はクラウドへ移行し、Docker/Kubernetes等へ段階的に寄せる。
- 「最初からK8s」ではなく、必要性（RPS、構成要素増、可用性要件）に応じて移行判断する。

---

## 2. デプロイ/実行形態（差し替え前提）
### 2.1 フェーズ別実行基盤
- Phase 1: Render（単一サービス想定、手動運用）
- Phase 2: クラウドのマネージド実行（例：Cloud Run/ECS等）
- Phase 3: マネージドKubernetes（例：GKE/EKS/AKS等）

### 2.2 差し替え境界（固定するもの / 首振りするもの）
**固定（外部契約）**
- ` /api/v1/* ` のエンドポイント体系
- 認証方式（匿名起点のBearer token）
- レート制限・日次回数制限の意味論（HTTP 429 等）
- 冪等性（`Idempotency-Key`）
- 設定更新の競合制御（`ETag` / `If-Match`）
- 返却JSONスキーマ（OpenAPI）

**首振り（内部実装）**
- LLMプロバイダ（OpenAI→他）
- データストア（SQLite→Postgres、Redis導入等）
- 同期処理→非同期（キュー/ワーカー）への移行
- 実行基盤（Render→クラウド→K8s）

---

## 3. 論理アーキテクチャ（コンポーネント）
### 3.1 コンポーネント一覧（論理）
- **API**（FastAPIアプリ）：HTTP入口、認証、入力検証、共通エラー
- **Auth**：匿名トークン発行/検証
- **Settings**：ユーザー設定の取得/更新（競合制御）
- **Generate**：生成要求受付 → 制限チェック → LLM呼び出し → 結果返却（本文非保存）
- **Usage/Limit**：日次回数制限、レート制限、冪等キー管理
- **Migration**：移行コード（12桁）の発行/消費（期限/1回/レート）
- **Billing**（将来）：購読状態→プラン反映（詳細は別Spec）

### 3.2 物理構成（Phase 1最小）
- 単一FastAPIサービス内にモジュールとして実装（モノリス）。
- DBは本文なしのメタのみ。
- Redisは任意（なければDB/メモリで代替し、Phase 2で導入）。

---

## 4. データ設計（本文ゼロの永続モデル）
### 4.1 永続化してよい情報（許可リスト）
- 匿名ユーザー識別子（`user_id`）
- 機能ティア/課金ティア（後述）
- 日次利用カウント（生成回数など）
- 設定値（本文を含まない項目のみ）
- 移行コード状態（ハッシュ、期限、使用済み）
- 観測用最小メタ（例：エラー種別集計、レイテンシ分布、時間帯バケット）

### 4.2 永続化禁止（禁止リスト）
- 入力本文（共有txt本文）
- 生成本文（返信案）
- 上記を復元可能な派生データ（長文サマリ、断片、特徴量など）

### 4.3 機能ティア/課金ティア（MUST）
「無料か、それ以外か」で機能判定しつつ、「課金Pro」と「永続無料（付与）」を区別するため、概念を分離する。

- **feature_tier（機能判定）**: `free` | `pro`
  - `free`：無料ユーザー
  - `pro`：Pro相当（課金Pro + 永続無料を含む）
- **billing_tier（課金区別）**: `free` | `pro_store` | `pro_comp`
  - `pro_store`：ストア課金Pro
  - `pro_comp`：管理者が明示付与する永続無料（知人/インフルエンサー向け）
  - `free`：無料

**ルール（MUST）**
- 機能解放・Pro専用機能の判定は **feature_tierのみ** で行う（`free` か、それ以外か）。
- 課金由来の差分（売上/分析/返金対応など）は **billing_tierのみ** で区別する。
- `feature_tier=pro` のユーザーは、外部互換のため APIレスポンス上は `plan=pro` として扱う（`plan`は2値互換維持）。

### 4.4 テーブル例（論理モデル）
- `users`
  - `user_id`（匿名ID）
  - `feature_tier`（free/pro）
  - `billing_tier`（free/pro_store/pro_comp）
  - `failed_pro_comp_attempts`（pro_comp承認依頼の失敗累積）
  - `is_locked`（不正アクセス抑止のロック状態）
  - `created_at`, `updated_at`
- `user_settings`
  - `user_id`
  - `settings_json`（本文禁止の項目のみ）
  - `etag`（楽観ロック）
  - `updated_at`
- `usage_daily`
  - `user_id`
  - `date_yyyymmdd`
  - `generate_count`
  - `updated_at`
- `migration_tokens`
  - `code_hash`
  - `source_user_id`
  - `expires_at`
  - `used_at`（未使用ならNULL）

---

## 5. API設計（外部契約：/api/v1）
### 5.1 共通ルール
- 認証: `Authorization: Bearer <token>`
- JSONのみ
- 失敗時は `error_code` を必須で返す（機械判定可能）
- 本文ログ禁止（request/response body を記録しない）

### 5.2 最小エンドポイント
- `POST /api/v1/auth/anonymous`
  - 匿名ユーザー開始（token発行）
- `DELETE /api/v1/auth/me`
  - アカウント削除（関連メタ削除 + セッション無効化）
- `GET /api/v1/me/settings`
  - 設定取得（`ETag`返却）
- `GET /api/v1/version`
  - アプリバージョン情報取得（認証不要）
  - Response:
    - `latest_version`（最新版。通常は app_version）
    - `min_supported_version`（最低対応版。下回ると強制アップデート）
    - `android_store_url` / `ios_store_url`（ストアリンク）
    - `release_note_title`（リリースノートタイトル）
    - `release_note_body`（リリースノート本文。最新版のみ）
  - DB: `AppReleaseNote` テーブルから最新版のノートを取得
  - キャッシュ: 設定値キャッシュ + DB レスポンスキャッシュ (TBD)
- `PUT /api/v1/me/settings`
  - 設定更新（`If-Match`必須。競合は409 `ETAG_MISMATCH`）
- `POST /api/v1/generate`
  - 返信案生成（本文を受け取るが保存しない）
  - Request（追記）:
    - `history_text`（必須）
    - `combo_id`（必須）
    - `my_line_name`（任意）: ユーザー本人のLINE表示名。クライアントが判別できた場合のみ付与する。
  - `Idempotency-Key` 必須（リトライ二重実行防止）
  - 日次回数制限・レート制限をサーバで判定
  - `my_line_name` は生成品質向上のための一時入力として扱い、永続化しない（DB保存・ログ出力禁止）。
  - レスポンス `meta.plan` は互換のため `free/pro` の2値
    - `feature_tier=free` → `plan=free`
    - `feature_tier=pro` → `plan=pro`
- `POST /api/v1/migration/start`
  - 移行コード発行（12桁、期限あり、レート制限）
  - Response: `migration_code`, `ticket_id`
- `POST /api/v1/migration/complete`
  - 移行コード消費（1回限り、期限あり、レート制限）
  - 新端末側から認証なしで呼ぶ。成功時 `access_token` と `user_id` を返す。
- `POST /api/v1/pro-comp/request`
  - pro_comp承認依頼（隠し導線用）
  - 入力メールを正規化（trim + lower）し、事前登録メールと一致する場合のみ承認判定
  - 失敗時は `remaining_attempts` を返却（5回失敗で `ACCOUNT_LOCKED`）
- `POST /api/v1/billing/verify`
  - ストア購入の検証結果を反映
  - Request:
    - `platform`（ios/android）
    - `product_id`（商品ID）
    - `purchase_token`（購入トークン/レシート）
  - Response:
    - `plan`（free/pro）
    - `verified`（bool）
  - 動作:
    - 許可された product_id かチェック（許可リスト: `com.sukimalab.permy.pro_monthly`（iOS）、`permy_pro_monthly`（Android））
    - purchase_token が存在するかチェック
    - 検証成功時、`feature_tier=pro`、`billing_tier=pro_store` に更新
    - PlanStatus を `plan=pro` に更新（未存在なら作成）
  - 制限:
    - 本番環境（`APP_ENV=prod`）では無効化（503 `BILLING_NOT_CONFIGURED`）
    - 現時点は mock mode のみ（実ストアサーバ検証は将来実装）
  - 注意:
    - 実ストアサーバ検証（Apple App Store Server API / Google Play Billing API）への置き換えが必要

### 5.3 エラーコード指針（例）
- `AUTH_INVALID`
- `RATE_LIMITED`
- `DAILY_LIMIT_EXCEEDED`
- `IDEMPOTENCY_CONFLICT`
- `ETAG_MISMATCH`
- `MIGRATION_CODE_INVALID`
- `MIGRATION_CODE_EXPIRED`
- `MIGRATION_CODE_ALREADY_USED`
- `OPENAI_DISABLED`（CI/手動テスト制御用）

---

## 6. 制限・安全装置（コスト暴発/不正対策）
### 6.1 レート制限
- `/generate` を中心にユーザー単位・IP単位で制限。
- 実装は差し替え可能（Redis→DB→WAF等）。
- 返却はHTTP 429 + `RATE_LIMITED`。

### 6.2 日次回数制限
- クライアント表示に依存せず、**サーバ側で必ず判定**。
- 上限値は別Specを正とし、本Specでは数値を固定しない（ズレ防止）。
- `usage_daily` に日次カウントを保持（本文なし）。

### 6.3 冪等性（Idempotency）
- `Idempotency-Key` で二重実行を防ぐ。
- 本文非保存の前提では「同一キーで同一本文レスポンスを再現」よりも、
  - 二重実行を抑止し、
  - 必要ならクライアント側で再生成（=再リクエスト）
  を優先する（ポリシーの詳細は別Spec/合意に従う）。

### 6.4 CIでLLM無効化
- `OPENAI_DISABLED=true` の場合、LLM呼び出しを行わず `OPENAI_DISABLED` を返す（コスト/安全のため）。

---

## 7. 観測（Observability）— 本文ゼロ
### 7.1 収集してよいメトリクス（例）
- レイテンシ（p50/p95/p99）
- ステータスコード分布
- `error_code` 件数
- 日次生成回数（集計）
- 時間帯バケット（例：30分単位の件数）
- 外部API（LLM）の失敗率・タイムアウト率

### 7.2 禁止
- リクエスト本文/レスポンス本文のログ
- 本文由来のサマリ/特徴量の保管

---

## 8. 永続無料（pro_comp）の付与（管理画面なし）
### 8.1 要件
- 永続無料は知人/インフルエンサーに限定し、**管理者が明示的に付与**する。
- 管理画面は作らない。
- `pro_comp` は機能面ではProと同等（`feature_tier=pro`）だが、課金は区別する（`billing_tier=pro_comp`）。

### 8.2 付与方法（運用CLI + 承認依頼API）
- 管理者は対象メールをCLIで事前登録する。
  - 例：`python tools/pro_comp/register_comp_email.py target@example.com 田中太郎`
- ユーザーは `POST /api/v1/pro-comp/request` で承認依頼する。
- 承認判定は「入力メール（正規化後）」と `pro_comp_grant_requests.email` の一致で行う。
- 承認成功時に以下を更新する。
  - `users.feature_tier=pro`
  - `users.billing_tier=pro_comp`
  - `plan_status.plan=pro`

### 8.3 不正アクセス対策
- 承認失敗ごとに `users.failed_pro_comp_attempts` を +1 する。
- 5回失敗で `users.is_locked=true` とし、以後 `/api/v1/pro-comp/request` は `ACCOUNT_LOCKED` を返す。
- 失敗時はエラー詳細に `remaining_attempts`（ロックまでの残回数）を含める。

---

## 9. 移行（Render→クラウド→K8s）の実務方針
### 9.1 コンテナ化
- FastAPIをDocker化（1コンテナ）。
- 外部依存（DB/Redis/LLM）を環境変数で切替可能にする。

### 9.2 K8s移行のトリガ（例）
- API/worker/queue 等の分離が必要になった
- ピークRPSで単一サービスのスケールだけでは吸収できない
- 可用性要件が上がり、単一障害点の排除が必要になった

---

## 10. 実装優先順位（設計観点）
1) `/auth/anonymous` + token検証
2) `/me/settings`（ETag/If-Match）
3) `/generate`（日次制限・レート制限・本文非ログ・冪等抑止）
4) `/migration/*`（12桁、期限、1回、レート）
5) 観測（本文ゼロのメトリクス・エラーコード整備）
6) （必要になったら）課金検証API・基盤移行
