from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Routine(Base):
    __tablename__ = "routines"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    goal: Mapped[str | None] = mapped_column(String(60), nullable=True)
    days_per_week: Mapped[int] = mapped_column(Integer, default=1)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="routines")
    days: Mapped[list["RoutineDay"]] = relationship(
        back_populates="routine",
        cascade="all, delete-orphan",
        order_by="RoutineDay.day_index",
    )


class RoutineDay(Base):
    __tablename__ = "routine_days"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    routine_id: Mapped[int] = mapped_column(
        ForeignKey("routines.id"), nullable=False, index=True
    )
    day_index: Mapped[int] = mapped_column(Integer, nullable=False)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    muscle_focus: Mapped[str | None] = mapped_column(String(120), nullable=True)

    routine: Mapped["Routine"] = relationship(back_populates="days")
    exercises: Mapped[list["RoutineExercise"]] = relationship(
        back_populates="routine_day",
        cascade="all, delete-orphan",
        order_by="RoutineExercise.order",
    )


class RoutineExercise(Base):
    __tablename__ = "routine_exercises"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    routine_day_id: Mapped[int] = mapped_column(
        ForeignKey("routine_days.id"), nullable=False, index=True
    )
    exercise_id: Mapped[int] = mapped_column(
        ForeignKey("exercises.id"), nullable=False, index=True
    )
    order: Mapped[int] = mapped_column(Integer, default=0)
    target_sets: Mapped[int] = mapped_column(Integer, default=3)
    target_reps_min: Mapped[int] = mapped_column(Integer, default=8)
    target_reps_max: Mapped[int] = mapped_column(Integer, default=12)
    target_rest_seconds: Mapped[int] = mapped_column(Integer, default=90)
    notes: Mapped[str | None] = mapped_column(String(500), nullable=True)

    routine_day: Mapped["RoutineDay"] = relationship(back_populates="exercises")
    exercise: Mapped["Exercise"] = relationship()
