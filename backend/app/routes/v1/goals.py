from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.goal import Goal, GoalMetric
from app.models.user import User
from app.schemas.goal import GoalCreate, GoalResponse
from app.services.goals import compute_goal_progress, get_current_value

router = APIRouter(prefix="/api/v1/goals", tags=["goals"])


def _serialize(db: Session, user: User, goal: Goal) -> dict:
    progress = compute_goal_progress(db, user, goal)
    return {
        "id": goal.id,
        "title": goal.title,
        "metric": goal.metric,
        "exercise_id": goal.exercise_id,
        "starting_value": goal.starting_value,
        "target_value": goal.target_value,
        "target_date": goal.target_date,
        "achieved_at": goal.achieved_at,
        **progress,
    }


@router.post("", response_model=GoalResponse, status_code=status.HTTP_201_CREATED)
def create_goal(
    payload: GoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    if (
        payload.metric in (GoalMetric.EXERCISE_MAX_WEIGHT, GoalMetric.EXERCISE_MAX_REPS)
        and not payload.exercise_id
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="exercise_id es requerido para este tipo de objetivo",
        )

    starting_value = (
        get_current_value(db, current_user, payload.metric, payload.exercise_id) or 0.0
    )

    goal = Goal(
        user_id=current_user.id,
        title=payload.title,
        metric=payload.metric,
        exercise_id=payload.exercise_id,
        starting_value=starting_value,
        target_value=payload.target_value,
        target_date=payload.target_date,
    )
    db.add(goal)
    db.commit()
    db.refresh(goal)
    return _serialize(db, current_user, goal)


@router.get("", response_model=list[GoalResponse])
def list_goals(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> list[dict]:
    goals = (
        db.query(Goal)
        .filter(Goal.user_id == current_user.id)
        .order_by(Goal.created_at.desc())
        .all()
    )
    return [_serialize(db, current_user, g) for g in goals]


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    goal = db.get(Goal, goal_id)
    if not goal or goal.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Objetivo no encontrado"
        )
    db.delete(goal)
    db.commit()
