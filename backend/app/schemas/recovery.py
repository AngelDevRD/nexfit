from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class CheckInUpsert(BaseModel):
    checkin_date: date
    sleep_hours: float = Field(ge=0, le=24)
    perceived_fatigue: int = Field(ge=1, le=10)


class CheckInResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    checkin_date: date
    sleep_hours: float
    perceived_fatigue: int


class RecoveryIndexResponse(BaseModel):
    recovery_index: int
    level: str
    sleep_hours: float
    perceived_fatigue: int
    checkin_date: date
