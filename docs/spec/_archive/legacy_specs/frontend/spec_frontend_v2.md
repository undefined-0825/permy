# 【Spec】ペルミィ - フロントエンド設計統合Spec（SSOT v1）

**Version:** v1  
**Last Updated (JST):** 2026-03-01 14:00:00 +0900

---

## 0. 位置づけ（SSOT階層）

本ファイルはフロントエンド「設計」における唯一の正（SSOT）である。

参照優先順位:
1. spec_rule_v{N}.md（N最大）  
2. spec_product_v{N}.md（N最大）  
3. spec_backend_v{N}.md（N最大）  
4. spec_backend_impl_v{N}.md（N最大）  
5. 本 spec_frontend_v1.md

---

## 1. 技術スタック（MUST）

- Framework: **Flutter（Dart）**
- 状態管理: Riverpod（推奨）/ Provider（許容）※実装都合で選択してよい
- ネットワーク: Dio（推奨）/ http（許容）
- 永続化:
  - **会話本文・生成本文は永続化禁止**
  - 設定（/me/settings相当）のみ端末に保持可（詳細は 4章）
  - 認証トークンは OS の Secure Storage（Android Keystore / iOS Keychain）に保存（必須）

---

## 2. アプリ情報（SSOT）

- アプリ名: **ペルミィ**
- コンセプト: 分身キャラ「ペルミィ」が夜職向けLINE返信を **A/B/Cの3案** 提案し、ユーザーは手動で送信する（自動送信なし）。
- モード: 夜職特化のみ（ビジネス・標準モード廃止）

---

## 3. 画面一覧（MUST）

画面IDは実装上のルーティング名（例）であり、差し替え可。ただし機能要件は固定。

1. `Splash`  
2. `Onboarding`（初回のみ）
3. `PersonaSetup`（ペルソナ診断/再診断）
4. `MainGenerate`（メイン：トーク履歴取り込み＋生成＋コピー）
5. `Settings`（返信長さ/関係性/NGタグ/NGフレーズ/スタイルメモ）
6. `Plan`（Free/Pro表示、課金導線、Pro機能のロック表示）
7. `Migration`（12桁移行コード：発行/入力）
8. `Legal`（プライバシーポリシー/利用規約/免責）
9. `Debug`（開発時のみ。Releaseでは無効化）

---

## 4. 端末保存（MUST/禁止）

### 4.1 端末保存「許可」

以下は端末に保存してよい（UIの利便性目的）。サーバの `/me/settings` と同期する。

- `true_self_type`
- `night_self_type`
- `persona_version`（現在は2）
- `relationship_type`
- `reply_length_pref`
- `ng_tags`
- `ng_free_phrases`（最大10）
- `style_memo`（自由入力。生成時にサーバへ送る）

### 4.2 端末保存「禁止」

- 会話本文（入力/履歴）
- 生成された返信案本文（A/B/C）
- LINEのtxtファイルそのもの（URI含む）を永続保存する行為（再利用目的の保持は禁止）

---

## 5. UI/UX仕様（MUST）

### 5.1 Safe Area / Insets

- Android: WindowInsets（ステータスバー/ナビバー/IME）を考慮
- iOS: Safe Area / Home indicator / Notch を考慮
- いずれも「後から調整が不要なレイアウト」を初期実装で確定する

### 5.2 日本語表示

- **左揃え（中央禁止）**
- 段落を維持して読みやすく（カード内は行間を確保）

### 5.3 画面状態（MainGenerate）

- 入力中: 返信案は非表示
- 生成中: Progress表示。生成ボタン/Spinner/入力欄/スタイルメモをロック
- 生成完了: A/B/Cカード表示。タップでコピー

### 5.4 コピー操作

- A/B/Cカードタップで **クリップボードへコピー**
- コピー成功時:
  - Toast表示
  - 0.4秒カードハイライト

### 5.5 テーマ

- 淡いピンク系テーマ（詳細なカラーコードは未SSOT。後続で確定し本Specへ追記する）

---

## 6. 入力導線（MUST）

### 6.1 LINEトーク履歴取り込み

- LINE「トーク履歴を送信」→ txt（URI）を受領
- アプリは txt を読み取り、**サーバ送信用の `history_text` を生成**する
- 端末保存は禁止（4.2）
- トリム:
  - Free: 120行 / 8,000文字
  - Pro: 300行 / 18,000文字

### 6.2 送信ペイロード（/generate）

- `history_text`: トリム後テキスト（最大 20,000文字はサーバ側でも検証）
- `combo_id`: 10/11/12
- `settings_snapshot`: `/me/settings` で確定した設定（差分でなくスナップショット）
- `style_memo`: 任意文字列（保存許可）
- `idempotency_key`: UUID推奨。ユーザー操作の「生成1回＝1キー」

---

## 7. 認証・セッション（MUST）

- 初回起動時に `POST /auth/anonymous` を呼び、`access_token` を取得しSecure Storageへ保存する
- 以後のAPIは `Authorization: Bearer <access_token>` を必須付与する
- トークン失効時:
  - 401受領 → 再度 `/auth/anonymous` を実行 → 以後再試行（ユーザー操作は阻害しない）

---

## 8. 課金・プラン（MUST）

- Free: 1日3回。combo_id=10,12のみ。微調整UIは無効（ロック表示）
- Pro: 月額1,280円。1日100回。combo_id=11利用可能。微調整UI有効。好意度/リスクメーター表示
- UI方針:
  - FreeでもPro機能は「表示するが選択時にPro案内」でアップセルする

---

## 9. 移行（MUST）

- 12桁移行コード方式（1回限り/期限あり/レート制限あり）
- 画面は「この端末でコード発行」「新端末でコード入力」の2導線を持つ

---

## 10. エラー/障害時UX（MUST）

- すべてのAPIエラーはユーザーに「次の一手」を提示する（再試行/設定見直し/プラン案内）
- 会話本文をエラーログとして端末/外部へ出力しない

---

# 付録A: 追加で明記する決定事項（MUST）

**Added (JST):** 2026-03-01 14:20:00 +0900

## A-1. アカウント登録画面は作らない

- 本アプリは **匿名開始** のため、ログイン/アカウント登録ページ（メール/電話番号/パスワード等）を実装しない。
- 起動時にバックグラウンドで `POST /auth/anonymous` を実行し、トークンをSecure Storageへ保存して利用する。

## A-2. 移行方式（QR廃止）

- 端末移行は **12桁移行コード** のみ。
- QRコード方式は実装しない。
