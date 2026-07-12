from pydantic import BaseModel, ConfigDict

from app.models.exercise import Difficulty, MovementType


class ExerciseResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    name: str
    muscle_group: str
    primary_muscles: list[str]
    secondary_muscles: list[str]
    equipment: list[str]
    difficulty: Difficulty
    movement_type: MovementType
    image_url: str | None
    animation_url: str | None
    description: str
    instructions: list[str]
    tips: list[str]
    common_mistakes: list[str]
    variants: list[str]
    benefits: list[str]


class ExerciseSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    slug: str
    name: str
    muscle_group: str
    difficulty: Difficulty
    image_url: str | None
