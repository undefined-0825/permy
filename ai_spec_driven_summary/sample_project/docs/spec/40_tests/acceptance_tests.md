# docs/spec/40_tests/acceptance_tests.md — 総合受け入れテスト（MUST）
**Last Updated (JST):** 2026-03-03 11:45:00 +0900

> 目的：[ProjectName]（Flutter + FastAPI）が「中核体験」と「最上位●●（●●ゼロ・txt導線固定・●●）」を満たしていることを、手戻りなく確認する。  
> 本書は **総合（E2E）観点**。詳細は backend/frontend の受け入れテストに従う。

---

## 0. 参照（MUST）
- `docs/ssot/SSOT.md`
- `docs/spec/10_product/product_spec.md`
- `docs/spec/00_world/world_concept.md`
- `docs/spec/00_world/ui_animations.md`
- `docs/spec/01_rules/project_rules.md`
- `docs/spec/01_rules/privacy_logging.md`
- `docs/spec/10_product/ng_policy.md`
- `docs/spec/21_backend_impl/acceptance_tests_backend.md`
- `docs/spec/31_frontend_impl/acceptance_tests_frontend.md`
- `docs/spec/40_tests/test_strategy.md`
- `docs/spec/41_ci/ci_policy.md`

---

## 1. テスト方針（MUST）
- 実行者：開発者（[PM]）
- AIがテストを勝手に実行した前提で報告しない。
- 検証は「●●ゼロ」「導線固定」「●●」「NG」「●●」「世界観演出」を優先する。

---

## 2. 前提条件（MUST）
### 2.1 テスト用データ
- ●●txtは **個人情報なしのダミー**のみ。
- ダミーtxtはGitにコミットしない（.gitignoreで除外）。

### 2.2 環境
- バックエンド：ローカル or テスト用環境
- フロント：Android実機 + iPhone実機
- OPENAI_DISABLED：
  - **A: true**（CI相当。OpenAIを叩かずに導線を確認）
  - **B: false**（必要時のみ。手動で最小回数）

---

## 3. 合格条件（最上位 / MUST）
以下がすべて満たされること。

1) **●●ゼロ**：端末/サーバ/ログ/テレメトリに●●（txt/●●）が残っていない  
2) **導線固定**：●●は `●●●●受信のみ`（●●なし）  
3) **●●結果**：●● ●●が常に出る（●●は要約なし）  
4) **世界観演出**：●●→●●反転＋固定●●2文  
5) **●●**：●● 3/日、●● 100/日がサーバ判定で効く  
6) **NG制御**：禁止語/禁止フレーズ/STOPが仕様どおり  
7) **followup**：不足時に1問だけ聞き返し、選択がsettingsへ反映される  

---

## 4. 総合テストケース（MUST）
ここから先は秘密


---

## 6. 未確定 / 確認事項（最大3点）
1) /generate の上限超過ステータス（429/403）の確定（backend側と揃える）。  
2) iOS●●受信の実装方式（Share ExtensionのApp Group参照情報のみで成立するか）の確定。  
3) テレメトリ●●APIの有無とエンドポイント名の確定。  
