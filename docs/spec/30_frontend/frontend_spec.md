# frontend.md — Permy フロントエンド設計 Spec（Flutter / 共有受信 / UX最優先）

**Scope:** 本Specはフロントエンド（iOS/Android）の設計を扱う。  
バックエンド契約は `api_contract.*` と `error_codes.*` を正とし、フロントはそれに厳密に整合させる。  
価格・課金条件・世界観文言・禁止語などのプロダクト仕様は別Specを正とし、本Specでは重複記載しない（ズレ防止）。  
ただし **UX設計の前提となる世界観の“振る舞い/トーン”** は、本SpecのUI方針として扱う。

## Spec参照順（MUST）

1. `docs/spec/00_world/world_concept.md`
2. `docs/spec/10_product/product_spec.md`
3. `docs/spec/40_design/permy_design_system_spec.md`
4. `docs/spec/30_frontend/frontend_spec.md`
5. `docs/spec/31_frontend_impl/frontend_impl.md`

## 参照前提（MUST）

- frontend設計・UIデザインに着手する前に、`docs/spec/40_design/permy_design_system_spec.md` を必ず事前参照する。
- 余白、色、タイポグラフィ、コンポーネント規則は上記デザインシステムを正とし、本Specの記述は矛盾しない範囲で適用する。

---

## 0. コア前提（MUST）

### 0.1 入力導線（固定）

- 入力は **LINEの「トーク履歴送信」→ `.txt` をPermyへ共有**のみ。
- アプリ内に「貼り付け欄」を作らない（テキスト貼り付けによる誤用・漏洩を避ける）。

### 0.2 返信は提案のみ（固定）

- 返信の自動送信は行わない。ユーザーが最終的に送信する。

### 0.3 本文非保存（最重要）

- 共有受信した `.txt` の本文、生成された返信文は **端末に永続保存しない**。
  - アプリ内ストレージ（DB/ファイル/キャッシュ）への保存禁止
  - クラッシュログ/解析SDK等への本文混入禁止
- 画面上のプレビュー表示・コピー操作に必要な範囲で **メモリ上のみ保持**し、アプリ終了/画面離脱で破棄する。

### 0.4 Safe Area（iOS/Android）

- ノッチ/ステータスバー/ホームインジケータ/ナビゲーションバー/キーボードと被らない設計を最初に確定する。
- 端末差分調整を後回しにしない（最初から定石に沿ってレイアウトを確定）。

---

## 1. 体験設計（世界観 × ユーザビリティ）

### 1.1 UIの基本姿勢

- ユーザーの「信頼できるパートナー（分身）」として振る舞う。
- 媚びすぎない／説教くさくしない。
- 可愛げは残すが、自己陶酔（「ぼくかわいい？」等）は禁止。
- 目的は「最小操作で、罪悪感を増やさず、返信を作れること」。

### 1.2 画面の“テンポ”をUXの中心に置く

- 入力が共有受信で重くなりがちなので、**待ち時間のストレスを減らす**。
- 生成中は視覚的に状態が分かる（例：淡い配色→生成時は黒反転など、演出はUIで完結）。
- 失敗時は「何をすれば回復するか」が一目で分かる（error_codeに沿ったメッセージ）。

### 1.3 プライバシーの安心導線

- UI上で「本文を保存しない」「送信はユーザー自身」が伝わること。
- 固定の短文コピー（別Spec/別ファイルが正）をUIの適切な場所で表示する。

---

## 2. 技術スタック（フロント）

- Flutter（単一コードベースでiOS/Android）
- 共有受信：ネイティブ実装（iOS Share Extension / Android Share Intent）＋ MethodChannel
  - 依存プラグインに丸投げしない（挙動差・将来破綻を避ける）
- IAP：導入段階で StoreKit2 / Play Billing（初期テスト運用では後回し可）
- 通信：HTTPS（バックエンドにtokenをBearerで送る）
- セキュア保管：tokenのみをKeychain/Keystore相当で保持（本文は保持しない）

---

## 3. バックエンド整合（MUST）

### 3.1 APIベースURL

