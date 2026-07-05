from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.nutrition import NutritionLogResponse
from app.schemas.recovery import CheckInResponse
from app.schemas.routine import RoutineResponse
from app.schemas.workout import WorkoutSessionResponse


class UserProfileExport(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: str
    email: str
    sex: str | None
    age: int | None
    height_cm: float | None
    weight_kg: float | None
    body_fat_pct: float | None
    goal: str | None
    experience_level: str | None


class GoalExport(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    title: str
    metric: str
    exercise_id: int | None
    starting_value: float
    target_value: float
    target_date: date | None
    achieved_at: datetime | None


class ExportData(BaseModel):
    profile: UserProfileExport
    routines: list[RoutineResponse] = Field(default_factory=list)
    workout_sessions: list[WorkoutSessionResponse] = Field(default_factory=list)
    nutrition_logs: list[NutritionLogResponse] = Field(default_factory=list)
    daily_checkins: list[CheckInResponse] = Field(default_factory=list)
    goals: list[GoalExport] = Field(default_factory=list)


class ExportEnvelope(BaseModel):
    version: int = 1
    exported_at: datetime
    data: ExportData


class ImportSummary(BaseModel):
    routines_created: int
    workout_sessions_created: int
    workout_sets_created: int
    nutrition_logs_created: int
    nutrition_logs_skipped: int
    daily_checkins_created: int
    daily_checkins_skipped: int
    goals_created: int
