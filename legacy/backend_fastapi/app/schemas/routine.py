from pydantic import BaseModel, ConfigDict, Field

from app.schemas.exercise import ExerciseSummary


class RoutineExerciseCreate(BaseModel):
    exercise_id: int
    order: int = 0
    target_sets: int = Field(default=3, ge=1, le=20)
    target_reps_min: int = Field(default=8, ge=1)
    target_reps_max: int = Field(default=12, ge=1)
    target_rest_seconds: int = Field(default=90, ge=0)
    notes: str | None = None


class RoutineExerciseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    order: int
    target_sets: int
    target_reps_min: int
    target_reps_max: int
    target_rest_seconds: int
    notes: str | None
    exercise: ExerciseSummary


class RoutineDayCreate(BaseModel):
    day_index: int
    name: str
    muscle_focus: str | None = None
    exercises: list[RoutineExerciseCreate] = Field(default_factory=list)


class RoutineDayResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    day_index: int
    name: str
    muscle_focus: str | None
    exercises: list[RoutineExerciseResponse]


class RoutineCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    goal: str | None = None
    days_per_week: int = Field(default=1, ge=1, le=7)
    days: list[RoutineDayCreate] = Field(default_factory=list)


class RoutineResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    goal: str | None
    days_per_week: int
    days: list[RoutineDayResponse]


class RoutineSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    goal: str | None
    days_per_week: int
