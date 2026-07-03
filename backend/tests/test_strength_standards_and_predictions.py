from app.models.exercise import Exercise
from tests.conftest import TestingSessionLocal


def _seed_bench_press() -> int:
    db = TestingSessionLocal()
    exercise = Exercise(
        slug="press-banca-barra",
        name="Press banca con barra",
        muscle_group="Pecho",
        primary_muscles=["Pectoral mayor"],
        secondary_muscles=[],
        equipment=["Barra"],
        difficulty="intermediate",
        movement_type="compound",
        description="",
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


def _complete_profile(client, auth_headers):
    client.patch(
        "/api/v1/users/me", json={"sex": "male", "weight_kg": 80}, headers=auth_headers
    )


def test_strength_standards_requires_complete_profile(client, auth_headers):
    exercise_id = _seed_bench_press()
    resp = client.get(
        f"/api/v1/stats/strength-standards/{exercise_id}", headers=auth_headers
    )
    assert resp.status_code == 404


def test_strength_standards_success(client, auth_headers):
    exercise_id = _seed_bench_press()
    _complete_profile(client, auth_headers)

    session_id = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]
    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 80, "reps": 5},
        headers=auth_headers,
    )

    resp = client.get(
        f"/api/v1/stats/strength-standards/{exercise_id}", headers=auth_headers
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["ratio"] == 1.0
    assert body["level"] == "intermediate"
    assert 0 <= body["percentile"] <= 100


def test_strength_standards_unsupported_exercise(client, auth_headers):
    db = TestingSessionLocal()
    exercise = Exercise(
        slug="curl-barra",
        name="Curl con barra",
        muscle_group="Bíceps",
        primary_muscles=["Bíceps"],
        secondary_muscles=[],
        equipment=["Barra"],
        difficulty="beginner",
        movement_type="isolation",
        description="",
        instructions=["Subí", "Bajá"],
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

    _complete_profile(client, auth_headers)
    resp = client.get(
        f"/api/v1/stats/strength-standards/{exercise_id}", headers=auth_headers
    )
    assert resp.status_code == 404


def test_record_prediction_needs_history(client, auth_headers):
    exercise_id = _seed_bench_press()
    resp = client.get(
        f"/api/v1/stats/record-prediction/{exercise_id}", headers=auth_headers
    )
    assert resp.status_code == 404


def test_record_prediction_with_upward_trend(client, auth_headers):
    exercise_id = _seed_bench_press()
    session_id = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]

    for i, weight in enumerate([80, 85, 90], start=1):
        client.post(
            f"/api/v1/workouts/{session_id}/sets",
            json={
                "exercise_id": exercise_id,
                "set_number": i,
                "weight_kg": weight,
                "reps": 5,
            },
            headers=auth_headers,
        )

    from app.models.record import PersonalRecord
    from datetime import datetime, timedelta, timezone

    db = TestingSessionLocal()
    records = (
        db.query(PersonalRecord)
        .filter(PersonalRecord.exercise_id == exercise_id)
        .order_by(PersonalRecord.id)
        .all()
    )
    base = datetime.now(timezone.utc) - timedelta(days=30)
    for i, record in enumerate(records):
        record.achieved_at = base + timedelta(days=i * 15)
    db.commit()
    db.close()

    resp = client.get(
        f"/api/v1/stats/record-prediction/{exercise_id}",
        params={"weeks_ahead": 8},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["predicted_kg"] > body["current_best_kg"]
    assert body["data_points"] == 3
