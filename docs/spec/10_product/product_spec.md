# docs/spec/10_product/product_spec.md — Permy プロダクト仕様（中核SSOT / MUST）

**Last Updated (JST):** 2026-03-07 12:30:00 +0900

> 目的：Copilotが迷わず実装できるよう、Permyの中核仕様（プラン/入出力/診断/生成/NG/UX）を **曖昧さなく固定**する。  
> 本文（LINE履歴txt・生成文）の保存禁止は **最優先**。本Spec内でも本文を扱う設計は行わない。

---

## 0. Spec参照順（MUST）

- 1. `docs/spec/00_world/world_concept.md`
- 2. `docs/spec/10_product/product_spec.md`
- 3. `docs/spec/40_design/permy_design_system_spec.md`
- 4. `docs/spec/30_frontend/frontend_spec.md`
- 5. `docs/spec/31_frontend_impl/frontend_impl.md`

## 0.1 参照優先順位（MUST）

- 参照起点：`docs/ssot/SSOT.md`
- 世界観SSOT：`docs/spec/00_world/world_concept.md`
- デザインシステムSSOT：`docs/spec/40_design/permy_design_system_spec.md`
- 運用・禁止：`docs/spec/01_rules/project_rules.md`
- プライバシー/ログ：`docs/spec/01_rules/privacy_logging.md`
- NG制御SSOT：`docs/spec/10_product/ng_policy.md`
- バックエンド設計：`docs/spec/20_backend/backend_spec.md`
- フロント設計：`docs/spec/30_frontend/frontend_spec.md`

本Specは上記と **矛盾しない**こと（矛盾がある場合は本Specを出さずに「確認事項」にする）。

---

## 1. プロダクト定義（MUST）

### 1.1 ゴール（内部KGI / MUST）

- **ちょびさんの収益最大化**（最短で課金・継続利用につながる状態を作る）。  
  ※ユーザー向け文言に「売上」「No.1」「プロ意識」等のプレッシャー表現を持ち込まない（世界観SSOT/NGポリシーに従う）。

### 1.2 ユーザー価値（MUST）

- 夜職ユーザーの「めんどくさい/だるい」LINE営業返信を、分身 **ペルミィ** が「夜の自分」として代行提案し、返信作成コストと罪悪感を下げる。

### 1.3 絶対制約（MUST）

- **返信は提案のみ**（自動送信しない。送信主体はユーザー）。
- **入力導線固定**：LINE「トーク履歴を送信」→ `.txt` を共有受信するのみ（貼り付け欄は実装しない）。
- **本文/生成文を保存しない**（端末・サーバ・ログ・テレメトリすべて）。
- 日本国内向け。Android / iPhone。

---

## 2. プラン・課金・回数制限（SSOT / MUST）

### 2.1 価格・回数制限（MUST）

- 価格：**Pro 月額 2,980円 / Premium 月額 4,980円**
- Free：**1日3回**
- Pro：**1日100回**
- Premium：**1日200回**

> 日次回数制限はクライアント表示に依存せず **サーバ側で必ず判定**する（backend_spec参照）。

### 2.2 プランの扱い（MUST）

- APIの `plan` は `free|pro|premium` の3値（backend_spec参照）。
- 課金形態の内部区別：
  - `feature_tier`: `free|pro|premium`
  - `billing_tier`: `free|pro_store|premium_store|premium_comp`
- **機能判定は feature_tier のみ**。`feature_tier=pro` は `plan=pro`、`feature_tier=premium` は `plan=premium` として返す（billing区別はフロントに露出しない）。

### 2.3 Pro専用機能（MUST）

- Proのみ：推定メーター（♥/🔥 0..100）表示（backend_implの `meta.pro` を使用）
- Proのみ：生成方針（コンボ）のうち **2/3/4/5** を実行可能（後述）
- Proのみ：Generate画面の生成調整5項目でPro専用値を選択可能（後述）
- PremiumはPro機能をすべて利用可能とする。
- Premiumのみ：顧客管理機能（セクション17）を利用可能とする。
- FreeはPro専用機能をUI上に表示してよいが、選択/実行時は「有料版のみ」案内（アップセル）を必ず出す。
- backendも Free時は5項目を強制的にFree値へ正規化する（クライアント制御だけに依存しない）。

