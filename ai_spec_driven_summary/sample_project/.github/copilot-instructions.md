# [ProjectName] Copilot Instructions (MUST)

## MUST: Start Here
- Before proposing or writing any code/spec, you MUST read: `docs/ssot/SSOT.md`.
- If you cannot confirm SSOT contents, STOP and ask the user to provide the file contents or path.

## MUST: Language / Style
- Output MUST be Japanese.
- All responses, comments, commit messages, PR descriptions, and spec edits MUST be in Japanese.
- Do not mix English unless the user explicitly asks.- Code comments MUST be Japanese and minimal.
- Readability-first. Minimal diff. No speculative features.

## Spec edits
- Spec changes are proposal-only; never commit without [PM] approval (PR required).
- Never add chat/export markers (e.g., ``) into any spec.

## MUST: Tests
- When generating implementation, generate corresponding tests in the same change.
- CI must not call OpenAI (set `OPENAI_DISABLED=true` in CI). No OpenAI secrets in CI.

## MUST: Privacy
- Never store/log/telemetry-send chat txt contents or generated reply texts.

## MUST: Rules Reference
- You MUST follow:
  - `docs/spec/01_rules/project_rules.md`
  - `docs/spec/01_rules/engineering_conventions.md`
