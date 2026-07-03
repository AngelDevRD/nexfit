import enum
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class RecordType(str, enum.Enum):
    MAX_WEIGHT = "max_weight"
    MAX_REPS = "max_reps"
    MAX_VOLUME = "max_volume"
    WEEKLY_TONNAGE = "weekly_tonnage"
    MONTHLY_TONNAGE = "monthly_tonnage"


class PersonalRecord(Base):
    __tablename__ = "personal_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    exercise_id: Mapped[int | None] = mapped_column(
        ForeignKey("exercises.id"), nullable=True, index=True
    )
    workout_set_id: Mapped[int | None] = mapped_column(
        ForeignKey("workout_sets.id"), nullable=True
    )

    record_type: Mapped[RecordType] = mapped_column(
        Enum(RecordType, name="record_type_enum")
    )
    value: Mapped[float] = mapped_column(Float, nullable=False)
    previous_value: Mapped[float | None] = mapped_column(Float, nullable=True)

    achieved_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="personal_records")
