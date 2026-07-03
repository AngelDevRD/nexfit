import enum
from datetime import date as date_type
from datetime import datetime

from sqlalchemy import Date, DateTime, Enum, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class GoalMetric(str, enum.Enum):
    EXERCISE_MAX_WEIGHT = "exercise_max_weight"
    EXERCISE_MAX_REPS = "exercise_max_reps"
    BODY_WEIGHT_KG = "body_weight_kg"
    BODY_FAT_PCT = "body_fat_pct"


class Goal(Base):
    __tablename__ = "goals"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    metric: Mapped[GoalMetric] = mapped_column(
        Enum(GoalMetric, name="goal_metric_enum")
    )
    exercise_id: Mapped[int | None] = mapped_column(
        ForeignKey("exercises.id"), nullable=True
    )

    starting_value: Mapped[float] = mapped_column(Float, nullable=False)
    target_value: Mapped[float] = mapped_column(Float, nullable=False)
    target_date: Mapped[date_type | None] = mapped_column(Date, nullable=True)

    achieved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
