# docs/spec/31_frontend_impl/native_share_wrappers.md — ネイティブ共有受信ラッパー仕様（Android/iOS / MUST）
**Last Updated (JST):** 2026-03-03 11:05:00 +0900

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
- `ShareReceiveService` を定義し、以下を提供する。

#### API
- `Future<SharedTxt?> getInitialSharedTxt()`
  - アプリ未起動状態で共有された場合の初回データ
- `Stream<SharedTxt> onSharedTxtReceived`
  - 起動中/復帰時に共有されたデータ

#### DTO: SharedTxt（本文は保持しない）
- `sourceApp`（可能なら `"LINE"` 等。取れないなら `"unknown"`）
- `displayName`（ファイル名。無ければ `"shared.txt"`）
- `mimeType`（例：`text/plain`）
- `byteLength`（取得できる場合）
- `uri`（OSのURI/パス文字列。Flutterから本文を読むために使用）
- `receivedAtUtc`（受信時刻）

> 注意：本文（テキスト）をDTOに持たせない。本文は **メモリ上で読み、即トリムしてバックエンドへ送る**（保存禁止）。

### 2.2 ネイティブラッパーの方針（MUST）
- Flutter <-> Native は MethodChannel で実装する（plugin依存を増やさない方針）。
- ただし、既に採用済みのプラグインがある場合は「最小差分」で採用を継続してよい（要レビュー）。

---

## 3. Android仕様（MUST）
### 3.1 受信方法
- `ACTION_SEND`（単一共有）を受ける。
- Intent filter：`text/plain` を許可。可能なら拡張子`.txt`を優先判定。
- 受信対象は `Intent.EXTRA_STREAM` の `content://` URI を想定。

### 3.2 Activity構成（MUST）
- 共有受信用に `ShareReceiverActivity`（透明/最小UI）を用意し、受信後にFlutterのMainActivityへ引き継ぐ。
- 既にMainActivityで処理できる設計ならMainActivity内で完結してよい（ただし可読性優先）。

### 3.3 URI処理（MUST）
- `ContentResolver.openInputStream(uri)` で読み取る。
- 読み取りは **メモリ上**。永続ファイルへコピー禁止。
- 読み取りの上限：
  - Free: 8,000文字相当、Pro: 18,000文字相当（product_specのトリム規則に合わせる）
  - ただしAndroid側は「過大ファイル防止」のため、byte上限（例：2MB）を先にチェックしてよい。

### 3.4 文字コード（SHOULD）
- UTF-8を第一候補。失敗時はShift-JIS等を試すのはFlutter側に寄せてもよい（実装を二重化しない）。

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
- 共有受信で得た `uri` を用い、Flutterで本文を読み取る。
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
- `ShareReceiveService` をモックし、受信→生成画面遷移→A/B/C表示までの導線をWidget testで最低1本。
- 文字数トリムはDomainのUnit testで検証。

### 7.2 手動受け入れ（acceptance_tests_frontend準拠 / MUST）
- Android/iOSそれぞれで、LINEから`.txt`共有→Permy受信が成立すること。
- 貼り付け欄が存在しないこと。
- 本文が永続化されていないこと（端末ストレージ/ログ確認）。

---

## 8. 未確定 / 確認事項（最大3点）
1) iOS Share Extensionの受け渡しでApp Groupを使用する場合、**参照情報のみ**で成立するか（security-scopedの扱い含む）を実装検証で確定する。  
2) 既存採用プラグイン（例：receive_sharing_intent等）がある場合、置換せずにラッパー化で吸収するか（最小差分優先）を決める。  
3) 受信した`.txt`の“折りたたみ表示”の既定表示範囲（先頭/末尾/両方）をfrontend_specで確定する。  
