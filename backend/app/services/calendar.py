from sqlalchemy.orm import Session

from app.services.predictions import predict_next_record
from app.services.stats import get_strength_profile, get_tonnage_history


def get_deload_recommendation(db: Session, user_id: int) -> dict:
    tonnage = get_tonnage_history(db, user_id, period="week", periods=5)
    values = [t["total_tonnage_kg"] for t in tonnage]

    baseline = values[:3]
    recent = values[3:]
    baseline_avg = sum(baseline) / len(baseline) if baseline else 0
    recent_avg = sum(recent) / len(recent) if recent else 0

    if baseline_avg > 0 and recent_avg > baseline_avg * 1.3:
        return {
            "recommended": True,
            "reason": "Tu volumen de entrenamiento viene en aumento sostenido las últimas semanas. "
            "Considerá una semana de descarga para favorecer la recuperación.",
        }
    return {
        "recommended": False,
        "reason": "Tu volumen reciente está dentro de un rango normal.",
    }


def get_upcoming_record_predictions(
    db: Session, user_id: int, weeks_ahead: int = 8
) -> list[dict]:
    profile = get_strength_profile(db, user_id)
    predictions = []
    for entry in profile["max_strength_by_exercise"]:
        prediction = predict_next_record(db, user_id, entry["exercise_id"], weeks_ahead)
        if prediction:
            predictions.append(prediction)
    return predictions
