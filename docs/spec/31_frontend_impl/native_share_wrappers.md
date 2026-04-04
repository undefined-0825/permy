# docs/spec/31_frontend_impl/native_share_wrappers.md — ネイティブ共有受信ラッパー仕様（Android/iOS / MUST）

**Last Updated (JST):** 2026-06-19 00:00:00 +0900

> 目的：LINEの「トーク履歴を送信」で出力される `.txt` を **Android/iOSで手軽に受信**し、Flutterに引き渡す。  
> 最上位制約：**貼り付け欄なし** / **本文（txt中身）を端末に永続保存しない** / **実装は簡潔で壊れにくく**。

---

## 0. 参照（MUST）

- `docs/ssot/SSOT.md`
- `docs/spec/10_product/product_spec.md`（入力導線固定・本文ゼロ・トリム規則）
- `docs/spec/30_frontend/frontend_spec.md`（画面遷移/UX）
- `docs/spec/01_rules/privacy_logging.md`（保存禁止/ログ禁止）
- `docs/spec/01_rules/engineering_conventions.md`（可読性/最小差分/テスト同時）

---

## 1. 要件（MUST）

### 1.1 入力の唯一手段

- 受信するのは **共有された `.txt` のみ**。
- アプリ内にテキスト貼り付け欄・手入力欄は作らない。

### 1.2 永続化禁止

- `.txt` 本文を端末の永続領域（ファイル/DB/SharedPreferences等）に保存しない。
- 例外：OSが共有で提供する一時ファイル/URIは利用してよいが、アプリ側でコピーして保持しない。

### 1.3 取り扱い対象

- 受信は **単一ファイル**のみ（複数添付はエラー）。
- 拡張子は `.txt` を優先。拡張子が無い場合は `text/plain` を許容しつつ、サイズ制限と先頭検査でガードする。

### 1.4 失敗時

- 受信失敗は「本文なし」でユーザーに説明（ファイル名/サイズ/エラー理由）。
- 端末ログに本文を出さない。

---

## 2. 全体アーキテクチャ（MUST）

Flutter側は **共通I/F** を持ち、OS差分はネイティブラッパーで吸収する。

### 2.1 Flutter共通I/F（MUST）

- `ShareReceiver` を定義し、以下を提供する。

#### API

- `Future<SharePayload?> getInitialPayload()`
  - アプリ未起動状態で共有された場合の初回データ（ネイティブ優先で取得）
- `Stream<SharePayload?> payloadStream`
  - 起動中/復帰時に共有されたデータ（EventChannel経由）

#### DTO: SharePayload（メモリ上のみ保持）

- `text`（共有テキスト本文。Android側でUTF-8デコード済み）
- `fileName`（ファイル名。無ければ `"shared.txt"`）

> 注意：本文（`text`フィールド）はメモリ上のみで保持する。ファイル/DBへの永続化は絶対禁止。

### 2.2 ネイティブラッパーの方針（MUST）

- Flutter <-> Native は以下の2チャンネルで実装する。
  - `MethodChannel("permy/share_receiver/methods")`：初回 payload 取得 / リセット
  - `EventChannel("permy/share_receiver/events")`：起動中の追加共有をストリームで通知
- プラグイン `receive_sharing_intent` は採用継続。ただし**ネイティブチャンネルを優先**し、プラグインはフォールバックとして機能する。
  - ネイティブ MethodChannel が payload を返した場合 → プラグイン結果を無視
  - ネイティブが `null` の場合のみ → プラグインの `SharedMediaFile` を使用

---

## 3. Android仕様（MUST）

### 3.1 受信方法

- `ACTION_SEND`（単一共有）を受ける。Intent filter：`text/plain`。
- 受信対象は `Intent.EXTRA_STREAM` の `content://` URI が主経路。
- **URI抽出の優先順**（Kotlin 側）：
  1. `EXTRA_STREAM`
  2. `clipData` の1番目の URI
  3. `clipData` のテキストが URI 文字列の場合
  4. `EXTRA_TEXT` が URI 文字列の場合
  5. `EXTRA_TEXT` テキスト直受け

### 3.2 Activity構成（MUST）

- 共有受信は `MainActivity` 内で完結する（`ShareReceiverActivity` は不使用）。
- `onNewIntent` / `onStart` で共有 Intent を解析し、MethodChannel / EventChannel 経由で Flutter へ渡す。

### 3.3 URI処理（MUST）

- `ContentResolver.openInputStream(uri)` で読み取る。
- 読み取りは **メモリ上**。永続ファイルへコピー禁止。
- byte上限：**2MB**（`MAX_SHARE_BYTES = 2 * 1024 * 1024`）超過でエラー。
- 文字数トリムはバックエンド側で実施するため、Android側では2MB制限のみ適用。
- ファイル名は `OpenableColumns.DISPLAY_NAME` で取得（取れなければ `"shared.txt"`）。

### 3.4 文字コード（MUST）

