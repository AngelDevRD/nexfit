from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.goal import Goal, GoalMetric
from app.models.record import PersonalRecord, RecordType
from app.models.user import User


def get_current_value(
    db: Session, user: User, metric: GoalMetric, exercise_id: int | None
) -> float | None:
    if metric == GoalMetric.BODY_WEIGHT_KG:
        return user.weight_kg
    if metric == GoalMetric.BODY_FAT_PCT:
        return user.body_fat_pct

    record_type = (
        RecordType.MAX_WEIGHT
        if metric == GoalMetric.EXERCISE_MAX_WEIGHT
        else RecordType.MAX_REPS
    )
    best = (
        db.query(PersonalRecord)
        .filter(
            PersonalRecord.user_id == user.id,
            PersonalRecord.exercise_id == exercise_id,
            PersonalRecord.record_type == record_type,
        )
        .order_by(PersonalRecord.value.desc())
        .first()
    )
    return best.value if best else 0.0


def compute_goal_progress(db: Session, user: User, goal: Goal) -> dict:
    current = get_current_value(db, user, goal.metric, goal.exercise_id)
    current = current if current is not None else goal.starting_value

    increasing = goal.target_value >= goal.starting_value
    span = abs(goal.target_value - goal.starting_value)

    if span == 0:
        progress_pct = 100.0 if current == goal.target_value else 0.0
    elif increasing:
        progress_pct = max(
            0.0, min(100.0, (current - goal.starting_value) / span * 100)
        )
    else:
        progress_pct = max(
            0.0, min(100.0, (goal.starting_value - current) / span * 100)
        )

    achieved = (
        (current >= goal.target_value) if increasing else (current <= goal.target_value)
    )
    if achieved and goal.achieved_at is None:
        goal.achieved_at = datetime.now(timezone.utc)
        db.commit()

    return {
        "current_value": current,
        "progress_pct": round(progress_pct, 1),
        "achieved": achieved,
    }
