from typing import Any

from pydantic import BaseModel, Field

# Versiones de CoachContext que este backend acepta (docs/COACH_CONTEXT.md).
SUPPORTED_CONTEXT_VERSIONS = {1}


class ChatRequest(BaseModel):
    """Ver docs/COACH_API.md -- POST /api/v1/coach/chat."""

    session_id: str = Field(alias="sessionId")
    message: str
    # CoachContext completo (docs/COACH_CONTEXT.md) -- el backend no valida su
    # forma de negocio campo por campo (es stateless y no le concierne), solo
    # que sea un objeto con una version soportada.
    context: dict[str, Any]

    model_config = {"populate_by_name": True}


class UsageInfo(BaseModel):
    prompt_tokens: int = Field(serialization_alias="promptTokens")
    completion_tokens: int = Field(serialization_alias="completionTokens")
    total_tokens: int = Field(serialization_alias="totalTokens")

    model_config = {"populate_by_name": True}


class ChatResponse(BaseModel):
    reply: str
    model: str
    usage: UsageInfo

    model_config = {"populate_by_name": True}


class StatusResponse(BaseModel):
    available: bool


class ErrorBody(BaseModel):
    code: str
    message: str


class ErrorResponse(BaseModel):
    error: ErrorBody
