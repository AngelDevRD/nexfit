from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.goal import Goal
from app.models.user import User
from app.schemas.calendar import CalendarOverviewResponse
from app.services.calendar import (
    get_deload_recommendation,
    get_upcoming_record_predictions,
)
from app.services.goals import compute_goal_progress

router = APIRouter(prefix="/api/v1/calendar", tags=["calendar"])


@router.get("/overview", response_model=CalendarOverviewResponse)
def calendar_overview(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> dict:
    goals = (
        db.query(Goal)
        .filter(Goal.user_id == current_user.id, Goal.achieved_at.is_(None))
        .order_by(Goal.target_date.asc().nulls_last())
        .all()
    )
    upcoming_goals = [
        {
            "id": g.id,
            "title": g.title,
            "metric": g.metric,
            "exercise_id": g.exercise_id,
            "starting_value": g.starting_value,
            "target_value": g.target_value,
            "target_date": g.target_date,
            "achieved_at": g.achieved_at,
            **compute_goal_progress(db, current_user, g),
        }
        for g in goals
    ]

    return {
        "upcoming_goals": upcoming_goals,
        "deload": get_deload_recommendation(db, current_user.id),
        "upcoming_record_predictions": get_upcoming_record_predictions(
            db, current_user.id
        ),
    }
