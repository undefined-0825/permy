# docs/spec/31_frontend_impl/acceptance_tests_frontend.md — Frontend受け入れテスト（MUST）
**Last Updated (JST):** 2026-03-03 10:35:00 +0900

> 目的：Flutter実装が **仕様どおり**であることを、手戻りなく検証するための受け入れ基準。  
> ●●（●●txt・●●）を端末に保存しない●●が最優先。UIでも●●を永続化しない。

---

## 0. 前提（MUST）
- 参照起点：`docs/ssot/SSOT.md`
- 中核仕様：`docs/spec/10_product/product_spec.md`
- 世界観：`docs/spec/00_world/world_concept.md`
- 運用/禁止：`docs/spec/01_rules/project_rules.md`
- プライバシー/ログ：`docs/spec/01_rules/privacy_logging.md`
- フロント設計：`docs/spec/30_frontend/frontend_spec.md`
- フロント実装規約：`docs/spec/01_rules/engineering_conventions.md`
- テスト方針：`docs/spec/40_tests/test_strategy.md`

---

## 1. テスト環境（MUST）
- 実行者：開発者（[PM]）
- 端末：Android実機 + iPhone実機（●●受信の差異があるため）
- ●●受信：●●から `●●` を●● → [ProjectName]で受け取れること（●●は存在しない）

---

## 2. 画面と導線（受け入れ対象 / MUST）
最低限、以下の導線が通ること。

1) 初回起動 → 匿名開始（バックエンドtoken取得）  
2) チュートリアル（txt●●手順） → 最後のボタン文言「●●を変える」  
3) txt●● → ●●画面へ遷移（●●なし）  
4) ●●演出（●●→●●反転＋●●）  
5) 結果画面：●● ●●表示 → タップで●●  
6) followup（不足時の聞き返し）が表示され、選択で設定更新できる  
7) ●●●●/Proアップセルが正しく動く  
8) 設定（/me/settings）同期が壊れない（ただし登録画面は作らない）

---

## 3. 受け入れ基準（共通 / MUST）
### 3.1 ●●ゼロ（最重要）
- 端末の永続領域に以下を保存しない（例：SharedPreferences/ファイル/DB）：
  - ●●txt●●
  - ●●した●●●●
- 端末ログ（debug/analytics/クラッシュログ）に●●を出さない。

### 3.2 ●●導線固定
- ●●・手●●欄は存在しない（UI上に出さない）。

### 3.3 UIのSafe Area
- iPhoneノッチ/ホームインジケータ、Androidナビバー/キーボードと被らない。
- 長文表示はスクロールで成立する（省略で隠さない）。

---

## 4. テストデータ（MUST）
- テスト用txtは個人情報なしのダミーのみ。
- ダミーtxtはリポジトリにコミットしない（.gitignoreで除外）。

---

## 5. テストケース（MUST）
表記：Given / When / Then

---

### TC-FE-01 初回起動（匿名開始）
**Given**
- アプリ初回起動（ストレージにtokenなし）

**When**
- アプリを起動

**Then**
- バックエンドへ匿名認証を行いtokenを取得
- tokenは安全なストレージに保存してよい（●●ではない）
- 画面はエラーで止まらず、チュートリアル or ホームへ遷移

---

### TC-FE-02 チュートリアル導線（txt●●手順）
**Given**
- 初回導線

**When**
- チュートリアルを最後まで進める

**Then**
- 手順が「●●の●●→●●を[ProjectName]へ●●」に固定されている
- 最後のボタン文言は **「●●を変える」**
- チュートリアルに●●誘導がない

---

### TC-FE-03 ●●受信（Android）— ●●を受け取れる
**Given**
- Android実機
- ●●の●●をエクスポート済み（ダミー）

**When**
- ●●から●● → [ProjectName]を選択

**Then**
- [ProjectName]が `●●` を受け取る
- 受け取ったファイル名が画面に表示される（●●は表示しないか、折りたたみ）
- アプリがクラッシュしない

---

### TC-FE-04 ●●受信（iOS）— ●●を受け取れる
**Given**
- iPhone実機
- ●●の●●をエクスポート済み（ダミー）

**When**
- ●●シートから[ProjectName]へ渡す

**Then**
- `●●` を受け取る
- ●●受信の実装が「Share Extension/Share Intent ラッパー」で成立
- アプリがクラッシュしない

---

### TC-FE-05 ●●が存在しない
**Given**
- 主要画面を確認

**When**
- ●●画面/ホーム/設定を探す

**Then**
- テキスト貼り付け/手●●の●●欄が存在しない

---

### TC-FE-06 ●●画面の演出（世界観）
**Given**
- `●●` ●●済み

**When**
- ●●ボタンを押す

**Then**
- 背景が **淡い●● → ●●** に反転する（●●中）
- ●●が順に表示される：
  1) 「●●●●」
  2) 「●●●●」
- ●●完了後、結果画面に遷移（演出は邪魔にならない長さ）

---

ここは秘密

---

## 7. 合格条件（MUST）
- TC-FE-01〜TC-FE-15 がすべて満たされる
- ●●ゼロ（保存/ログ/テレメトリ）の●●を破っていない
- Settings の再●● → 自動リロード → SnackBar が正常に機能している
- PersonaDiagnosisResultScreen が読み取り専用で表示される

---

## 8. 未確定 / 確認事項（最大3点）
1) `淡い●●/●●` のHexを world_concept 側で固定するか（UI調整で必要）。  
2) iOS●●受信（Share Extension）をMVPで必須にする前提は採用済みだが、実装方式（Extension or URL scheme）をfrontend_implで確定する必要がある。  
3) 結果画面の「根拠（●●）折りたたみ表示」のUI詳細（どこまで見せるか）をfrontend_specで確定する必要がある。  
