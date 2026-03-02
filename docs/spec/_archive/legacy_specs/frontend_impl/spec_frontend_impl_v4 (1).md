# 【Spec】ペルミィ - フロントエンド実装統合Spec（SSOT v1）
**Version:** v1  
**Last Updated (JST):** 2026-03-01 14:00:00 +0900

---

## 0. 位置づけ（SSOT階層）
本ファイルはフロントエンド「実装」における唯一の正（SSOT）である。設計Spec（spec_frontend_v1.md）を実装へ落とす際の具体規約・ファイル構成・実装タスクを定義する。

---

## 1. 推奨ディレクトリ構成（MUST）
- `lib/`
  - `main.dart`
  - `app.dart`（Router/Theme）
  - `core/`
    - `api/`（Dio/http client, interceptors）
    - `storage/`（secure_storage, shared_prefs）
    - `models/`（settings DTO, generate DTO）
    - `utils/`（text trim, uuid, validation）
  - `features/`
    - `auth/`（anonymous auth）
    - `onboarding/`
    - `persona/`
    - `generate/`
    - `settings/`
    - `plan/`
    - `migration/`
    - `legal/`
  - `widgets/`（A/B/C card, toast wrapper など）

---

## 2. APIクライアント規約（MUST）
### 2.1 共通ヘッダ
- `Authorization: Bearer <token>`
- `Content-Type: application/json`
- `Idempotency-Key: <uuid>`（/generateのみ必須）

### 2.2 リトライ方針
- 401: token再取得→1回だけリトライ
- 409（settings競合）: GETで再取得→ユーザーへ「更新競合」表示（自動マージ禁止）
- 422（入力超過）: UIで即時エラー（ユーザーにトリム設定/見直し案内）

---

## 3. テキスト取り込み実装（MUST）
- OS共有（Android: Intent ACTION_SEND / iOS: Share Extension相当）で txt URI を受領
- txt読み込みはストリームで行い、メモリ爆発を避ける
- トリム関数（SSOT）:
  1. 行数上限（Free/Pro）で先に切る
  2. 文字数上限（Free/Pro）で追加切り
  3. サーバ上限（20,000文字）を超える場合はUIで警告し、送信禁止（サーバで422になるため）

---

## 4. 状態管理（MUST）
- `GenerateState`: idle / editing / loading / done / error
- `SettingsState`: loaded(etag, json), saving, conflict, error
- `PlanState`: free/pro（サーバのusers.planに同期。未取得時はfree扱い）

---

## 5. MainGenerate 画面の実装仕様（MUST）
- 入力欄:
  - 「トーク履歴取り込み」ボタン（共有から）
  - プレビュー領域（保存しない。再起動で消えてよい）
- 目的（combo_id）UI:
  - 10,12は常に選択可能
  - 11はロック表示（Freeはタップ時にPro案内）
- 生成ボタン:
  - loading中は無効
  - Idempotency-Keyは「生成ボタン押下で新規発行」
- 結果表示:
  - A/B/Cカード。タップでコピー
  - Proの場合のみ、各案に好意度/リスク（♥/🔥 + 0-100バー）を表示（Freeでは非表示）

---

## 6. 設定（/me/settings）同期実装（MUST）
- 起動時に `GET /me/settings`
- 編集後に `PUT /me/settings`（If-MatchにETag必須）
- 成功時はETag更新、ローカル保存更新
- 競合（409）の場合:
  - 自動上書き禁止
  - 画面で「別端末で更新された可能性」案内→再取得→再編集を促す

---

## 7. ログ/解析（HARD）
- 会話本文・生成本文をログ出力禁止（print/analytics含む）
- クラッシュレポート導入時も、送信ペイロードから本文を除外する仕組みが必須

---

## 8. 実装タスク（優先度順）
P0（配布に必須）
1. anonymous auth + token保存 + interceptor
2. /me/settings GET/PUT（ETag/If-Match）
3. txt受領→トリム→/generate（A/B/C表示＋コピー）
4. Free/Pro UIロック（combo_id=11、微調整）
5. 移行（発行/入力）UI（APIはバックエンド実装に同期）

P1（品質）
6. エラー文言の整備（422/403/409/5xx）
7. Safe Area最終確認（Android/iOS）
8. トースト＋0.4秒ハイライト

---

## 9. 受け入れ基準（MUST）
- 会話本文/生成本文が端末に永続化されない（再起動で消える）
- Freeで1日3回、Proで1日100回の制限がUX的に破綻しない（残回数表示は任意）
- 生成中ロックが正しく機能し、二重送信でも多重カウントされない（Idempotency-Key）

---

# 付録A: 追加で明記する決定事項（MUST）
**Added (JST):** 2026-03-01 14:20:00 +0900

## A-1. アカウント登録画面は作らない
- 本アプリは **匿名開始** のため、ログイン/アカウント登録ページ（メール/電話番号/パスワード等）を実装しない。
- 起動時にバックグラウンドで `POST /auth/anonymous` を実行し、トークンをSecure Storageへ保存して利用する。

## A-2. 移行方式（QR廃止）
- 端末移行は **12桁移行コード** のみ。
- QRコード方式は実装しない。
---

## 80. 共有受信（LINEトーク履歴txt）プラグイン選定の注意（MUST/SHOULD）
**Added (JST):** 2026-03-01 15:00:00 +0900

### 80.1 Android Gradle Plugin 8系での破綻ポイント
- `receive_sharing_intent` の一部バージョンは `namespace` 未指定でビルドが失敗する。fileciteturn2file3L8-L56
- Kotlin/Java の `jvmTarget` 不整合（例：Java 1.8 / Kotlin 21）でビルドが失敗するケースがある。fileciteturn2file0L1-L37

### 80.2 実装方針（SHOULD）
- 依存プラグインは「AGP8 + 最新Flutter stable」でビルドが通る組合せに **固定** する（バージョン固定）。
- pub cache への手動パッチは再現性が低いので原則禁止。やむを得ず行う場合は、必ず手順を `docs/dev_notes.md` 等に残して、CI/新規端末でも再現できる状態にする。
- iOS含むクロスプラットフォームの共有受信は、最終的に「ネイティブShare Extension/Intent」実装が必要になる可能性が高い（技術選定は別途確定する）。

### 80.3 Dart側の規約（MUST）
- APIベースURL等の定数は「クラス内const」ではなく、トップレベル `const String` または `static const` で定義する（Dartコンパイルエラー回避）。fileciteturn2file3L81-L86

---

# 付録B: MVPにネイティブ共有受信を含める（MUST）
**Added (JST):** 2026-03-01 14:35:00 +0900

## B-1. 実装範囲（MVP）
- Android: `ACTION_SEND` / `ACTION_SEND_MULTIPLE` から txt URI を受領し、アプリ本体へ引き渡す。
- iOS: Share Extension（推奨）で txt（ファイル/テキスト）を受領し、App Group/URL Scheme等で本体へ引き渡す。
  - ※受領データは **一時領域のみ**。本文/生成文の永続保存は禁止。

## B-2. 受け入れ基準（MUST）
- LINEから「共有」→ ペルミィ起動 → 取り込み完了 が迷わず到達できる。
- iOS/Androidともに、共有受信に失敗した場合はユーザーに次の操作（再共有/ファイル選択/権限確認）を提示する。
