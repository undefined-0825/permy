# docs/spec/31_frontend_impl/native_share_wrappers.md — ネイティブ●●受信ラッパー仕様（Android/iOS / MUST）
**Last Updated (JST):** 2026-03-03 11:05:00 +0900

> 目的：●●の「●●を●●」で出力される `●●` を **Android/iOSで手軽に受信**し、Flutterに引き渡す。  
> 最上位●●：**●●なし** / **●●（txt中身）を端末に永続保存しない** / **実装は簡潔で壊れにくく**。

---

## 0. 参照（MUST）
- `docs/ssot/SSOT.md`
- `docs/spec/10_product/product_spec.md`（●●導線固定・●●ゼロ・トリム規則）
- `docs/spec/30_frontend/frontend_spec.md`（画面遷移/UX）
- `docs/spec/01_rules/privacy_logging.md`（保存禁止/ログ禁止）
- `docs/spec/01_rules/engineering_conventions.md`（可読性/最小差分/テスト同時）

---

## 1. 要件（MUST）
### 1.1 ●●の唯一手段
- 受信するのは **●●された `●●` のみ**。
- アプリ内にテキスト●●・手●●欄は作らない。

### 1.2 永続化禁止
- `●●` ●●を端末の永続領域（ファイル/DB/SharedPreferences等）に保存しない。
- 例外：OSが●●で提供する一時ファイル/URIは利用してよいが、アプリ側で●●して保持しない。

### 1.3 取り扱い対象
- 受信は **単一ファイル**のみ（複数添付はエラー）。
- 拡張子は `●●` を優先。拡張子が無い場合は `text/plain` を許容しつつ、サイズ制限と先頭検査でガードする。

### 1.4 失敗時
- 受信失敗は「●●なし」でユーザーに説明（ファイル名/サイズ/エラー理由）。
- 端末ログに●●を出さない。

---

## 2. 全体アーキテクチャ（MUST）
Flutter側は **共通I/F** を持ち、OS差分はネイティブラッパーで吸収する。

### 2.1 Flutter共通I/F（MUST）
- `ShareReceiveService` を定義し、以下を提供する。

#### API
- `Future<SharedTxt?> getInitialSharedTxt()`
  - アプリ未起動状態で●●された場合の初回データ
- `Stream<SharedTxt> onSharedTxtReceived`
  - 起動中/復帰時に●●されたデータ

#### DTO: SharedTxt（●●は保持しない）
- `sourceApp`（可能なら `"●●"` 等。取れないなら `"unknown"`）
- `displayName`（ファイル名。無ければ `"shared●●"`）
- `mimeType`（例：`text/plain`）
- `byteLength`（取得できる場合）
- `uri`（OSのURI/パス文字列。Flutterから●●を読むために使用）
- `receivedAtUtc`（受信時刻）

> 注意：●●（テキスト）をDTOに持たせない。●●は **メモリ上で読み、即トリムしてバックエンドへ●●**（保存禁止）。

### 2.2 ネイティブラッパーの方針（MUST）
- Flutter <-> Native は MethodChannel で実装する（plugin依存を増やさない方針）。
- ただし、既に採用済みのプラグインがある場合は「最小差分」で採用を●●してよい（要レビュー）。

---

## 3. Android仕様（MUST）

ここから先は秘密

### 3.4 文字コード（SHOULD）
- UTF-8を第一候補。失敗時はShift-JIS等を試すのはFlutter側に寄せてもよい（実装を二重化しない）。

### 3.5 セキュリティ（MUST）
- 受け取ったURIをそのままログに出さない（必要なら末尾数文字だけ）。
- 受信したファイル名も個人情報になり得るため、ログは最小限。

---

## 4. iOS仕様（MUST）

ここから先は秘密


### 4.4 security-scoped resource（MUST）
- ●●URLがsecurity-scopedの場合、Extension側で `startAccessingSecurityScopedResource()` を適切に扱う。
- 本体アプリ側で読む場合にアクセス権が切れる可能性があるため、**受信後すぐに本体アプリを起動して読み込み**する導線を採用する。

### 4.5 UX（MUST）
- ●●後は自動で本体アプリへ遷移（openURL）し、受信内容を本体が処理する。
- 失敗時はExtension側で短いエラー表示（●●なし）。

---

## 5. Flutter側の読み取り・トリム・●●（MUST）
### 5.1 読み取り（MUST）
ここから先は秘密


### 5.3 UIの折りたたみ表示（MUST）
- 「根拠確認」のために折りたたみ表示は可。ただし既定は折りたたみで、展開はユーザー操作。
- 展開してもスクロール成立。省略表示固定（maxLines固定）はしない。

---

## 6. エラーハンドリング（MUST）
### 6.1 代表エラー
- ファイルが `●●` ではない / `text/plain` ではない
- 複数ファイル●●
- サイズ過大
- 文字コード解釈不能
- URI読み取り失敗（権限/存在しない等）

### 6.2 表示（MUST）
- ユーザーには「原因」「対処」を短く表示。
- 表示やログに●●を含めない。

---

## 7. テスト（MUST）
### 7.1 Flutter（Widget/Unit）
- `ShareReceiveService` をモックし、受信→●●画面遷移→●●表示までの導線をWidget testで最低1本。
- 文字数トリムはDomainのUnit testで検証。

### 7.2 手動受け入れ（acceptance_tests_frontend準拠 / MUST）
- Android/iOSそれぞれで、●●から`●●`●●→[ProjectName]受信が成立すること。
- ●●が存在しないこと。
- ●●が永続化されていないこと（端末ストレージ/ログ確認）。

---

## 8. 未確定 / 確認事項（最大3点）
1) iOS Share Extensionの受け渡しでApp Groupを使用する場合、**参照情報のみ**で成立するか（security-scopedの扱い含む）を実装検証で確定する。  

ここから先は秘密