---

## 3. 初期導線・アカウント・移行（MUST）

### 3.1 匿名開始（MUST）

- 初回は **匿名ユーザーID** で開始し、ユーザー入力の登録導線は作らない（離脱率上昇のため）。
- 起動時、token未保持なら `POST /api/v1/auth/anonymous` で token取得（frontend_spec / backend_spec参照）。

### 3.2 端末移行（MUST）

- QR移行は廃止。二段階承認は入れない。
- **移行コード12桁**で移行（期限あり / 1回限り / レート制限あり）。

### 3.3 アカウント削除（MUST）

- 削除導線は設定画面に配置し、確認ダイアログを必須とする。
- 削除実行は `DELETE /api/v1/auth/me` で行う。
- 削除対象はユーザー本体と設定・日次利用カウント等の関連メタ情報とし、会話本文/生成本文はもともと保存しない。
- 削除後は既存セッションを無効化し、同一トークンではAPIを利用できない状態にする。

---

## 4. 入力（.txt）仕様（MUST）

### 4.1 受領形式（MUST）

- `.txt` ファイル（URI）を共有受信する。
- アプリ内の貼り付け欄/手入力欄は実装しない。

### 4.2 文字コード（SHOULD）

- UTF-8優先 + フォールバック（実装詳細はfrontend_impl/backend_impl側で確定）

### 4.3 トリム規則（MUST）

- **末尾（最新）優先**で切り詰める。
- Free：**120行 / 8,000文字**  
- Pro：**300行 / 18,000文字**  
- 不足時は全行、超過時は末尾から文字数で切る。

### 4.4 UI上の根拠表示（MUST）

- 返信生成画面に「もらったトーク履歴」を **折りたたみ表示**（ユーザーが根拠を確認できる）。

---

## 5. ペルソナ（TrueSelf/NightSelf）仕様（SSOT / MUST）

### 5.1 二軸の定義（MUST）

- Permyは以下2軸で分身を構成し、生成に反映する：
  - **TrueSelfType**（本当の私：価値観/制約）
  - **NightSelfType**（夜の私：営業スタイル）

