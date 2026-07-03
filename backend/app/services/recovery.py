from sqlalchemy.orm import Session

from app.models.recovery import DailyCheckIn
from app.services.stats import get_tonnage_history

SLEEP_TARGET_HOURS = 8.0


def _clamp(value: float, low: float = 0, high: float = 100) -> float:
    return max(low, min(high, value))


def compute_recovery_index(db: Session, user_id: int) -> dict | None:
    checkin = (
        db.query(DailyCheckIn)
        .filter(DailyCheckIn.user_id == user_id)
        .order_by(DailyCheckIn.checkin_date.desc())
        .first()
    )
    if checkin is None:
        return None

    sleep_score = _clamp((checkin.sleep_hours / SLEEP_TARGET_HOURS) * 100)
    fatigue_score = _clamp((10 - checkin.perceived_fatigue) * 10)

    tonnage = get_tonnage_history(db, user_id, period="week", periods=5)
    this_week = tonnage[-1]["total_tonnage_kg"]
    previous_weeks = [
        t["total_tonnage_kg"] for t in tonnage[:-1] if t["total_tonnage_kg"] > 0
    ]
    avg_previous = sum(previous_weeks) / len(previous_weeks) if previous_weeks else 0

    if avg_previous > 0:
        overload_ratio = this_week / avg_previous
        load_score = _clamp(100 - max(0, overload_ratio - 1) * 100)
    else:
        load_score = 100.0

    recovery_index = round(0.4 * sleep_score + 0.3 * fatigue_score + 0.3 * load_score)

    if recovery_index >= 80:
        level = "recovered"
    elif recovery_index >= 50:
        level = "medium"
    else:
        level = "high_fatigue_risk"

    return {
        "recovery_index": recovery_index,
        "level": level,
        "sleep_hours": checkin.sleep_hours,
        "perceived_fatigue": checkin.perceived_fatigue,
        "checkin_date": checkin.checkin_date,
    }
