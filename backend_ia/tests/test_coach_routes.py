import pytest
from fastapi.testclient import TestClient

from app.auth import get_current_user_id
from app.llm.base import (
    LlmNotConfiguredError,
    LlmProviderError,
    LlmReply,
    LlmTimeoutError,
    LlmUsage,
)
from app.main import app
from app.rate_limiter import InMemoryRateLimiter
from app.routes.coach import get_llm_provider, get_rate_limiter

VALID_CONTEXT = {"version": 1, "profile": {"name": "Angel"}}


class _FakeProvider:
    def __init__(self, configured=True, reply=None, raise_exc=None):
        self._configured = configured
        self._reply = reply or LlmReply(
            text="Vas bien.", model="fake/model", usage=LlmUsage(10, 5, 15)
        )
        self._raise_exc = raise_exc

    def is_configured(self) -> bool:
        return self._configured

    async def complete(self, system_prompt: str, user_message: str) -> LlmReply:
        if self._raise_exc:
            raise self._raise_exc
        return self._reply


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


def _body(message="¿Cómo voy?", context=None):
    return {
        "sessionId": "b3f1c2b0-6e9d-4b3a-9e2e-1a2b3c4d5e6f",
        "message": message,
        "context": context if context is not None else VALID_CONTEXT,
    }


def test_chat_ok(client):
    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider()

    response = client.post("/api/v1/coach/chat", json=_body())

    assert response.status_code == 200
    data = response.json()
    assert data["reply"] == "Vas bien."
    assert data["model"] == "fake/model"
    assert data["usage"] == {
        "promptTokens": 10,
        "completionTokens": 5,
        "totalTokens": 15,
    }


def test_chat_sin_auth_header_devuelve_401(client):
    response = client.post("/api/v1/coach/chat", json=_body())
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_chat_mensaje_vacio_devuelve_400(client):
    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider()

    response = client.post("/api/v1/coach/chat", json=_body(message="   "))

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_request"


def test_chat_context_sin_version_soportada_devuelve_400(client):
    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider()

    response = client.post("/api/v1/coach/chat", json=_body(context={"version": 99}))

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_request"


def test_chat_context_demasiado_grande_devuelve_400(client):
    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider()

    huge_context = {"version": 1, "filler": "x" * (20 * 1024)}
    response = client.post("/api/v1/coach/chat", json=_body(context=huge_context))

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "context_too_large"


def test_chat_rate_limited_devuelve_429_con_retry_after(client):
    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider()
    app.dependency_overrides[get_rate_limiter] = lambda: InMemoryRateLimiter(
        max_requests_per_window=0
    )

    response = client.post("/api/v1/coach/chat", json=_body())

    assert response.status_code == 429
    assert response.json()["error"]["code"] == "rate_limited"
    assert int(response.headers["Retry-After"]) > 0


def test_chat_llm_no_configurado_devuelve_503(client):
    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider(
        raise_exc=LlmNotConfiguredError("falta la key")
    )

    response = client.post("/api/v1/coach/chat", json=_body())

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "llm_unavailable"


def test_chat_llm_timeout_devuelve_504(client):
    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider(
        raise_exc=LlmTimeoutError("tardo demasiado")
    )

    response = client.post("/api/v1/coach/chat", json=_body())

    assert response.status_code == 504
    assert response.json()["error"]["code"] == "timeout"


def test_chat_llm_error_generico_devuelve_500(client):
    app.dependency_overrides[get_current_user_id] = lambda: "user-1"
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider(
        raise_exc=LlmProviderError("groq devolvio algo raro")
    )

    response = client.post("/api/v1/coach/chat", json=_body())

    assert response.status_code == 500
    assert response.json()["error"]["code"] == "internal_error"


def test_status_available_true(client):
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider(configured=True)
    response = client.get("/api/v1/coach/status")
    assert response.status_code == 200
    assert response.json() == {"available": True}


def test_status_available_false(client):
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider(configured=False)
    response = client.get("/api/v1/coach/status")
    assert response.status_code == 200
    assert response.json() == {"available": False}


def test_status_no_requiere_autenticacion(client):
    # Sin override de get_current_user_id ni Authorization header -- /status
    # no depende de esa dependency en absoluto.
    app.dependency_overrides[get_llm_provider] = lambda: _FakeProvider()
    response = client.get("/api/v1/coach/status")
    assert response.status_code == 200