### 5.2 Type定義（IDはenum名がSSOT / MUST）

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
    Heal,        // 癒し系タイプ
    LittleDevil, // 小悪魔系タイプ
    BigClient,   // 太客育成タイプ
    Balance,     // バランスタイプ
}
```

#### 5.2.1 互換性（MUST）

- 旧 `Flow` は廃止し `Balance` を採用する。
- 既存データに `Flow` がある場合、サーバは `Balance` に正規化して返す（クライアントは `Flow` を扱わない）。

### 5.3 診断結果の保持（MUST）

- 診断結果は **1セットのみ**保持。再診断で上書きする。
- 保存先SSOT：`/api/v1/me/settings` の `settings_json`（端末ローカルに本文/診断結果を永続保存しない）。
- 設問・重み・判定アルゴリズムは `persona_scoring_spec.md` を正とする。

### 5.4 診断結果画像（SSOT / MUST）

- 画像はアプリ同梱。サーバは画像を扱わない。
- 画像ファイル名はSSOT（命名変更/リネーム禁止）。

TrueSelf:

- `true_stability.png`
- `true_independence.png`
- `true_approval.png`
- `true_realism.png`
- `true_romance.png`

NightSelf:

- `night_visit_push.png`
- `night_heal.png`
- `night_little_devil.png`
- `night_big_client.png`
- `night_balance.png`

---

## 6. Settings（/me/settings）スキーマ（SSOT / MUST）

> `settings_json` は「本文ではない設定メタ」のみ。本文保存禁止と矛盾させない。

### 6.1 必須キー（MUST）

- `persona_version: int`
- `true_self_type: TrueSelfType`（文字列）
- `night_self_type: NightSelfType`（文字列）
- `persona_goal_primary: string`（診断から算出）
- `persona_goal_secondary: string | null`（診断から算出）
- `style_assertiveness: int`（0..100）
- `style_warmth: int`（0..100）
- `style_risk_guard: int`（0..100）
- `relationship_type: string`（後述）
- `reply_length_pref: string`（short|standard|long）
- `line_break_pref: string`（few|infer|many）
- `emoji_amount_pref: string`（none|standard|many）
- `reaction_level_pref: string`（low|standard|high）
- `partner_name_usage_pref: string`（none|once|many）
- `ng_tags: string[]`（後述）
- `ng_free_phrases: string[]`（短いフレーズ、上限10）

### 6.2 relationship_type（SSOT / MUST）

- `new` / `regular` / `big_client` / `caution` / `peer`

### 6.3 reply_length_pref（SSOT / MUST）

- `short` / `standard` / `long`
- Free が選択可能: `short` のみ
- Pro のみ: `standard` / `long`

### 6.4 line_break_pref（SSOT / MUST）

- `few`（少なめ）/ `infer`（履歴から推測）/ `many`（多め）
- Free が選択可能: `few` のみ
- Pro のみ: `infer` / `many`
- デフォルト: `infer`

### 6.5 emoji_amount_pref（SSOT / MUST）

- `none`（なし）/ `standard`（標準）/ `many`（多め）
- Free が選択可能: `none` のみ
- Pro のみ: `standard` / `many`
- デフォルト: `standard`

### 6.6 reaction_level_pref（SSOT / MUST）

- `low`（低め）/ `standard`（標準）/ `high`（高め）
- Free が選択可能: `low` のみ
- Pro のみ: `standard` / `high`
- デフォルト: `standard`

### 6.7 partner_name_usage_pref（SSOT / MUST）

- `none`（使わない）/ `once`（1回程度）/ `many`（多めに）
- Free が選択可能: `none` のみ
- Pro のみ: `once` / `many`
- デフォルト: `once`

### 6.8 NGタグ（SSOT / MUST）

- `no_preach`
- `no_pressure`
- `no_romance_bait`
- `no_money_talk`
- `no_sexual_joke`
- `no_late_reply_blame`

### 6.9 自由入力NG（SSOT / MUST）

- `ng_free_phrases` は短いフレーズのみ（上限10）。
- 会話本文/生成本文をここに混ぜない。

---

## 7. 返信生成（/generate）仕様（中核 / MUST）

### 7.1 返却形式（MUST）

- **夜職専用**。返信案は **常にA/B/Cの3案**（ユーザー表示：A/B/C）。
- 要約は出力しない（返信案のみ）。
- 標準・ビジネスモードは廃止。本プロジェクトは夜職特化のみ。

### 7.2 A/B/Cの役割（夜職固定 / MUST）

世界観SSOTに従い、A/B/Cは以下で固定：

- **A：余裕（信頼・安心）**
- **B：甘め（距離を縮める）**
- **C：攻め（次アクション）**

> 3案は言い回し違いではなく、温度/距離感/目的が明確に異なる案にする。

### 7.3 長さ・構造（SHOULD / MUST）

- デフォルトは **長文寄り（2〜4段落）**。短文は「短文が最適な文脈」のときのみ許容。
- 基本骨格（既定）：**共感 → 状況確認 → 提案**
- ただし固定テンプレ連発は禁止（構造は守りつつ、語尾/順/具体例で揺らす）。

### 7.4 生成制御の3軸（MUST）

- `NightSelfType` を主軸に文体・押し引きを決める
- `TrueSelfType` は上位制約（無理の上限、禁則、負担）
- `combo`（生成方針）で今回の戦術目標を決める（後述）

- **手打ち感（スマホ文体）**:
  - 丁寧すぎる敬語・完璧すぎる整文は「営業感/AI感」のノイズになり得るため避ける。
  - ただし「雑＝失礼」にならない範囲で、以下を *状況に応じて* 適用して“人間の手打ち感”を作る。
    - 句読点を打ちすぎない（ゼロ固定はしない）
    - ひらがな/口語を適度に混ぜる
    - 改行のリズムで温度感を作る（1〜2回程度を基本）
  - 目的：お客様に「AIっぽさ」を悟らせず、距離感を自然に保つ。
  - 例外：謝罪・重要確認・トラブル回避など、誤解リスクが高い場面は整文優先（手打ち感より明瞭さを優先）。

---

## 8. 生成方針（コンボ）SSOT（MUST）

### 8.1 定義（MUST）

コンボは数値ID（0..5）がSSOT（クライアント/サーバ共通）。

- 0: 次回来店の約束
- 1: 休眠復活
- 2: 新規客の集客（初回来店）
- 3: 火消し（境界線・リスク回避）
- 4: 同伴誘導
- 5: 落とす（恋愛寄せ）

### 8.2 Free/Pro/Premiumの実行可否（MUST）

- Freeで実行可：0,1
- Pro/Premiumで実行可：2,3,4,5
- UIは全項目を表示してよいが、Freeで有料専用を実行しようとした場合：
  - 生成を実行しない
  - 「有料版のみ」案内（アップセル）を表示する

---

## 9. 入力不足時の followup（聞き返し）（MUST）

### 9.1 ポリシー（MUST）

- 原則：質問は1つだけ（不足1点に絞る）
- **A/B/Cは仮で出した上で**、不足1点を聞く（離脱を減らす）

### 9.2 DTO（MUST）

- `GenerateResponse.followup`（nullable）
  - `key: String`
  - `question: String`
  - `choices: List<{id:String,label:String}>`（1..3）

### 9.3 key許可リスト（MUST）

- `relationship_type`
- `reply_length_pref`
- `ng_tags`
- `ng_free_phrases`
（追加はPR提案→承認後のみ）

### 9.4 選択の反映（MUST）

- ユーザーが選んだ `choice.id` を `key` に応じて settings に反映する（ローカルのsnapshot＋`/me/settings`）。
- 反映後、生成ボタンを再度有効化し、ユーザー操作で再生成できる状態に戻す。

---

## 10. メタ情報（/generate meta）とPro表示（MUST）

### 10.1 成功レスポンス共通meta（MUST）

- `meta.request_id`
- `meta.plan`（free/pro/premium）
- `meta.daily.limit/used/remaining`
- `meta.model_hint`（固定化しない“ヒント”）
- `meta.timestamp`（任意）

### 10.2 Proのみ（MAY → ただし実装は可能）

- `meta.pro` に推定メーター（♥/🔥 0..100）を含めてもよい。
- Freeには出さない。

---

## 11. バージョン管理・アップデート通知（MUST）

(詳細: `backend_spec.md` / `backend_impl.md` / `frontend_impl.md` / `version_release_process.md` を正とし、本Specではプロダクト仲介のみ)

### 11.1 ユーザー体験（MUST）

- **起動時**: `/api/v1/version` で最新バージョンを確認。
- **アップデート必須**: インストール版 < min_supported_version の場合、強制アップデート画面（Close不可）を表示し、Google Play へ誘導。
- **アップデート任意**: インストール版 < latest_version の場合、任意アップデート画面を表示。
- **画面表示内容**: 最新バージョン番号、リリースノート（タイトル 1 行 + 本文）、「バージョンアップする」ボタン。

### 11.2 バージョン定義（MUST）

- `major.minor.patch` 形式（例: `1.2.3`）
- min_supported_version: サーバ側で指定される最小利用可能版。下回るユーザーは強制アップデート。
- latest_version: 最新版（通常は app_version = latest_version）。

### 11.3 リリースノート登録（MUST）

- DB に保存: `AppReleaseNote` テーブル（version, title, body, released_at）
- 新バージョンリリース時に DBA / デプロイ担当が INSERT
- 最新版のみ `/api/v1/version` で返す（複数版の履歴は送らない）

---

## 12. NG（禁止/書き換え/注意喚起）適用（SSOT / MUST）

- NG制御は `ng_policy.md` をSSOTとする。
- 優先順位（高→低）：
  1) 安全ゲート（STOP）
  2) ユーザー設定のNG（タグ/禁止フレーズ）
  3) プロジェクト共通の表現禁止（圧/中二病/自己陶酔 等）
  4) WARN（安全寄せ）

---

## 13. UI/UX（プロダクト側で固定する要点 / MUST）

### 12.1 生成のテンポ（MUST）

- 生成中はUIをロックして二重送信を防ぐ。
- A/B/Cは生成完了後にのみ表示（生成前は非表示）。

### 12.2 コピー操作（MUST）

- A/B/Cカードのタップでコピー（ボタンを増やさない）。
- コピー成功フィードバック：トースト＋0.4秒ハイライト。

### 12.3 世界観演出（MUST）

- 通常：淡いピンク
- 生成時：黒へ反転
- 固定セリフ（文言一字一句固定）：
  1) 「ぼくはきみの分身・・・」
  2) 「ぼくに任せて・・・」

---

## 14. 公開に必要な文書（MUST）

- 利用規約
- プライバシーポリシー
- ヘルプ（使い方）

---

## 15. 未確定 / 確認事項（最大3点）

1) 「淡いピンク」「黒反転」の具体Hexを固定するか（world_concept側で未確定）。  
2) プライバシー短文コピー（例：「トーク履歴は残さないよ。送信するのはきみだよ」）のSSOT配置先が本Specか別copybookか。  
3) NightSelf画像ファイル名が `night_balance.png` で確定で良いか（過去資産に `night_flow.png` があるため、差し替え運用の整理が必要）。  

### 15.1.2 アカウント削除実装状況（2026-03-07追加）

- 設定画面に「アカウントを削除する」導線と確認ダイアログを実装済み。
- backendに `DELETE /api/v1/auth/me` を実装済み。
- 削除時に関連メタ情報の削除とセッション無効化を実施。

### 15.1 備考

- 本TODOは「MVP機能」ではなく「公開審査・運用」観点の最低限チェック項目である。
- 課金機能を有効化しない段階でも、利用規約/プライバシーポリシー/ヘルプは必須とする。

---

## 16. 公開前TODO（法務/ストア審査の最低限）

- [x] 設定画面から遷移できる「利用規約」ページを実装（または外部URL導線を実装）。
- [x] 設定画面から遷移できる「プライバシーポリシー」ページを実装（または外部URL導線を実装）。
- [x] 設定画面から遷移できる「ヘルプ（使い方）」ページを実装。
- [x] Google Play / App Store の公開情報に、上記法務ページURLを登録。
- [x] 課金導線を出す場合は「購入復元」導線を実装し、ストア審査要件を満たす。
- [x] 課金導線を出す場合は「サブスクリプション管理（解約）」導線を実装。
- [x] アカウント削除/データ削除要件に備え、削除導線（UI）とAPI方針をSpecで確定。
- [x] OSSライセンス表示導線を設定画面に実装（Flutter標準のライセンス画面可）。

### 16.1.1 課金機能実装状況（2026-03-07更新）

- MVPシンプル実装完了（ローカル状態管理のみ）
- 購入フロー・購入復元・サブスク管理導線を実装済み
- **backend連携を実装済み**（POST /api/v1/billing/verify）
  - PurchaseService → BillingProof → Settings画面 → API連携フロー完成
  - 購入成功時に feature_tier/billing_tier を自動更新
  - mock mode で動作確認済み（実ストアサーバ検証は将来実装）
- Android 商品ID（SSOT）：`permy_pro_monthly` / `permy-premium-monthly`
- iOS 商品ID（SSOT）：`com.sukimalab.permy.pro_monthly` / `com.sukimalab.permy.premium_monthly`

---

## 17. 顧客管理機能（夜職向け顧客管理 / MUST）

### 17.1 目的（MUST）

- 夜職ユーザーが、お客様ごとの接客情報・関係性・注意点を構造化して管理できるようにする。
- 目的は「CRMそのもの」ではなく、**次回接客・返信生成・検索・リマインド**に使える最小限の顧客情報基盤を提供すること。
- 本機能は、返信生成と独立したメモ機能ではなく、**Permyの提案精度と再来店支援を高めるための補助機能**として扱う。

### 17.2 絶対制約（MUST）

- **会話本文・生成本文は保存しない**。
- 保存してよいのは、ユーザーが明示的に登録した **構造化メタ情報** のみとする。
- LINEトーク履歴 `.txt` の本文を顧客メモへ自動保存してはならない。
- 顧客メモは、本文復元可能な長文ログ・全文検索インデックス・可逆圧縮データを保持しない。
- 自動送信は行わない。顧客メモはあくまで提案補助である。

### 17.3 顧客メモの位置づけ（MUST）

- 本機能の正式名称は **「顧客メモ」** とする。
- ユーザー向けには「管理」「営業支配」「CRM」等の硬い表現を避け、**覚えておきたいことを整理する機能**として扱う。
- 世界観上、説教・圧・成績強要に繋がる見せ方は禁止する。

### 17.4 顧客エンティティ（SSOT / MUST）

顧客メモは以下の単位で保持する。

#### 17.4.1 Customer（顧客基本情報）

- `customer_id: string`
- `display_name: string`  
  - 顧客の表示名
- `nickname: string | null`
  - ユーザー側の管理用呼称
- `call_name: string | null`
  - 相手を呼ぶときの呼称（例：たかしさん / たかちゃん）
- `area_tag: string | null`
  - 居住地・活動地の簡易タグ（例：梅田 / ミナミ / 西宮）
- `age_range: string | null`
  - `unknown|20s_early|20s_late|30s|40s|50s_or_more`
- `job_tag: string | null`
  - 職業や属性の簡易タグ（例：経営 / 営業 / 飲食）
- `relationship_stage: string`
  - `new|regular|important|caution|inactive`
- `visit_frequency_tag: string | null`
  - `unknown|weekly|biweekly|monthly|rare`
- `drink_style_tag: string | null`
  - `unknown|light|normal|heavy|gets_drunk_fast`
- `last_visit_at: datetime | null`
- `last_contact_at: datetime | null`
- `memo_summary: string | null`
  - 120文字以内の短い要約。本文ではなく、ユーザーが整理した要点のみ
- `is_archived: bool`
- `created_at: datetime`
- `updated_at: datetime`

#### 17.4.2 CustomerTag（顧客タグ）

- 顧客ごとに複数タグを保持できる
- タグは以下のカテゴリで管理する

カテゴリ:

- `personality`
- `topic`
- `ng`
- `lifestyle`
- `relationship`
- `sales_hint`
- `event`

例:

- personality: `lonely`, `proud`, `gentle`
- topic: `work`, `romance`, `family`, `hobby_car`
- ng: `no_money_talk`, `no_push`, `avoid_late_night`
- lifestyle: `last_train_sensitive`, `busy_weekdays`
- relationship: `likes_meeting`, `slow_reply_ok`
- sales_hint: `visit_push_ok`, `heal_prefer`
- event: `birthday_soon`, `job_change`

#### 17.4.3 CustomerVisitLog（来店ログ）

- `visit_log_id: string`
- `customer_id: string`
- `visited_on: date`
- `visit_type: string`
  - `store|douhan|after|other`
- `stay_minutes: int | null`
- `spend_level: string | null`
  - `unknown|low|middle|high|very_high`
- `drink_amount_tag: string | null`
  - `light|normal|heavy`
- `mood_tag: string | null`
  - `good|normal|bad|unstable`
- `memo_short: string | null`
  - 80文字以内の短文要点
- `created_at: datetime`

#### 17.4.4 CustomerEvent（顧客イベント）

- `event_id: string`
- `customer_id: string`
- `event_type: string`
  - `birthday|first_visit_anniversary|last_visit_reminder|special_day|custom`
- `event_date: date`
- `title: string`
- `note: string | null`
  - 80文字以内
- `remind_days_before: int`
- `is_active: bool`

### 17.5 本文非保存と両立するメモ方針（MUST）

- 保存対象は以下に限定する
  - 顧客属性
  - タグ
  - 来店日時
  - 金額レンジ
  - 短い要約メモ
  - イベント日付
- 保存禁止
  - LINE本文
  - 会話の逐語記録
  - 返信案本文
  - 顧客とのやり取り全文
  - 本文を再現可能な長文サマリ

### 17.6 検索機能（中核 / MUST）

#### 17.6.1 検索目的

- ユーザーが「名前を忘れたが特徴は覚えている」状態でも顧客を探せるようにする。

#### 17.6.2 検索対象

検索対象は本文ではなく、以下の構造化項目のみとする。

- `display_name`
- `nickname`
- `call_name`
- `area_tag`
- `job_tag`
- `memo_summary`
- `CustomerTag`
- `CustomerVisitLog.memo_short`
- `CustomerEvent.title`

#### 17.6.3 検索仕様

- 単一検索窓から横断検索する
- 名前完全一致を前提にしない
- 部分一致で候補表示してよい
- 並び順は以下を優先
  1. 名前一致
  2. タグ一致
  3. 要約メモ一致
  4. 最終更新日時が新しい順

#### 17.6.4 想定クエリ例

- 「終電」
- 「梅田」
- 「転職」
- 「誕生日」
- 「不機嫌」
- 「重い酒」
- 「アフター」

### 17.7 リマインド機能（MUST）

#### 17.7.1 目的

- 顧客ごとの連絡・再来店・記念日対応漏れを減らす。

#### 17.7.2 リマインド種別

- 誕生日
- 初回来店記念日
- 最終来店から一定日数経過
- 最終連絡から一定日数経過
- ユーザー手動登録イベント

#### 17.7.3 期限系の初期候補

- `3日連絡なし`
- `7日連絡なし`
- `14日来店なし`
- `30日来店なし`

※日数閾値は将来設定化してよいが、MVPでは固定値でよい。

### 17.8 Generateとの連携（MUST）

- 顧客を選択して生成する場合、以下の構造化情報のみ生成に利用してよい
  - 呼称
  - relationship_stage
  - visit_frequency_tag
  - drink_style_tag
  - 顧客タグ
  - last_visit_at / last_contact_at
  - memo_summary
- 来店ログやイベントは、必要に応じて短い特徴量に変換して生成へ渡してよい
- 生成時も本文保存禁止を破ってはならない
- 顧客メモ由来のNGは、既存 `ng_tags` より弱くしてはならない

### 17.9 UI要件（MUST）

#### 17.9.1 画面一覧

- 顧客一覧
- 顧客詳細
- 顧客編集
- 来店ログ追加
- イベント追加
- 顧客検索結果一覧

#### 17.9.2 顧客一覧

- 名前
- 関係性ラベル
- 最終来店日
- 最終連絡日
- 主要タグ2〜3個
- 検索導線を上部固定

#### 17.9.3 顧客詳細

- 基本情報
- タグ
- 直近来店ログ
- イベント
- 「この顧客で返信を作る」導線

#### 17.9.4 入力UX

- 手入力負荷を減らすため、タグ選択UIを優先する
- 自由記述は短文のみ
- 音声入力は将来拡張とし、MVPでは必須にしない

### 17.10 Free/Pro/Premium差分（MUST）

- Free:
  - 顧客登録数 上限あり（例：30件）
  - 検索可
  - 基本メモ可
  - リマインドは主要種別のみ
- Pro:
  - 顧客管理機能は利用不可（Generate/設定のPro機能のみ）
- Premium:
  - 顧客登録数 上限拡大または無制限
  - 全検索可
  - イベント/来店ログをフル利用可
  - 顧客連携生成を利用可

※ 上限数の具体値は別途確定する。未確定の間は product_spec 本文に固定しない。

### 17.11 NG / リスク制御（MUST）

- 顧客メモ機能は、相手の個人情報を過剰に収集する設計にしてはならない
- 住所・勤務先詳細・本名・機微情報の収集を前提にしない
- 自由記述欄には、過度にセンシティブな情報入力を促す文言を置かない
- ユーザーに「監視」「支配」「囲い込み」を想起させるコピーは禁止する

### 17.12 未確定事項（最大3点）

1. 顧客登録数のFree/Premium上限値
2. 顧客メモを夜職版Permy本体へ入れるか、ホスト版のみ先行導入するか
3. 来店ログの `spend_level` を5段階固定にするか、店側運用に合わせて将来設定化するか
