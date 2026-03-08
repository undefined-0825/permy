import asyncio

import app.db as db_module


def test_ensure_schema_calls_create_all(monkeypatch):
    """ensure_schema が create_all を実行することを確認する。"""
    called: dict[str, object] = {}

    class DummyConn:
        async def run_sync(self, fn):
            called["run_sync"] = True
            return fn("dummy_sync_connection")

    class DummyBeginContext:
        async def __aenter__(self):
            called["entered"] = True
            return DummyConn()

        async def __aexit__(self, exc_type, exc, tb):
            called["exited"] = True
            return False

    class DummyEngine:
        def begin(self):
            called["begin"] = True
            return DummyBeginContext()

    def fake_create_all(bind):
        called["create_all_bind"] = bind

    monkeypatch.setattr(db_module, "engine", DummyEngine())
    monkeypatch.setattr(db_module.Base.metadata, "create_all", fake_create_all)

    asyncio.run(db_module.ensure_schema())

    assert called.get("begin") is True
    assert called.get("entered") is True
    assert called.get("run_sync") is True
    assert called.get("exited") is True
    assert called.get("create_all_bind") == "dummy_sync_connection"
