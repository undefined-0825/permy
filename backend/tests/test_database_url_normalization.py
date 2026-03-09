from app.db import normalize_database_url


def test_normalize_database_url_postgresql_to_psycopg() -> None:
    src = "postgresql://user:pass@db.example.com:5432/permy"
    got = normalize_database_url(src)
    assert got == "postgresql+psycopg://user:pass@db.example.com:5432/permy"


def test_normalize_database_url_postgres_alias_to_psycopg() -> None:
    src = "postgres://user:pass@db.example.com:5432/permy"
    got = normalize_database_url(src)
    assert got == "postgresql+psycopg://user:pass@db.example.com:5432/permy"


def test_normalize_database_url_keeps_existing_async_driver() -> None:
    src = "postgresql+asyncpg://user:pass@db.example.com:5432/permy"
    got = normalize_database_url(src)
    assert got == src
