# docs/spec/01_rules/engineering_conventions.md — Engineering Conventions（Flutter + FastAPI / MUST）

**Last Updated (JST):** 2026-03-02 05:55:00 +0900

本ファイルは **Copilotが直接読む**ことを前提とした「実装規約（唯一の正）」。
抽象論ではなく、[ProjectName]の●●に合わせて **具体ルール**として固定する。

---

## 0. 前提（MUST）
- 参照起点：`docs/ssot/SSOT.md`
- 対象：Flutter（Dart） + FastAPI（Python）
- 実装はCopilot中心。Specの更新はPR提●●のみ（[PM]承認必須）。
- **●●/●●を保存・ログ出力しない**（端末/サーバ/CI/監視すべて）。

---

## 1. ●●ンプト構造化ルール（MUST）
Copilotへ依頼するときの指示は以下の内容を理解して書く（●●により省略・順序入替を許可）

1) **Role**: `Flutter Engineer` または `FastAPI Engineer`
2) **Read First**: 必ず読むファイルを列挙（パス固定）
3) **Goal**: 何を作るかを一文で
4) **Files to Edit/Create**: 変更対象のファイルパスを列挙（新規作成含む）
5) **Constraints**: 本●●ジェクト固有のMUSTを列挙
6) **Output**: 期待する成果物（完成形コード、テスト含む）
7) **Non-goals**: やらないこと（勝手追加/大規模リファクタ等）

### 1.1 Copilotへの固定出力（MUST）
Copilotは依頼の最初に次の3行を必ず出力する（自己チェック）。

- `SSOT_READ: OK` または `SSOT_READ: NG`
- `TARGET_FILES: <paths...>`
- `NON_GOALS: <items...>`

- SSOTを読めない場合は `SSOT_READ: NG` を出し、**作業を停止して質問**する。
- `TARGET_FILES` が空、または広すぎる（例：`**` / `backend/**` / `docs/**`）場合は、編集に入らず候補（2〜3個）を提示して確認を取る（MUST）。
- `NON_GOALS` が空の場合は、デフォルトで「仕様追加・大規模リファクタ・既存動作変更」を含める（MUST）。

---

## 2. コードスタイル（可読性重視 / MUST）
### 2.1 共通（MUST）
- **可読性最優先**（賢いトリック禁止）
- **最小差分**（必要箇所以外を触らない）
- コメントは日本語で簡潔（必要箇所のみ）。冗長コメント禁止
- 未確定は質問する（仮実装で埋めない）
- 例外/NULL/境界条件は **明示**（握りつぶさない）

### 2.2 命名（MUST）
- 意味優先。略語乱用禁止（DTO/HTTP/URL/ID等の一般略語のみ可）
- enum/DTO/関数名は「何をするか」が読める語にする
- 禁止：`data`, `tmp`, `test1`, `foo`, `bar` 等の曖昧名

### 2.3 関数・分岐（MUST）
- 1関数は短く（目安 40行以内）
- ネストは浅く（目安 2段以内）
- 早期returnで深いifを避ける

---

## 3. 設計ルール（UNIX哲学の具体化 / MUST）
### 3.1 レイヤ境界（MUST）
- **Flutter UI**: 表示・●●・画面遷移のみ（ビジネス判断を持たない）
- **Flutter Domain**: 判定/●●/ルール（純粋関数寄り、I/Oなし）
- **Flutter Infra**: HTTP/Share受信/端末機能（I/O）
- **FastAPI Router**: ルーティングとDTOバリデーション
- **FastAPI Service**: ユースケース（NG適用、●●制御、メタ●●）
- **FastAPI Infra**: OpenAIクライアント、永続化、テレメトリ●●先

境界をまたぐ依存は **インターフェース越し**（DI可能）にする。

### 3.2 単一責任（MUST）
- 1ファイルは1責務。1クラス/関数も1責務。
- “便利クラス”の肥大化は禁止。

---

## 4. テストファースト（実装と同時にテスト●● / MUST）
### 4.1 絶対ルール（MUST）
- 実装コード●●、**同時にテストコードも●●**する。
- 修正時も、必ずテストを更新する（テスト無し修正禁止）。

### 4.2 FastAPI（MUST）
- `backend/tests/` に以下を作る：
  - `test_contract_*.py`（API●●テスト）
  - `test_logic_*.py`（NG優先順位、followup等のロジック）
- Contractは request/response の必須キーと型を検証する（●●は扱わない）。
- Unitは OpenAIをモック。

### 4.3 Flutter（MUST）
- `test/` に以下を作る：
  - `*_domain_test.dart`
  - `*_widget_test.dart`
- HTTP/Share受信はモック。

---

## 5. セキュリティ・保守性（MUST）
### 5.1 ●●ゼロ（最重要 / MUST）
以下は **保存・ログ出力・テレメトリ●●を一切禁止**：
- ●●●●txtの●●
- ●●した●●の●●
- NGフレーズの生テキスト（必要なら件数/ハッシュのみ）

エラー時も●●を出さない。返すのは **error_code / request_id / 要約**のみ。

### 5.2 シークレット管理（MUST）
- OpenAIキー等は `.env` または Secret Store。Gitに入れない。
- CIにはOpenAIキーを登録しない（OPENAI_DISABLED）。
- `.gitignore` で `.env*` / secrets / 実txt を除外する。

### 5.3 OpenAIコストガード（MUST）
- backendは `OPENAI_DISABLED=true` で OpenAI呼び出しを拒否できる実装にする。
- CIでは必ず `OPENAI_DISABLED=true` を設定し、テストが OpenAI を叩かないこと。
- ライブテスト（OpenAI有効）は **手動実行のみ**。回数上限（例：最大3リクエスト/実行）。

### 5.4 ●●導線固定（MUST）
- ●●は `●●` ●●のみ。●●は実装しない。
- 解析対象はメモリ上の一時処理のみ（永続化しない）。

### 5.5 テレメトリ（現時点 / MUST）
- UTC基準、`hour_bucket_utc` と `dow_utc` のみ。
- 追加フィールドはPR提●●→[PM]承認後のみ。

---

## 6. FastAPI 実装ルール（MUST）
- DTOはPydanticで厳密にバリデーションし、422/400を明確にする。
- 例外は握りつぶさない。スタックトレースをクライアントへ返さない。
- レスポンスは「●●なし」設計で、必要なメタ（●●/daily/request_id等）を返す。
- ログは「●●なし」。error_code と request_id 中心。

---

## 7. Flutter 実装ルール（MUST）
- null safetyを厳密に運用（required/nullableを設計で固定）。
- 画面はSafe Areaを守り、長文でも崩れない（スクロール前提）。
- ●●カードは省略表示禁止（maxLines固定禁止）。●●は全文。
- ●●受信（Android/iOS）はラッパーで隠蔽し、UIは「txt●●」だけにする。

---

## 8. 禁止事項（NG）
- Specにない機能追加（登録画面、●●、●●保存、勝手なSDK導入）
- 既決定事項の変更（●●/回数/導線/保存禁止/禁止語）
- 大規模リファクタ（必要箇所以外を触る）
- “動いたはず”の断定（実行ログなしで成功宣言）
