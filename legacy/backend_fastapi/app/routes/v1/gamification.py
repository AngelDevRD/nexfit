from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.user import User
from app.schemas.gamification import GamificationProfileResponse
from app.services.gamification import get_gamification_profile

router = APIRouter(prefix="/api/v1/gamification", tags=["gamification"])


@router.get("/profile", response_model=GamificationProfileResponse)
def gamification_profile(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> dict:
    return get_gamification_profile(db, current_user.id)