- `API_BASE_URL` は差し替え可能にする（Render → クラウド移行でURLが変わってもアプリ改修を最小化）。
- Base Path: `/api/v1`（`api_contract.*` を正）

### 3.2 認証

- 起動時、token未保持なら `POST /auth/anonymous` を呼びtoken取得。
- 以後は `Authorization: Bearer <token>` を全APIに付与。
- `401 AUTH_INVALID` が返った場合は token破棄 → `/auth/anonymous` で再取得 → 1回だけ自動リトライ。

### 3.3 エラー処理

- エラーは `error_codes.*` に基づいてUI分岐する。
- messageは補助。分岐は `error_code` 優先。
- `429` は「待てば回復」なので、UIは待機案内を明確化。

### 3.4 plan（外部互換）

- `/generate` の `meta.plan` は `free|pro` の2値。
- Pro同等（課金Pro/永続無料付与）は **両方とも `pro`** として扱う（内部の課金区別はフロントに露出させない）。

---

## 4. 共有受信（`.txt`）設計（最重要）

### 4.1 Android（Share Intent）

- 対応Intent：
  - `ACTION_SEND`（単体共有）
  - `ACTION_SEND_MULTIPLE`（念のため）
  - `ACTION_VIEW`（ファイルマネージャから開く）
- 対応MIME：
  - `text/plain`
  - `text/*`
  - `application/octet-stream`（端末依存のため許容）
- 受信データ：
  - `Uri`（content://）からストリーム読み取り（権限・ライフサイクルに注意）
  - 可能ならファイル名/サイズを表示（本文は表示しない）

### 4.2 iOS（Share Extension）

- UTType：
  - `public.plain-text` / `public.text`
  - `public.file-url`（.txt）
- Share Extensionでファイル内容を読み取り、App Group経由で **本文を永続化しない形**で受け渡す必要がある。
  - 原則：共有直後にMain Appへディープリンク起動し、Main App側で読み取り（可能なら）。
  - App Groupへ置く場合でも **短命・削除必須**（受け渡し後即削除）。本文非保存の方針に抵触しないよう実装で担保する。

### 4.3 共通（本文非保存を守るための実装ルール）

- 共有受信本文は、Main Appのメモリへ取り込み、画面表示に使うのみ。
- OS共有の一時ファイル/バッファがあることは前提だが、アプリ側で再保存・保持をしない。
- クラッシュレポートに本文が載らないよう、例外メッセージ・ログ出力に本文を含めない。

---

## 5. 画面構成（UX最小の導線）

### 5.1 画面一覧（MVP）

1) **起動画面（Splash）**

   - token確保（必要ならanonymous auth）
   - 初回のみOnboardingへ

2) **Onboarding（初回チュートリアル）**

   - 「LINEからトーク履歴を送る→Permyで開く」手順を、短いステップで提示
   - プライバシー（本文非保存・送信はユーザー）を分かりやすく提示
   - 完了後は初回診断へ遷移

3) **初回診断（Diagnosis）**

   - 7問固定の診断を実施し、`POST /me/diagnosis` を呼ぶ
   - 診断結果スライドで内容を確認後、Generateへ遷移

4) **Generate（メイン画面）**

   - 共有受信したtxtを受け取ると自動でこの画面が開き、生成準備状態になる
   - 設定（purpose/combo/禁止事項等）は最小UIで選べる
   - 「生成」ボタン → 生成中演出 → A/B/C候補表示

5) **Settings（ユーザー設定）**

   - バックエンドの `/me/settings` と同期（ETag対応）
   - 変更時はPUT、競合は再取得→再編集

6) **Migration（端末移行）**

   - 発行（/migration/issue）→ 12桁コード表示
   - 取込（/migration/consume）→ token更新

7) **About/Privacy**

   - プライバシー方針（本文非保存）を明示
   - 問い合わせ導線（必要なら）

※課金導線は実装済み。Pro専用項目選択時に ProUpgradeScreen（訴求ページ）へ遷移し、Settings 画面の購入導線へ接続する。

---

## 6. Generate画面 詳細（最重要UX）

### 6.1 レイアウト（Safe Area前提）

