def test_profile_starts_at_level_one(client, auth_headers):
    resp = client.get("/api/v1/gamification/profile", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["level"] == 1
    assert body["total_xp"] == 0
    assert body["level_band"] == "novice"
    codes_unlocked = {a["code"]: a["unlocked"] for a in body["achievements"]}
    assert codes_unlocked["first_workout"] is False


def test_xp_increases_with_activity(client, auth_headers):
    from app.models.exercise import Exercise
    from tests.conftest import TestingSessionLocal

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

    session_id = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]
    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 100, "reps": 5},
        headers=auth_headers,
    )
    from datetime import datetime, timezone

    client.patch(
        f"/api/v1/workouts/{session_id}",
        json={"ended_at": datetime.now(timezone.utc).isoformat()},
        headers=auth_headers,
    )

    resp = client.get("/api/v1/gamification/profile", headers=auth_headers)
    body = resp.json()
    assert body["total_xp"] > 0
    assert body["sessions_completed"] == 1
    assert body["records_count"] >= 1
    codes_unlocked = {a["code"]: a["unlocked"] for a in body["achievements"]}
    assert codes_unlocked["first_workout"] is True
    assert codes_unlocked["first_pr"] is True


def test_gamification_requires_auth(client):
    resp = client.get("/api/v1/gamification/profile")
    assert resp.status_code == 401
