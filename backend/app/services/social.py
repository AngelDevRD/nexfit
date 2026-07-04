import secrets
import string
from datetime import datetime, time

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.social import Challenge, ChallengeMetric, ChallengeParticipant
from app.models.user import User
from app.models.workout import WorkoutSession, WorkoutSet

_CODE_ALPHABET = string.ascii_uppercase + string.digits  # sin ambiguos no vale la pena


def generate_invite_code(db: Session, length: int = 6) -> str:
    """Genera un codigo de invitacion unico (reintenta si colisiona)."""
    for _ in range(10):
        code = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(length))
        exists = db.query(Challenge.id).filter(Challenge.invite_code == code).first()
        if not exists:
            return code
    raise RuntimeError("No se pudo generar un codigo de invitacion unico")


def _date_bounds(challenge: Challenge) -> tuple[datetime, datetime]:
    """Rango [inicio 00:00, fin+1 00:00) para incluir todo el dia final."""
    start = datetime.combine(challenge.starts_on, time.min)
    # fin exclusivo: medianoche del dia siguiente al ends_on
    end = datetime.combine(challenge.ends_on, time.max)
    return start, end


def _value_for_user(db: Session, challenge: Challenge, user_id: int) -> float:
    start, end = _date_bounds(challenge)
    session_filter = (
        WorkoutSession.user_id == user_id,
        WorkoutSession.started_at >= start,
        WorkoutSession.started_at <= end,
    )

    if challenge.metric == ChallengeMetric.TOTAL_SESSIONS:
        count = db.query(func.count(WorkoutSession.id)).filter(*session_filter).scalar()
        return float(count or 0)

    query = (
        db.query(
            func.coalesce(
                func.sum(
                    WorkoutSet.weight_kg * WorkoutSet.reps
                    if challenge.metric == ChallengeMetric.TOTAL_VOLUME_KG
                    else WorkoutSet.reps
                ),
                0,
            )
        )
        .join(WorkoutSession, WorkoutSet.session_id == WorkoutSession.id)
        .filter(*session_filter)
        .filter(WorkoutSet.is_warmup.is_(False))
    )
    return float(query.scalar() or 0)


def build_leaderboard(db: Session, challenge: Challenge, me_id: int) -> list[dict]:
    """Ranking de participantes por la metrica del reto, de mayor a menor."""
    rows = []
    for participant in challenge.participants:
        user = db.get(User, participant.user_id)
        if user is None:
            continue
        rows.append(
            {
                "user_id": user.id,
                "name": user.name,
                "value": _value_for_user(db, challenge, user.id),
                "is_me": user.id == me_id,
            }
        )

    rows.sort(key=lambda r: r["value"], reverse=True)
    for index, row in enumerate(rows, start=1):
        row["rank"] = index
    return rows


def get_membership(
    db: Session, challenge_id: int, user_id: int
) -> ChallengeParticipant | None:
    return (
        db.query(ChallengeParticipant)
        .filter(
            ChallengeParticipant.challenge_id == challenge_id,
            ChallengeParticipant.user_id == user_id,
        )
        .first()
    )
