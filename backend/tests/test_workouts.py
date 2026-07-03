from app.models.exercise import Exercise
from tests.conftest import TestingSessionLocal


def _seed_exercise() -> int:
    db = TestingSessionLocal()
    exercise = Exercise(
        slug="press-banca-barra",
        name="Press banca con barra",
        muscle_group="Pecho",
        primary_muscles=["Pectoral mayor"],
        secondary_muscles=["Tríceps"],
        equipment=["Barra"],
        difficulty="intermediate",
        movement_type="compound",
        description="Press base.",
        instructions=["Bajá", "Subí"],
        tips=[],
        common_mistakes=[],
        variants=[],
        benefits=[],
    )
    db.add(exercise)
    db.commit()
    db.refresh(exercise)
    exercise_id = exercise.id
    db.close()
    return exercise_id


def test_full_workout_flow_detects_records(client, auth_headers):
    exercise_id = _seed_exercise()

    resp = client.post("/api/v1/workouts", json={}, headers=auth_headers)
    assert resp.status_code == 201
    session_id = resp.json()["id"]

    resp = client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 80, "reps": 8},
        headers=auth_headers,
    )
    assert resp.status_code == 201

    resp = client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={"exercise_id": exercise_id, "set_number": 2, "weight_kg": 100, "reps": 8},
        headers=auth_headers,
    )
    assert resp.status_code == 201

    resp = client.get(f"/api/v1/workouts/{session_id}/records", headers=auth_headers)
    assert resp.status_code == 200
    records = resp.json()
    record_types = {r["record_type"] for r in records}
    assert "max_weight" in record_types
    assert "max_volume" in record_types
    weight_records = [r for r in records if r["record_type"] == "max_weight"]
    assert len(weight_records) == 2
    latest = max(weight_records, key=lambda r: r["value"])
    assert latest["value"] == 100
    assert latest["previous_value"] == 80


def test_edit_set_individually(client, auth_headers):
    exercise_id = _seed_exercise()
    session_id = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]
    set_resp = client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 60, "reps": 10},
        headers=auth_headers,
    )
    set_id = set_resp.json()["id"]

    resp = client.patch(
        f"/api/v1/workouts/sets/{set_id}",
        json={"weight_kg": 65, "rpe": 8.5, "techniques": ["drop_set"]},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["weight_kg"] == 65
    assert resp.json()["techniques"] == ["drop_set"]


def test_history_filters_by_muscle_group(client, auth_headers):
    exercise_id = _seed_exercise()
    session_id = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]
    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 50, "reps": 10},
        headers=auth_headers,
    )

    resp = client.get(
        "/api/v1/workouts", params={"muscle_group": "Pecho"}, headers=auth_headers
    )
    assert resp.status_code == 200
    assert len(resp.json()) == 1

    resp = client.get(
        "/api/v1/workouts", params={"muscle_group": "Espalda"}, headers=auth_headers
    )
    assert resp.json() == []


def test_workouts_require_auth(client):
    resp = client.get("/api/v1/workouts")
    assert resp.status_code == 401
