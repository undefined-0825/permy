# frontend_impl.md — Permy フロント実装Spec（Flutter / 共有受信 / 本文非保存 / API整合）

**Scope:** 本ドキュメントはフロントエンドの実装指針を定義する。  
設計は `frontend.*`、バックエンド契約は `api_contract.*` と `error_codes.*` を正とする。

---

## 0. 実装の大原則（MUST）
1) **入力は共有受信のみ**：貼り付け欄を作らない  
2) **本文非保存**：共有txt本文/生成本文を端末永続化しない（DB/ファイル/キャッシュ/ログ禁止）  
3) **API整合**：`/api/v1` 契約・error_code分岐・ETag/If-Match・Idempotency-Key を厳守  
4) **UX最優先**：待ち時間・失敗時の復帰が分かりやすい。Safe Area/キーボード対応を最初から確定  
5) **依存最小**：共有受信はネイティブ実装（プラグイン丸投げ禁止）

---

## 1. Flutter アーキテクチャ（推奨）
### 1.1 レイヤ
- `presentation`：Widget / Screen / UI State
- `application`：UseCase（Generate/Settings/Migration/Auth）
- `domain`：Model（Settings, Candidate, ApiErrorなど）
- `infrastructure`：API client, storage, platform channels

### 1.2 状態管理
- 既存方針に合わせる（Riverpod/Bloc等の選択はプロジェクト標準に従う）
- 必須条件：画面遷移・ローディング・エラー表示・リトライを一貫して扱えること

---

## 2. ディレクトリ構成（例）
```
lib/
  main.dart
  app.dart
  core/
    config.dart
    logger.dart
    safe_area.dart
    errors.dart
    ui_copy.dart
  domain/
    models/
      settings.dart
      candidates.dart
      plan.dart
      api_error.dart
  application/
    usecases/
      bootstrap_usecase.dart
      generate_usecase.dart
      settings_usecase.dart
      migration_usecase.dart
  infrastructure/
    api/
      api_client.dart
      endpoints.dart
      interceptors.dart
      dto/
        auth_dto.dart
        settings_dto.dart
        generate_dto.dart
        migration_dto.dart
    storage/
      secure_token_store.dart
    platform/
      share_receiver_channel.dart
  presentation/
    routing/
      router.dart
    screens/
      splash_screen.dart
      onboarding_screen.dart
      generate_screen.dart
      settings_screen.dart
      migration_screen.dart
      about_screen.dart
    widgets/
      candidate_card.dart
      loading_overlay.dart
      error_banner.dart
      locked_badge.dart
android/
ios/
```

---

## 3. 本文非保存（MUST）— 実装ルール
### 3.1 禁止事項
- 共有txt本文/生成本文を以下へ保存禁止：
  - SharedPreferences / Hive / SQLite / ファイル
  - 画像キャッシュ/ログ
  - Crashlytics等へ本文混入（例外メッセージ含む）
- `print()` で本文を出力禁止

### 3.2 許可
- メモリ上（state）のみ保持：Generate画面表示〜コピー完了まで
- 画面離脱/アプリ中断で破棄（`dispose` / state reset）

### 3.3 スクリーンの方針
- txt本文は全量表示しない（必要なら短縮プレビュー）
- A/B/Cは表示するが、履歴として保存しない

---

## 4. API クライアント（/api/v1）
### 4.1 Base URL
- `API_BASE_URL` は差し替え可能（flavor/env）
- `/api/v1` を固定

### 4.2 認証（Bearer token）
- tokenは `SecureTokenStore`（Keychain/Keystore）に保存
- 起動時（Splash）に token がなければ `POST /auth/anonymous`
- 401 `AUTH_INVALID`：
  - token削除 → `POST /auth/anonymous` → 1回だけ自動再試行
  - それでも失敗ならエラー表示

### 4.3 リクエストヘッダ
- `Authorization: Bearer <token>`
- `Content-Type: application/json`
- `Idempotency-Key`（/generateのみ必須）
- `If-Match`（/me/settings PUTのみ必須）

### 4.4 レスポンスの扱い
- `meta.plan` は `free|pro` の2値のみ。UI上は free/proとして扱う（pro_compは露出しない）。
- エラーは `error_code` を最優先で分岐。

---

