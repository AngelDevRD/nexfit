from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.record import RecordType


class PersonalRecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    exercise_id: int | None
    record_type: RecordType
    value: float
    previous_value: float | None
    achieved_at: datetime
