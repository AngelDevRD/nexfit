from datetime import date, datetime

from pydantic import BaseModel


class MuscleVolumeEntry(BaseModel):
    muscle_group: str
    total_sets: int
    total_volume: float
    last_trained_at: datetime | None
    level: str


class MaxStrengthEntry(BaseModel):
    exercise_id: int
    exercise_name: str
    max_weight_kg: float


class MuscleFrequencyEntry(BaseModel):
    muscle_group: str
    sessions: int


class StrengthProfileResponse(BaseModel):
    max_strength_by_exercise: list[MaxStrengthEntry]
    weekly_volume_kg: float
    weekly_frequency_by_muscle: list[MuscleFrequencyEntry]


class ExerciseProgressEntry(BaseModel):
    session_id: int
    date: datetime
    max_weight_kg: float
    volume_kg: float


class TonnagePeriodEntry(BaseModel):
    period_start: date
    total_tonnage_kg: float


class TrainingStreakResponse(BaseModel):
    current_streak_days: int
    longest_streak_days: int
    last_trained_at: date | None


class StrengthStandardResponse(BaseModel):
    exercise_id: int
    exercise_name: str
    lift_kg: float
    bodyweight_kg: float
    ratio: float
    percentile: float
    level: str


class RecordPredictionResponse(BaseModel):
    exercise_id: int
    exercise_name: str
    current_best_kg: float
    predicted_kg: float
    weeks_ahead: int
    data_points: int
