# Permy Copilot Instructions (MUST)

## MUST: Start Here
- Before proposing or writing any code/spec, you MUST read: `docs/ssot/SSOT.md`.
- If you cannot confirm SSOT contents, STOP and ask the user to provide the file contents or path.

## MUST: Language / Style
- Output MUST be Japanese.
- All responses, comments, commit messages, PR descriptions, and spec edits MUST be in Japanese.
- Do not mix English unless the user explicitly asks.- Code comments MUST be Japanese and minimal.
- Readability-first. Minimal diff. No speculative features.

## Spec edits
- Spec changes are proposal-only; never commit without Choby approval (PR required).
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

## UI implementation rules
- 新規UIを作る前に、既存画面の改善を優先する
- 直値の色、余白、角丸、TextStyleを増やさない
- 共通UIは core/theme と core/widgets を優先利用する
- AppScaffold, AppSectionHeader, AppButton, AppListItem を優先する
- UI変更時は、情報削減・余白整理・CTA強調を優先する
- 派手な装飾追加で解決しない
- 修正後は hierarchy / whitespace / CTA / consistency / cognitive load の5観点で自己レビューする