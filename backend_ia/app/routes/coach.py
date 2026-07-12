"""Endpoints del Coach IA -- docs/COACH_API.md es la fuente de verdad del
contrato HTTP, este modulo solo lo implementa.
"""

import json

from fastapi import APIRouter, Depends

from app.auth import get_current_user_id
from app.config import Settings, get_settings
from app.errors import (
    ContextTooLargeError,
    InternalError,
    InvalidRequestError,
    LlmUnavailableError,
    RateLimitedError,
)
from app.errors import LlmTimeoutError as CoachTimeoutError
from app.llm.base import LlmNotConfiguredError, LLMProvider, LlmProviderError
from app.llm.base import LlmTimeoutError as ProviderTimeoutError
from app.llm.factory import build_llm_provider
from app.prompt import render_system_prompt
from app.rate_limiter import InMemoryRateLimiter, RateLimitExceeded
from app.schemas import (
    SUPPORTED_CONTEXT_VERSIONS,
    ChatRequest,
    ChatResponse,
    StatusResponse,
    UsageInfo,
)

router = APIRouter(prefix="/api/v1/coach", tags=["coach"])

# Presupuesto de tamano de docs/COACH_CONTEXT.md ("Presupuesto de tokens / tamano").
_MAX_CONTEXT_BYTES = 15 * 1024

_rate_limiter_by_settings: dict[int, InMemoryRateLimiter] = {}


def get_rate_limiter(settings: Settings = Depends(get_settings)) -> InMemoryRateLimiter:
    key = id(settings)
    limiter = _rate_limiter_by_settings.get(key)
    if limiter is None:
        limiter = InMemoryRateLimiter(
            max_requests_per_window=settings.rate_limit_per_minute
        )
        _rate_limiter_by_settings[key] = limiter
    return limiter


def get_llm_provider(settings: Settings = Depends(get_settings)) -> LLMProvider:
    return build_llm_provider(settings)


def _validate_and_serialize_context(context: dict) -> str:
    version = context.get("version")
    if version not in SUPPORTED_CONTEXT_VERSIONS:
        raise InvalidRequestError(
            f"context.version no soportado: {version!r} "
            f"(soportadas: {sorted(SUPPORTED_CONTEXT_VERSIONS)})"
        )

    context_json = json.dumps(context, ensure_ascii=False)
    if len(context_json.encode("utf-8")) > _MAX_CONTEXT_BYTES:
        raise ContextTooLargeError(
            f"El context supera el limite de {_MAX_CONTEXT_BYTES} bytes"
        )
    return context_json


@router.post("/chat", response_model=ChatResponse)
async def chat(
    payload: ChatRequest,
    user_id: str = Depends(get_current_user_id),
    rate_limiter: InMemoryRateLimiter = Depends(get_rate_limiter),
    provider: LLMProvider = Depends(get_llm_provider),
) -> ChatResponse:
    if not payload.message.strip():
        raise InvalidRequestError("El mensaje no puede estar vacio")

    context_json = _validate_and_serialize_context(payload.context)

    try:
        rate_limiter.check_and_record(user_id)
    except RateLimitExceeded as exc:
        raise RateLimitedError(
            "Superaste el limite de mensajes por minuto. Proba de nuevo en unos segundos.",
            retry_after_seconds=exc.retry_after_seconds,
        ) from exc

    system_prompt = render_system_prompt(context_json, payload.message)

    try:
        reply = await provider.complete(system_prompt, payload.message)
    except LlmNotConfiguredError as exc:
        raise LlmUnavailableError(str(exc)) from exc
    except ProviderTimeoutError as exc:
        raise CoachTimeoutError(str(exc)) from exc
    except LlmProviderError as exc:
        raise InternalError(str(exc)) from exc

    return ChatResponse(
        reply=reply.text,
        model=reply.model,
        usage=UsageInfo(
            prompt_tokens=reply.usage.prompt_tokens,
            completion_tokens=reply.usage.completion_tokens,
            total_tokens=reply.usage.total_tokens,
        ),
    )


@router.get("/status", response_model=StatusResponse)
async def status_check(
    provider: LLMProvider = Depends(get_llm_provider),
) -> StatusResponse:
    return StatusResponse(available=provider.is_configured())
