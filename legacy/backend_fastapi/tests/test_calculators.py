def test_one_rep_max(client):
    resp = client.post(
        "/api/v1/calculators/one-rep-max", json={"weight_kg": 100, "reps": 5}
    )
    assert resp.status_code == 200
    assert resp.json()["estimated_1rm_kg"] == 116.7


def test_one_rep_max_single_rep(client):
    resp = client.post(
        "/api/v1/calculators/one-rep-max", json={"weight_kg": 100, "reps": 1}
    )
    assert resp.json()["estimated_1rm_kg"] == 100


def test_bmi(client):
    resp = client.post(
        "/api/v1/calculators/bmi", json={"weight_kg": 80, "height_cm": 180}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["bmi"] == 24.7
    assert body["category"] == "normal"


def test_lean_body_mass_with_bodyfat(client):
    resp = client.post(
        "/api/v1/calculators/lean-body-mass",
        json={"weight_kg": 80, "height_cm": 180, "sex": "male", "body_fat_pct": 15},
    )
    assert resp.status_code == 200
    assert resp.json()["lean_body_mass_kg"] == 68.0


def test_lean_body_mass_without_bodyfat(client):
    resp = client.post(
        "/api/v1/calculators/lean-body-mass",
        json={"weight_kg": 80, "height_cm": 180, "sex": "male"},
    )
    assert resp.status_code == 200
    assert resp.json()["lean_body_mass_kg"] > 0


def test_ideal_weight(client):
    resp = client.post(
        "/api/v1/calculators/ideal-weight", json={"height_cm": 180, "sex": "male"}
    )
    assert resp.status_code == 200
    assert resp.json()["ideal_weight_kg"] > 0


def test_nutrition(client):
    resp = client.post(
        "/api/v1/calculators/nutrition",
        json={
            "weight_kg": 80,
            "height_cm": 180,
            "age": 30,
            "sex": "male",
            "activity_level": "moderate",
            "goal": "hypertrophy",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["target_calories"] > body["bmr"]
    assert body["protein_g"] == 160.0
    assert body["water_ml"] == 2800.0


def test_water_intake(client):
    resp = client.post("/api/v1/calculators/water-intake", json={"weight_kg": 70})
    assert resp.status_code == 200
    assert resp.json()["water_ml"] == 2450.0


def test_fat_loss_rate(client):
    resp = client.post(
        "/api/v1/calculators/fat-loss-rate",
        json={"current_weight_kg": 90, "target_weight_kg": 80},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["weight_to_lose_kg"] == 10
    assert body["estimated_weeks"] > 0


def test_calculators_do_not_require_auth(client):
    resp = client.post(
        "/api/v1/calculators/bmi", json={"weight_kg": 70, "height_cm": 170}
    )
    assert resp.status_code == 200
