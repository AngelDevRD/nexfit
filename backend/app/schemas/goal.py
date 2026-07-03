from datetime import date, datetime

from pydantic import BaseModel, Field

from app.models.goal import GoalMetric


class GoalCreate(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    metric: GoalMetric
    exercise_id: int | None = None
    target_value: float
    target_date: date | None = None


class GoalResponse(BaseModel):
    id: int
    title: str
    metric: GoalMetric
    exercise_id: int | None
    starting_value: float
    target_value: float
    target_date: date | None
    achieved_at: datetime | None
    current_value: float
    progress_pct: float
    achieved: bool
