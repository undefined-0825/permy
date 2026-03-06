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
### 4.0 API 契約
- Base Path: `/api/v1`（`api_contract.md` を正）
- **OpenAPI 3.1.0 仕様**: `docs/api/openapi.json`（コード生成に利用可）
- エラーコードは `error_codes.md` に従う

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

### 6.4 色定義とテーマ（MUST）

**カラーパレット（world_concept.md 準拠）**：
- **通常時背景**：淡いピンク系グラデーション
  - `Color(0xFFE8D4F8)` 淡いパープル（グラデーション開始色）
  - `Color(0xFFFCE4EC)` 淡いピンク（グラデーション終了色）
- **生成時背景**：黒（#000000）※反転演出用、後で実装
- **アクセントカラー（ボタン・選択状態）**：
  - プライマリピンク：`Color(0xFFFFB3C1)` ボタン背景、ハイライト用
  - セカンダリピンク：`Color(0xFFFF69B4)` 選択ボーダー、チェックマーク
  - 淡ピンク：`Colors.pink.shade50` プレースホルダー背景
- **テキストカラー**：
  - 標準：`Colors.black87`
  - エラー：`Colors.red`
  - ボタン上テキスト：`Colors.white`
- **無効化状態**：`Colors.grey.shade300`

**適用ルール**：
- 診断画面・生成画面・Settings等、全画面で統一使用
- 将来的に `lib/core/theme.dart` で ThemeData 定義予定（現在は各Widget内でハードコード）
- Material Design 3 準拠、ColorScheme 活用を推奨

**デザイン意図（world_concept 参照）**：
- 淡いピンク：ユーザーの緊張を和らげ、安心感を提供
- 黒への反転：NightSelf（分身稼働）モードへの視覚的切り替え
- 過剰な可愛さを避け、信頼感と機能性のバランスを重視

### 6.5 アセット管理ルール（MUST）
- 画像アセットは「存在確認」だけでなく「実体確認」まで行う（空ファイル・プレースホルダー禁止）。
- 差し替え直後は最低限次を確認する：
  - ファイルサイズが異常に小さくない（例：数十バイトは異常）
  - 対象画面で実表示できる
  - `pubspec.yaml` に正しいパスで登録されている
- 一時プレースホルダーを置いた場合は、その場で TODO を残し、完了前に必ず実アセットへ置換する。

### 6.6 AppBar設計ルール（MUST）
- 戻る導線が必要な画面では、デフォルト戻る動作を壊す実装を禁止する。
- `AppBar.leading` をカスタムアイコンで上書きする場合は、戻るボタン消失リスクを必ず検証する。
- ロゴ/アイコン追加は原則として `title` 側で構成し、戻る導線と共存させる。
- Material Design 3 準拠の基本値：
  - AppBar 高さ 56dp
  - ヘッダーアイコン 24dp
  - タイトルは可読性を優先し、過度な装飾を避ける

### 6.7 背景画像時の可読性ルール（MUST）
- 背景画像を使う場合、テキスト可読性を損なわないことを最優先とする。
- 明度差が不足する場合は、ColorFilter / オーバーレイ / 文字色統一のいずれかで補正する。
- 見出し・本文・ボタンラベルの最低可読状態を、実機またはエミュレータで確認する。

### 6.8 UI実装完了チェック（MUST）
画面改修の完了宣言前に、以下を満たすこと。

1. 画像アセットが実体ファイルであり、対象画面で表示確認済み
2. AppBar の戻る導線が維持されている
3. 背景と文字の可読性が確保されている
4. Material Design 3 の基本寸法（56dp/24dp）を逸脱していない
5. 画面遷移（戻る/進む）に破綻がない

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

### 7.2.1 Persona Diagnosis（導入時）
- 初回導入は **7問固定**（True 2問 + Night 5問）
- 設問ID/重み/判定は `docs/spec/10_product/persona_scoring_spec.md` を正とする
- 回答完了後に `POST /me/diagnosis` を呼び、判定結果と派生パラメータを取得
- 取得結果を `PUT /me/settings`（If-Match必須）で保存
- 途中離脱時は旧設定を維持

#### 7.2.1.1 Diagnosis Screen UI（デザインリニューアル版）

**全体構造**：
- Scaffold body に Container を配置、decoration で背景設定
- SafeArea 内に Column（上部ヘッダー + 質問エリア + エラー表示 + ボタン）

