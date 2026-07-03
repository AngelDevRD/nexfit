from sqlalchemy.orm import Session

from app.data.strength_standards import (
    LEVEL_LABELS,
    LEVEL_PERCENTILES,
    STRENGTH_STANDARDS,
)
from app.models.exercise import Exercise
from app.models.record import PersonalRecord, RecordType
from app.models.user import User


def _interpolate_percentile(ratio: float, thresholds: list[float]) -> float:
    if ratio <= thresholds[0]:
        return (
            round(LEVEL_PERCENTILES[0] * ratio / thresholds[0], 1)
            if thresholds[0] > 0
            else 0.0
        )
    if ratio >= thresholds[-1]:
        return float(LEVEL_PERCENTILES[-1])

    for i in range(len(thresholds) - 1):
        lower, upper = thresholds[i], thresholds[i + 1]
        if lower <= ratio <= upper:
            span = upper - lower
            fraction = (ratio - lower) / span if span > 0 else 0
            percentile = LEVEL_PERCENTILES[i] + fraction * (
                LEVEL_PERCENTILES[i + 1] - LEVEL_PERCENTILES[i]
            )
            return round(percentile, 1)
    return float(LEVEL_PERCENTILES[-1])


def _level_label(ratio: float, thresholds: list[float]) -> str:
    level = LEVEL_LABELS[0]
    for label, threshold in zip(LEVEL_LABELS, thresholds):
        if ratio >= threshold:
            level = label
    return level


def compare_to_strength_standards(
    db: Session, user: User, exercise_id: int
) -> dict | None:
    exercise = db.get(Exercise, exercise_id)
    if not exercise or exercise.slug not in STRENGTH_STANDARDS:
        return None
    if not user.weight_kg or not user.sex:
        return None

    thresholds = STRENGTH_STANDARDS[exercise.slug].get(user.sex.value)
    if not thresholds:
        return None

    best_lift = (
        db.query(PersonalRecord)
        .filter(
            PersonalRecord.user_id == user.id,
            PersonalRecord.exercise_id == exercise_id,
            PersonalRecord.record_type == RecordType.MAX_WEIGHT,
        )
        .order_by(PersonalRecord.value.desc())
        .first()
    )
    if not best_lift:
        return None

    ratio = best_lift.value / user.weight_kg
    return {
        "exercise_id": exercise_id,
        "exercise_name": exercise.name,
        "lift_kg": best_lift.value,
        "bodyweight_kg": user.weight_kg,
        "ratio": round(ratio, 2),
        "percentile": _interpolate_percentile(ratio, thresholds),
        "level": _level_label(ratio, thresholds),
    }
