# Permy Design System Spec

Project: ペルミィ (Permy) Purpose:
売れるUXと高いユーザビリティを両立し、AI（Copilot等）でも解釈可能なUI設計を定義する。

## Spec参照順（MUST）
1. `docs/spec/00_world/world_concept.md`
2. `docs/spec/10_product/product_spec.md`
3. `docs/spec/40_design/permy_design_system_spec.md`
4. `docs/spec/30_frontend/frontend_spec.md`
5. `docs/spec/31_frontend_impl/frontend_impl.md`

## 運用方針（MUST）
- 今後のUI設計・実装の洗練は、本Spec（`permy_design_system_spec.md`）を唯一のベースとして進める。
- 画面ごとの個別判断でデザインルールを増やさず、必要な変更は本Specへ集約してから反映する。

------------------------------------------------------------------------

# 1. Design Philosophy

## 1.1 Design Goal

PermyのUIは以下を満たす。

-   迷わない
-   すぐ使える
-   安心感がある
-   疲れない

夜職ユーザーはストレス状態でアプリを使う可能性があるため、UIは思考コストを最小化する。

------------------------------------------------------------------------

## 1.2 売れるアプリの共通パターン

人気アプリ（Instagram / LINE / TikTok / Uber / Airbnb
等）に共通する構造。

1画面に存在する要素

Header Main Action Secondary Info Optional Options Footer

最大5ブロックを超えない。

------------------------------------------------------------------------

## 1.3 売れるUIの基本原則

### 原則1

1画面1目的

例 Generate Screen 目的：返信生成

### 原則2

Primary CTAは1つ

### 原則3

視線誘導

上 → 中央 → Primary Action

### 原則4

余白は情報

------------------------------------------------------------------------

# 2. Layout Rules

## 2.1 Grid System

8pt grid

## 2.2 Spacing Tokens

xs = 4pt sm = 8pt md = 16pt lg = 24pt xl = 32pt xxl = 48pt

使用ルール

要素内部余白 = sm コンポーネント間 = md セクション区切り = lg 画面余白 =
md

------------------------------------------------------------------------

## 2.3 Side Margin

16pt

------------------------------------------------------------------------

## 2.4 Vertical Rhythm

コンポーネント間は一定リズムで配置する。

------------------------------------------------------------------------

# 3. Color System

## 3.1 Emotional Design

Permyの色は

安心 柔らかさ 信頼

を作る。

------------------------------------------------------------------------

## 3.2 Background

通常 Gradient #E8D4F8 → #FCE4EC

生成時 #000000

------------------------------------------------------------------------

## 3.3 Accent Color

Primary #FFB3C1

Secondary #FF69B4

------------------------------------------------------------------------

## 3.4 Text Colors

Primary Title: #1A1C1E Body: #374151 Meta: #6B7280

------------------------------------------------------------------------

## 3.5 Color Usage Rules

Accent colorは以下のみ使用

-   Primary Button
-   Selected State
-   Accent Numbers

本文には使用しない。

------------------------------------------------------------------------

# 4. Typography

Font SF Pro / Hiragino / Noto Sans

Title: 18pt Bold Body: 15pt Regular Meta: 13pt Medium Accent: 20pt
SemiBold

1画面のフォント階層は最大3段。

------------------------------------------------------------------------

# 5. Component System

## Border Radius

sm = 8 md = 12 lg = 16

------------------------------------------------------------------------

## List Item

Height 72 Icon 40

Structure

Icon Title Subtitle Action

------------------------------------------------------------------------

## Primary Button

Height 48 Radius 12 Color #FFB3C1 Text White

------------------------------------------------------------------------

## Floating Action Button

64 x 64 Circle Right bottom

------------------------------------------------------------------------

# 6. Screen Design Rules

## Screen Block Limit

1画面 最大5ブロック

例

Header Content Options Primary Action Footer

------------------------------------------------------------------------

## Screen Goal

各画面は1行の目的を持つ

例

Generate Screen 最短で返信生成

------------------------------------------------------------------------

# 7. Interaction Rules

Tap Feedback Light Haptic

Selection Pink border

Animation 150ms〜250ms

------------------------------------------------------------------------

# 8. UX Rules

## Decision Count

1画面での意思決定数 ≤ 3

------------------------------------------------------------------------

## Input Reduction

入力より選択を優先

------------------------------------------------------------------------

## Error Recovery

エラー表示は

原因 ↓ 解決

------------------------------------------------------------------------

# 9. Visual Balance Rules

Balance

色 余白 情報量

------------------------------------------------------------------------

Density

中密度

------------------------------------------------------------------------

Visual Weight

サイズ 色 位置

で重要度を表現

------------------------------------------------------------------------

# 10. Design Consistency

Permyはアプリ全体で統一する。

禁止

-   画面ごとに違うUI
-   違う余白
-   違うフォント
-   違うボタン

------------------------------------------------------------------------

# 11. AI Implementation Rules

Layout

8pt grid Side margin 16

Typography

Title 18 Body 15 Meta 13

Button

Radius 12 Pink background

Screen Rule

Max 5 blocks Primary CTA = 1

------------------------------------------------------------------------

# 12. AI Self Review

UI生成後

以下をチェック

1 hierarchy 2 whitespace 3 CTA visibility 4 component consistency 5
spacing tokens

Total score \< 80 → layout refactor

------------------------------------------------------------------------

# 13. UI Review Engine

UI Quality Score

Hierarchy 20 Whitespace 20 CTA Visibility 20 Consistency 20 Cognitive
Load 20

------------------------------------------------------------------------

## Hierarchy

主要情報は3段以内

------------------------------------------------------------------------

## Whitespace

Spacing tokenのみ使用

------------------------------------------------------------------------

## CTA Visibility

Primary CTAが最も目立つ

------------------------------------------------------------------------

## Consistency

同種コンポーネントは統一

------------------------------------------------------------------------

## Cognitive Load

1画面意思決定 ≤ 3

------------------------------------------------------------------------

# 14. Decision Time Rule

ユーザーは

3秒以内に次の行動を理解できる

------------------------------------------------------------------------

# 15. Visual Gravity

視線

上 → 中央 → 下

CTAは中央〜下に配置

------------------------------------------------------------------------

# 16. UI Density

Permyは低〜中密度UI

------------------------------------------------------------------------

# 17. Screenshot Review Loop

UI生成 ↓ スクリーンショット取得 ↓ AIレビュー ↓ 修正