- 1画面完結で、**上部固定 + 下部結果エリア拡張**を基本とする。
- 上部：ステータス/ナビゲーションと干渉しない余白、ペルソナ要約、生成方針（combo）
- 中央：Primary CTA（生成ボタン）
- 下部：常設の生成結果エリア（A/B/C固定スロット）
- 履歴共有後の表示順は「共有プレビュー → Primary CTA（ぼくが返信案を考えるよ） → 返信案の調整カード → 結果エリア → ペルソナ要約」とする。

### 6.2 A/B/C候補の表示（固定）

- 返信候補は **A/B/C** の3案で表示する（ユーザー向け表記はA/B/C）。
- 結果エリアは常時表示し、未生成時/生成中/生成後の状態を同じ領域で切り替える。
- 各案は「カード」表示とする。
- 返信案タップ時の動作は Settings の `candidate_tap_action` で切り替える。
  - `copy`（デフォルト）：タップでコピー
  - `share`：タップでOS共有シートを開く
- コピー成功時は **0.4秒のハイライト**等で視覚フィードバック。
- 本文は保存しないため、「履歴」機能は持たない（後で追加予定なら別Specで）。

### 6.3 生成中演出

- 状態が一目で分かる演出（例：画面の色調反転、進行表示、セリフ表示など）
- 生成キャンセル（任意）：通信を中断できるが、最初は必須ではない

### 6.4 入力（txt）プレビューの扱い

- 本文の全量表示は避ける（長い/機微/スクショ流出のリスク）。
- 必要なら「先頭数行だけ」等の短縮プレビュー（ただし保存しない）。
- 共有受信が無い場合は、Generate画面内で共有手順を案内し、結果エリアには待機プレースホルダーを表示する。

### 6.5 生成前調整（Generate画面の5項目 / MUST）

- 履歴共有後、Generate画面の「返信案の調整」カード内で送信前に変更できる。
- 各項目はドロップダウンで切り替え、変更は即時 `/me/settings` に自動保存する。
- Settings画面に遷移せず済むため、履歴共有後の文脈（履歴テキスト）が消える問題を回避できる。
- 履歴共有前（`sharedText` が空）の状態では「返信案の調整」カードを表示しない。
- 履歴共有前（`sharedText` が空）の状態では「ぼくが返信案を考えるよ」ボタンを表示しない。

| 項目 | キー | Free可能値 | Pro専用値 |
| ------ | ----- | --------- | ---------- |
| 返信の長さ | `reply_length_pref` | `short`（短め） | `standard` / `long` |
| 改行設定 | `line_break_pref` | `few`（少なめ） | `infer` / `many` |
| 絵文字の量 | `emoji_amount_pref` | `none`（なし） | `standard` / `many` |
| リアクション | `reaction_level_pref` | `low`（低め） | `standard` / `high` |
| 相手の呼び方 | `partner_name_usage_pref` | `none`（使わない） | `once` / `many` |

- FreeユーザーがPro専用値を選択した場合、課金導線（ProUpgradeScreen）へ遷移する。
- backend側でも Free時は5項目を強制的にFree値へ正規化する（防御側）。
- 各項目のPro専用値には「Pro」バッジを表示する。

### 7.1 取得/更新

- 初回表示で `GET /me/settings` → `ETag` を保持
- 保存時 `PUT /me/settings`（If-Match必須）
- `409 ETAG_MISMATCH` なら再取得して差分をユーザーに促す（自動マージはしない）
- Settings で変更した `candidate_tap_action` は Generate 復帰時に再読込し、返信案タップ挙動へ即時反映する

### 7.2 Pro専用項目の扱い

- Freeが選択できない項目は **UI上でロック表示**（タップで説明/アップセル）。
- 実際の最終判定はサーバ（/generateで `403 PLAN_REQUIRED`）で担保する。
- 返信の長さ/改行設定/絵文字の量/リアクション/相手の呼び方の5項目はSettings画面では設定しない。コンボ皛法画面（Generate）の調整カードで送信前に変更する（詳細は実装Spec 7.3節参照）。

---

## 8. Migration画面（12桁コード）

