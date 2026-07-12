from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.recovery import DailyCheckIn
from app.models.nutrition import NutritionLog
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


def _day_block(db: Session, user_id: int, day: date) -> str | None:
    """Arma el resumen de un dia puntual (entrenamiento/nutricion/check-in). Devuelve
    None si no hay ningun dato registrado ese dia."""
    lines = []

    sessions = (
        db.query(WorkoutSession)
        .filter(
            WorkoutSession.user_id == user_id,
            func.date(WorkoutSession.started_at) == day,
        )
        .all()
    )
    if sessions:
        set_lines = []
        for session in sessions:
            for workout_set in session.sets:
                tag = " (calentamiento)" if workout_set.is_warmup else ""
                set_lines.append(
                    f"{workout_set.exercise.name} {workout_set.weight_kg}kg x "
                    f"{workout_set.reps} reps{tag}"
                )
        if set_lines:
            lines.append("Entrenamiento: " + "; ".join(set_lines) + ".")
        else:
            lines.append("Se inicio un entrenamiento pero sin series registradas.")

    nutrition = (
        db.query(NutritionLog)
        .filter(NutritionLog.user_id == user_id, NutritionLog.log_date == day)
        .first()
    )
    if nutrition:
        lines.append(
            f"Nutricion: {nutrition.calories:.0f} kcal, {nutrition.protein_g:.0f}g "
            f"proteina, {nutrition.carbs_g:.0f}g carbohidratos, {nutrition.fat_g:.0f}g "
            f"grasa, {nutrition.water_ml:.0f}ml agua."
        )

    checkin = (
        db.query(DailyCheckIn)
        .filter(DailyCheckIn.user_id == user_id, DailyCheckIn.checkin_date == day)
        .first()
    )
    if checkin:
        lines.append(
            f"Check-in: {checkin.sleep_hours:.1f}hs de sueno, "
            f"fatiga percibida {checkin.perceived_fatigue}/10."
        )

    if not lines:
        return None
    return " ".join(lines)


MAX_ACTIVITY_LOG_DAYS = 90


def get_activity_log(db: Session, user_id: int, start: date, end: date) -> str:
    """Devuelve el detalle dia por dia (entrenamiento/nutricion/check-in) de un rango
    de fechas. Pensado para ser invocado por el coach IA via tool calling cuando el
    usuario pregunta por una fecha o periodo especifico."""
    if end < start:
        start, end = end, start

    truncated_note = ""
    if (end - start).days + 1 > MAX_ACTIVITY_LOG_DAYS:
        start = end - timedelta(days=MAX_ACTIVITY_LOG_DAYS - 1)
        truncated_note = f" (rango acotado a los ultimos {MAX_ACTIVITY_LOG_DAYS} dias)"

    lines = []
    day = start
    while day <= end:
        block = _day_block(db, user_id, day)
        if block:
            lines.append(f"{day.isoformat()}: {block}")
        day += timedelta(days=1)

    if not lines:
        return (
            f"No hay datos registrados entre {start.isoformat()} y "
            f"{end.isoformat()}{truncated_note}."
        )
    return f"Historial{truncated_note}:\n" + "\n".join(lines)


def _today_summary(db: Session, user_id: int) -> str:
    today = date.today()
    block = _day_block(db, user_id, today)
    if block is None:
        return "Hoy todavia no registraste ningun entrenamiento, nutricion ni check-in."
    return f"Hoy: {block}"


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

    lines.append(_today_summary(db, user_id))

    return "\n".join(lines)


SYSTEM_PROMPT = """Sos el entrenador personal con IA de AppGym, un "Gemelo Digital" que conoce
el historial de entrenamiento del usuario. Respondes en espanol, de forma breve, concreta y
basandote UNICAMENTE en los datos de contexto provistos o en los que obtengas con la
herramienta disponible. El contexto ya incluye un resumen agregado (volumen semanal, racha,
records) y el detalle de hoy. Si te preguntan por un dia o periodo especifico que no este
cubierto por ese resumen (ayer, el mes pasado, una fecha puntual, etc.), usa la herramienta
"consultar_historial" para pedir el detalle de ese rango de fechas antes de responder. Si ni
el contexto ni la herramienta alcanzan para responder algo con precision, decilo
explicitamente en vez de inventar numeros o afirmaciones sobre el historial del usuario. No
des consejos medicos; ante dolor o lesion, sugerí consultar a un profesional de la salud."""
