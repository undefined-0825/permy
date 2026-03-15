# Permy Generate UI Instructions

applyTo: frontend/lib/src/presentation/**/*generate*.dart

## 画面目的
ユーザーが3秒以内に「生成する」を押せること。
Generate画面はPermyの最重要導線。

ユーザーが理解すべき3点
1. 今の生成設定
2. 生成ボタン
3. 生成結果

## 必須UIルール
Permy Design Systemに従う。

必ず使用:
- AppScaffold
- AppSectionHeader
- AppButton
- AppSpacing
- AppRadius
- AppTextStyles
- AppColors

禁止:
- 色の直値
- 余白の直値
- BorderRadiusの直値
- TextStyle直書き

## UXルール
Generate画面では以下を優先する。

1. 主CTA（生成ボタン）を最も目立たせる
2. 情報ブロックは最大4つ
3. 余白を増やして読みやすくする
4. 不要な説明文は削減
5. 生成結果エリアの視認性を高くする

## レイアウト構成
画面は以下の順序で構成する。

1. ペルソナ情報
2. 生成設定
3. Generateボタン
4. 生成結果

主CTAは画面中央〜下部。

## 作業手順
1. 現状の問題点を5件以内で列挙
2. 最小差分で改善
3. 修正後UIの自己レビューを書く

## レビュー基準
以下の5点で評価する。

- hierarchy clarity
- whitespace consistency
- CTA visibility
- component consistency
- cognitive load

## 注意
新しい装飾を増やすよりも、
情報整理・余白整理・CTA強調を優先する。

既存ロジックは壊さない。
flutter analyze が通ること。
