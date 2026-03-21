import asyncio

import app.db as db_module


def test_ensure_schema_calls_create_all(monkeypatch):
    """ensure_schema が create_all を実行することを確認する。"""
    called: dict[str, object] = {}

    class DummyConn:
        async def run_sync(self, fn):
            run_sync_calls = called.setdefault("run_sync_calls", [])
            assert isinstance(run_sync_calls, list)
            run_sync_calls.append(fn)
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
    monkeypatch.setattr(
        db_module,
        "inspect",
        lambda _: type(
            "DummyInspector",
            (),
            {
                "get_table_names": lambda self: [],
                "get_columns": lambda self, _table_name: [],
            },
        )(),
    )

    asyncio.run(db_module.ensure_schema())

    assert called.get("begin") is True
    assert called.get("entered") is True
    run_sync_calls = called.get("run_sync_calls")
    assert isinstance(run_sync_calls, list)
    assert len(run_sync_calls) == 2
    assert run_sync_calls[1] is db_module._ensure_backward_compatible_columns
    assert called.get("exited") is True
    assert called.get("create_all_bind") == "dummy_sync_connection"


def test_ensure_backward_compatible_columns_adds_missing_user_columns(monkeypatch):
    executed: list[str] = []

    class DummyInspector:
        def get_table_names(self):
            return ["users"]

        def get_columns(self, table_name):
            assert table_name == "users"
            return [{"name": "user_id"}, {"name": "created_at"}, {"name": "updated_at"}]

    class DummyConn:
        def execute(self, stmt):
            executed.append(str(stmt))

    monkeypatch.setattr(db_module, "inspect", lambda _: DummyInspector())

    db_module._ensure_backward_compatible_columns(DummyConn())

    assert any("ADD COLUMN feature_tier" in stmt for stmt in executed)
    assert any("ADD COLUMN billing_tier" in stmt for stmt in executed)
    assert any("ADD COLUMN failed_pro_comp_attempts" in stmt for stmt in executed)
    assert any("ADD COLUMN is_locked" in stmt for stmt in executed)
