# spec_serverside_impl_dev_v1.md
（サーバサイド実装：実装チャット用Spec / 雛形）

本Specは「【Spec】サーバサイド実装（実装専用）」チャットのSSOTとして運用する。
参照階層：**rule → product spec → serverside spec → serverside_impl_dev**

---

## 1. 目的
- serverside spec（設計SSOT）に従い、API実装・生成品質・安全制御・レート制限・移行等の実装を進める。
- 「本文非保存」「自動送信しない」「A/B/C固定」のコア制約を破らずに完成度を上げる。

---

## 2. 対象範囲（実装）
- FastAPI エンドポイント実装（/generate, /migration/*, /me/settings, /auth/anonymous）
- OpenAI呼び出し（Structured Outputs）、プロンプト制御、A/B/C役割固定、長文寄せ
- 中ゲート（blocked時の代替A/B/C）、NG表現二重チェック、再生成（上限1回）
- Redis導入（セッション/レート/移行/冪等） ※環境により段階導入
- DBスキーマ/マイグレーション（必要最小限）

---

## 3. 進め方（運用ルール）
- 既存コードを推測しない。必要ファイルはユーザーが貼る。
- 差分パッチのみの提示を避け、置換可能な完成形コードを提示する。
- 実装変更はこのSpecに決定事項として追記し、versionを上げる（上書きしない）。

---

## 4. 直近TODO（初期）
- [ ] /generate: A/B/C役割固定と長文寄せの安定化
- [ ] NG表現・プレースホルダの二重チェック（再生成1回）
- [ ] 中ゲート代替A/B/C（AI呼び出し無し、カウント加算無し）
- [ ] settingsキーのSSOT化（必須キー・型・デフォルト）
- [ ] migration: 実装完成（12桁・10分・1回・失敗10回無効・IP 5/min）

---
