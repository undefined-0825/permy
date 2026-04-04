# CI Policy（現時点：CIのみ / MUST）

**Last Updated (JST):** 2026-03-02 04:35:00 +0900

## 1. 決定事項（MUST）

- 現時点は **CIのみ**（自動デプロイは行わない）
- CIで実行するのは「壊していないこと」の検出に限る（短時間・低コスト）

## 2. 実行対象（MUST）

- Lint / format（任意）
- Unit tests（必須）
- Contract tests（必須：API契約の破壊検知）
- Type check（任意）

## 3. OpenAIコストガード（MUST）

- CI環境では `OPENAI_DISABLED=true` を強制
- OpenAIキーはCIに登録しない
- OpenAIを呼ぶE2E/ライブテストはCIで禁止（workflow_dispatchの手動のみ）

## 4. 生成物/ログ（MUST）

- CIログに会話本文/生成本文を出さない
- 失敗時もエラーコード/要約のみ（本文は出さない）
