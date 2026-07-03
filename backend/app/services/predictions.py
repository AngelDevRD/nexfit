from sqlalchemy.orm import Session

from app.models.exercise import Exercise
from app.models.record import PersonalRecord, RecordType

MIN_DATA_POINTS = 3


def predict_next_record(
    db: Session, user_id: int, exercise_id: int, weeks_ahead: int = 8
) -> dict | None:
    exercise = db.get(Exercise, exercise_id)
    if not exercise:
        return None

    records = (
        db.query(PersonalRecord)
        .filter(
            PersonalRecord.user_id == user_id,
            PersonalRecord.exercise_id == exercise_id,
            PersonalRecord.record_type == RecordType.MAX_WEIGHT,
        )
        .order_by(PersonalRecord.achieved_at.asc())
        .all()
    )
    if len(records) < MIN_DATA_POINTS:
        return None

    first_date = records[0].achieved_at
    xs = [(r.achieved_at - first_date).days for r in records]
    ys = [r.value for r in records]
    n = len(xs)

    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    numerator = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    denominator = sum((x - mean_x) ** 2 for x in xs)
    if denominator == 0:
        return None

    slope = numerator / denominator
    intercept = mean_y - slope * mean_x

    target_x = xs[-1] + weeks_ahead * 7
    predicted = intercept + slope * target_x

    if predicted <= ys[-1]:
        return None

    return {
        "exercise_id": exercise_id,
        "exercise_name": exercise.name,
        "current_best_kg": ys[-1],
        "predicted_kg": round(predicted, 1),
        "weeks_ahead": weeks_ahead,
        "data_points": n,
    }
