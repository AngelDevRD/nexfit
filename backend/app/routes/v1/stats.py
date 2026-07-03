from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.exercise import Exercise
from app.models.user import User
from app.schemas.stats import (
    ExerciseProgressEntry,
    MuscleVolumeEntry,
    RecordPredictionResponse,
    StrengthProfileResponse,
    StrengthStandardResponse,
    TonnagePeriodEntry,
    TrainingStreakResponse,
)
from app.services.predictions import predict_next_record
from app.services.stats import (
    get_exercise_progress,
    get_muscle_volume,
    get_strength_profile,
    get_tonnage_history,
    get_training_streak,
)
from app.services.strength_standards import compare_to_strength_standards

router = APIRouter(prefix="/api/v1/stats", tags=["stats"])


@router.get("/muscle-analysis", response_model=list[MuscleVolumeEntry])
def muscle_analysis(
    days: int = Query(default=30, ge=1, le=365),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    return get_muscle_volume(db, current_user.id, days)


@router.get("/strength-profile", response_model=StrengthProfileResponse)
def strength_profile(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> dict:
    return get_strength_profile(db, current_user.id)


@router.get("/progress/{exercise_id}", response_model=list[ExerciseProgressEntry])
def exercise_progress(
    exercise_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    if not db.get(Exercise, exercise_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Ejercicio no encontrado"
        )
    return get_exercise_progress(db, current_user.id, exercise_id)


@router.get("/tonnage", response_model=list[TonnagePeriodEntry])
def tonnage_history(
    period: Literal["week", "month"] = "week",
    periods: int = Query(default=12, ge=1, le=52),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    return get_tonnage_history(db, current_user.id, period, periods)


@router.get("/streak", response_model=TrainingStreakResponse)
def training_streak(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> dict:
    return get_training_streak(db, current_user.id)


@router.get(
    "/strength-standards/{exercise_id}", response_model=StrengthStandardResponse
)
def strength_standards(
    exercise_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    result = compare_to_strength_standards(db, current_user, exercise_id)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sin datos suficientes: completá tu perfil (peso, sexo) y registrá al menos un PR "
            "en press banca, sentadilla o peso muerto",
        )
    return result


@router.get("/record-prediction/{exercise_id}", response_model=RecordPredictionResponse)
def record_prediction(
    exercise_id: int,
    weeks_ahead: int = Query(default=8, ge=1, le=52),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    result = predict_next_record(db, current_user.id, exercise_id, weeks_ahead)
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sin suficiente histórico de récords para este ejercicio todavía",
        )
    return result