**背景**：
- **現在実装**：LinearGradient（topCenter → bottomCenter）
  - 開始色：`Color(0xFFE8D4F8)` 淡いパープル
  - 終了色：`Color(0xFFFCE4EC)` 淡いピンク
- **将来対応**：DecorationImage (`assets/images/backgrounds/diagnosis_background.png`, fit: BoxFit.cover)
  - 現在はコメントアウト、画像準備後に有効化

**上部ヘッダー**（SafeArea内、padding 16-12-16-12）：
- Row構成：ペルミィアイコン + SizedBox(12) + 進捗表示
- **ペルミィアイコン**（プレースホルダー、後で画像差し替え）：
  - Container 48x48、黒背景（Colors.black87）、borderRadius 24
  - Icon(Icons.pets, color: white, size: 28)
- **進捗表示**：
  - Text「N/7」（例：1/7, 2/7, ...、N は _currentQuestionIndex + 1）
  - fontSize 18、fontWeight bold、color black87

**質問表示エリア**（Expanded + SingleChildScrollView）：
- **ページング動作**：
  - 状態変数 `_currentQuestionIndex`（0〜6）で現在問を管理
  - 「次へ」ボタンタップで `_currentQuestionIndex++`、最終問は送信
  - 各問の回答は `_answers[questionId] = choiceId` で保持（全問回答可能）
- **質問文**：
  - padding: EdgeInsets.symmetric(horizontal: 16)
  - SizedBox(height: 24) 後に配置
  - fontSize 20、fontWeight bold、color black87、height 1.5
  - textAlign center
- **選択肢カード群**：
  - SizedBox(height: 32) 後に配置
  - 各選択肢を `_ChoiceCard` ウィジェットで表示

**選択肢カード** (`_ChoiceCard`)：
- **構造**：Padding(bottom: 12) > InkWell > Container
- **InkWell**：onTap で選択、borderRadius 16
- **Container**：
  - padding 16、borderRadius 16
  - 背景：白（opacity 0.9）
  - ボーダー：選択時のみ `Color(0xFFFF69B4)` ピンク、width 3
  - boxShadow：黒10%、blurRadius 8、offset (0,2)
- **内部レイアウト**（Row）：
  1. **画像プレースホルダー**（80x80、borderRadius 12）：
     - Container、背景 `Colors.pink.shade50`
     - Icon(Icons.image_outlined, size: 40, color: pink.shade200)
     - 後でキャラクター画像（Image.asset）に差し替え可能
  2. SizedBox(width: 16)
  3. **選択肢テキスト**（Expanded）：
     - fontSize 14、fontWeight w500、color black87、height 1.4
  4. **チェックマーク**（選択時のみ表示）：
     - Icon(Icons.check_circle, color: 0xFFFF69B4, size: 28)

**エラー表示**（ボタン上部、ペルミィトーン統一）：
- if (_error != null) で条件表示
- Padding(horizontal: 16)
- Text：赤文字（Colors.red）、fontWeight bold、textAlign center
- 表示内容：`error_code` に基づいて以下を返す（`error_codes.md` を正とする不）：
  - `AUTH_INVALID` / `AUTH_REQUIRED`：「認証を更新したよ。もう一度ためしてね」
  - `VALIDATION_ERROR`：「うまく読めなかった。もう一度ためしてね」
  - `RATE_LIMITED`：「少し混み合ってるみたい。少し待って、もう一度」
  - `UPSTREAM_UNAVAILABLE` / `UPSTREAM_TIMEOUT`：「今は不安定みたい。少し待って、もう一度」
  - `INTERNAL_ERROR` / `STORAGE_UNAVAILABLE`：「サーバーが不安定みたい。少し待って、もう一度」
  - その他：「うまく反映できなかった。少し待って、もう一度」
- エラー発生後、ユーザーは「完了」ボタン（"この内容で進む"）を再度タップして retry。呼び出し側（Settings）で retry 後の結果判定を担当

**次へボタン**（下部固定）：
- Padding(all: 16) 内に SizedBox(width: double.infinity, height: 56)
- **ElevatedButton**：
  - onPressed：`_canProceed && !_saving ? _handleNext : null`
    - `_canProceed`：現在問の回答が存在するか判定
    - `_isLastQuestion`：最終問（index == 6）判定
  - style：
    - backgroundColor: `Color(0xFFFFB3C1)` ピンク
    - foregroundColor: 白
    - disabledBackgroundColor: `Colors.grey.shade300`
    - shape: RoundedRectangleBorder(borderRadius: 28)
    - elevation: 0
  - child：
    - 保存中（_saving）：CircularProgressIndicator（24x24、白、strokeWidth 2）
    - 通常：Text（fontSize 16、fontWeight bold）
      - 最終問：「この内容で進む」
      - それ以外：「次へ」