### 8.1 発行

- `POST /migration/issue` を実行し、12桁コードと期限を表示
- 共有ボタン（OS共有）でコードを送れる（コードは本文ではない）

### 8.2 消費

- 新端末側で12桁コード入力 → `POST /migration/consume`
- 成功で token更新（旧token破棄）

### 8.3 エラー対応

- `MIGRATION_CODE_INVALID`：入力ミスを促す
- `MIGRATION_CODE_EXPIRED`：再発行を促す
- `MIGRATION_CODE_ALREADY_USED`：再発行を促す
- レート制限：待機案内

---

## 8.5 課金連携（Billing Verification）

### 8.5.1 概要

- ストア課金（iOS/Android）と backend を連携し、購入成功時に自動的に feature_tier/billing_tier を更新する。
- 購入イベントを PurchaseService で監視し、backend へ検証リクエストを送信する。
- 現行実装は iOS / Android の両方で BillingProof 送信まで対応済み。サーバ側検証は mock mode で、本番では未有効。

### 8.5.2 BillingProof モデル

- PurchaseService から Settings画面へ購入情報を伝達するための軽量モデル
- フィールド:
  - `platform`（String: "ios" or "android"）
  - `productId`（String: 商品ID）
  - `purchaseToken`（String: 購入トークン/レシート）

### 8.5.3 フロー

1. ユーザーが Settings画面で「Pro/Premiumプランを購入」操作
2. PurchaseService が `in_app_purchase` パッケージで購入フロー実行
3. 購入成功時、PurchaseService が `billingProofStream` に BillingProof を emit
4. Settings画面が stream を subscribe し、BillingProof を受信
5. Settings画面が `POST /api/v1/billing/verify` を呼び出し
6. backend が検証し、成功時に feature_tier/billing_tier を更新
7. Settings画面がユーザーに成功通知（スナックバー等）

### 8.5.4 エラー対応

- `BILLING_NOT_CONFIGURED`（503）：ストア検証が未設定（開発中）を案内
- `BILLING_PRODUCT_INVALID`（400）：商品IDが不正（登録されていない商品）
- `BILLING_RECEIPT_INVALID`（400）：購入情報が不正
- ネットワークエラー：リトライ可能を案内

### 8.5.5 注意事項

- 現時点は mock mode での動作（実ストアサーバ検証は将来実装）
- 本番環境では `/billing/verify` が 503 を返すため、ストア検証実装後に有効化
- 商品ID（SSOT）：Android=`permy_pro_monthly`,`permy-premium-monthly` / iOS=`com.sukimalab.permy.pro_monthly`,`com.sukimalab.permy.premium_monthly`

---

## 9. 運用・安全（本文ゼロ）

### 9.1 ログ/解析SDK

- 解析SDKを入れる場合でも、本文が送信されないことを担保する（イベント設計はメタ情報のみ）。
- 例外ログに本文が混入しないよう、例外メッセージ生成時に本文を含めない。

### 9.2 スクリーンショット/プレビュー

- OSのスクショ禁止は基本しない（UX悪化）。代わりに本文全量表示を避ける。
- どうしても必要な画面（生成結果）でスクショ抑止する場合は別Specで合意を取る。

---

## 10. 実装優先順位（フロント）

1) 共有受信（Android/iOS）→ Generate画面へ入力連携（本文はメモリのみ）
2) anonymous auth（token取得/保持）＋APIクライアント
3) Generate UI（設定→生成→A/B/C→コピー）
4) Settings（GET/PUT + ETag/If-Match）
5) Migration（issue/consume）
6) エラーコードに沿ったUX改善（429/503/403等）
7) Onboarding（短い手順と安心導線）

---

## 11. 受け入れ基準（MUST）

- 共有受信以外で本文を入力できない（貼り付け欄なし）
- 本文が端末ストレージに残らない（アプリが保存しない）
- `/api/v1` 契約に整合（401/409/429/403のUI分岐ができる）
- A/B/Cのコピー体験が気持ちよく、迷わない（0.4秒フィードバック）
- Safe Areaで崩れない（主要端末で確認）