## 5. エラー処理（error_codes.* 整合）
### 5.1 UIメッセージ（例：実装側の責務）
- `RATE_LIMITED`：一定時間待って再試行（リトライボタン）
- `DAILY_LIMIT_EXCEEDED`：本日は上限到達（次回案内）
- `PLAN_REQUIRED`：ロック表示＋説明（課金導線は別Spec）
- `OPENAI_DISABLED`：テスト環境で生成不可表示
- `UPSTREAM_UNAVAILABLE/TIMEOUT`：時間を置いて再試行
- `ETAG_MISMATCH`：設定再読込（リロード導線）
- `MIGRATION_*`：再入力/再発行導線

※文言は別Specを正。ここでは「分岐」と「復帰導線」を固定する。

### 5.2 実装
- API層で `ApiError(errorCode, httpStatus)` に正規化
- Presentation層は errorCodeでUIを選ぶ

---

## 6. 共有受信（Android/iOS）実装（最重要）
### 6.1 共通（MethodChannel）
- Channel名例：`permy/share_receiver`
- メソッド例：
  - `getInitialSharedText`（起動時の共有）
  - `onSharedText`（ランタイムの共有イベント）

### 6.2 Android
- `MainActivity` で Intent を受ける
  - `ACTION_SEND`, `ACTION_VIEW`, `ACTION_SEND_MULTIPLE`
- `Uri` を stream で読み取り
- 読み取った本文は **即Flutterへ渡し、ネイティブ側で保持しない**
- 例外ログに本文が混入しないように注意

### 6.3 iOS
- Share Extension を実装（.txt受領）
- Main App起動へ橋渡し（URL Scheme / Universal Link）
- App Groupを使う場合：
  - 共有データは短命（受け渡し後即削除）
  - 平文の永続保存は禁止（実装で削除を担保）

---

## 7. 画面実装（MVP）
### 7.1 Splash
- tokenロード
- 未所持なら anonymous auth
- 初回判定（onboardingフラグのみ保持可：本文ではない）
- 共有受信テキストがある場合はGenerateへ遷移し、stateに流し込む

### 7.2 Onboarding
- LINEトーク履歴送信→共有→Permyの手順
- プライバシー短文コピー（固定文言は別Spec）
- 完了でGenerateへ

### 7.3 Generate（メイン）
- sharedText state（メモリのみ）
- settings state（GET/PUT同期）
- 「生成」ボタンで `/generate`
  - `Idempotency-Key` はUUID生成
- 生成中：ローディング＋演出（色反転等）
- 結果：A/B/Cカード
  - タップでClipboardへコピー
  - 0.4秒のハイライトフィードバック

### 7.4 Settings
- GET `/me/settings` → ETag保持
- PUT `/me/settings`（If-Match必須）
- 409 `ETAG_MISMATCH`：再取得導線

### 7.5 Migration
- issue：コード表示＋共有（コードは本文ではない）
- consume：コード入力→token更新
- 各エラーコードに沿う導線

### 7.6 About/Privacy
- 本文非保存/送信はユーザー の説明（固定文言は別Spec）
- 連絡先（必要なら）

---

## 8. セキュアストレージ
- tokenのみを Secure Storage に保存
- onboarding完了フラグ等、本文でない軽微データは SharedPreferences可

---

## 9. ロギング（本文ゼロ）
- ログに出してよい：
  - endpoint, status, error_code, latency, request_id
- ログに出してはいけない：
  - sharedText, candidates本文

---

## 10. テスト
### 10.1 ユニット
- ApiError正規化（error_codeごとの分岐）
- Settings ETag処理
- Idempotency-Key付与（/generate）

### 10.2 結合（手動中心）
- 共有受信（Android/iOS） → Generateへ自動遷移
- 生成 → A/B/C → コピー → 0.4秒フィードバック
- エラー（429/503/403/409）を意図的に発生させて復帰導線確認

---

## 11. 受け入れ基準（実装）
- 共有受信以外の本文入力導線がない（貼り付け欄なし）
- 本文が端末に残らない（ファイル/DB/ログなし）
- `/api/v1` 契約に整合（header/ETag/Idempotency/エラー分岐）
- Safe Area崩れなし（主要端末）
- コピー体験が明確（0.4秒フィードバック）
