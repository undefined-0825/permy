from __future__ import annotations

import json
import re
from typing import List

from openai import AsyncOpenAI

from app.ai_client import AiClient, GenerateContext
from app.config import settings
from app.errors import err


_RX_LABEL = re.compile(r"^\s*([ABC])[\s:：.-]+(.*)$")


def _extract_abc_fallback(text: str) -> list[str] | None:
    """フォールバック：A/B/Cラベル形式をパースする（Structured Outputs非対応時用）"""
    lines = [ln.strip() for ln in (text or "").splitlines() if ln.strip()]
    bucket: dict[str, list[str]] = {"A": [], "B": [], "C": []}
    cur: str | None = None
    for ln in lines:
        m = _RX_LABEL.match(ln)
        if m:
            cur = m.group(1)
            rest = m.group(2).strip()
            if rest:
                bucket[cur].append(rest)
            continue
        if cur in bucket:
            bucket[cur].append(ln)

    if all(bucket[k] for k in ("A", "B", "C")):
        return [
            "\n".join(bucket["A"]).strip(),
            "\n".join(bucket["B"]).strip(),
            "\n".join(bucket["C"]).strip(),
        ]
    return None


def _truncate(s: str, n: int = 300) -> str:
    if len(s) <= n:
        return s
    return s[:n] + "..."


def _contains_any(text: str, needles: list[str]) -> bool:
    t = text or ""
    for n in needles:
        if not n:
            continue
        if n in t:
            return True
    return False


def _violates_ng(a: str, b: str, c: str, ng_free_phrases: list[str]) -> bool:
    if not ng_free_phrases:
        return False
    return _contains_any(a, ng_free_phrases) or _contains_any(b, ng_free_phrases) or _contains_any(c, ng_free_phrases)


def _has_placeholder(a: str, b: str, c: str) -> bool:
    bad = ["○○", "〇〇", "{name}", "[name]"]
    return _contains_any(a, bad) or _contains_any(b, bad) or _contains_any(c, bad)


def _length_guidance(pref: str | None) -> str:
    if pref == "long":
        return "各案は3〜5文を目安。『気遣いの一文』＋『次に進める軽い提案（候補日/時間/質問1つ）』を必ず入れる。"
    return "各案は2〜3文を目安。短すぎる一言返信は禁止。"


def _line_break_guidance(pref: str | None) -> str:
    if pref == "few":
        return "改行は少なめ。基本は1つのまとまりとして読みやすく整える。"
    if pref == "many":
        return "改行は多め。1〜2文ごとに適度に改行して、見やすさを優先する。"
    return "改行量は履歴の雰囲気から推測する。相手や元の文面が詰め気味なら少なめ、見やすく区切られているなら多めにする。"


def _emoji_guidance(pref: str | None) -> str:
    if pref == "none":
        return "絵文字は使わない。"
    if pref == "many":
        return "各案に絵文字を2〜3個入れる。文の意味を邪魔しない位置に置く。"
    return "各案に絵文字を1個まで入れてよい。過剰装飾は避ける。"


def _reaction_guidance(pref: str | None) -> str:
    if pref == "low":
        return "落ち着いた温度感で書く。感嘆符の多用は避ける。"
    if pref == "high":
        return "反応をはっきり示す。各案で感嘆符や前向き表現を適度に使う。"
    return "自然な温度感で書く。過剰にテンションを上げない。"


def _partner_name_usage_guidance(pref: str | None) -> str:
    if pref == "none":
        return "相手の名前や呼び方は入れない。"
    if pref == "many":
        return "相手の名前や呼び方が履歴から自然に分かる場合、各案で1〜2回使って親しみを出す。分からない場合は無理に補わない。"
    return "相手の名前や呼び方が履歴から自然に分かる場合のみ、各案で1回程度まで使う。分からない場合は無理に補わない。"


def _identity_analysis_guidance() -> str:
    return (
        "返信案の作成前に、履歴から次を正確に分析する。"
        "ユーザーの口調、相手の呼び方、返信の内容傾向、文体・温度感・改行・絵文字の使い方を必ず捉える。"
        "その分析結果を反映し、ユーザー本人が送ったと錯覚する自然さで書く。"
        "汎用テンプレートは使わず、常に『ユーザーの分身』として返信案を作る。"
    )


