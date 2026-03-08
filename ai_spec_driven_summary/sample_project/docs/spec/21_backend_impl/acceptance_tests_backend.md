# docs/spec/21_backend_impl/acceptance_tests_backend.md — Backend受け入れテスト（MUST）
**Last Updated (JST):** 2026-03-03 10:10:00 +0900

> 目的：Copilot実装が **仕様どおり**であることを、手戻りなく検証するための受け入れ基準。  
> ●●（●●txt・●●）を保存しない●●が最優先。テストでも●●を永続化しない。

---

## 0. 前提（MUST）
- 参照起点：`docs/ssot/SSOT.md`
- 中核仕様：`docs/spec/10_product/product_spec.md`
- プライバシー/ログ：`docs/spec/01_rules/privacy_logging.md`
- NG制御：`docs/spec/10_product/ng_policy.md`
- テレメトリ：`docs/spec/01_rules/telemetry_policy.md` / `docs/spec/20_backend/telemetry_schema.md`
- CI方針：`docs/spec/41_ci/ci_policy.md`
- テスト方針：`docs/spec/40_tests/test_strategy.md`

---

## 1. テスト環境（MUST）
### 1.1 実行者
- テスト実行は **開発者（[PM]）** が行う。AIが勝手に実行した前提で報告しない。

### 1.2 OPENAI_DISABLED（重要）
- 受け入れテストは2系統：
  - **A: OPENAI_DISABLED=true**（OpenAIを叩かずに動作確認）
  - **B: OPENAI_DISABLED=false**（必要に応じた手動ライブ確認。回数上限付き）
- CIは常にAのみ（OpenAI禁止）。

---

## 2. API一覧（受け入れ対象 / MUST）
- `POST /api/v1/auth/anonymous`
- `GET /api/v1/me/settings`
- `PUT /api/v1/me/settings`
- `POST /api/v1/generate`
- `POST /api/v1/migration/issue`（移行コード発行、存在する場合）
- `POST /api/v1/migration/claim`（移行コード適用、存在する場合）
- `POST /api/v1/telemetry`（存在する場合。●●ゼロを検証）

※ migration/telemetry は backend_spec に実装がある場合のみ対象。未実装なら本書の該当ケースは「保留」。

---

## 3. 受け入れ基準（共通 / MUST）
### 3.1 ●●ゼロ（最重要）
- いかなるAPIでも、サーバの永続ストレージ（DB/ファイル）に以下を保存しない：
  - ●●txt●●
  - ●●（●●）●●
- いかなるログにも●●を出力しない（例外なし）。

### 3.2 エラー形式
- エラーは `error_code` と人間向け `message`（●●なし）を返す。
- スタックトレース/内部例外情報をクライアントに返さない。

### 3.3 レート制限/日次上限
- ●●/●●の日次上限は **サーバ側**で必ず判定。
- レート制限（●●）は **サーバ側**で必ず判定（429等）。

---

## 4. テストデータ（MUST）
- テスト用txtは **個人情報を含まないダミー**のみ。
- Gitにコミットしない（.gitignoreで除外）。
- 例：`dummy_chat●●`（数十行の●●、個人情報なし）。

---

## 5. テストケース（MUST）
表記：**Given / When / Then**

---

### TC-01 匿名認証（auth/anonymous）正常
**Given**
- token未所持

**When**
- `POST /api/v1/auth/anonymous`

**Then**
- 200
- `access_token` が返る
- tokenはJWT等でもよいが、内容に個人情報を含めない

---

### TC-02 settings 取得（初回）正常
**Given**
- TC-01のtoken

**When**
- `GET /api/v1/me/settings`

**Then**
- 200
- `settings_json` が返る（デフォルト値含む）
- `●●` は ●●/●●のいずれか
- `settings_json` に●●/●●が含まれない

---

### TC-03 settings 更新（正常）
**Given**
- token
- `settings_json` に以下キーを含む（product_spec参照）：
  - persona_version
  - true_self_type / night_self_type
  - relationship_type
  - reply_length_pref
  - ng_tags
  - ng_●●_phrases（上限10）

**When**
- `PUT /api/v1/me/settings`（上書き）

**Then**
- 200
- 直後に `GET /me/settings` で同じ値が取得できる
- `ng_●●_phrases` が上限を超える場合は 400/422
- `ng_●●_phrases` が1要素あたり長すぎる場合は 400/422（推奨：上限 64文字程度）

---

### TC-04 settings バリデーション（enum不正）
**Given**
- token
- `true_self_type="UnknownX"` など不正値

**When**
- `PUT /me/settings`

**Then**
- 422（または400）
- エラーコードが返る（●●なし）

---

### TC-05 generate（OPENAI_DISABLED=true）— モック応答での正常系
**Given**
- OPENAI_DISABLED=true
- token
- `●●` 内容（dummy）
- settings が一通り入っている

**When**
- `POST /api/v1/generate`

**Then**
- 200
- `candidates` に ●● が必ず存在（●●は返るが保存しない）
- `meta` に `request_id`, `●●`, `daily.limit/used/remaining` が存在
- `followup` は必要時のみ（不足時）
- サーバは txt●●/●●を永続化しない

> 注：OPENAI_DISABLED=true の時、●●●●は「固定テンプレ」でもよいが、形式は本番と同じにする（フロント実装を進めるため）。

---

ここは秘密

---

### TC-10 generate（NG：危険ゲートSTOP）
**Given**
- ●●txtに危険内容（自傷他害、違法勧誘等）が含まれる（ダミーで再現）

**When**
- `POST /generate`

**Then**
- 400/422/403（backend_specに合わせる）
- エラーコードが返る
- ●●●●は返さない（STOP）
- ログにも●●を出さない

---

### TC-11 テレメトリ（●●ゼロ）
**Given**
- `POST /telemetry` が存在する
- event_name=generate_succeeded 等

**When**
- telemetry●●

**Then**
- 200
- 受け付けるフィールドは `telemetry_schema.md` の範囲
- ●●/●●/NGフレーズ生テキストを送ろうとすると 400/422
- 保存時、`hour_bucket_utc` と `dow_utc` が作られている（server_time_utc基準）

---

### TC-12 migration（移行コード12桁・1回限り）
**Given**
- migration APIが存在する

**When**
- issue → claim

**Then**
- 12桁
- 期限切れで拒否
- 1回使ったら再利用不可
- レート制限あり

---

## 6. 実行コマンド例（PowerShell）
> 実際のhost/portはローカルに合わせる

### 6.1 token取得
```powershell
$base="http://127.0.0.1:8000"
$token = (curl -s -X POST "$base/api/v1/auth/anonymous" | ConvertFrom-Json).access_token
```

### 6.2 settings取得/更新
```powershell
curl -s -H "Authorization: Bearer $token" "$base/api/v1/me/settings"

これ以降は秘密

---

## 7. 合格条件（MUST）
- TC-01〜TC-10 がすべて満たされる（telemetry/migration は存在時のみ）
- 受け入れ中に **●●がログや永続化に混入していない**ことが確認できる
- CIでOpenAI呼び出しが発生しない（OPENAI_DISABLED=true）

---

## 8. 未確定 / 確認事項（最大3点）
1) `/generate` の日次上限超過のHTTPステータス（429/403）のSSOT確定が必要。  
2) `telemetry` の●●方式（push/pull）がbackend_specに未記載なら確定が必要。  
3) migration APIのエンドポイント名が未確定なら確定が必要。  