**動作フロー**：
1. 初期表示：_currentQuestionIndex = 0、質問1を表示
2. ユーザーが選択肢タップ → _answers[questionId] = choiceId、UI更新
3. 「次へ」タップ：
   - 最終問以外 → _currentQuestionIndex++、次問へ遷移
   - 最終問 → _submit()、POST /me/diagnosis 実行
4. 送信成功 → widget.onCompleted(answers) 呼び出し、pop で Settings へ戻る
5. 送信失敗 → エラーメッセージ表示

**段階的実装の注記**：
- **Phase 1（完了）**：グラデーション背景、プレースホルダー配置、UI構造実装
- **Phase 2（今後）**：
  - 背景画像有効化（DecorationImage コメントアウト解除）
  - ペルミィアイコン画像差し替え（Container → Image.asset）
  - 選択肢画像差し替え（Icon → Image.asset、20-30枚想定）

### 7.3 Generate（メイン）
- sharedText state（メモリのみ）
- settings state（GET/PUT同期）
- 「生成」ボタンで `/generate`
  - `Idempotency-Key` はUUID生成
- 生成中：ローディング＋演出（色反転等）
- 結果：A/B/Cカード
  - タップでClipboardへコピー
  - 0.4秒のハイライトフィードバック

#### 7.3.1 Generate 画面のエラーハンドリング
- **エラー発生箇所**：`/generate` 呼び出し失敗時
- **エラー表示**：_ErrorBanner ウィジェット（の背景色：淡赤、text：赤文字）
- **メッセージング**：`error_code` に基づいて以下を返す（`error_codes.md` を正とする）：
  - `AUTH_INVALID` / `AUTH_REQUIRED`：「認証を更新したよ。もう一度ためしてね」
  - `SETTINGS_VERSION_CONFLICT` / `ETAG_MISMATCH`：「設定が更新されていたみたい。読み込み直してね」
  - `RATE_LIMITED`：「少し混み合ってるみたい。少し待って、もう一度」
  - `DAILY_LIMIT_REACHED` / `DAILY_LIMIT_EXCEEDED`：「今日はここまで。続きは明日か、Proで使える」
  - `PLAN_REQUIRED`：「この機能はProで使えるよ」
  - `OPENAI_DISABLED`：「この環境では生成を止めているよ」
  - `UPSTREAM_UNAVAILABLE` / `UPSTREAM_TIMEOUT`：「今は不安定みたい。少し待って、もう一度」
  - その他：「うまく読めなかった。もう一度共有して」
- **Retry 導線**：エラー表示後、ユーザーは「生成」ボタンを再度タップして retry。自動リトライは行わない（ユーザーの明示的操作）

### 7.3.2 Persona Diagnosis Result Screen（新規画面）
- **目的**：診断されたペルソナを詳細表示。Settings から タップエントリーポイント
- **表示内容**（読み取り専用）：
  1) 普段の自分：True Self（5タイプ：Stability/Independence/Approval/Realism/Romance）
  2) 夜の私：Night Self（5タイプ：VisitPush/Heal/LittleDevil/BigClient/Balance）
  3) スタイルスコア（主張度/温かみ/リスク回避）：0-100の LinearProgressIndicator
- **各タイプの説明文**：固定テキスト（詳細は後述）
- **保存**：なし（読み取り専用、スクロール可）
- **遷移**：Settings から「ペルソナ欄」をタップで表示、BackボタンまたはAppBar戻るで Settings に復帰

### 7.4 Settings
- **GET `/me/settings`** → ETag 保持、初期化時に呼び出し
- **PUT `/me/settings`**（If-Match必須）
- **409 `ETAG_MISMATCH`**：再取得 → ユーザーへ「設定が更新されました。再読込してください。」表示 → 自動リロード

