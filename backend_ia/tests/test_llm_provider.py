import pytest

from app.llm.base import LLMProvider, LlmReply, LlmUsage


def test_llm_provider_no_se_puede_instanciar_directo():
    with pytest.raises(TypeError):
        LLMProvider()


class _FakeProvider(LLMProvider):
    def is_configured(self) -> bool:
        return True

    async def complete(self, system_prompt: str, user_message: str) -> LlmReply:
        return LlmReply(
            text="ok",
            model="fake/model",
            usage=LlmUsage(prompt_tokens=1, completion_tokens=1, total_tokens=2),
        )


@pytest.mark.asyncio
async def test_implementacion_concreta_funciona():
    provider = _FakeProvider()
    assert provider.is_configured() is True
    reply = await provider.complete("system", "hola")
    assert reply.text == "ok"
    assert reply.usage.total_tokens == 2
