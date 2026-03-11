# docs/spec/90_tests/acceptance_tests.md — 総合受け入れテスト（MUST）
**Last Updated (JST):** 2026-03-03 11:45:00 +0900

> 目的：Permy（Flutter + FastAPI）が「中核体験」と「最上位制約（本文ゼロ・txt導線固定・回数制限）」を満たしていることを、手戻りなく確認する。  
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
- `docs/spec/90_tests/test_strategy.md`
- `docs/spec/91_ci/ci_policy.md`

---

## 1. テスト方針（MUST）
- 実行者：開発者（ちょび）
- AIがテストを勝手に実行した前提で報告しない。
- 検証は「本文ゼロ」「導線固定」「3案」「NG」「回数制限」「世界観演出」を優先する。

---

## 2. 前提条件（MUST）
### 2.1 テスト用データ
- LINE履歴txtは **個人情報なしのダミー**のみ。
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

1) **本文ゼロ**：端末/サーバ/ログ/テレメトリに本文（txt/生成文）が残っていない  
2) **導線固定**：入力は `.txt共有受信のみ`（貼り付け欄なし）  
3) **生成結果**：A/B/C 3案が常に出る（夜職は要約なし）  
4) **世界観演出**：ピンク→黒反転＋固定セリフ2文  
5) **回数制限**：Free 3/日、Pro 100/日がサーバ判定で効く  
6) **NG制御**：禁止語/禁止フレーズ/STOPが仕様どおり  
7) **followup**：不足時に1問だけ聞き返し、選択がsettingsへ反映される  

---

## 4. 総合テストケース（MUST）
表記：Given / When / Then

---

### TC-E2E-01 初回起動 → 匿名開始 → チュートリアル
**Given**
- アプリ初回起動（tokenなし）

**When**
- アプリ起動してチュートリアルを最後まで進める

**Then**
- 匿名認証される（登録導線なし）
- チュートリアルは「LINE履歴送信→.txt共有」のみを案内
- チュートリアル最後のボタン文言：**「ペルミィを変える」**

---

### TC-E2E-02 .txt共有受信（Android）
**Given**
- Android実機
- ダミーtxt

**When**
- LINEから共有→Permy

**Then**
- `.txt` を受け取れる
- 貼り付け欄が存在しない
- 受信後、生成画面へ遷移できる

---

### TC-E2E-03 .txt共有受信（iOS）
**Given**
- iPhone実機
- ダミーtxt

**When**
- 共有シートからPermy

**Then**
- `.txt` を受け取れる（Share Extension/ラッパー）
- 貼り付け欄が存在しない

---

### TC-E2E-04 生成（OPENAI_DISABLED=true）導線確認
**Given**
- OPENAI_DISABLED=true
- `.txt`受領済み
- settingsが未設定でもよい

**When**
- 生成ボタンを押す

**Then**
- 演出：淡いピンク→黒反転
- セリフ：  
  1) 「ぼくはきみの分身・・・」  
  2) 「ぼくに任せて・・・」
- 結果：A/B/Cが表示される（モックでも可）
- タップでコピーできる

---

### TC-E2E-05 followup（不足時）→ 選択 → settings反映
**Given**
- サーバがfollowupを返す状況（relationship_type欠け等）

**When**
- followupの選択肢を選ぶ→再生成

**Then**
- 質問は1つだけ
- 選択が `/me/settings` に反映される
- 再生成はユーザー操作で行う（自動再送しない）

---

### TC-E2E-06 Free回数制限（3回/日）
**Given**
- Freeプラン
- 当日3回成功済み（残0）

**When**
- 4回目の生成を試みる

**Then**
- サーバが拒否（statusはbackend_spec準拠）
- フロントは壊れず、説明とアップセル導線を出す（押し付けない）

---

### TC-E2E-07 Pro回数制限（100回/日）
**Given**
- Proプラン
- 当日100回成功済み

**When**
- 101回目の生成

**Then**
- サーバが拒否
- フロントは壊れない

---

### TC-E2E-08 Pro専用コンボの制御
**Given**
- Freeプラン

**When**
- コンボ2/3/4/5を選ぶ

**Then**
- 生成は実行されない
- 「有料版のみ」案内（アップセル）が出る
- 元に戻れる（UIロックが残らない）

---

### TC-E2E-09 NG（禁止フレーズ適用）
**Given**
- settings.ng_free_phrases に短い禁止フレーズを設定済み

**When**
- 生成

**Then**
- 返信案に禁止フレーズがそのまま含まれない
- 重大NGはSTOP（次）

---

### TC-E2E-10 NG（STOP）
**Given**
- 入力に危険内容のダミーを含める（自傷他害等）

**When**
- 生成

**Then**
- 返信案は出ず、STOP扱いのエラー
- UIは回復し、ユーザーが戻れる
- 本文をログに出さない

---

### TC-E2E-11 本文ゼロ監査（端末）
**Given**
- 上のテストを一通り実施

**When**
- 端末ストレージ/ログを確認

**Then**
- `.txt`本文や返信案本文が永続領域に残っていない
- debugログ/クラッシュログに本文が出ていない

---

### TC-E2E-12 本文ゼロ監査（サーバ）
**Given**
- テスト実施後

**When**
- サーバのDB/ログを確認

**Then**
- txt本文/返信案本文が永続化されていない
- ログにも本文が出ていない（エラーコードとrequest_id中心）

---

### TC-E2E-13 テレメトリ（時間帯バケットのみ）
**Given**
- telemetry実装がある

**When**
- 生成成功/コピー等でイベント送信

**Then**
- 本文/生成文は送られていない
- hour_bucket_utc/dow_utcがサーバで付与されている

---

## 5. 実行チェックリスト（MUST）
- [ ] Androidで共有受信OK
- [ ] iOSで共有受信OK
- [ ] 貼り付け欄なし
- [ ] 演出（ピンク→黒、固定セリフ2文）
- [ ] A/B/C 3案表示・コピー
- [ ] followup 1問→設定反映
- [ ] Free 3/日、Pro 100/日
- [ ] NG（禁止/STOP）
- [ ] 端末/サーバ：本文ゼロ
- [ ] テレメトリ：本文ゼロ＋時間帯バケット

---

## 6. 未確定 / 確認事項（最大3点）
1) /generate の上限超過ステータス（429/403）の確定（backend側と揃える）。  
2) iOS共有受信の実装方式（Share ExtensionのApp Group参照情報のみで成立するか）の確定。  
3) テレメトリ送信APIの有無とエンドポイント名の確定。  
