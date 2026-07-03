from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.user import User
from app.schemas.coach import CoachChatRequest, CoachChatResponse
from app.services.digital_twin import SYSTEM_PROMPT, build_user_context
from app.services.llm_client import LlmNotConfiguredError, ask_llm

router = APIRouter(prefix="/api/v1/coach", tags=["coach"])


@router.post("/chat", response_model=CoachChatResponse)
async def chat(
    payload: CoachChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    context = build_user_context(db, current_user.id, current_user.name)
    prompt = f"{context}\n\nPregunta del usuario: {payload.message}"

    try:
        reply = await ask_llm(SYSTEM_PROMPT, prompt)
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
