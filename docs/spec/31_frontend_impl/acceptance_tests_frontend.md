# docs/spec/31_frontend_impl/acceptance_tests_frontend.md — Frontend受け入れテスト（MUST）
**Last Updated (JST):** 2026-03-03 10:35:00 +0900

> 目的：Flutter実装が **仕様どおり**であることを、手戻りなく検証するための受け入れ基準。  
> 本文（LINE履歴txt・生成文）を端末に保存しない制約が最優先。UIでも本文を永続化しない。

---

## 0. 前提（MUST）
- 参照起点：`docs/ssot/SSOT.md`
- 中核仕様：`docs/spec/10_product/product_spec.md`
- 世界観：`docs/spec/00_world/world_concept.md`
- 運用/禁止：`docs/spec/01_rules/project_rules.md`
- プライバシー/ログ：`docs/spec/01_rules/privacy_logging.md`
- フロント設計：`docs/spec/30_frontend/frontend_spec.md`
- フロント実装規約：`docs/spec/01_rules/engineering_conventions.md`
- テスト方針：`docs/spec/90_tests/test_strategy.md`

---

## 1. テスト環境（MUST）
- 実行者：開発者（ちょび）
- 端末：Android実機 + iPhone実機（共有受信の差異があるため）
- 共有受信：LINEから `.txt` を共有 → Permyで受け取れること（貼り付け欄は存在しない）

---

## 2. 画面と導線（受け入れ対象 / MUST）
最低限、以下の導線が通ること。

1) 初回起動 → 匿名開始（バックエンドtoken取得）  
2) チュートリアル（txt送信手順） → 最後のボタン文言「ペルミィを変える」  
3) txt受領 → 生成画面へ遷移（貼り付け欄なし）  
4) 生成演出（ピンク→黒反転＋セリフ）  
5) 結果画面：A/B/C 3案表示 → タップでコピー  
6) followup（不足時の聞き返し）が表示され、選択で設定更新と返信案更新ができる  
7) Free回数制限/Proアップセルが正しく動く  
8) 設定（/me/settings）同期が壊れない（ただし登録画面は作らない）

---

## 3. 受け入れ基準（共通 / MUST）
### 3.1 本文ゼロ（最重要）
- 端末の永続領域に以下を保存しない（例：SharedPreferences/ファイル/DB）：
  - LINE履歴txt本文
  - 生成した返信案本文
- 端末ログ（debug/analytics/クラッシュログ）に本文を出さない。

### 3.2 入力導線固定
- 貼り付け欄・手入力欄は存在しない（UI上に出さない）。

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
- tokenは安全なストレージに保存してよい（本文ではない）
- 画面はエラーで止まらず、チュートリアル or ホームへ遷移

---

### TC-FE-02 チュートリアル導線（txt送信手順）
**Given**
- 初回導線

**When**
- チュートリアルを最後まで進める

**Then**
- 手順が「LINEのトーク履歴送信→.txtをPermyへ共有」に固定されている
- 最後のボタン文言は **「ペルミィを変える」**
- チュートリアルに貼り付け欄誘導がない

---

### TC-FE-03 共有受信（Android）— .txtを受け取れる
**Given**
- Android実機
- LINEのトーク履歴をエクスポート済み（ダミー）

**When**
- LINEから共有 → Permyを選択

**Then**
- Permyが `.txt` を受け取る
- 受け取ったファイル名が画面に表示される（本文は表示しないか、折りたたみ）
- アプリがクラッシュしない

---

### TC-FE-04 共有受信（iOS）— .txtを受け取れる
**Given**
- iPhone実機
- LINEのトーク履歴をエクスポート済み（ダミー）

**When**
- 共有シートからPermyへ渡す

**Then**
- `.txt` を受け取る
- 共有受信の実装が「Share Extension/Share Intent ラッパー」で成立
- アプリがクラッシュしない

---

### TC-FE-05 貼り付け欄が存在しない
**Given**
- 主要画面を確認

**When**
- 返信生成画面/ホーム/設定を探す

**Then**
- テキスト貼り付け/手入力の入力欄が存在しない

---

### TC-FE-06 生成画面の演出（世界観）
**Given**
- `.txt` 受領済み

**When**
- 生成ボタンを押す

**Then**
- 背景が **淡いピンク → 黒** に反転する（生成中）
- セリフが順に表示される：
  1) 「ぼくはきみの分身・・・」
  2) 「ぼくに任せて・・・」
- 生成完了後、結果画面に遷移（演出は邪魔にならない長さ）

---

### TC-FE-07 結果画面（A/B/C 3案）
**Given**
- 生成成功

**When**
- 結果画面を表示

**Then**
- A/B/C の3カードが常に表示される
- 省略表示禁止（maxLines固定で途中が隠れない。スクロールで全文を読める）
- タップでコピー（ボタン増やさない）
- コピー成功：トースト + 0.4秒ハイライト

---

### TC-FE-08 followup（不足時の聞き返し）
**Given**
- サーバが followup を返した

**When**
- 画面に followup を表示し、選択肢を選ぶ

**Then**
- followupの質問が1つだけ表示される
- 選択肢は 1..3
- 選択後、settingsが更新される（ローカルスナップショット + `/me/settings`）
- 選択後、同じ共有履歴で自動再生成され、A/B/C が更新される

---

### TC-FE-09 Free回数制限（3回/日）
**Given**
- Freeプラン
- 当日3回使用済み（残0）