#### 7.4.1 Settings 画面の UI 構成
**セクション別**：
1) **ペルソナ**：
   - 行1：「普段の属性」= `true_self_type` 値
   - 行2：「夜の属性」= `night_self_type` 値
   - 背景色：診断済み時は淡青 `Colors.blue.shade50`（否、診断待機表示）
   - 動作：タップで PersonaDiagnosisResultScreen へ遷移（診断済み時のみ）

2) **ペルソナ再診断**：
   - ボタン：「再診断する」
   - 遷移：DiagnosisScreen（7問固定、全類型への回答）
   - 完了後：自動リロード + SnackBar「再診断を反映しました」

3) **生成設定**：
   - SegmentedButton「生成戦術」：
     - 0=「通常」（combo_id: 0 / デフォルト）
     - 1=「短め」（combo_id: 1）
     - 2=「長め」（combo_id: 2）
   - `combo_id` を settings で管理

4) **NG設定**：
   - テキスト表示：「禁止ワード・表現を設定してください。実装は後日予定です。」
   - 現在の禁止設定表示（`forbidden_type_ids`）
   - 実装時に `ng_tags` / `ng_free_phrases` フォーム追加予定

5) **端末移行**：
   - ボタン：「端末移行の設定」
   - 遷移：MigrationScreen

6) **もっと知る**：
   - ボタン：「このアプリについて」
   - 遷移：AboutPrivacyScreen

7) **保存**：
   - ボタン：「保存」
   - 動作：PUT `/me/settings` を発火、成功時「設定を保存しました」SnackBar
   - 失敗時：エラーに応じて再取得または復帰導線

#### 7.4.2 再診断フロー（詳細）
1. Settings 画面の「再診断する」ボタンをタップ
2. DiagnosisScreen（7問）が MaterialPageRoute で push される
3. ユーザーが全問回答 → `onCompleted` callback 発火
4. callback 内で `completeDiagnosis(answers)` API 呼び出し（POST /me/diagnosis）
5. 返却された診断結果を settings に反映させ、pop(true) で Settings に戻る
6. Settings state が `updated == true` を検知して `_loadSettings()` リロード実行
7. リロード完了後「再診断を反映しました」SnackBar 表示
8. 画面表示が新しいペルソナ値で即座に更新される

### 7.5 Migration
- issue：コード表示＋共有（コードは本文ではない）
- consume：コード入力→token更新
- 各エラーコードに沿う導線

### 7.6 About/Privacy
- 本文非保存/送信はユーザー の説明（固定文言は別Spec）
- 連絡先（必要なら）

### 7.7 固定UI文言（MUST）
**PersonaDiagnosisResultScreen**
- AppBar 標題：「あなたのペルソナ」
- セクション標題：
  - 「普段の自分」（True Self セクション）
  - 「夜の私」（Night Self セクション）
  - 「スタイルスコア」
- 各スコア行ラベル：「主張度」「温かみ」「リスク回避」
- 説明文：「これらのペルソナは、あなたの返信スタイルを決める大事な指標。ときどき見返して、「今のぼくはこう考えてるんだ」って確認してみてね。」

**True Self（5タイプ）説明文**
- Stability：「バランスを大事にする。無理のない生活を心がけ、まずは安定から。」
- Independence：「自分のペースを守る。誰かに縛られず、自分の判断を信じる。」
- Approval：「人の評価を大事にする。信頼を集めることが喜び。その分相手との距離が近い。」
- Realism：「現実的に考える。長期的な得を見える人。堅実さが武器。」
- Romance：「感情を大事にする。気持ちが満たされることが優先。その直感は案外正しい。」

**Night Self（5タイプ）説明文**
- VisitPush：「次のお約束を大事にする。関係を続けることが目標。その誠実さが信頼を呼ぶ。」
- Heal：「相手を癒したい。そっと寄り添うのが得意。その優しさが人を呼ぶ。」
- LittleDevil：「駆け引きを楽しむ。軽やかなテンポが自分らしい。その遊び心が魅力。」
- BigClient：「大事な人を見極める。重点的に寄せることを選ぶ。その戦略眼が効く。」
- Balance：「全体のバランスを見る。状況に合わせて柔軟に対応。その臨機応変さが強み。」

---

## 8. Followup（聞き返し）実装（MUST）
### 8.1 ポリシー
- `GenerateResponse.followup` が返された場合、A/B/C の下に質問UIを表示
- 質問は1つだけ（不足1点に絞る）
- A/B/C は仮で出した上で、不足1点を聞く（離脱防止）

