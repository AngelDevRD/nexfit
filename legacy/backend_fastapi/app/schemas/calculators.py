from typing import Literal

from pydantic import BaseModel, Field

from app.models.user import Goal, Sex

ActivityLevel = Literal["sedentary", "light", "moderate", "active", "very_active"]


class OneRepMaxRequest(BaseModel):
    weight_kg: float = Field(gt=0)
    reps: int = Field(ge=1, le=20)


class OneRepMaxResponse(BaseModel):
    estimated_1rm_kg: float


class BmiRequest(BaseModel):
    weight_kg: float = Field(gt=0)
    height_cm: float = Field(gt=0)


class BmiResponse(BaseModel):
    bmi: float
    category: str


class LeanBodyMassRequest(BaseModel):
    weight_kg: float = Field(gt=0)
    height_cm: float = Field(gt=0)
    sex: Sex
    body_fat_pct: float | None = Field(default=None, ge=0, le=70)


class LeanBodyMassResponse(BaseModel):
    lean_body_mass_kg: float


class IdealWeightRequest(BaseModel):
    height_cm: float = Field(gt=0)
    sex: Sex


class IdealWeightResponse(BaseModel):
    ideal_weight_kg: float


class NutritionRequest(BaseModel):
    weight_kg: float = Field(gt=0)
    height_cm: float = Field(gt=0)
    age: int = Field(gt=0, le=100)
    sex: Sex
    activity_level: ActivityLevel
    goal: Goal


class NutritionResponse(BaseModel):
    bmr: float
    tdee: float
    target_calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    water_ml: float


class WaterIntakeRequest(BaseModel):
    weight_kg: float = Field(gt=0)


class WaterIntakeResponse(BaseModel):
    water_ml: float


class FatLossRateRequest(BaseModel):
    current_weight_kg: float = Field(gt=0)
    target_weight_kg: float = Field(gt=0)


class FatLossRateResponse(BaseModel):
    weight_to_lose_kg: float
    min_weekly_loss_kg: float
    max_weekly_loss_kg: float
    estimated_weeks: float
