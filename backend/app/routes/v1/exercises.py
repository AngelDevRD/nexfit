from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.models.exercise import Exercise
from app.schemas.exercise import ExerciseResponse, ExerciseSummary

router = APIRouter(prefix="/api/v1/exercises", tags=["exercises"])


@router.get("", response_model=list[ExerciseSummary])
def list_exercises(
    muscle_group: str | None = None,
    equipment: str | None = None,
    db: Session = Depends(get_db),
) -> list[Exercise]:
    query = db.query(Exercise)
    if muscle_group:
        query = query.filter(Exercise.muscle_group == muscle_group)
    exercises = query.order_by(Exercise.name).all()
    if equipment:
        exercises = [e for e in exercises if equipment in e.equipment]
    return exercises


@router.get("/{exercise_id}", response_model=ExerciseResponse)
def get_exercise(exercise_id: int, db: Session = Depends(get_db)) -> Exercise:
    exercise = db.get(Exercise, exercise_id)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Ejercicio no encontrado"
        )
    return exercise
