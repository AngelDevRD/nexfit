from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.exercise import Exercise
from app.models.record import PersonalRecord
from app.models.routine import Routine
from app.models.user import User
from app.models.workout import WorkoutSession, WorkoutSet
from app.schemas.record import PersonalRecordResponse
from app.schemas.workout import (
    WorkoutSessionCreate,
    WorkoutSessionResponse,
    WorkoutSessionSummary,
    WorkoutSessionUpdate,
    WorkoutSetCreate,
    WorkoutSetResponse,
    WorkoutSetUpdate,
)
from app.services.records import check_and_save_records

router = APIRouter(prefix="/api/v1/workouts", tags=["workouts"])


def _get_owned_session(session_id: int, user: User, db: Session) -> WorkoutSession:
    session = db.get(WorkoutSession, session_id)
    if not session or session.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Entrenamiento no encontrado"
        )
    return session


@router.post(
    "", response_model=WorkoutSessionResponse, status_code=status.HTTP_201_CREATED
)
def start_session(
    payload: WorkoutSessionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> WorkoutSession:
    if payload.routine_id is not None:
        routine = db.get(Routine, payload.routine_id)
        if not routine or routine.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Rutina no encontrada"
            )

    session = WorkoutSession(
        user_id=current_user.id, routine_id=payload.routine_id, notes=payload.notes
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


@router.patch("/{session_id}", response_model=WorkoutSessionResponse)
def update_session(
    session_id: int,
    payload: WorkoutSessionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> WorkoutSession:
    session = _get_owned_session(session_id, current_user, db)
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(session, field, value)
    db.commit()
    db.refresh(session)
    return session


@router.get("/{session_id}", response_model=WorkoutSessionResponse)
def get_session(
    session_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> WorkoutSession:
    return _get_owned_session(session_id, current_user, db)


@router.get("", response_model=list[WorkoutSessionSummary])
def list_sessions(
    exercise_id: int | None = None,
    muscle_group: str | None = None,
    routine_id: int | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[WorkoutSession]:
    query = db.query(WorkoutSession).filter(WorkoutSession.user_id == current_user.id)
    if routine_id is not None:
        query = query.filter(WorkoutSession.routine_id == routine_id)
    if date_from is not None:
        query = query.filter(
            WorkoutSession.started_at
            >= datetime.combine(date_from, datetime.min.time())
        )
    if date_to is not None:
        query = query.filter(
            WorkoutSession.started_at <= datetime.combine(date_to, datetime.max.time())
        )
    if exercise_id is not None:
        query = (
            query.join(WorkoutSession.sets)
            .filter(WorkoutSet.exercise_id == exercise_id)
            .distinct()
        )
    if muscle_group is not None:
        query = (
            query.join(WorkoutSession.sets)
            .join(WorkoutSet.exercise)
            .filter(Exercise.muscle_group == muscle_group)
            .distinct()
        )
    return query.order_by(WorkoutSession.started_at.desc()).all()


@router.post(
    "/{session_id}/sets",
    response_model=WorkoutSetResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_set(
    session_id: int,
    payload: WorkoutSetCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> WorkoutSet:
    session = _get_owned_session(session_id, current_user, db)

    exercise = db.get(Exercise, payload.exercise_id)
    if not exercise:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Ejercicio no encontrado"
        )

    workout_set = WorkoutSet(session_id=session.id, **payload.model_dump())
    db.add(workout_set)
    db.flush()

    check_and_save_records(db, current_user.id, workout_set)
    db.commit()
    db.refresh(workout_set)
    return workout_set


@router.patch("/sets/{set_id}", response_model=WorkoutSetResponse)
def update_set(
    set_id: int,
    payload: WorkoutSetUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> WorkoutSet:
    workout_set = db.get(WorkoutSet, set_id)
    if not workout_set or workout_set.session.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Serie no encontrada"
        )

    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(workout_set, field, value)
    db.flush()

    check_and_save_records(db, current_user.id, workout_set)
    db.commit()
    db.refresh(workout_set)
    return workout_set


@router.delete("/sets/{set_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_set(
    set_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    workout_set = db.get(WorkoutSet, set_id)
    if not workout_set or workout_set.session.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Serie no encontrada"
        )
    db.delete(workout_set)
    db.commit()


@router.get("/{session_id}/records", response_model=list[PersonalRecordResponse])
def get_session_records(
    session_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = _get_owned_session(session_id, current_user, db)
    set_ids = [s.id for s in session.sets]
    if not set_ids:
        return []
    return (
        db.query(PersonalRecord)
        .filter(PersonalRecord.workout_set_id.in_(set_ids))
        .all()
    )
