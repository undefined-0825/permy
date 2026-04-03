import sys
import types


openai_stub = types.ModuleType("openai")


class _DummyAsyncOpenAI:
    def __init__(self, *args, **kwargs):
        pass


openai_stub.AsyncOpenAI = _DummyAsyncOpenAI
sys.modules.setdefault("openai", openai_stub)

from app.ai_client_openai import (
    _customer_context_lines,
    _identity_analysis_guidance,
    _is_a_too_short,
    _min_a_chars,
    _noise_control_guidance,
)


def test_identity_analysis_guidance_requires_style_analysis():
    text = _identity_analysis_guidance()
    assert "ユーザーの口調" in text
    assert "相手の呼び方" in text
    assert "返信の内容傾向" in text
    assert "文体・温度感・改行・絵文字" in text


def test_identity_analysis_guidance_requires_twin_mode():
    text = _identity_analysis_guidance()
    assert "ユーザー本人が送ったと錯覚" in text
    assert "汎用テンプレートは使わず" in text
    assert "ユーザーの分身" in text


def test_identity_analysis_guidance_emphasizes_stronger_a_candidate():
    text = _identity_analysis_guidance()
    assert "口調" in text
    assert "相手の呼び方" in text
    assert "ユーザーの分身" in text


def test_min_a_chars_thresholds():
    assert _min_a_chars("long") == 70
    assert _min_a_chars(None) == 45


def test_is_a_too_short_respects_pref():
    assert _is_a_too_short("あ" * 44, None)
    assert not _is_a_too_short("あ" * 45, None)
    assert _is_a_too_short("あ" * 69, "long")
    assert not _is_a_too_short("あ" * 70, "long")


def test_noise_control_guidance_has_required_constraints():
    text = _noise_control_guidance()
    assert "情報を説明しすぎない" in text
    assert "丁寧すぎる敬語・ビジネス文体を避け" in text
    assert "毎回同じ文構造を使わない" in text
    assert "1メッセージの意図は1つに絞る" in text


def test_noise_control_guidance_preserves_meaning_and_ng_priority():
    text = _noise_control_guidance()
    assert "意味は変えない" in text
    assert "NGポリシー・安全制約・ユーザー設定を最優先" in text


def test_customer_context_lines_include_core_fields():
    lines = _customer_context_lines(
        {
            "display_name": "山田さん",
            "call_name": "やまださん",
            "relationship_stage": "regular",
            "memo_summary": "終電前に帰る",
            "tags": [
                {"category": "topic", "value": "誕生日"},
                {"category": "drink", "value": "ハイボール"},
            ],
            "recent_visit_log_summaries": ["2026-04-01 store middle"],
            "upcoming_event_summaries": ["2026-04-15 birthday 誕生日"],
        }
    )

    assert len(lines) <= 6
    assert lines[0].startswith("関係性:")
    assert any("顧客名: 山田さん" in line for line in lines)
    assert any("要約メモ: 終電前に帰る" in line for line in lines)
    assert any("タグ:" in line for line in lines)


def test_customer_context_lines_trim_noise_and_limit_low_priority():
    lines = _customer_context_lines(
        {
            "display_name": "山田さん",
            "relationship_stage": "regular",
            "memo_summary": "とても長いメモ" * 20,
            "tags": [
                {"category": "topic", "value": "誕生日"},
                {"category": "unknown", "value": "雑多"},
                {"category": "unknown2", "value": "さらに雑多"},
            ],
            "recent_visit_log_summaries": ["x" * 100],
            "upcoming_event_summaries": ["y" * 100],
        }
    )

    assert len(lines) <= 6
    assert any("要約メモ:" in line and line.endswith("…") for line in lines)
    assert not any("unknown2" in line for line in lines)
