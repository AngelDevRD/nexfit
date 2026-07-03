from app.models.user import Goal, Sex

ACTIVITY_MULTIPLIERS = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}

GOAL_CALORIE_FACTOR = {
    Goal.FAT_LOSS: 0.8,
    Goal.HYPERTROPHY: 1.1,
    Goal.STRENGTH: 1.1,
    Goal.RECOMPOSITION: 1.0,
    Goal.ENDURANCE: 1.05,
    Goal.SPORT_PREP: 1.05,
}

GOAL_PROTEIN_PER_KG = {
    Goal.FAT_LOSS: 2.2,
    Goal.HYPERTROPHY: 2.0,
    Goal.STRENGTH: 1.8,
    Goal.RECOMPOSITION: 2.0,
    Goal.ENDURANCE: 1.6,
    Goal.SPORT_PREP: 1.8,
}


def estimate_one_rep_max(weight_kg: float, reps: int) -> float:
    if reps <= 1:
        return round(weight_kg, 1)
    return round(weight_kg * (1 + reps / 30), 1)


def calculate_bmi(weight_kg: float, height_cm: float) -> tuple[float, str]:
    height_m = height_cm / 100
    bmi = weight_kg / (height_m**2)
    if bmi < 18.5:
        category = "bajo_peso"
    elif bmi < 25:
        category = "normal"
    elif bmi < 30:
        category = "sobrepeso"
    else:
        category = "obesidad"
    return round(bmi, 1), category


def estimate_lean_body_mass(
    weight_kg: float, height_cm: float, sex: Sex, body_fat_pct: float | None
) -> float:
    if body_fat_pct is not None:
        return round(weight_kg * (1 - body_fat_pct / 100), 1)

    if sex == Sex.MALE:
        lbm = 0.407 * weight_kg + 0.267 * height_cm - 19.2
    else:
        lbm = 0.252 * weight_kg + 0.473 * height_cm - 48.3
    return round(lbm, 1)


def estimate_ideal_weight(height_cm: float, sex: Sex) -> float:
    height_in = height_cm / 2.54
    base = 50 if sex == Sex.MALE else 45.5
    ideal = base + 2.3 * max(height_in - 60, 0)
    return round(ideal, 1)


def calculate_water_intake(weight_kg: float) -> float:
    return round(weight_kg * 35, 0)


def calculate_nutrition(
    weight_kg: float,
    height_cm: float,
    age: int,
    sex: Sex,
    activity_level: str,
    goal: Goal,
) -> dict[str, float]:
    if sex == Sex.MALE:
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    else:
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161

    tdee = bmr * ACTIVITY_MULTIPLIERS[activity_level]
    target_calories = tdee * GOAL_CALORIE_FACTOR[goal]

    protein_g = GOAL_PROTEIN_PER_KG[goal] * weight_kg
    fat_g = 0.8 * weight_kg
    remaining_calories = target_calories - (protein_g * 4) - (fat_g * 9)
    carbs_g = max(remaining_calories / 4, 0)

    return {
        "bmr": round(bmr, 0),
        "tdee": round(tdee, 0),
        "target_calories": round(target_calories, 0),
        "protein_g": round(protein_g, 0),
        "carbs_g": round(carbs_g, 0),
        "fat_g": round(fat_g, 0),
        "water_ml": calculate_water_intake(weight_kg),
    }


def estimate_fat_loss_rate(
    current_weight_kg: float, target_weight_kg: float
) -> dict[str, float]:
    weight_to_lose = current_weight_kg - target_weight_kg
    min_weekly_loss = current_weight_kg * 0.005
    max_weekly_loss = current_weight_kg * 0.01
    avg_weekly_loss = (min_weekly_loss + max_weekly_loss) / 2
    weeks_estimate = weight_to_lose / avg_weekly_loss if avg_weekly_loss > 0 else 0

    return {
        "weight_to_lose_kg": round(weight_to_lose, 1),
        "min_weekly_loss_kg": round(min_weekly_loss, 2),
        "max_weekly_loss_kg": round(max_weekly_loss, 2),
        "estimated_weeks": round(weeks_estimate, 1),
    }
