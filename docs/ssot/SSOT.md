# docs/ssot/SSOT.md — Project Permy（Copilot作業用 SSOT / 入口）

**Last Updated (JST):** 2026-03-02 04:05:00 +0900

---

## 出力言語（MUST）
- Copilot/AIの出力（回答・提案・Spec文言・コメント）は日本語とする。
- ユーザーが明示的に英語を要求した場合のみ英語を許可する。

## 0. このSSOTの目的（MUST）
- GitHub Copilot / AIが **迷わず**仕様を参照し、**勝手判断・仕様劣化・虚偽・混入ゴミ**を起こさないための「唯一の入口」とする。
- 仕様の正は **docs配下のSpec**に固定し、過去のファイル・チャット内容・記憶に依存しない。

---

## 1. 最上位原則（MUST）
### 1.1 変更管理（MUST）
- Specは **Git管理**。変更は **必ずPR** 経由。
- **私（ちょび）のレビュー承認がない限り、docs配下のSpecは commit しない**。
- AIはローカル環境（`C:\dev\permy`）を参照できない前提。見た前提の断定は禁止。

### 1.2 仕様の唯一性（MUST）
- 「仕様」「ルール」「世界観」「禁止事項」は **Specファイルのみが正**。
- 会話中の説明・提案は正ではない。Specに反映され、レビュー承認されたものだけが正。

### 1.3 禁止（MUST）
- 勝手判断（良かれと思って補完・推測で埋める）禁止。判断不能は必ず質問。
- 虚偽報告（読んだ/検証した/出力したの断定）禁止。実施した手順・対象を併記できないなら「未確認」と書く。
- 仕様劣化（同じ概念の別名・別値・参照揺れ）禁止。
- Spec本文へ **内部マーカー/混入ゴミ**を入れない（例：`filecite...`、turn番号等）。

---

## 2. 読む順序（SSOT参照優先順位 / MUST）
Copilot・AI・開発者は必ずこの順で読む。

1) `docs/spec/00_world/world_concept.md`（戦略・コンセプト・世界観定義）  
2) `docs/spec/00_world/ui_animations.md`（UI演出SSOT：ピンク→黒反転、固定セリフ2文、変身シークエンス）  
3) `docs/spec/01_rules/project_rules.md`（運用ルール/禁止事項/してはいけない推論/品質ゲート）  
4) `docs/spec/01_rules/engineering_conventions.md`（実装規約：Flutter+FastAPI、可読性、テスト同時生成、プロンプト構造化）  
5) `docs/spec/01_rules/privacy_logging.md`（本文ゼロ：保存禁止/ログ禁止/例外時の扱い）  
6) `docs/spec/10_product/ng_policy.md`（NG制御SSOT：STOP/REWRITE/WARN、優先順位）  
7) `docs/spec/10_product/product_spec.md`（プロダクト仕様：価格/プラン/回数制限/入力導線/診断/生成/コンボ/followup）  
8) `docs/spec/20_backend/backend_spec.md`（バックエンド設計：API/認証/データモデル/本文ゼロ/レート制限/コストガード）  
9) `docs/spec/21_backend_impl/backend_impl.md`（バックエンド実装仕様：DTO/生成/中ゲート/メタ/OPENAI_DISABLED）  
10) `docs/spec/30_frontend/frontend_spec.md`（フロント設計：画面遷移/導線/文言/演出/貼り付け欄禁止）  
11) `docs/spec/31_frontend_impl/frontend_impl.md`（フロント実装：状態/DTO/API呼び出し/NG UI/設定同期）  
12) `docs/spec/31_frontend_impl/native_share_wrappers.md`（Android/iOS共有受信ラッパー：.txtのみ、永続化禁止、受け渡しI/F）

補助（必要時のみ）：
- `docs/spec/01_rules/telemetry_policy.md`（本文ゼロの計測ポリシー：時間帯バケットUTC）
- `docs/spec/20_backend/telemetry_schema.md`（テレメトリイベントスキーマ：hour_bucket_utc/dow_utc）
- `docs/spec/40_tests/test_strategy.md`（テスト方針：CIはOpenAI禁止、ライブは手動・上限）
- `docs/spec/41_ci/ci_policy.md`（CI方針：PR必須、OpenAI禁止、実行範囲）
- `docs/spec/42_deploy/deploy_strategy.md`（現時点：自動デプロイなし）
- `docs/spec/21_backend_impl/acceptance_tests_backend.md`（Backend受け入れテスト）
- `docs/spec/31_frontend_impl/acceptance_tests_frontend.md`（Frontend受け入れテスト）
- `docs/spec/40_tests/acceptance_tests.md`（総合E2E受け入れテスト）

---

## 3. プロジェクトの不変要件（MUST）
### 3.1 対象・課金
- 日本国内向け。Android / iPhone。
- 価格：**月額 2,980円**。
- Free：**1日3回**。
- Pro：**1日100回**（価格改定後も維持）。

