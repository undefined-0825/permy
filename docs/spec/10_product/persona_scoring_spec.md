# persona_scoring_spec.md — ペルソナ診断スコアリング仕様（7問固定 / 生成パラメータ連携）

**Scope:** 本書は、ペルソナ診断の設問・重み・最終判定アルゴリズム・生成パラメータへの変換を固定する。  
設問文言の微修正は許可するが、**設問ID / 選択肢ID / 重み / 判定ロジック**は本書を正とする。

---

## 0. 前提（MUST）
- 本診断は導入部として **7問固定**（True 2問 + Night 5問）
- 回答方式は単一選択（1問ごとに1回答）
- 選択肢数は3〜5択
- 本文（会話履歴/生成文）は扱わない
- 診断結果は `/me/settings` に上書き保存し、履歴は保持しない

---

## 1. タイプ軸（再掲）
### 1.1 本当の私（TrueSelfType）
- `Stability`（安定重視タイプ）
- `Independence`（自立タイプ）
- `Approval`（承認欲求タイプ）
- `Realism`（現実派タイプ）
- `Romance`（ロマンタイプ）

### 1.2 夜の私（NightSelfType）
- `VisitPush`（来店重視タイプ）
- `Heal`（癒し系タイプ）
- `LittleDevil`（小悪魔系タイプ）
- `BigClient`（太客育成タイプ）
- `Balance`（バランスタイプ）

---

## 2. 設問定義（7問固定 / MUST）
> 文言はUI copybookに合わせて軽微修正可。IDと選択肢IDは固定。

### 2.1 True（2問）
#### Q1 `true_priority`
**設問文:** 「普段いちばん大切にしているもの？」
- A `life_balance`（ライフバランス）
- B `future_stability`（将来の安定）
- C `partner_time`（パートナーとの時間）
- D `social_trust`（周りの人からの評価・信頼）
- E `self_autonomy`（自分の価値観・自由）

#### Q2 `true_decision_axis`
**設問文:** 「迷った時はどうする？」
- A `low_stress`（無理が少ない方にする）
- B `long_term_return`（長期的に得な方にする）
- C `emotional_satisfaction`（気持ちが満たされる方にする）
- D `pace_control`（自分のペースを守れる方にする）

### 2.2 Night（5問）
#### Q3 `night_goal_primary`
**設問文:** 「夜職のLINE返信で一番達成したいことは？」
- A `next_visit`（次回来店の約束）
- B `relationship_keep`（お客様との関係を維持する）
- C `special_distance`（特別感を出して距離を縮める）
- D `long_term_growth`（長期で太く育成したい）

#### Q4 `night_temperature`
**設問文:** 「返信の温度感は？」
- A `calm_safe`（安心感を重視する）
- B `sweet_light`（軽く甘めに攻めてみる）
- C `clear_proposal`（自分の考えをはっきり伝える）
- D `adaptive`（相手に合わせる）

#### Q5 `night_game_tolerance`
**設問文:** 「お客様との駆け引きは？」
- A `avoid_game`（ほぼ使わない）
- B `light_game`（少しなら使う）
- C `adaptive_game`（状況次第で使う）
- D `active_game`（積極的に使う）

#### Q6 `night_customer_allocation`
**設問文:** 「お客様との関係をどうしたい？」
- A `wide_touchpoints`（幅広く接点を増やす）
- B `care_existing`（今ある関係を丁寧に維持したい）
- C `focus_key_clients`（重要なお客を大切にする）
- D `dynamic_balance`（状況で配分を切り替える）

#### Q7 `night_risk_response`
**設問文:** 「お客様とトラブル。どうする？」
- A `firefighting_safe`（まずは火消しして安全を確保）
- B `soft_distance`（柔らかく距離を保つ）
- C `recover_initiative`（主導権を握って解決）
- D `adaptive_landing`（相手に合わせて様子を見る）

---

## 3. 重みテーブル（MUST）
> 各選択肢ごとに加点する。未回答は0点。

### 3.1 True重み
| Question | Choice | Stability | Independence | Approval | Realism | Romance |
|---|---|---:|---:|---:|---:|---:|
| Q1 | life_balance | 3 | 1 | 0 | 1 | 0 |
| Q1 | future_stability | 2 | 1 | 0 | 3 | 0 |
| Q1 | partner_time | 1 | 0 | 1 | 0 | 3 |
| Q1 | social_trust | 0 | 0 | 3 | 1 | 1 |
| Q1 | self_autonomy | 1 | 3 | 0 | 1 | 0 |
| Q2 | low_stress | 3 | 1 | 0 | 2 | 0 |
| Q2 | long_term_return | 1 | 1 | 0 | 3 | 0 |
| Q2 | emotional_satisfaction | 0 | 0 | 2 | 0 | 3 |
| Q2 | pace_control | 1 | 3 | 0 | 1 | 0 |

