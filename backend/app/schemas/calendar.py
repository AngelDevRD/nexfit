from pydantic import BaseModel

from app.schemas.goal import GoalResponse
from app.schemas.stats import RecordPredictionResponse


class DeloadRecommendation(BaseModel):
    recommended: bool
    reason: str


class CalendarOverviewResponse(BaseModel):
    upcoming_goals: list[GoalResponse]
    deload: DeloadRecommendation
    upcoming_record_predictions: list[RecordPredictionResponse]
