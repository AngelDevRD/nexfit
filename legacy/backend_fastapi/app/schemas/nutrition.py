from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class NutritionLogUpsert(BaseModel):
    log_date: date
    calories: float = Field(default=0, ge=0)
    protein_g: float = Field(default=0, ge=0)
    carbs_g: float = Field(default=0, ge=0)
    fat_g: float = Field(default=0, ge=0)
    water_ml: float = Field(default=0, ge=0)
    notes: str | None = None


class NutritionLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    log_date: date
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    water_ml: float
    notes: str | None