**When**
- 4回目の生成を試みる

**Then**
- 生成を実行しない or サーバエラーを受けてUIで説明
- 「有料版で回数が増える」導線を表示（押し付けない）
- UIが壊れず、ユーザー操作で戻れる

---

### TC-FE-10 Pro専用機能の表示と制御
**Given**
- Freeプラン

**When**
- コンボ 2/3/4/5 を選ぶ、または Pro専用表示をタップ

**Then**
- 実行はできない
- 「有料版のみ」案内（アップセル）を表示
- Freeの生成ボタンを勝手に無効化し続けない（戻れる）

---

### TC-FE-11 settings同期（永続化最小）
**Given**
- settingsを更新した

**When**
- アプリ再起動 / 画面遷移

**Then**
- settingsは復元される（settings_jsonのみ）
- txt本文/生成本文は復元されない（保存されていないため）

---

### TC-FE-12 ログ/クラッシュ時に本文が出ない
**Given**
- 意図的にAPI失敗を起こす（ネットワーク断など）

**When**
- エラーが発生

**Then**
- 画面には error_code/要約のみ
- debugログ/クラッシュログに txt本文/返信本文が出ない
- 生成画面ではエラーを **メッセージボックス** で表示し、`error_code` を明示する

---

### TC-FE-16 生成失敗時のエラーコード表示
**Given**
- `.txt` の共有受信は完了している
- `POST /api/v1/generate` が `4xx/5xx` を返す

**When**
- 返信案生成ボタンを押す

**Then**
- 画面下の小さな文言ではなく、メッセージボックスが表示される
- メッセージボックス内に `error_code` が表示される
- ユーザー向け要約メッセージと詳細メッセージが表示される

---

### TC-FE-13 Settings → 再診断導線
**Given**
- Settings 画面が表示されている
- 既にペルソナが診断済み

**When**
- 「ペルソナ再診断」セクションの「再診断する」ボタンをタップ

**Then**
- DiagnosisScreen（7問）が表示される
- ユーザーが全問回答して完了
- 自動的に Settings に戻る
- 「再診断を反映しました」SnackBar が表示される
- ペルソナ属性値が新しい診断結果で更新されている

---

### TC-FE-14 Settings → 診断結果詳細表示（PersonaDiagnosisResultScreen）
**Given**
- Settings 画面が表示されている
- ペルソナが診断済み（「普段の属性」「夜の属性」に値がある）

**When**
- ペルソナ情報エリア（背景が淡青のカード）をタップ

**Then**
- PersonaDiagnosisResultScreen が表示される
- 以下が表示される：
  1) 「普段の自分」セクション：True Self タイプと説明文
  2) 「夜の私」セクション：Night Self タイプと説明文
  3) 「ペルソナパラメータ」セクション：主張度/温かみ/リスク回避（LinearProgressIndicator付き）
- 画面をスクロールして全内容が見える
- BackボタンまたはAppBar戻るで Settings に復帰

---

### TC-FE-15 Settings → 端末移行・About 遷移確認
**Given**
- Settings 画面が表示されている

**When**
- 「サポート・規約・その他設定」アコーディオンを開き、「端末移行の設定」リンクをタップ

**Then**
- MigrationScreen が表示される

**When**
- Settings に戻って同じアコーディオン内の「このアプリについて」リンクをタップ

**Then**
- AboutPrivacyScreen が表示される
- プライバシー説明、連絡先情報が表示される

---

## 6. 目視チェック（MUST）
- iPhoneのSafe Area（ノッチ/ホームインジケータ）と被らない
- Androidのナビバー/キーボードと被らない
- 長文のカードが崩れない（スクロール成立）

---

## 6.1 画面遷移の回帰チェック（追加運用 / MUST）
- 画面遷移は「実装済み」だけで完了扱いにしない。
- 各導線に対してウィジェットテストを追加し、最低でも以下を毎回確認する（対応 TC：TC-FE-13〜TC-FE-15）：
  - Settings → 再診断（TC-FE-13）
  - Settings → 端末移行（TC-FE-15）
  - Settings → About/Privacy（TC-FE-15）
  - Settings → 診断結果詳細（TC-FE-14）
- 同一ラベルが複数ある画面は、`findsOneWidget` に固定せず `Key` または画面種別 (`find.byType`) で検証する。

---

## 6.2 E2Eの運用分離（追加運用 / MUST）
- E2Eはバックエンド接続・認証状態に依存するため、通常の回帰（ユニット/ウィジェット）と分離する。
- 日常の回帰確認は「E2E除外」で実行し、E2Eは環境準備完了時のみ個別実行する。

---

## 7. 合格条件（MUST）
- TC-FE-01〜TC-FE-15 がすべて満たされる
- 本文ゼロ（保存/ログ/テレメトリ）の制約を破っていない
- Settings の再診断 → 自動リロード → SnackBar が正常に機能している
- PersonaDiagnosisResultScreen が読み取り専用で表示される

---

## 8. 未確定 / 確認事項（最大3点）
1) `淡いピンク/黒` のHexを world_concept 側で固定するか（UI調整で必要）。  
2) iOS共有受信（Share Extension）をMVPで必須にする前提は採用済みだが、実装方式（Extension or URL scheme）をfrontend_implで確定する必要がある。  
3) 結果画面の「根拠（トーク履歴）折りたたみ表示」のUI詳細（どこまで見せるか）をfrontend_specで確定する必要がある。  