def _noise_control_guidance() -> str:
    return (
        "以下は自然さのための必須制約。"
        "1) 情報を説明しすぎない。理由や主語は必要な範囲で省略する。"
        "2) 丁寧すぎる敬語・ビジネス文体を避け、少し崩した口語を使う。"
        "3) 毎回同じ文構造を使わない。文の長さと改行位置に揺らぎを持たせる。"
        "4) 『ちょっと』『なんか』『たぶん』など曖昧語を必要に応じて自然に混ぜる。"
        "5) 1メッセージの意図は1つに絞る。"
        "6) 余白を残し、言い切りすぎない。疑問形や余韻で終えてよい。"
        "7) 完璧さより自然さを優先する。"
        "ただし意味は変えない。NGポリシー・安全制約・ユーザー設定を最優先する。"
    )


def _min_a_chars(pref: str | None) -> int:
    if pref == "long":
        return 70
    return 45


def _is_a_too_short(a: str, pref: str | None) -> bool:
    return len((a or "").strip()) < _min_a_chars(pref)


class OpenAiChatClient(AiClient):
    def __init__(self) -> None:
        if not settings.openai_api_key:
            raise RuntimeError("OPENAI_API_KEY is required for AI_PROVIDER=openai")
        self._client = AsyncOpenAI(api_key=settings.openai_api_key)

    async def generate_abc(self, history_text: str, ctx: GenerateContext) -> List[str]:
        ng_lines: list[str] = []
        if ctx.ng_tags:
            ng_lines.append(f"NGタグ: {', '.join(ctx.ng_tags)}")
        if ctx.ng_free_phrases:
            ng_lines.append("NG表現: " + " / ".join(ctx.ng_free_phrases))

        profile: list[str] = []
        if ctx.relationship_type:
            profile.append(f"関係性: {ctx.relationship_type}")
        if ctx.true_self_type:
            profile.append(f"本来の自分: {ctx.true_self_type}")
        if ctx.night_self_type:
            profile.append(f"夜の自分: {ctx.night_self_type}")
        if ctx.persona_goal_primary:
            profile.append(f"主目的: {ctx.persona_goal_primary}")
        if ctx.persona_goal_secondary:
            profile.append(f"副目的: {ctx.persona_goal_secondary}")
        if ctx.style_assertiveness is not None:
            profile.append(f"押しの強さ(0-100): {ctx.style_assertiveness}")
        if ctx.style_warmth is not None:
            profile.append(f"あたたかさ(0-100): {ctx.style_warmth}")
        if ctx.style_risk_guard is not None:
            profile.append(f"安全寄せ(0-100): {ctx.style_risk_guard}")
        if ctx.reply_length_pref:
            profile.append(f"長さ: {ctx.reply_length_pref}")
        if ctx.line_break_pref:
            profile.append(f"改行設定: {ctx.line_break_pref}")
        if ctx.emoji_amount_pref:
            profile.append(f"絵文字量: {ctx.emoji_amount_pref}")
        if ctx.reaction_level_pref:
            profile.append(f"リアクション: {ctx.reaction_level_pref}")
        if ctx.partner_name_usage_pref:
            profile.append(f"相手の呼び方: {ctx.partner_name_usage_pref}")
        profile.append(f"コンボID: {ctx.combo_id}")

        system_instructions = (
            settings.openai_instructions
            + "\n\n【A/B/Cの役割（固定）】\n"
            + "- A：おすすめ（最も自然で刺さる）。相手の温度感に合わせつつ、次に進める“軽い一手”を入れる。\n"
            + "  さらにAは最優先で『ユーザーの分身』として書く。語尾・言い回し・テンポ・改行癖・絵文字癖を履歴に最大限寄せ、汎用表現を避ける。\n"
            + "- B：無難（角が立たない）。丁寧で安全運転、確認質問は1つまで。\n"
            + "- C：攻め（距離を詰める/提案強め）。ただし圧はかけない、断定しない。\n"
            + "\n【分身モード（最重要）】\n"
            + _identity_analysis_guidance()
            + "\n"
            + "\n【ノイズ制御（自然さ強制）】\n"
            + _noise_control_guidance()
            + "\n"
            + "\n【長さ】\n"
            + _length_guidance(ctx.reply_length_pref)
            + "\n"
            + "\n【改行】\n"
            + _line_break_guidance(ctx.line_break_pref)
            + "\n"
            + "\n【絵文字】\n"
            + _emoji_guidance(ctx.emoji_amount_pref)
            + "\n"
            + "\n【リアクション】\n"
            + _reaction_guidance(ctx.reaction_level_pref)
            + "\n"
            + "\n【相手の呼び方】\n"
            + _partner_name_usage_guidance(ctx.partner_name_usage_pref)
            + "\n"
            + "\n【制約】\n"
            + "- 出力は必ず3案（A/B/C）。それぞれ狙いを変えて“別案”にする。\n"
            + f"- Aは最低{_min_a_chars(ctx.reply_length_pref)}文字以上で、ユーザーの口調再現を最優先する。\n"
            + "- 断定せず提案として書く（命令・詰問・強要は禁止）。\n"
            + "- 記号や箇条書き多用は避ける（会話文）。\n"
            + "- 相手の名前が不明なら「○○」などのプレースホルダは使わない。\n"
            + (("- " + "\n- ".join(ng_lines) + "\n") if ng_lines else "")
            + (("【プロファイル】\n" + "\n".join(profile) + "\n") if profile else "")
        )

        schema = {
            "name": "abc_candidates",
            "description": "A/B/Cの返信案を必ず返す",
            "schema": {
                "type": "object",
                "properties": {"A": {"type": "string"}, "B": {"type": "string"}, "C": {"type": "string"}},
                "required": ["A", "B", "C"],
                "additionalProperties": False,
            },
            "strict": True,
        }

        user_input = (
            "以下はトーク履歴。文脈を読んで返信案を作って。\n"
            + (f"【重要】このトーク履歴において「{ctx.my_line_name}」が返信を送るユーザーです。「{ctx.my_line_name}」の相手に向けた返信案を作ってください。\n" if ctx.my_line_name else "")
            + "----\n"
            f"{history_text}\n"
            "----\n"
            "出力は JSON で、必ずキー A/B/C を含めてください。\n"
        )

        def _messages(extra_system: str | None) -> list[dict]:
            if not extra_system:
                return [
                    {"role": "system", "content": system_instructions},
                    {"role": "user", "content": user_input},
                ]
            return [
                {"role": "system", "content": system_instructions + "\n\n【再生成指示】\n" + extra_system},
                {"role": "user", "content": user_input},
            ]

        for attempt in range(2):
            regen_hint = None
            if attempt == 1:
                regen_hint = (
                    "前回の出力に禁止表現/プレースホルダが含まれました。"
                    "次の文字列は絶対に含めないでください: "
                    + (" / ".join(ctx.ng_free_phrases) if ctx.ng_free_phrases else "(なし)")
                    + "。"
                    "また、相手の名前が不明なら○○などのプレースホルダは使わないでください。"
                    f"A案は最低{_min_a_chars(ctx.reply_length_pref)}文字以上にしてください。"
                )

            try:
                resp = await self._client.chat.completions.create(
                    model=settings.openai_model,
                    messages=_messages(regen_hint),
                    response_format={"type": "json_schema", "json_schema": schema},
                )
            except Exception:
                try:
                    resp = await self._client.chat.completions.create(
                        model=settings.openai_model,
                        messages=_messages(regen_hint),
                        response_format={"type": "json_object"},
                    )
                except Exception as e2:
                    raise err(
                        "AI_UPSTREAM_ERROR",
                        "AI呼び出しに失敗しました",
                        {"type": e2.__class__.__name__, "message": _truncate(str(e2))},
                        status_code=502,
                    ) from e2

            out = (resp.choices[0].message.content or "").strip()

            a = b = c = ""
            try:
                obj = json.loads(out)
                a = str(obj.get("A") or "").strip()
                b = str(obj.get("B") or "").strip()
                c = str(obj.get("C") or "").strip()
            except Exception:
                abc = _extract_abc_fallback(out)
                if abc:
                    a, b, c = [x.strip() for x in abc]

            if not a or not b or not c:
                if attempt == 0:
                    continue
                raise err(
                    "AI_BAD_OUTPUT",
                    "AI出力形式が不正です",
                    {"message": "json/label parse failed"},
                    status_code=502,
                )

            if _violates_ng(a, b, c, ctx.ng_free_phrases) or _has_placeholder(a, b, c):
                if attempt == 0:
                    continue
                raise err(
                    "AI_BAD_OUTPUT",
                    "AI出力に禁止表現が含まれました",
                    {"message": "ng/placeholder violation"},
                    status_code=502,
                )

            if _is_a_too_short(a, ctx.reply_length_pref):
                if attempt == 0:
                    continue
                raise err(
                    "AI_BAD_OUTPUT",
                    "A案が短すぎます",
                    {"message": "A candidate too short"},
                    status_code=502,
                )

            return [a, b, c]

        raise err("AI_BAD_OUTPUT", "AI出力の生成に失敗しました", status_code=502)