### 8.2 UI表示
- `followup.question` を表示（例：「お客様との関係を教えてね」）
- `followup.choices` を選択肢として表示（1〜3個のボタン）
- ユーザーが選択肢をタップ

### 8.3 選択後の処理
1. 選択した `choice.id` を `followup.key` に応じて settings に反映
   - `relationship_type` → `settings.relationship_type = choice.id`
   - `reply_length_pref` → `settings.reply_length_pref = choice.id`
   - など
2. `PUT /me/settings` で更新（ETag/If-Match 必須）
3. 設定更新成功後、生成ボタンを再度有効化
4. ユーザーが再生成ボタンをタップで再度 `/generate` 呼び出し

### 8.4 許可リスト（MUST）
- `relationship_type`
- `reply_length_pref`
- `ng_tags`
- `ng_free_phrases`

詳細は `product_spec.md` セクション 9 参照。

---

## 8.5 診断派生パラメータ（生成連携 / MUST）
- 以下キーは `settings` 同期対象として扱う
  - `persona_goal_primary`
  - `persona_goal_secondary`
  - `style_assertiveness`
  - `style_warmth`
  - `style_risk_guard`
- `/generate` 前に `GET /me/settings` 済みであることを保証する

---

## 9. Telemetry（テレメトリ）実装（MUST）
### 9.1 ポリシー
- 本文/生成文は送信しない（privacy-first）
- イベントは `POST /api/v1/telemetry/events` へバッチ送信（1〜100イベント）
- サーバ側で `user_id_hash`（HMAC-SHA256）、`server_time_utc`、`hour_bucket_utc`、`dow_utc` を自動付与

### 9.2 イベントタイプ（5種）
1. **generate_requested**: 生成リクエスト開始時
   - `daily_used`, `daily_remaining`, `has_ng_setting`, `persona_version`
2. **generate_succeeded**: 生成成功時
   - `latency_ms`, `ng_gate_triggered`, `followup_returned`
3. **generate_failed**: 生成失敗時
   - `latency_ms` (optional), `error_code`
4. **candidate_copied**: 候補コピー時
   - `candidate_id`: "A" | "B" | "C"
5. **app_opened**: アプリ起動時（任意）

### 9.3 送信タイミング
- イベント発生時にローカルキューに追加
- 以下のタイミングでバッチ送信：
  - キューが10イベント溜まったら
  - アプリがバックグラウンドに行く前
  - 最大100イベントまで一度に送信

### 9.4 実装例
```dart
class TelemetryEvent {
  final String eventName;
  final String appVersion;
  final String os;
  final String deviceClass;
  final Map<String, dynamic>? eventData;
}

// 送信
await apiClient.post('/api/v1/telemetry/events', {
  'events': [
    {
      'event_name': 'generate_requested',
      'app_version': '1.0.0',
      'os': 'android',
      'device_class': 'phone',
      'daily_used': 1,
      'daily_remaining': 2,
      'has_ng_setting': true,
      'persona_version': 2,
    }
  ]
});
```

### 9.5 エラー処理
- Telemetry 送信失敗は **ユーザー体験を妨げない**
- 失敗したイベントは再送キューに保持（最大100件、古いものから破棄）
- 次回送信時にリトライ

詳細は `telemetry_schema.md` 参照。

---

## 10. セキュアストレージ
- tokenのみを Secure Storage に保存
- onboarding完了フラグ等、本文でない軽微データは SharedPreferences可

---

## 11. ロギング（本文ゼロ）
- ログに出してよい：
  - endpoint, status, error_code, latency, request_id
- ログに出してはいけない：
  - sharedText, candidates本文

---

## 12. テスト
### 12.1 ユニット
- ApiError正規化（error_codeごとの分岐）
- Settings ETag処理
- Idempotency-Key付与（/generate）

### 12.2 結合（手動中心）
- 共有受信（Android/iOS） → Generateへ自動遷移
- 生成 → A/B/C → コピー → 0.4秒フィードバック
- エラー（429/503/403/409）を意図的に発生させて復帰導線確認

### 12.3 実装で発生した失敗の再発防止（MUST）
- **遷移テストは導線ごとに1本以上**を追加する。
  - 最低対象：Settings → 再診断 / 端末移行 / About / 診断結果
- 同一文言が複数表示される可能性があるUIでは、`find.text(..., findsOneWidget)` 前提に依存しない。
  - 必要に応じて `Key` を付与し、`find.byKey` で検証する。
