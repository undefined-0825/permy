"""pytest configuration."""
import asyncio
import subprocess
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

# Test database path (relative to backend directory)
TEST_DB_PATH = Path(__file__).parent.parent / "permy_test.db"
TEST_DB_URL = f"sqlite+aiosqlite:///{TEST_DB_PATH.as_posix()}"


def pytest_configure(config):
    """Initialize test database before tests run."""
    # Remove old test DB
    if TEST_DB_PATH.exists():
        TEST_DB_PATH.unlink()
    
    # Run init script to create tables
    init_script = Path(__file__).parent.parent / "init_db_simple.py"
    import os
    env = os.environ.copy()
    env["DATABASE_URL"] = f"sqlite+aiosqlite:///{TEST_DB_PATH.as_posix()}"
    
    result = subprocess.run(
        [sys.executable, str(init_script)],
        env=env,
        cwd=str(Path(__file__).parent.parent),
        capture_output=True,
        text=True,
    )
    
    if result.returncode != 0:
        print(f"Error initializing test DB: {result.stderr}")
        raise RuntimeError(f"Failed to initialize test DB: {result.stderr}")
    
    print(f"\n*** Test database initialized: {TEST_DB_PATH} ***")


def pytest_sessionfinish(session, exitstatus):
    """Clean up  test database after tests finish."""
    if TEST_DB_PATH.exists():
        TEST_DB_PATH.unlink()
        print(f"\n*** Test database cleaned up ***")


@pytest.fixture
def event_loop():
    """Provide asyncio event loop."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    yield loop
    loop.close()


@pytest.fixture
def client():
    """HTTP client using test database."""
    # Create engine pointing to test DB
    test_engine = create_async_engine(
        TEST_DB_URL,
        echo=False,
        future=True,
    )

    # Define dependency override
    async def override_get_db():
        """Provide test DB session (async generator)."""
        session_maker = async_sessionmaker(test_engine, class_=AsyncSession, expire_on_commit=False)
        async with session_maker() as session:
            yield session

    # Import app
    from app.main import app
    from app.db import get_db
    
    # Remove old override if exists
    if get_db in app.dependency_overrides:
        del app.dependency_overrides[get_db]
    
    # Set dependency override
    app.dependency_overrides[get_db] = override_get_db

    # Create TestClient
    test_client = TestClient(app)

    yield test_client

    # Cleanup
    app.dependency_overrides.clear()

    async def cleanup():
        """Dispose engine."""
        await test_engine.dispose()

    asyncio.run(cleanup())


