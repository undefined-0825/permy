"""
リリースノートを app_release_notes テーブルに登録（UPSERT）するスクリプト。

使い方:
    python tools/upsert_release_note.py
"""
from __future__ import annotations

import asyncio
import sys
import os

# backend/ をパスに追加
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from sqlalchemy import text
from app.db import engine
from app.config import settings

VERSION = settings.app_version

TITLE = "バージョンアップのお知らせ"

BODY = """\
・Android版でリリースビルドが失敗することがある問題を修正しました
・アプリの内部バージョンを更新しました
・安定性と品質を改善しました\
"""


async def main() -> None:
    async with engine.begin() as conn:
        await conn.execute(
            text(
                """
                INSERT INTO app_release_notes (version, title, body, released_at)
                VALUES (:version, :title, :body, NOW())
                ON CONFLICT (version) DO UPDATE
                    SET title = EXCLUDED.title,
                        body  = EXCLUDED.body,
                        released_at = EXCLUDED.released_at
                """
            ),
            {"version": VERSION, "title": TITLE, "body": BODY},
        )
    print(f"Upserted release note for version {VERSION}")


if __name__ == "__main__":
    asyncio.run(main())
