from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models.goal import Goal
from app.models.nutrition import NutritionLog
from app.models.recovery import DailyCheckIn
from app.models.routine import Routine, RoutineDay, RoutineExercise
from app.models.user import User
from app.models.workout import WorkoutSession, WorkoutSet
from app.schemas.data_transfer import ExportData, ExportEnvelope, ImportSummary

router = APIRouter(prefix="/api/v1/users/me", tags=["data-transfer"])


@router.get("/export", response_model=ExportEnvelope)
def export_data(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> ExportEnvelope:
    routines = (
        db.query(Routine)
        .filter(Routine.user_id == current_user.id)
        .order_by(Routine.id)
        .all()
    )
    sessions = (
        db.query(WorkoutSession)
        .filter(WorkoutSession.user_id == current_user.id)
        .order_by(WorkoutSession.started_at)
        .all()
    )
    nutrition_logs = (
        db.query(NutritionLog)
        .filter(NutritionLog.user_id == current_user.id)
        .order_by(NutritionLog.log_date)
        .all()
    )
    checkins = (
        db.query(DailyCheckIn)
        .filter(DailyCheckIn.user_id == current_user.id)
        .order_by(DailyCheckIn.checkin_date)
        .all()
    )
    goals = (
        db.query(Goal).filter(Goal.user_id == current_user.id).order_by(Goal.id).all()
    )

    data = ExportData(
        profile=current_user,
        routines=routines,
        workout_sessions=sessions,
        nutrition_logs=nutrition_logs,
        daily_checkins=checkins,
        goals=goals,
    )
    return ExportEnvelope(exported_at=datetime.now(timezone.utc), data=data)


@router.post("/import", response_model=ImportSummary)
def import_data(
    payload: ExportEnvelope,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ImportSummary:
    """Restaura un export previo como datos NUEVOS del usuario actual. No mergea con lo
    existente: cada rutina/sesion/set importado se crea de cero. nutrition_logs y
    daily_checkins tienen unique constraint por fecha, asi que una fecha ya cargada se
    saltea (se cuenta como omitida) en vez de fallar. Los personal_records no se
    reconstruyen para el historial importado -- se calculan solos para sets nuevos que se
    carguen de aca en adelante."""
    routine_id_map: dict[int, int] = {}
    for routine_data in payload.data.routines:
        routine = Routine(
            user_id=current_user.id,
            name=routine_data.name,
            goal=routine_data.goal,
            days_per_week=routine_data.days_per_week,
        )
        for day_data in routine_data.days:
            day = RoutineDay(
                day_index=day_data.day_index,
                name=day_data.name,
                muscle_focus=day_data.muscle_focus,
            )
            for ex_data in day_data.exercises:
                day.exercises.append(
                    RoutineExercise(
                        exercise_id=ex_data.exercise.id,
                        order=ex_data.order,
                        target_sets=ex_data.target_sets,
                        target_reps_min=ex_data.target_reps_min,
                        target_reps_max=ex_data.target_reps_max,
                        target_rest_seconds=ex_data.target_rest_seconds,
                        notes=ex_data.notes,
                    )
                )
            routine.days.append(day)
        db.add(routine)
        db.flush()
        routine_id_map[routine_data.id] = routine.id

    workout_sets_created = 0
    for session_data in payload.data.workout_sessions:
        new_routine_id = (
            routine_id_map.get(session_data.routine_id)
            if session_data.routine_id is not None
            else None
        )
        session = WorkoutSession(
            user_id=current_user.id,
            routine_id=new_routine_id,
            started_at=session_data.started_at,
            ended_at=session_data.ended_at,
            notes=session_data.notes,
        )
        db.add(session)
        db.flush()
        for set_data in session_data.sets:
            db.add(
                WorkoutSet(
                    session_id=session.id,
                    exercise_id=set_data.exercise.id,
                    set_number=set_data.set_number,
                    weight_kg=set_data.weight_kg,
                    reps=set_data.reps,
                    rpe=set_data.rpe,
                    rir=set_data.rir,
                    rest_seconds=set_data.rest_seconds,
                    techniques=set_data.techniques,
                    superset_group_id=set_data.superset_group_id,
                    tempo=set_data.tempo,
                    is_warmup=set_data.is_warmup,
                    notes=set_data.notes,
                )
            )
            workout_sets_created += 1

    nutrition_created = 0
    nutrition_skipped = 0
    for log_data in payload.data.nutrition_logs:
        try:
            with db.begin_nested():
                db.add(
                    NutritionLog(
                        user_id=current_user.id,
                        log_date=log_data.log_date,
                        calories=log_data.calories,
                        protein_g=log_data.protein_g,
                        carbs_g=log_data.carbs_g,
                        fat_g=log_data.fat_g,
                        water_ml=log_data.water_ml,
                        notes=log_data.notes,
                    )
                )
            nutrition_created += 1
        except IntegrityError:
            nutrition_skipped += 1

    checkins_created = 0
    checkins_skipped = 0
    for checkin_data in payload.data.daily_checkins:
        try:
            with db.begin_nested():
                db.add(
                    DailyCheckIn(
                        user_id=current_user.id,
                        checkin_date=checkin_data.checkin_date,
                        sleep_hours=checkin_data.sleep_hours,
                        perceived_fatigue=checkin_data.perceived_fatigue,
                    )
                )
            checkins_created += 1
        except IntegrityError:
            checkins_skipped += 1

    for goal_data in payload.data.goals:
        db.add(
            Goal(
                user_id=current_user.id,
                title=goal_data.title,
                metric=goal_data.metric,
                exercise_id=goal_data.exercise_id,
                starting_value=goal_data.starting_value,
                target_value=goal_data.target_value,
                target_date=goal_data.target_date,
                achieved_at=goal_data.achieved_at,
            )
        )

    db.commit()

    return ImportSummary(
        routines_created=len(payload.data.routines),
        workout_sessions_created=len(payload.data.workout_sessions),
        workout_sets_created=workout_sets_created,
        nutrition_logs_created=nutrition_created,
        nutrition_logs_skipped=nutrition_skipped,
        daily_checkins_created=checkins_created,
        daily_checkins_skipped=checkins_skipped,
        goals_created=len(payload.data.goals),
    )
