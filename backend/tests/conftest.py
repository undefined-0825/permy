"""pytest configuration."""
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    """HTTP client using in-memory test database."""
    # Import app after fixture setup to ensure test environment
    from app.main import app
    
    return TestClient(app)


