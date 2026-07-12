from sqlalchemy.orm import Session

from app.models.record import PersonalRecord, RecordType
from app.models.workout import WorkoutSet


def _best_previous(
    db: Session, user_id: int, exercise_id: int, record_type: RecordType
) -> float | None:
    record = (
        db.query(PersonalRecord)
        .filter(
            PersonalRecord.user_id == user_id,
            PersonalRecord.exercise_id == exercise_id,
            PersonalRecord.record_type == record_type,
        )
        .order_by(PersonalRecord.value.desc())
        .first()
    )
    return record.value if record else None


def check_and_save_records(
    db: Session, user_id: int, workout_set: WorkoutSet
) -> list[PersonalRecord]:
    if workout_set.is_warmup:
        return []

    exercise_id = workout_set.exercise_id
    candidates = {
        RecordType.MAX_WEIGHT: workout_set.weight_kg,
        RecordType.MAX_REPS: float(workout_set.reps),
        RecordType.MAX_VOLUME: workout_set.weight_kg * workout_set.reps,
    }

    new_records: list[PersonalRecord] = []
    for record_type, value in candidates.items():
        if value <= 0:
            continue
        previous = _best_previous(db, user_id, exercise_id, record_type)
        if previous is None or value > previous:
            record = PersonalRecord(
                user_id=user_id,
                exercise_id=exercise_id,
                workout_set_id=workout_set.id,
                record_type=record_type,
                value=value,
                previous_value=previous,
            )
            db.add(record)
            new_records.append(record)

    if new_records:
        db.flush()
    return new_records
