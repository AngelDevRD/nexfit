from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.nutrition import NutritionLog
from app.models.user import User
from app.schemas.nutrition import NutritionLogResponse, NutritionLogUpsert

router = APIRouter(prefix="/api/v1/nutrition", tags=["nutrition"])


@router.put("/logs", response_model=NutritionLogResponse)
def upsert_log(
    payload: NutritionLogUpsert,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NutritionLog:
    log = (
        db.query(NutritionLog)
        .filter(
            NutritionLog.user_id == current_user.id,
            NutritionLog.log_date == payload.log_date,
        )
        .first()
    )
    if log is None:
        log = NutritionLog(user_id=current_user.id, log_date=payload.log_date)
        db.add(log)

    for field in ("calories", "protein_g", "carbs_g", "fat_g", "water_ml", "notes"):
        setattr(log, field, getattr(payload, field))

    db.commit()
    db.refresh(log)
    return log


@router.get("/logs", response_model=list[NutritionLogResponse])
def list_logs(
    date_from: date | None = None,
    date_to: date | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[NutritionLog]:
    query = db.query(NutritionLog).filter(NutritionLog.user_id == current_user.id)
    if date_from is not None:
        query = query.filter(NutritionLog.log_date >= date_from)
    if date_to is not None:
        query = query.filter(NutritionLog.log_date <= date_to)
    return query.order_by(NutritionLog.log_date.desc()).all()


@router.get("/logs/{log_date}", response_model=NutritionLogResponse)
def get_log(
    log_date: date,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NutritionLog:
    log = (
        db.query(NutritionLog)
        .filter(
            NutritionLog.user_id == current_user.id, NutritionLog.log_date == log_date
        )
        .first()
    )
    if not log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Sin registro para esa fecha"
        )
    return log


@router.delete("/logs/{log_date}", status_code=status.HTTP_204_NO_CONTENT)
def delete_log(
    log_date: date,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    log = (
        db.query(NutritionLog)
        .filter(
            NutritionLog.user_id == current_user.id, NutritionLog.log_date == log_date
        )
        .first()
    )
    if not log:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Sin registro para esa fecha"
        )
    db.delete(log)
    db.commit()
