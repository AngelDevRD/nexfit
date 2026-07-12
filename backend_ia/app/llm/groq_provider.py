"""Unica implementacion de LLMProvider que conoce el SDK/API de Groq.
Ninguna otra parte del backend debe importar httpx apuntando a Groq
directamente -- ver docs/FASE_4_DISENO.md seccion 7.
"""

import httpx

from app.llm.base import (
    LlmNotConfiguredError,
    LLMProvider,
    LlmProviderError,
    LlmReply,
    LlmTimeoutError,
    LlmUsage,
)


class GroqProvider(LLMProvider):
    def __init__(
        self,
        api_key: str | None,
        base_url: str,
        model: str,
        timeout_seconds: float,
    ):
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._model = model
        self._timeout_seconds = timeout_seconds

    def is_configured(self) -> bool:
        return bool(self._api_key)

    async def complete(self, system_prompt: str, user_message: str) -> LlmReply:
        if not self.is_configured():
            raise LlmNotConfiguredError(
                "Falta configurar LLM_API_KEY para habilitar el Coach IA"
            )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ]

        async with httpx.AsyncClient(timeout=self._timeout_seconds) as client:
            try:
                response = await client.post(
                    f"{self._base_url}/chat/completions",
                    headers={"Authorization": f"Bearer {self._api_key}"},
                    json={"model": self._model, "messages": messages},
                )
            except httpx.TimeoutException as exc:
                raise LlmTimeoutError(
                    "Groq no respondio dentro del tiempo esperado"
                ) from exc
            except httpx.HTTPError as exc:
                raise LlmProviderError(
                    f"Error de red hablando con Groq: {exc}"
                ) from exc

        if response.status_code >= 400:
            raise LlmProviderError(
                f"Groq devolvio un error ({response.status_code}): {response.text}"
            )

        data = response.json()
        try:
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError) as exc:
            raise LlmProviderError(
                "Respuesta de Groq en un formato inesperado"
            ) from exc

        usage = data.get("usage", {})
        return LlmReply(
            text=content,
            model=f"groq/{self._model}",
            usage=LlmUsage(
                prompt_tokens=usage.get("prompt_tokens", 0),
                completion_tokens=usage.get("completion_tokens", 0),
                total_tokens=usage.get("total_tokens", 0),
            ),
        )