### 3.2 Night重み
| Question | Choice | VisitPush | Heal | LittleDevil | BigClient | Balance |
|---|---|---:|---:|---:|---:|---:|
| Q3 | next_visit | 3 | 0 | 1 | 2 | 1 |
| Q3 | relationship_keep | 1 | 3 | 0 | 1 | 2 |
| Q3 | special_distance | 1 | 0 | 3 | 1 | 1 |
| Q3 | long_term_growth | 1 | 1 | 0 | 3 | 2 |
| Q4 | calm_safe | 0 | 3 | 0 | 1 | 2 |
| Q4 | sweet_light | 1 | 1 | 3 | 0 | 1 |
| Q4 | clear_proposal | 3 | 0 | 1 | 2 | 1 |
| Q4 | adaptive | 1 | 2 | 1 | 2 | 3 |
| Q5 | avoid_game | 0 | 3 | 0 | 2 | 2 |
| Q5 | light_game | 1 | 1 | 2 | 1 | 3 |
| Q5 | adaptive_game | 2 | 1 | 2 | 2 | 3 |
| Q5 | active_game | 2 | 0 | 3 | 1 | 1 |
| Q6 | wide_touchpoints | 3 | 1 | 1 | 1 | 1 |
| Q6 | care_existing | 1 | 3 | 0 | 2 | 2 |
| Q6 | focus_key_clients | 1 | 0 | 1 | 3 | 1 |
| Q6 | dynamic_balance | 1 | 2 | 1 | 2 | 3 |
| Q7 | firefighting_safe | 1 | 2 | 0 | 2 | 3 |
| Q7 | soft_distance | 0 | 3 | 0 | 1 | 2 |
| Q7 | recover_initiative | 3 | 0 | 2 | 1 | 1 |
| Q7 | adaptive_landing | 1 | 2 | 1 | 2 | 3 |

---

## 4. 最終判定アルゴリズム（MUST）
### 4.1 集計
1) Q1〜Q2でTrue5タイプを加点集計  
2) Q3〜Q7でNight5タイプを加点集計

### 4.2 型判定
- `true_self_type`: Trueスコア最大タイプ
- `night_self_type`: Nightスコア最大タイプ

### 4.3 同点処理（固定）
- True同点優先順: `Stability > Realism > Independence > Approval > Romance`
- Night同点優先順: `Balance > BigClient > VisitPush > Heal > LittleDevil`

### 4.4 信頼度（任意）
- `persona_confidence = top1_score - top2_score`
- 0〜1は「暫定判定」として扱ってよい

---

## 5. 生成向け派生パラメータ（MUST）
診断完了時に以下を算出し `settings_json` に保持する。

- `persona_goal_primary: string`
  - `next_visit | relationship_keep | long_term_growth | firefighting | special_distance`
- `persona_goal_secondary: string | null`
- `style_assertiveness: int`（0..100）
- `style_warmth: int`（0..100）
- `style_risk_guard: int`（0..100）

### 5.1 算出規則
- `persona_goal_primary`
  - Q3を主キーに決定
  - ただしQ7が`firefighting_safe`で、かつNightの`Balance`または`Heal`が1位なら `firefighting` を優先
- `persona_goal_secondary`
  - Nightスコア2位タイプ由来の目的語を設定（未差異ならnull）
- `style_assertiveness`
  - `VisitPush` と `LittleDevil` の合計を0..100へ線形正規化
- `style_warmth`
  - `Heal` と `Balance` の合計を0..100へ線形正規化
- `style_risk_guard`
  - `Balance` + Q7の安全系回答ボーナスで0..100へ正規化

---

## 6. API連携（MUST）
### 6.1 診断入力
- `POST /api/v1/me/diagnosis`（新設）
  - request: `answers`（Q1..Q7のchoice_id配列）
  - response: `true_self_type`, `night_self_type`, 派生パラメータ

### 6.2 設定保存
- サーバは診断結果を `settings_json` に反映
- 反映時は `settings_schema_version` と `persona_version` を更新

---

## 7. バージョン管理（MUST）
- 本仕様バージョンキー: `persona_version`
- 初版: `persona_version = 3`
- 設問/重み/同点規則の変更は `persona_version` をインクリメント

---

## 8. 受け入れ基準（MUST）
- 7問すべて回答で判定が一意に決まる
- 同一回答集合は常に同一タイプへ決定される
- 診断結果と派生パラメータが `/generate` の出力傾向に反映される
- 本文/生成文を診断過程で保存しない
