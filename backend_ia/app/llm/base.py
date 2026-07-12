"""Interfaz LLMProvider (docs/FASE_4_DISENO.md seccion 7).

Regla estricta: el resto del backend (rutas, rate limiter, prompt) SOLO
importa este modulo -- nunca un SDK de un proveedor concreto. Cambiar de
proveedor es agregar una clase nueva que implemente `LLMProvider` y
seleccionarla en `app/llm/factory.py` por `LLM_PROVIDER`.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass


class LlmProviderError(Exception):
    """Error generico al hablar con el proveedor de LLM."""


class LlmNotConfiguredError(LlmProviderError):
    """Falta la API key del proveedor activo."""


class LlmTimeoutError(LlmProviderError):
    """El proveedor no respondio dentro del timeout configurado."""


@dataclass
class LlmUsage:
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


@dataclass
class LlmReply:
    text: str
    model: str
    usage: LlmUsage


class LLMProvider(ABC):
    """Cada proveedor (Groq/OpenAI/Gemini/Claude/Ollama) implementa esto.
    Sin tool-calling -- ver docs/FASE_4_DISENO.md seccion 2: el contexto ya
    viene completo desde el cliente, el LLM nunca vuelve a pedir datos.
    """

    @abstractmethod
    def is_configured(self) -> bool:
        """Para GET /api/v1/coach/status -- ver docs/COACH_API.md."""

    @abstractmethod
    async def complete(self, system_prompt: str, user_message: str) -> LlmReply:
        """Levanta LlmNotConfiguredError / LlmTimeoutError / LlmProviderError
        segun corresponda -- las rutas las traducen a los codigos de
        docs/COACH_API.md (503 / 504 / 500 respectivamente)."""
