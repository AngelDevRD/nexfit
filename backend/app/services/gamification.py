from sqlalchemy import func

from sqlalchemy.orm import Session

from app.models.record import PersonalRecord
from app.models.workout import WorkoutSession, WorkoutSet
from app.services.stats import get_training_streak

XP_PER_SESSION = 10
XP_PER_SET = 1
XP_PER_RECORD = 25
XP_PER_LONGEST_STREAK_DAY = 2

LEVEL_BANDS = [
    (20, "elite"),
    (10, "advanced"),
    (5, "intermediate"),
    (1, "novice"),
]


def _level_for_xp(total_xp: float) -> tuple[int, float, float]:
    level = 1
    while 100 * level**2 <= total_xp:
        level += 1
    current_threshold = 100 * (level - 1) ** 2
    next_threshold = 100 * level**2
    progress_pct = round(
        (total_xp - current_threshold) / (next_threshold - current_threshold) * 100, 1
    )
    return level, next_threshold - total_xp, progress_pct


def _band_for_level(level: int) -> str:
    for min_level, band in LEVEL_BANDS:
        if level >= min_level:
            return band
    return "novice"


def get_gamification_profile(db: Session, user_id: int) -> dict:
    sessions_completed = (
        db.query(func.count(WorkoutSession.id))
        .filter(WorkoutSession.user_id == user_id, WorkoutSession.ended_at.isnot(None))
        .scalar()
        or 0
    )
    sets_logged = (
        db.query(func.count(WorkoutSet.id))
        .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
        .filter(WorkoutSession.user_id == user_id, WorkoutSet.is_warmup.is_(False))
        .scalar()
        or 0
    )
    records_count = (
        db.query(func.count(PersonalRecord.id))
        .filter(PersonalRecord.user_id == user_id)
        .scalar()
        or 0
    )
    streak = get_training_streak(db, user_id)
    lifetime_tonnage = (
        db.query(func.coalesce(func.sum(WorkoutSet.weight_kg * WorkoutSet.reps), 0.0))
        .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
        .filter(WorkoutSession.user_id == user_id, WorkoutSet.is_warmup.is_(False))
        .scalar()
        or 0.0
    )

    total_xp = (
        sessions_completed * XP_PER_SESSION
        + sets_logged * XP_PER_SET
        + records_count * XP_PER_RECORD
        + streak["longest_streak_days"] * XP_PER_LONGEST_STREAK_DAY
    )

    level, xp_to_next_level, progress_pct = _level_for_xp(total_xp)

    achievements = [
        {
            "code": "first_workout",
            "title": "Primer entrenamiento",
            "unlocked": sessions_completed >= 1,
        },
        {
            "code": "100_workouts",
            "title": "100 entrenamientos",
            "unlocked": sessions_completed >= 100,
        },
        {
            "code": "first_pr",
            "title": "Primer record personal",
            "unlocked": records_count >= 1,
        },
        {
            "code": "100_prs",
            "title": "100 records personales",
            "unlocked": records_count >= 100,
        },
        {
            "code": "30_day_streak",
            "title": "30 dias consecutivos entrenando",
            "unlocked": streak["longest_streak_days"] >= 30,
        },
        {
            "code": "million_kg",
            "title": "1,000,000 kg levantados en total",
            "unlocked": lifetime_tonnage >= 1_000_000,
        },
    ]

    return {
        "level": level,
        "level_band": _band_for_level(level),
        "total_xp": total_xp,
        "xp_to_next_level": xp_to_next_level,
        "progress_pct": progress_pct,
        "sessions_completed": sessions_completed,
        "records_count": records_count,
        "longest_streak_days": streak["longest_streak_days"],
        "lifetime_tonnage_kg": round(lifetime_tonnage, 1),
        "achievements": achievements,
    }
