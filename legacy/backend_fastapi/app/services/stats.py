from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.exercise import Exercise
from app.models.record import PersonalRecord, RecordType
from app.models.workout import WorkoutSession, WorkoutSet


def _since(days: int) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=days)


def get_muscle_volume(db: Session, user_id: int, days: int) -> list[dict]:
    cutoff = _since(days)
    rows = (
        db.query(
            Exercise.muscle_group,
            func.count(WorkoutSet.id),
            func.coalesce(func.sum(WorkoutSet.weight_kg * WorkoutSet.reps), 0.0),
            func.max(WorkoutSession.started_at),
        )
        .join(WorkoutSet, WorkoutSet.exercise_id == Exercise.id)
        .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSession.started_at >= cutoff,
            WorkoutSet.is_warmup.is_(False),
        )
        .group_by(Exercise.muscle_group)
        .all()
    )

    trained = {
        muscle_group: {
            "muscle_group": muscle_group,
            "total_sets": total_sets,
            "total_volume": float(total_volume),
            "last_trained_at": last_trained_at,
        }
        for muscle_group, total_sets, total_volume, last_trained_at in rows
    }

    all_muscle_groups = {
        row[0] for row in db.query(Exercise.muscle_group).distinct().all()
    }
    volumes = sorted((v["total_volume"] for v in trained.values()), reverse=True)

    def _level(volume: float) -> str:
        if volume <= 0:
            return "muy_bajo"
        rank = sum(1 for v in volumes if v > volume) / len(volumes)
        if rank < 1 / 3:
            return "alto"
        if rank < 2 / 3:
            return "medio"
        return "bajo"

    result = []
    for muscle_group in all_muscle_groups:
        entry = trained.get(
            muscle_group,
            {
                "muscle_group": muscle_group,
                "total_sets": 0,
                "total_volume": 0.0,
                "last_trained_at": None,
            },
        )
        entry["level"] = _level(entry["total_volume"])
        result.append(entry)

    return sorted(result, key=lambda e: e["total_volume"], reverse=True)


def get_strength_profile(db: Session, user_id: int) -> dict:
    max_weight_rows = (
        db.query(PersonalRecord.exercise_id, func.max(PersonalRecord.value))
        .filter(
            PersonalRecord.user_id == user_id,
            PersonalRecord.record_type == RecordType.MAX_WEIGHT,
        )
        .group_by(PersonalRecord.exercise_id)
        .all()
    )
    exercise_ids = [exercise_id for exercise_id, _ in max_weight_rows]
    exercises_by_id = {
        e.id: e for e in db.query(Exercise).filter(Exercise.id.in_(exercise_ids)).all()
    }
    max_strength = [
        {
            "exercise_id": exercise_id,
            "exercise_name": exercises_by_id[exercise_id].name,
            "max_weight_kg": value,
        }
        for exercise_id, value in max_weight_rows
        if exercise_id in exercises_by_id
    ]

    weekly_volume = float(
        db.query(func.coalesce(func.sum(WorkoutSet.weight_kg * WorkoutSet.reps), 0.0))
        .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSession.started_at >= _since(7),
            WorkoutSet.is_warmup.is_(False),
        )
        .scalar()
        or 0.0
    )

    frequency_rows = (
        db.query(Exercise.muscle_group, func.count(func.distinct(WorkoutSession.id)))
        .join(WorkoutSet, WorkoutSet.exercise_id == Exercise.id)
        .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSession.started_at >= _since(7),
            WorkoutSet.is_warmup.is_(False),
        )
        .group_by(Exercise.muscle_group)
        .all()
    )

    return {
        "max_strength_by_exercise": max_strength,
        "weekly_volume_kg": weekly_volume,
        "weekly_frequency_by_muscle": [
            {"muscle_group": muscle_group, "sessions": sessions}
            for muscle_group, sessions in frequency_rows
        ],
    }


def get_exercise_progress(db: Session, user_id: int, exercise_id: int) -> list[dict]:
    rows = (
        db.query(
            WorkoutSession.id,
            WorkoutSession.started_at,
            func.max(WorkoutSet.weight_kg),
            func.coalesce(func.sum(WorkoutSet.weight_kg * WorkoutSet.reps), 0.0),
        )
        .join(WorkoutSet, WorkoutSet.session_id == WorkoutSession.id)
        .filter(
            WorkoutSession.user_id == user_id,
            WorkoutSet.exercise_id == exercise_id,
            WorkoutSet.is_warmup.is_(False),
        )
        .group_by(WorkoutSession.id, WorkoutSession.started_at)
        .order_by(WorkoutSession.started_at.asc())
        .all()
    )

    return [
        {
            "session_id": session_id,
            "date": started_at,
            "max_weight_kg": max_weight,
            "volume_kg": float(volume),
        }
        for session_id, started_at, max_weight, volume in rows
    ]


def _period_key(day: date, period: str) -> str:
    if period == "month":
        return day.replace(day=1).isoformat()
    return (day - timedelta(days=day.weekday())).isoformat()


def get_tonnage_history(
    db: Session, user_id: int, period: str, periods: int
) -> list[dict]:
    rows = (
        db.query(WorkoutSession.started_at, WorkoutSet.weight_kg, WorkoutSet.reps)
        .join(WorkoutSet, WorkoutSet.session_id == WorkoutSession.id)
        .filter(WorkoutSession.user_id == user_id, WorkoutSet.is_warmup.is_(False))
        .all()
    )

    buckets: dict[str, float] = {}
    for started_at, weight_kg, reps in rows:
        key = _period_key(started_at.date(), period)
        buckets[key] = buckets.get(key, 0.0) + weight_kg * reps

    today = datetime.now(timezone.utc).date()
    result = []
    for i in range(periods - 1, -1, -1):
        if period == "month":
            month_index = today.month - 1 - i
            year = today.year + month_index // 12
            month = month_index % 12 + 1
            start = date(year, month, 1)
        else:
            start = today - timedelta(days=today.weekday()) - timedelta(weeks=i)
        key = start.isoformat()
        result.append(
            {"period_start": start, "total_tonnage_kg": round(buckets.get(key, 0.0), 1)}
        )

    return result


def get_training_streak(db: Session, user_id: int) -> dict:
    session_dates = sorted(
        {
            started_at.date()
            for (started_at,) in db.query(WorkoutSession.started_at)
            .filter(WorkoutSession.user_id == user_id)
            .all()
        }
    )

    if not session_dates:
        return {
            "current_streak_days": 0,
            "longest_streak_days": 0,
            "last_trained_at": None,
        }

    longest_streak = 1
    run = 1
    for previous_day, current_day in zip(session_dates, session_dates[1:]):
        if (current_day - previous_day).days == 1:
            run += 1
        else:
            run = 1
        longest_streak = max(longest_streak, run)

    today = datetime.now(timezone.utc).date()
    last_day = session_dates[-1]
    current_streak = 0
    if (today - last_day).days <= 1:
        current_streak = 1
        for previous_day, current_day in zip(
            reversed(session_dates[:-1]), reversed(session_dates[1:])
        ):
            if (current_day - previous_day).days == 1:
                current_streak += 1
            else:
                break

    return {
        "current_streak_days": current_streak,
        "longest_streak_days": longest_streak,
        "last_trained_at": last_day,
    }
