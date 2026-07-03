from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.routine import Routine, RoutineDay, RoutineExercise
from app.models.user import User
from app.schemas.routine import RoutineCreate, RoutineResponse, RoutineSummary

router = APIRouter(prefix="/api/v1/routines", tags=["routines"])


def _get_owned_routine(routine_id: int, user: User, db: Session) -> Routine:
    routine = db.get(Routine, routine_id)
    if not routine or routine.user_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Rutina no encontrada"
        )
    return routine


@router.post("", response_model=RoutineResponse, status_code=status.HTTP_201_CREATED)
def create_routine(
    payload: RoutineCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Routine:
    routine = Routine(
        user_id=current_user.id,
        name=payload.name,
        goal=payload.goal,
        days_per_week=payload.days_per_week,
    )
    for day_payload in payload.days:
        day = RoutineDay(
            day_index=day_payload.day_index,
            name=day_payload.name,
            muscle_focus=day_payload.muscle_focus,
        )
        for ex_payload in day_payload.exercises:
            day.exercises.append(
                RoutineExercise(
                    exercise_id=ex_payload.exercise_id,
                    order=ex_payload.order,
                    target_sets=ex_payload.target_sets,
                    target_reps_min=ex_payload.target_reps_min,
                    target_reps_max=ex_payload.target_reps_max,
                    target_rest_seconds=ex_payload.target_rest_seconds,
                    notes=ex_payload.notes,
                )
            )
        routine.days.append(day)

    db.add(routine)
    db.commit()
    db.refresh(routine)
    return routine


@router.get("", response_model=list[RoutineSummary])
def list_routines(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[Routine]:
    return (
        db.query(Routine)
        .filter(Routine.user_id == current_user.id)
        .order_by(Routine.id.desc())
        .all()
    )


@router.get("/{routine_id}", response_model=RoutineResponse)
def get_routine(
    routine_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Routine:
    return _get_owned_routine(routine_id, current_user, db)


@router.delete("/{routine_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_routine(
    routine_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    routine = _get_owned_routine(routine_id, current_user, db)
    db.delete(routine)
    db.commit()