- UTF-8を第一候補でデコード（`allowMalformed: true`）。
- 非ASCII比率が高い等、文字化けが疑われる場合は Shift_JIS でリトライ。
- **文字コードフォールバックは Android 側（Kotlin）で実施する。** Flutter側では実施しない（二重化禁止）。

### 3.5 セキュリティ（MUST）

- 受け取ったURIをそのままログに出さない（必要なら末尾数文字だけ）。
- 受信したファイル名も個人情報になり得るため、ログは最小限。

---

## 4. iOS仕様（MUST）

### 4.1 受信方法（MVPに含める：既決）

- iOSは Share Extension を使用して `.txt` を受け取る。
- 共有受信は拡張機能内で `NSExtensionItem` / `NSItemProvider` を処理する。

### 4.2 受け取り対象（MUST）

- UTType：`public.plain-text`（iOS 14+なら `UTType.plainText`）
- 受け取れるのは単一ファイルのみ（複数はエラー）。

### 4.3 受け渡し方式（MUST）

- Share Extension → Flutter本体への受け渡しは **App Group** を使う（推奨）。
  - ただし「本文永続化禁止」のため、App Groupに本文を保存しない。
  - 代わりに **共有ファイルURL（security-scoped）** や **一時的な参照情報**のみを渡す。

#### 受け渡しデータ（MUST）

- `sharedUri`（ファイルのURL文字列）
- `displayName`
- `mimeType`
- `byteLength`（可能なら）

> 共有ファイルをApp Group領域へコピーして保持する設計は禁止（本文保存に近くなる）。

### 4.4 security-scoped resource（MUST）

- 共有URLがsecurity-scopedの場合、Extension側で `startAccessingSecurityScopedResource()` を適切に扱う。
- 本体アプリ側で読む場合にアクセス権が切れる可能性があるため、**受信後すぐに本体アプリを起動して読み込み**する導線を採用する。

### 4.5 UX（MUST）

- 共有後は自動で本体アプリへ遷移（openURL）し、受信内容を本体が処理する。
- 失敗時はExtension側で短いエラー表示（本文なし）。

---

## 5. Flutter側の読み取り・トリム・送信（MUST）

### 5.1 読み取り（MUST）

- 本文は **Android 側（Kotlin）で読み取り・デコード済み**の `SharePayload.text` として Flutter に届く。
- Flutter が URI から直接ファイルを読む（`File.readAsBytes()`）のは、ネイティブが `null` を返した場合のプラグインフォールバック時のみ。
- 読み取った本文は **画面表示用の折りたたみ（任意）** と **バックエンド送信**にのみ使い、永続化しない。

### 5.2 トリム（SSOT / MUST）

- product_specのトリム規則に従い、末尾優先で切り詰める。
  - Free: 120行 / 8,000文字
  - Pro: 300行 / 18,000文字
- トリム前後の本文を保存しない。必要なら「トリム結果の行数/文字数」だけをテレメトリ送信（本文なし）。

### 5.3 UIの折りたたみ表示（MUST）

- 「根拠確認」のために折りたたみ表示は可。ただし既定は折りたたみで、展開はユーザー操作。
- 展開してもスクロール成立。省略表示固定（maxLines固定）はしない。

---

## 6. エラーハンドリング（MUST）

### 6.1 代表エラー

- ファイルが `.txt` ではない / `text/plain` ではない
- 複数ファイル共有
- サイズ過大
- 文字コード解釈不能
- URI読み取り失敗（権限/存在しない等）

### 6.2 表示（MUST）

- ユーザーには「原因」「対処」を短く表示。
- 表示やログに本文を含めない。

---

## 7. テスト（MUST）

### 7.1 Flutter（Widget/Unit）

- `ShareReceiver` をモックし、受信→生成画面遷移→A/B/C表示までの導線をWidget testで最低1本。
- `ShareReceiver` の単体テスト：`share_receiver_test.dart` でネイティブ優先動作を検証済み（5件）。
- 文字数トリムはバックエンド側で実施するため、フロントエンドのトリム Unit test は不要。

### 7.2 手動受け入れ（acceptance_tests_frontend準拠 / MUST）

- Android/iOSそれぞれで、LINEから`.txt`共有→Permy受信が成立すること。
- 貼り付け欄が存在しないこと。
- 本文が永続化されていないこと（端末ストレージ/ログ確認）。

---

## 8. 未確定 / 確認事項（最大3点）

1) iOS Share Extensionの受け渡しでApp Groupを使用する場合、**参照情報のみ**で成立するか（security-scopedの扱い含む）を実装検証で確定する。  
2) ~~既存採用プラグイン（`receive_sharing_intent`）の置換/ラッパー化~~ → **確定**：ネイティブチャンネル優先・プラグインはフォールバックとして採用継続。  
3) 受信した`.txt`の"折りたたみ表示"の既定表示範囲（先頭/末尾/両方）をfrontend_specで確定する。  
