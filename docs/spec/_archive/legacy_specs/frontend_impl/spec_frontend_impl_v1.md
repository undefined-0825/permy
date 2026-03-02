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
