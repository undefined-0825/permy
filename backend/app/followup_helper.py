"""
Followup generation helper
設定の不足をチェックして、聞き返し（followup）を生成する
"""
from __future__ import annotations

from app.schemas import Followup, FollowupChoice


def check_missing_setting(settings: dict) -> Followup | None:
    """
    設定の不足を1点だけチェックして、必要ならfollowupを返す
    
    優先順位：
    1. relationship_type
    2. reply_length_pref
    
    複数不足の場合は最優先1点のみ返す（product_spec 9.1）
    """
    
    # 1. relationship_type チェック
    relationship_type = settings.get("relationship_type")
    valid_relationships = {"new", "regular", "big_client", "caution", "peer"}
    
    if not relationship_type or relationship_type not in valid_relationships:
        return Followup(
            key="relationship_type",
            question="お客様との関係を教えてね",
            choices=[
                FollowupChoice(id="new", label="新規（初めて）"),
                FollowupChoice(id="regular", label="常連（何度も来てる）"),
                FollowupChoice(id="big_client", label="太客（大切なお客様）"),
            ]
        )
    
    # 2. reply_length_pref チェック
    reply_length_pref = settings.get("reply_length_pref")
    valid_lengths = {"short", "standard", "long"}
    
    if not reply_length_pref or reply_length_pref not in valid_lengths:
        return Followup(
            key="reply_length_pref",
            question="返信の長さはどうする？",
            choices=[
                FollowupChoice(id="short", label="短め"),
                FollowupChoice(id="standard", label="標準"),
                FollowupChoice(id="long", label="長め"),
            ]
        )
    
    # 不足なし
    return None

    return None
