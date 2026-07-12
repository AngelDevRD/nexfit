import httpx
import pytest
import respx

from app.llm.base import LlmNotConfiguredError, LlmProviderError, LlmTimeoutError
from app.llm.groq_provider import GroqProvider


def _provider(api_key="test-key"):
    return GroqProvider(
        api_key=api_key,
        base_url="https://api.groq.com/openai/v1",
        model="llama-3.3-70b-versatile",
        timeout_seconds=5.0,
    )


def test_is_configured_refleja_si_hay_api_key():
    assert _provider(api_key="algo").is_configured() is True
    assert _provider(api_key=None).is_configured() is False


@pytest.mark.asyncio
async def test_complete_sin_api_key_levanta_llm_not_configured():
    provider = _provider(api_key=None)
    with pytest.raises(LlmNotConfiguredError):
        await provider.complete("system", "hola")


@pytest.mark.asyncio
@respx.mock
async def test_complete_devuelve_reply_y_usage():
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [{"message": {"content": "Vas muy bien esta semana."}}],
                "usage": {
                    "prompt_tokens": 120,
                    "completion_tokens": 30,
                    "total_tokens": 150,
                },
            },
        )
    )

    provider = _provider()
    reply = await provider.complete("system prompt", "¿como voy?")

    assert reply.text == "Vas muy bien esta semana."
    assert reply.model == "groq/llama-3.3-70b-versatile"
    assert reply.usage.prompt_tokens == 120
    assert reply.usage.completion_tokens == 30
    assert reply.usage.total_tokens == 150


@pytest.mark.asyncio
@respx.mock
async def test_complete_no_manda_tools_en_el_body():
    route = respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(
            200,
            json={
                "choices": [{"message": {"content": "ok"}}],
                "usage": {},
            },
        )
    )

    await _provider().complete("system", "hola")

    sent_body = route.calls.last.request.content
    import json

    body = json.loads(sent_body)
    assert "tools" not in body
    assert "tool_choice" not in body


@pytest.mark.asyncio
@respx.mock
async def test_complete_timeout_levanta_llm_timeout_error():
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        side_effect=httpx.TimeoutException("timeout")
    )
    with pytest.raises(LlmTimeoutError):
        await _provider().complete("system", "hola")


@pytest.mark.asyncio
@respx.mock
async def test_complete_error_http_levanta_llm_provider_error():
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(500, text="boom")
    )
    with pytest.raises(LlmProviderError):
        await _provider().complete("system", "hola")


@pytest.mark.asyncio
@respx.mock
async def test_complete_formato_inesperado_levanta_llm_provider_error():
    respx.post("https://api.groq.com/openai/v1/chat/completions").mock(
        return_value=httpx.Response(200, json={"choices": []})
    )
    with pytest.raises(LlmProviderError):
        await _provider().complete("system", "hola")