- クリップボードや非同期コールバック起点の `SnackBar` はタイミング依存で不安定になりうる。
  - `pumpAndSettle` のみで保証せず、まず遷移/表示の主目的を検証する。
- E2E（バックエンド接続依存）は通常の回帰セットから分離し、
  - デフォルトはユニット/ウィジェットを実行、
  - E2Eは環境準備済み時のみ明示実行する。

---

## 13. 受け入れ基準（実装）
- 共有受信以外の本文入力導線がない（貼り付け欄なし）
- 本文が端末に残らない（ファイル/DB/ログなし）
- `/api/v1` 契約に整合（header/ETag/Idempotency/エラー分岐）
- Safe Area崩れなし（主要端末）
- コピー体験が明確（0.4秒フィードバック）
---

## 14. 開発・実行手順（MUST / Development Guide）
### 14.1 エミュレータ起動（初回または停止状態時）
```bash
# 1. 利用可能なエミュレータを確認
flutter emulators

# 2. エミュレータを起動（バックグラウンド）
flutter emulators --launch <emulator_id>

# 注意：起動完了を待つため、最低 45〜60秒待機してから flutter devices で確認
Start-Sleep -Seconds 60  # PowerShell例
```

### 14.2 Flutter run（アプリ実行 / 重要）
```bash
# 【必ず実行】1. frontend フォルダに移動
Set-Location c:\dev\permy\frontend
# または
cd c:\dev\permy\frontend

# 【必ず確認】2. pubspec.yaml が存在することとカレントディレクトリを確認
Get-Location
Test-Path pubspec.yaml

# 【実行】3. エミュレータに実行
flutter run -d emulator-5554

# 代替案：複数デバイスがある場合
flutter devices  # 接続デバイスを確認
flutter run -d <device_id>
```

### 14.3 よくあるエラーと対処（MUST）

#### ❌ Error: No pubspec.yaml file found
```
This command should be run from the root of your Flutter project.
```
**原因**: `frontend` ディレクトリ内にいない（`backend` や `c:\dev\permy` にいる）  
**対処**:
```bash
Set-Location c:\dev\permy\frontend
cd c:\dev\permy\frontend
```

#### ❌ Device not found / エミュレータが認識されない
```
No emulators were detected. You can create one using 'flutter emulators --create'
```
**原因**: エミュレータが起動していない、またはPATHが通っていない  
**対処**:
```bash
# 1. 現在のエミュレータ状況を確認
flutter emulators

# 2. バックグラウンドで起動（必ず60秒待機）
flutter emulators --launch Medium_Phone_API_36.1
Start-Sleep -Seconds 60

# 3. デバイス再確認（タイムアウト20秒で明示的に待機）
flutter devices --device-timeout 20
```

#### ❌ flutter run が終了する（Exit Code: 1）
Flutterビルドが失敗している（詳細ログ確認が必要）  
**対処**:
```bash
# キャッシュをクリアして再実行
flutter clean

# デバイス再確認
flutter devices --device-timeout 20

# ビルド再実行（ログ出力）
flutter run -d emulator-5554 --verbose
```

#### ❌ `Could not find device or driver connected`
**原因**: cd コマンドでディレクトリ移動していない（PowerShell の `Set-Location` と `cd` の使い分けが混在）  
**対処**:
- **推奨**: `Set-Location` を使用（PowerShell標準）
  ```powershell
  Set-Location c:\dev\permy\frontend
  ```
- **代替**: `cd` + フルパスを使用
  ```powershell
  cd 'c:\dev\permy\frontend'  # パスに空白があれば quotes で囲む
  ```

### 14.4 手順チェックリスト（毎回実行前に確認 / MUST）
```
□ flutter emulators --launch <id> を実行し、60秒待機した
□ Set-Location c:\dev\permy\frontend を実行
□ Get-Location で `c:\dev\permy\frontend` が出力される
□ Test-Path pubspec.yaml で True が出力される
□ flutter devices で `emulator-5554` が表示される（--device-timeout 20）
□ 以上確認後、flutter run -d emulator-5554 を実行
```

### 14.5 開発中の Hot Reload / Hot Restart
```bash
# 実行中、コンソールで以下キーを入力可能
r     # Hot Reload（状態保持、コード変更反映）
R     # Hot Restart（状態リセット、コード変更反映）
q     # アプリ終了
```

---