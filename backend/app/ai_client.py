from __future__ import annotations

from dataclasses import dataclass
import re

from app.config import settings


@dataclass(frozen=True)
class GenerateContext:
    true_self_type: str | None
    night_self_type: str | None
    persona_goal_primary: str | None
    persona_goal_secondary: str | None
    style_assertiveness: int | None
    style_warmth: int | None
    style_risk_guard: int | None
    relationship_type: str | None
    reply_length_pref: str | None
    line_break_pref: str | None
    emoji_amount_pref: str | None
    reaction_level_pref: str | None
    partner_name_usage_pref: str | None
    combo_id: int
    ng_tags: list[str]
    ng_free_phrases: list[str]
    tuning: dict | None
    my_line_name: str | None = None


class AiClient:
    async def generate_abc(self, history_text: str, ctx: GenerateContext) -> list[str]:
        raise NotImplementedError


class DummyAiClient(AiClient):
    async def generate_abc(self, history_text: str, ctx: GenerateContext) -> list[str]:
        # 起動確認用のダミー。内容は最小限でOK（受け入れ条件の本番生成は後続でAIクライアントに委譲）
        rel = ctx.relationship_type or "unknown"
        counterpart_name = _extract_counterpart_name(history_text)
        base = "了解！メッセージありがとう。"
        a = f"{base}（A）関係: {rel}。今夜どうする？"
        b = f"{base}（B）関係: {rel}。落ち着いたら電話できる？"
        c = f"{base}（C）関係: {rel}。会える日また教えてね。"

        if (ctx.reply_length_pref or "standard") == "long":
            a += "\n\n今日はバタバタしてたけど、ちゃんと読んでるよ。無理ないタイミングで返してね。"
            b += "\n\nちょっとだけ声聞けたら安心する。タイミング合う時で大丈夫。"
            c += "\n\n予定が見えたら合わせるよ。無理なら無理って言ってね。"

        a = _apply_line_break_preference(a, history_text, ctx.line_break_pref)
        b = _apply_line_break_preference(b, history_text, ctx.line_break_pref)
        c = _apply_line_break_preference(c, history_text, ctx.line_break_pref)

        emoji_pref = ctx.emoji_amount_pref or "standard"
        if emoji_pref == "many":
            a += " 😊✨"
            b += " 🙌😊"
            c += " 🌙✨"
        elif emoji_pref == "none":
            pass
        else:
            a += " 😊"
            b += " 🙂"
            c += " ✨"

        reaction_pref = ctx.reaction_level_pref or "standard"
        if reaction_pref == "high":
            a += "！"
            b += "！"
            c += "！"
        elif reaction_pref == "low":
            a = a.replace("！", "")
            b = b.replace("！", "")
            c = c.replace("！", "")

        a = _apply_partner_name_usage(a, counterpart_name, ctx.partner_name_usage_pref)
        b = _apply_partner_name_usage(b, counterpart_name, ctx.partner_name_usage_pref)
        c = _apply_partner_name_usage(c, counterpart_name, ctx.partner_name_usage_pref)

        return [a, b, c]


def _extract_counterpart_name(history_text: str) -> str | None:
    matches = []
    for pattern in (
        r"([一-龠ぁ-んァ-ヶA-Za-z0-9]{1,12}(?:さん|くん|ちゃん|様))",
        r"([一-龠ぁ-んァ-ヶA-Za-z0-9]{1,12})[：:]",
    ):
        matches.extend(__import__("re").findall(pattern, history_text or ""))

    blacklist = {"User", "Shop", "Me", "You", "相手", "自分"}
    for candidate in matches:
        normalized = str(candidate).strip()
        if not normalized or normalized in blacklist:
            continue
        return normalized
    return None


def _apply_partner_name_usage(
    text: str,
    counterpart_name: str | None,
    usage_pref: str | None,
) -> str:
    if not counterpart_name or usage_pref == "none":
        return text

    if usage_pref == "many":
        return f"{counterpart_name}、{text} {counterpart_name}の都合に合わせたいな。"

    return f"{counterpart_name}、{text}"


def _apply_line_break_preference(
    text: str,
    history_text: str,
    line_break_pref: str | None,
) -> str:
    effective_pref = _resolve_line_break_pref(history_text, line_break_pref)
    if effective_pref == "few":
        return text.replace("\n\n", " ").replace("\n", " ").strip()

    compact = text.replace("\n\n", "\n").replace("\n", " ").strip()
    return re.sub(r"([。！？])\s*", r"\1\n", compact).strip()


def _resolve_line_break_pref(history_text: str, line_break_pref: str | None) -> str:
    if line_break_pref in {"few", "many"}:
        return line_break_pref

    lines = [line.strip() for line in (history_text or "").splitlines() if line.strip()]
    if "\n\n" in (history_text or "") or len(lines) >= 4:
        return "many"
    return "few"


def get_ai_client() -> AiClient:
    # settings 側のスイッチに合わせて選択（既存設計に合わせて最低限）
    provider = getattr(settings, "ai_provider", None) or getattr(settings, "AI_PROVIDER", None)
    if provider and str(provider).lower() == "openai":
        # 循環import回避のためローカルimport
        from app.ai_client_openai import OpenAiChatClient as OpenAiClient
        return OpenAiClient()
    return DummyAiClient()
