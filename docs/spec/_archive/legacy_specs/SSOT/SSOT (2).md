# SSOT.md（参照点固定）
**Last Updated (JST):** 2026-03-01 19:05:00 +0900

## 1. 参照順（厳守）
1. `spec_rule_v20.md`
2. `spec_product_v17.md`
3. `spec_backend_v8.md`
4. `spec_backend_impl_v10.md`
5. `spec_frontend_v8.md`
6. `spec_frontend_impl_v9.md`

## 2. 運用ルール（最小）
- 仕様が衝突した場合、上位のSSOTが常に優先。
- 実装・レビュー・Copilot投入前に、必ずこのSSOT.mdから最新ファイルを開いて開始する（取り違え防止）。
- Specは上書き禁止。更新は新しいversionファイルを作成する。

## 3. 不変要件（抜粋）
- 自動送信なし（提案のみ）
- 会話本文（入力/履歴/生成）をサーバ・端末に保存しない
- 夜職特化（ビジネス等は別アプリ展開）
---

## 4. 旧Specファイル名の扱い（MUST）
本プロジェクトでは、過去に以下の命名でSpecが存在したが、**現行SSOTでは使用しない**（参照禁止）。

- `spec_serverside_v*.md`
- `spec_serverside_dev_v*.md`
- `spec_serverside_impl_dev_v*.md`
- `spec_v*.md`（旧プロダクトSpec）

参照は本SSOT.mdの「参照順」に列挙したファイルのみを正とする。
（Copilot投入・レビュー・実装開始時は必ず本ファイルから開くこと）
**Updated (JST):** 2026-03-01 19:25:00 +0900
