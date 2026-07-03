from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.workout import WorkoutSession
from app.services.stats import (
    get_muscle_volume,
    get_strength_profile,
    get_training_streak,
)


def _months_training(db: Session, user_id: int) -> int:
    first_session = (
        db.query(WorkoutSession)
        .filter(WorkoutSession.user_id == user_id)
        .order_by(WorkoutSession.started_at.asc())
        .first()
    )
    if not first_session:
        return 0
    started_at = first_session.started_at
    now = datetime.now(timezone.utc) if started_at.tzinfo else datetime.now()
    days = (now - started_at).days
    return max(0, days // 30)


def _muscle_frequency_trend(db: Session, user_id: int) -> list[str]:
    recent = {
        e["muscle_group"]: e["total_volume"]
        for e in get_muscle_volume(db, user_id, days=30)
    }
    older = {
        e["muscle_group"]: e["total_volume"]
        for e in get_muscle_volume(db, user_id, days=60)
    }

    notes = []
    for muscle_group, recent_volume in recent.items():
        older_volume = max(older.get(muscle_group, 0) - recent_volume, 0)
        if older_volume > 0 and recent_volume < older_volume * 0.6:
            drop_pct = round((1 - recent_volume / older_volume) * 100)
            notes.append(
                f"{muscle_group}: el volumen bajo un {drop_pct}% respecto al mes anterior"
            )
    return notes


def build_user_context(db: Session, user_id: int, user_name: str) -> str:
    months = _months_training(db, user_id)
    strength = get_strength_profile(db, user_id)
    streak = get_training_streak(db, user_id)
    trend_notes = _muscle_frequency_trend(db, user_id)

    lines = [f"Usuario: {user_name}. Meses entrenando en la app: {months}."]
    lines.append(f"Volumen de esta semana: {strength['weekly_volume_kg']:.0f} kg.")
    lines.append(
        f"Racha actual: {streak['current_streak_days']} dias. Mejor racha: {streak['longest_streak_days']} dias."
    )

    if strength["max_strength_by_exercise"]:
        lifts = ", ".join(
            f"{e['exercise_name']} {e['max_weight_kg']}kg"
            for e in strength["max_strength_by_exercise"]
        )
        lines.append(f"Mejores marcas registradas: {lifts}.")
    else:
        lines.append("Todavia no tiene records personales registrados.")

    if trend_notes:
        lines.append("Cambios de tendencia detectados: " + "; ".join(trend_notes) + ".")

    return "\n".join(lines)


SYSTEM_PROMPT = """Sos el entrenador personal con IA de AppGym, un "Gemelo Digital" que conoce
el historial de entrenamiento del usuario. Respondes en espanol, de forma breve, concreta y
basandote UNICAMENTE en los datos de contexto provistos. Si el contexto no alcanza para responder
algo con precision, decilo explicitamente en vez de inventar numeros o afirmaciones sobre el
historial del usuario. No des consejos medicos; ante dolor o lesion, sugerí consultar a un
profesional de la salud."""
