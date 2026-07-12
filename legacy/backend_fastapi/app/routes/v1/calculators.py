from fastapi import APIRouter

from app.schemas.calculators import (
    BmiRequest,
    BmiResponse,
    FatLossRateRequest,
    FatLossRateResponse,
    IdealWeightRequest,
    IdealWeightResponse,
    LeanBodyMassRequest,
    LeanBodyMassResponse,
    NutritionRequest,
    NutritionResponse,
    OneRepMaxRequest,
    OneRepMaxResponse,
    WaterIntakeRequest,
    WaterIntakeResponse,
)
from app.services.calculators import (
    calculate_bmi,
    calculate_nutrition,
    calculate_water_intake,
    estimate_fat_loss_rate,
    estimate_ideal_weight,
    estimate_lean_body_mass,
    estimate_one_rep_max,
)

router = APIRouter(prefix="/api/v1/calculators", tags=["calculators"])


@router.post("/one-rep-max", response_model=OneRepMaxResponse)
def one_rep_max(payload: OneRepMaxRequest) -> OneRepMaxResponse:
    return OneRepMaxResponse(
        estimated_1rm_kg=estimate_one_rep_max(payload.weight_kg, payload.reps)
    )


@router.post("/bmi", response_model=BmiResponse)
def bmi(payload: BmiRequest) -> BmiResponse:
    value, category = calculate_bmi(payload.weight_kg, payload.height_cm)
    return BmiResponse(bmi=value, category=category)


@router.post("/lean-body-mass", response_model=LeanBodyMassResponse)
def lean_body_mass(payload: LeanBodyMassRequest) -> LeanBodyMassResponse:
    value = estimate_lean_body_mass(
        payload.weight_kg, payload.height_cm, payload.sex, payload.body_fat_pct
    )
    return LeanBodyMassResponse(lean_body_mass_kg=value)


@router.post("/ideal-weight", response_model=IdealWeightResponse)
def ideal_weight(payload: IdealWeightRequest) -> IdealWeightResponse:
    value = estimate_ideal_weight(payload.height_cm, payload.sex)
    return IdealWeightResponse(ideal_weight_kg=value)


@router.post("/nutrition", response_model=NutritionResponse)
def nutrition(payload: NutritionRequest) -> NutritionResponse:
    result = calculate_nutrition(
        payload.weight_kg,
        payload.height_cm,
        payload.age,
        payload.sex,
        payload.activity_level,
        payload.goal,
    )
    return NutritionResponse(**result)


@router.post("/water-intake", response_model=WaterIntakeResponse)
def water_intake(payload: WaterIntakeRequest) -> WaterIntakeResponse:
    return WaterIntakeResponse(water_ml=calculate_water_intake(payload.weight_kg))


@router.post("/fat-loss-rate", response_model=FatLossRateResponse)
def fat_loss_rate(payload: FatLossRateRequest) -> FatLossRateResponse:
    result = estimate_fat_loss_rate(payload.current_weight_kg, payload.target_weight_kg)
    return FatLossRateResponse(**result)
