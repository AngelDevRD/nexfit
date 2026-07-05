from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.user import User
from app.schemas.coach import CoachChatRequest, CoachChatResponse
from app.services.digital_twin import (
    SYSTEM_PROMPT,
    build_user_context,
    get_activity_log,
)
from app.services.llm_client import LlmNotConfiguredError, ask_llm

router = APIRouter(prefix="/api/v1/coach", tags=["coach"])

ACTIVITY_LOG_TOOL = {
    "type": "function",
    "function": {
        "name": "consultar_historial",
        "description": "Devuelve el detalle de entrenamientos, nutricion y check-ins "
        "registrados por el usuario en un rango de fechas especifico.",
        "parameters": {
            "type": "object",
            "properties": {
                "fecha_inicio": {"type": "string", "description": "YYYY-MM-DD"},
                "fecha_fin": {"type": "string", "description": "YYYY-MM-DD"},
            },
            "required": ["fecha_inicio", "fecha_fin"],
        },
    },
}


@router.post("/chat", response_model=CoachChatResponse)
async def chat(
    payload: CoachChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    context = build_user_context(db, current_user.id, current_user.name)
    prompt = f"{context}\n\nPregunta del usuario: {payload.message}"

    def tool_executor(name: str, arguments: dict) -> str:
        if name != "consultar_historial":
            return f"Herramienta desconocida: {name}."
        try:
            start = date.fromisoformat(arguments.get("fecha_inicio", ""))
            end = date.fromisoformat(arguments.get("fecha_fin", ""))
        except ValueError:
            return (
                "Fechas invalidas, deben tener formato YYYY-MM-DD. "
                "Volve a pedir el rango con ese formato."
            )
        return get_activity_log(db, current_user.id, start, end)

    try:
        reply = await ask_llm(
            SYSTEM_PROMPT,
            prompt,
            tools=[ACTIVITY_LOG_TOOL],
            tool_executor=tool_executor,
        )
    except LlmNotConfiguredError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc

    return {"reply": reply}


@router.get("/context-preview")
def context_preview(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> dict:
    return {"context": build_user_context(db, current_user.id, current_user.name)}
