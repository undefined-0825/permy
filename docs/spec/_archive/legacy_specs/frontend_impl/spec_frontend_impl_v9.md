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

---

# 付録C: 共有受信の実装方針（MUST / 既知事故の封じ込み）

**Added (JST):** 2026-03-01 15:10:00 +0900

## C-1. 取り込み方式の優先順位（SSOT）

- 入力は **「トーク履歴を送信」→ txtファイル（URI）受領** をSSOTとする（テキスト長押し共有に依存しない）。
- Android/iOSとも、共有受信は **ファイル（txt）受領** を第一に実装する。

## C-2. 実装手段（MVP: ネイティブラッパー）

- Flutterの既存共有プラグイン（例：receive_sharing_intent）への依存は **MVPでは禁止**。
  - 理由：Android Gradle Plugin 世代差により、依存プラグイン側の `namespace` 未対応でビルドが停止する既知事故がある（Pub cacheパッチ等の場当たり対処は禁止）。
- 代替として、Android/iOSに **最小のネイティブ共有受信ラッパー**を実装し、MethodChannelでFlutterへ渡す。

## C-3. Android（MUST）

- Manifest: `MainActivity` に `MAIN/LAUNCHER` を保持しつつ、共有受信の intent-filter を追加する。
- 受領対象：
  - `ACTION_SEND` + `EXTRA_STREAM`（content URI）を優先（txtファイル）
  - `ACTION_SEND_MULTIPLE`（複数添付）は **MVPでは先頭1件のみ** 処理してよい
- 受領したURIは **その場で読み取り**（ストリーム）。永続保存は禁止。
- 文字コードはUTF-8を基本とし、失敗時はフォールバック（Shift_JIS等）を試してよい（本文保存は禁止は維持）。

## C-4. iOS（MUST）

- Share Extension（推奨）で txt を受領し、App本体へ引き渡す（App Group / URL Scheme 等）。
- 本体側で読み取り → トリム → `history_text` 化（永続保存禁止）。

## C-5. UI統合（MUST）

- 共有で起動した場合、`MainGenerate` の入力欄に **自動で差し込む**（ユーザーの追加操作を最小化）。
- 取り込み後は「生成」ボタンが押せる状態にする（ただし生成はユーザー操作起点で自動送信しない）。

---

# 付録D: フォールバック貼り付け禁止（MUST）

**Added (JST):** 2026-03-01 15:40:00 +0900

## D-1. UI/実装禁止事項

- `MainGenerate` に、会話本文を手動で貼り付けるためのテキスト入力欄（ペースト欄）を実装しない。
- 入力は共有受信（txt URI）からのみ生成される `history_text` を利用する。
- 共有受信に失敗した場合は、エラー種別に応じたUI（再共有/権限/再起動）を提示する。

## D-2. 受け入れ基準

- LINEからの共有受信が失敗しても、ユーザーが「何をすれば良いか」を迷わない文言が表示される。
- フォールバック貼り付け入力がUIに存在しない。

---

# 付録E: UI文言・操作の最終固定（MUST）

**Added (JST):** 2026-03-01 17:55:00 +0900

## E-1. 取り込み導線の表示文言（UI規約）

- 取り込み説明文・ボタン文言に「共有」を使わない（例：×「共有で渡す」）。
- 使用する表現は「トーク履歴を送る/渡す/取り込む」に限定する。
- 実装上は Share Extension / Intent を用いていても、UI文言は上記に従う。

## E-2. 返信案カードの実装（ボタン最小化）

- `A/B/C` のカードは `InkWell` 等でカード全体をタップ可能にする。
- `onTap` で `Clipboard.setData` を呼び、トースト「コピーしたよ」を表示。
- コピーしたカードを **0.4秒だけ** 視覚的に強調（背景/枠の一時変更。色はテーマに従う）。
- カード下に「コピー」ボタンを常設しない（誤タップ/視認性低下/テスト増を避ける）。

---

# 付録X: Type表示名SSOT（MUST）

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


# 付録Y: followup（聞き返し）実装（MUST）

**Added (JST):** 2026-03-01 18:25:00 +0900

## Y-1. DTO

- `GenerateResponse` に `followup`（nullable）を追加する:
  - `key: String`
  - `question: String`
  - `choices: List<{id:String,label:String}>`（1..3）

## Y-2. 状態

- `GenerateState` の `done` に followup を保持できるようにする（nullable）。
- followup を表示しても、A/B/C のコピー動作は既存通り。

## Y-3. 選択処理

- 選択した `choice.id` を `key` に応じて `settings_snapshot`（ローカル＋/me/settings）へ反映する。
- 反映後、生成ボタンは有効化し、ユーザー操作で再生成できる状態に戻す。

---

# 付録Z: ローカル疎通時の前提（開発向け / SHOULD）

**Added (JST):** 2026-03-01 20:05:00 +0900

## Z-1. バックエンドがメモリRedis運用の場合

- `REDIS_DISABLED=true` の開発運用では、バックエンド再起動でセッションが消える。
- そのためフロント側の開発では、APIが401（AUTH_INVALID/AUTH_REQUIRED）を返した場合に
  - 自動で `/auth/anonymous` を叩き直してトークンを更新し、**ユーザー操作を止めない** 実装を推奨する（ただし無限リトライ禁止）。
- 本番（Redisあり）ではこの挙動は起きない想定。開発時の便宜としてのみ扱う。
