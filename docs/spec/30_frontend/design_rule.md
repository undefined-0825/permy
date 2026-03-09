# 📱 アプリ名：ペルミィ (Permy) - デザイン基本設計定義書

## 1. デザインコンセプト： "Modern Seamless & Breathable"
ペルミィは女性が使うので、使いにくいと判断したらすぐ離脱する可能性が高い。
最大減にユーザビリティと売れるデザインを意識して画面を作成すること。
余白を「情報の区切り」として機能させ、コンテンツが浮いているような軽やかさを提供する。

---

## 2. レイアウト構造 (Layout Specification)

### 2.1 画面基本構成
* **背景色:** 淡いピンク系グラデーション（`#E8D4F8` → `#FCE4EC`）+ 背景画像オーバーレイ（診断画面等）
* **デザイン意図（world_concept 参照）:** 淡いピンクでユーザーの緊張を和らげ、安心感を提供。過剰な可愛さを避け、信頼感と機能性のバランスを重視。
* **サイドマージン:** `16pt` (現行実装、カード型でないため呼吸感を確保)
* **セパレーター:** 要素間の境界線は原則引かない。
  * 必要な場合は `#E5E7EB` の `0.5pt` 極細ラインを、サイドマージン分インセットして配置。

### 2.2 ヘッダー設計
* **スタイル:** ラージタイトル・プロトコル
* **フォント:** `28pt / Bold`（スクロール開始で `17pt / Semi-bold` へアニメーション）
* **インタラクション:** 背景はブラー（透過）させ、コンテンツがヘッダーの下を潜り込む表現。

---

## 3. カラーパレット定義 (Color Palette)

### 3.1 背景色
* **通常時背景:** 淡いピンク系グラデーション
  * グラデーション開始色: `#E8D4F8` (淡いパープル)
  * グラデーション終了色: `#FCE4EC` (淡いピンク)
* **生成時背景:** `#000000` (黒) ※反転演出用、将来実装

### 3.2 アクセントカラー（ボタン・選択状態）
* **プライマリピンク:** `#FFB3C1` — ボタン背景、ハイライト用
* **セカンダリピンク:** `#FF69B4` — 選択ボーダー、チェックマーク
* **淡ピンク:** `Colors.pink.shade50` (Flutter) — プレースホルダー背景

### 3.3 テキストカラー（design_rule.md 準拠）
| 役割 | 色コード | 用途 |
| :--- | :--- | :--- |
| **プライマリタイトル** | `#1A1C1E` | 画面タイトル、セクション見出し |
| **本文 / メイン項目** | `#374151` | 通常テキスト、リスト項目 |
| **メタ情報 / 補助** | `#6B7280` | 副次的情報、説明文 |
| **エラー** | `Colors.red` (Flutter) | エラーメッセージ |
| **ボタン上テキスト** | `#FFFFFF` | ボタンラベル |
| **無効化状態** | `Colors.grey.shade300` | 非活性コントロール |

### 3.4 適用ルール
* 診断画面・生成画面・Settings等、全画面で統一使用。
* 将来的に `lib/core/theme.dart` で ThemeData 定義予定（現在は各Widget内でハードコード）。
* Material Design 3 準拠、ColorScheme 活用を推奨。

---

## 4. タイポグラフィ定義 (Typography)
カードの枠がない分、フォントのサイズと色で階層（Hierarchy）を明確にする。

| 役割 | サイズ | 太さ | 色 | 行間 |
| :--- | :--- | :--- | :--- | :--- |
| **プライマリタイトル** | 18pt | Bold | `#1A1C1E` | 1.4 |
| **本文 / メイン項目** | 15pt | Regular | `#374151` | 1.6 |
| **メタ情報 / 補助** | 13pt | Medium | `#6B7280` | 1.4 |
| **アクセント数値** | 20pt | Semi-bold | `#FFB3C1` (プライマリピンク) | 1.2 |

---

## 5. UIコンポーネント定義 (Non-Card Style)

### 5.1 リストアイテム
* **高さ:** `72pt` (標準)
* **構造:** アイコン(40pt) + テキスト(Title/Subtitle) + アクション(Chevron等)
* **タップフィードバック:** セル全体が `#F3F4F6` に一瞬変化 ＋ `Light Haptic`

### 5.2 インプット・アクション
* **入力フィールド:** 下線(Underline)スタイル。フォーカス時にアクセントカラー（`#FFB3C1`プライマリピンク）の `2pt` ラインに変化。
* **フローティングアクション:** 画面右下に `64x64pt` の正円ボタン。
* **プライマリボタン:** 
  * 角丸 `12pt`
  * 背景色: `#FFB3C1` (プライマリピンク)
  * テキスト色: `#FFFFFF` (白)
  * 微細なグラデーションと `Inner Glow` を推奨（洗練感向上）
  * 無効化時: `#E6DCE8` (淡いグレイピンク)

---

## Copilot への実装指示プロンプト (System Instructions)

```text
Project Name: ペルミィ (Permy)
Target: Cross-platform (iOS/Android)
UI Style: Edge-less Flat (Non-Card based) with Soft Pink Gradient Background

[Implementation Rules]
1. Grid: Use 8pt base grid. Side margins = 16pt.
2. Card-less: Avoid using card containers or drop shadows. Use whitespace and typography weights for information hierarchy.
3. Background: Gradient (#E8D4F8 to #FCE4EC) with optional overlay image. Keep pink theme for warmth and trust.
4. Header: Implement a Large Title (28pt Bold) that shrinks to 17pt Semi-bold on scroll.
5. List Item: Fixed height 72pt, with optional 0.5pt inset separator (#E5E7EB).
6. Typography: 
   - Primary Title: 18pt Bold, #1A1C1E
   - Main Body: 15pt Regular, #374151, Leading 1.6
   - Meta Info: 13pt Medium, #6B7280
   - Accent Numbers: 20pt Semi-bold, #FFB3C1 (Primary Pink)
7. Buttons: 
   - Border Radius: 12pt
   - Primary: Background #FFB3C1 (Pink), Text #FFFFFF, with subtle gradient + Inner Glow
   - Disabled: Background #E6DCE8
8. Haptics: Trigger 'selection' feedback on list tap, and 'success' on primary action buttons.
9. System Fonts: SF Pro (iOS) / Hiragino (Japanese) / Noto Sans (Android)