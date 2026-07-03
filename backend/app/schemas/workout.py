from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.exercise import ExerciseSummary


class WorkoutSetCreate(BaseModel):
    exercise_id: int
    set_number: int = Field(ge=1)
    weight_kg: float = Field(default=0, ge=0)
    reps: int = Field(default=0, ge=0)
    rpe: float | None = Field(default=None, ge=0, le=10)
    rir: int | None = Field(default=None, ge=0, le=10)
    rest_seconds: int | None = Field(default=None, ge=0)
    techniques: list[str] = Field(default_factory=list)
    superset_group_id: int | None = None
    tempo: str | None = None
    is_warmup: bool = False
    notes: str | None = None


class WorkoutSetUpdate(BaseModel):
    weight_kg: float | None = Field(default=None, ge=0)
    reps: int | None = Field(default=None, ge=0)
    rpe: float | None = Field(default=None, ge=0, le=10)
    rir: int | None = Field(default=None, ge=0, le=10)
    rest_seconds: int | None = Field(default=None, ge=0)
    techniques: list[str] | None = None
    superset_group_id: int | None = None
    tempo: str | None = None
    is_warmup: bool | None = None
    notes: str | None = None


class WorkoutSetResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    set_number: int
    weight_kg: float
    reps: int
    rpe: float | None
    rir: int | None
    rest_seconds: int | None
    techniques: list[str]
    superset_group_id: int | None
    tempo: str | None
    is_warmup: bool
    notes: str | None
    exercise: ExerciseSummary


class WorkoutSessionCreate(BaseModel):
    routine_id: int | None = None
    notes: str | None = None


class WorkoutSessionUpdate(BaseModel):
    ended_at: datetime | None = None
    notes: str | None = None


class WorkoutSessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    routine_id: int | None
    started_at: datetime
    ended_at: datetime | None
    notes: str | None
    sets: list[WorkoutSetResponse]


class WorkoutSessionSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    routine_id: int | None
    started_at: datetime
    ended_at: datetime | None
