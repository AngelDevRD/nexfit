import enum

from sqlalchemy import JSON, Enum, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Difficulty(str, enum.Enum):
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED = "advanced"


class MovementType(str, enum.Enum):
    COMPOUND = "compound"
    ISOLATION = "isolation"


class Exercise(Base):
    __tablename__ = "exercises"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    slug: Mapped[str] = mapped_column(
        String(150), unique=True, index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)

    muscle_group: Mapped[str] = mapped_column(String(60), nullable=False, index=True)
    primary_muscles: Mapped[list[str]] = mapped_column(JSON, default=list)
    secondary_muscles: Mapped[list[str]] = mapped_column(JSON, default=list)
    equipment: Mapped[list[str]] = mapped_column(JSON, default=list)

    difficulty: Mapped[Difficulty] = mapped_column(
        Enum(Difficulty, name="difficulty_enum")
    )
    movement_type: Mapped[MovementType] = mapped_column(
        Enum(MovementType, name="movement_type_enum")
    )

    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    animation_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    description: Mapped[str] = mapped_column(Text, default="")
    instructions: Mapped[list[str]] = mapped_column(JSON, default=list)
    tips: Mapped[list[str]] = mapped_column(JSON, default=list)
    common_mistakes: Mapped[list[str]] = mapped_column(JSON, default=list)
    variants: Mapped[list[str]] = mapped_column(JSON, default=list)
    benefits: Mapped[list[str]] = mapped_column(JSON, default=list)
