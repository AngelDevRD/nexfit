from pydantic import BaseModel, ConfigDict

from app.models.user import ExperienceLevel, Goal, Sex


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    name: str
    age: int | None
    sex: Sex | None
    height_cm: float | None
    weight_kg: float | None
    body_fat_pct: float | None
    goal: Goal | None
    experience_level: ExperienceLevel | None


class UserProfileUpdate(BaseModel):
    name: str | None = None
    age: int | None = None
    sex: Sex | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    body_fat_pct: float | None = None
    goal: Goal | None = None
    experience_level: ExperienceLevel | None = None
