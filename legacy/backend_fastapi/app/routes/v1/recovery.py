from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.recovery import DailyCheckIn
from app.models.user import User
from app.schemas.recovery import CheckInResponse, CheckInUpsert, RecoveryIndexResponse
from app.services.recovery import compute_recovery_index

router = APIRouter(prefix="/api/v1/recovery", tags=["recovery"])


@router.put("/checkins", response_model=CheckInResponse)
def upsert_checkin(
    payload: CheckInUpsert,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DailyCheckIn:
    checkin = (
        db.query(DailyCheckIn)
        .filter(
            DailyCheckIn.user_id == current_user.id,
            DailyCheckIn.checkin_date == payload.checkin_date,
        )
        .first()
    )
    if checkin is None:
        checkin = DailyCheckIn(
            user_id=current_user.id, checkin_date=payload.checkin_date
        )
        db.add(checkin)

    checkin.sleep_hours = payload.sleep_hours
    checkin.perceived_fatigue = payload.perceived_fatigue

    db.commit()
    db.refresh(checkin)
    return checkin


@router.get("/index", response_model=RecoveryIndexResponse)
def recovery_index(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> dict:
    result = compute_recovery_index(db, current_user.id)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Registrá tu check-in diario (sueño y fatiga percibida) para ver tu índice de recuperación",
        )
    return result
