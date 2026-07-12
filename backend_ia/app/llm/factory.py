"""Selecciona la implementacion de LLMProvider activa segun LLM_PROVIDER.
Unico punto que sabe que proveedores existen -- agregar uno nuevo (OpenAI,
Gemini, Claude, Ollama) es una implementacion de LLMProvider + un branch acá,
sin tocar rutas ni el resto del backend.
"""

from app.config import Settings
from app.llm.base import LLMProvider
from app.llm.groq_provider import GroqProvider


def build_llm_provider(settings: Settings) -> LLMProvider:
    if settings.llm_provider == "groq":
        return GroqProvider(
            api_key=settings.llm_api_key,
            base_url=settings.llm_base_url,
            model=settings.llm_model,
            timeout_seconds=settings.llm_timeout_seconds,
        )
    raise ValueError(f"LLM_PROVIDER desconocido: {settings.llm_provider!r}")
