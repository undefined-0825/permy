# docs/ssot/SSOT.md（参照点固定 / 入口）

**Last Updated (JST):** 2026-03-01 20:20:00 +0900

---

## 1. SSOT（参照優先順位）とファイル命名（MUST）

1. **最新の運用ルール**: `spec_rule_v{N}.md`（N最大が最新） ※最優先
2. **最新のプロダクトSpec**: `spec_product_v{N}.md`
3. **サーバサイド設計Spec**: `spec_backend_v{N}.md`
4. **サーバサイド実装Spec**: `spec_backend_impl_v{N}.md`
5. **フロントエンド設計Spec**: `spec_frontend_v{N}.md`
6. **フロントエンド実装Spec**: `spec_frontend_impl_v{N}.md`

- **Version運用**: 1ずつ加算（飛び番・上書き厳禁）。ファイル名の最大値を最新と見なす。
- **入口の固定**: `docs/ssot/SSOT.md` を起点としてプロジェクトの現在地を確認する。
  - 設計段階で `docs/ssot/SSOT.md` が存在しない場合は `spec_rule_v{N}.md` の最新を入口とする。

---

## 2. “最新版”の解決方法（MUST）

このSSOTは **特定のversion番号を固定しない**。最新版の決定は次のルールで行う。

- 例: `spec_backend_impl_v1.md`, `spec_backend_impl_v2.md` ... が存在する場合、
  **vが最大のファイルが最新版**。
- 参照・実装・Copilot投入前に必ず最新版を解決し、上記の優先順位で読む。

---

## 3. 現在地（任意 / 参考）

このセクションは「その時点の最大N」を人手でメモしてよいが、**この値を正として固定しない**。
（常に 2章のルールで解決する）

- latest `spec_rule_vN.md`: （例）v20
- latest `spec_product_vN.md`: （例）v17
- latest `spec_backend_vN.md`: （例）v8
- latest `spec_backend_impl_vN.md`: （例）v10
- latest `spec_frontend_vN.md`: （例）v8
- latest `spec_frontend_impl_vN.md`: （例）v9

---

## 4. 旧Specファイル名の扱い（MUST）

過去に以下の命名でSpecが存在したが、**現行SSOTでは使用しない（参照禁止）**。

- `spec_serverside_v*.md`
- `spec_serverside_dev_v*.md`
- `spec_serverside_impl_dev_v*.md`
- `spec_v*.md`（旧プロダクトSpec）