### 3.2 入力導線（MUST）
- 入力は **LINE「トーク履歴送信」→ `.txt` 受領のみ**。
- **手動貼り付け欄は実装しない**。

### 3.3 保存禁止（MUST）
- 会話本文（トーク履歴txtの中身）/生成本文（返信案本文）を **端末・サーバに保存しない**。
- ログにも出さない（デバッグでも例外なし）。

### 3.4 世界観・禁止語（MUST）
- 黒猫の分身「ペルミィ」。一人称「ぼく」。
- プレッシャー表現（例：No.1/プロ/売上向上）禁止。
- 中二病設定用語（例：サンクトリア）禁止。
- 演出：通常「淡いピンク」→ 生成時「黒」へ反転。セリフ「ぼくはきみの分身・・・」「ぼくに任せて・・・」。

### 3.5 テスト/CI/コストガード（MUST）
- 現時点は **CIのみ**（自動デプロイなし）。
- CIでは OpenAI API を **呼ばない**（`OPENAI_DISABLED=true` 強制）。
- OpenAIを叩くライブテストは **手動実行のみ**＋回数上限。

### 3.6 テレメトリ（現時点スコープ / MUST）
- 本文/生成文は送らない。
- 分析はUTC基準、**時間帯バケットのみ**：
  - `hour_bucket_utc`（0..23）
  - `dow_utc`（0..6）

---

## 4. Specファイルに「何を書くか」定義（MUST）
### 4.1 world_concept.md（世界観）
- ターゲット心理、世界観、キャラクター、演出、禁止表現。
- UIに出す固定セリフ・文言禁止リストの“正”。

### 4.2 project_rules.md（運用ルール）
- 変更管理（PR/レビュー/承認）、勝手判断禁止、虚偽禁止、混入禁止。
- 破壊的操作（削除/リネーム/大量置換）の前提手順。
- “完成宣言”の条件（品質ゲート）。

### 4.3 product_spec.md（プロダクト仕様）
- 価格/プラン/回数制限、Free/Pro差、アップセル方針。
- 返信生成のI/O要件（A/B/C、followupの扱い、NG優先順位）。
- 夜職タイプ診断（参照先）と、設定キーの正。
- ユーザー向け文言（チュートリアル/CTAなど）の正。

### 4.4 backend_spec.md（バックエンド設計）
- API一覧・認証（匿名ID開始）、移行コード方針。
- データモデル（本文保存禁止に抵触しない範囲）。
- レート制限、コストガード、ログ方針（本文ゼロ）。
- テレメトリのサーバ処理（スキーマ参照）。

### 4.5 backend_impl.md（バックエンド実装仕様）
- DTO/JSON Schema（Structured Outputsを使う場合の制約）。
- 中ゲート（AIへ送らない条件）と、NG反映方法。
- `meta`（plan/daily/request_id等）返却仕様。
- OpenAIを呼ばないモード（CI/開発）の仕様。

### 4.6 frontend_spec.md（フロント設計）
- 画面遷移・Safe Area・UI要素。
- `.txt` 取り込み導線（貼り付け無し）。
- 生成時演出（色反転/セリフ）と禁止語。
- A/B/Cカード仕様（タップでコピー等）。

### 4.7 frontend_impl.md（フロント実装仕様）
- 状態管理、DTO、API呼び出し。
- Android/iOS共有受信ラッパー（`.txt`）。
- NG設定UI（ng_tags/ng_free_phrases）同期、テレメトリ送信（本文無し）。

### 4.8 telemetry_policy.md / telemetry_schema.md
- 収集してよい情報/禁止情報。
- イベントスキーマ、保持期間、集計（hourly rollup）。

### 4.9 test_strategy.md / ci_policy.md / deploy_strategy.md
- CIのみ（自動デプロイなし）を前提に、実行範囲とコストガードを定義。
- OpenAIライブテストは手動のみ＆上限必須。

---

## 5. 品質ゲート（MUST）
AIが「完成」「更新済み」と言う前に、以下が全て満たされていること。

- Spec本文に `filecite` 等の混入が **0件**
- 旧Spec（`docs/spec/_archive/`）への参照が **0件**
- 価格/回数制限/禁止語/入力導線/保存禁止が **矛盾0件**
- 変更は **PR提案**として提示され、ユーザー承認なしに反映しない

---

## 6. アーカイブ運用（MUST）
- 旧 `spec_*_vN.md` は `docs/spec/_archive/legacy_specs/` に隔離。
- Copilotは `docs/spec/_archive/` を参照しない（参照禁止）。

---

## 7. “AIにやらせる範囲”の明確化（MUST）
- AIは **実装を進めてよい**が、Spec変更は **提案のみ**。
- AIはテストを **勝手に実行しない**（実行は開発者が行う）。
- OpenAI課金が発生する処理は、CIでは絶対に実行しない。
