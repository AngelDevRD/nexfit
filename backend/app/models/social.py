import enum
from datetime import date as date_type
from datetime import datetime

from sqlalchemy import (
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ChallengeMetric(str, enum.Enum):
    """Metrica sobre la que compiten los participantes de un reto."""

    TOTAL_VOLUME_KG = "total_volume_kg"
    TOTAL_SESSIONS = "total_sessions"
    TOTAL_REPS = "total_reps"


class Challenge(Base):
    __tablename__ = "challenges"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    metric: Mapped[ChallengeMetric] = mapped_column(
        Enum(ChallengeMetric, name="challenge_metric_enum"), nullable=False
    )
    starts_on: Mapped[date_type] = mapped_column(Date, nullable=False)
    ends_on: Mapped[date_type] = mapped_column(Date, nullable=False)
    invite_code: Mapped[str] = mapped_column(
        String(8), unique=True, index=True, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    participants: Mapped[list["ChallengeParticipant"]] = relationship(
        back_populates="challenge", cascade="all, delete-orphan"
    )


class ChallengeParticipant(Base):
    __tablename__ = "challenge_participants"
    __table_args__ = (
        UniqueConstraint("challenge_id", "user_id", name="uq_challenge_participant"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    challenge_id: Mapped[int] = mapped_column(
        ForeignKey("challenges.id"), nullable=False, index=True
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    challenge: Mapped["Challenge"] = relationship(back_populates="participants")
