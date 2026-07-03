def test_create_body_weight_goal_and_progress(client, auth_headers):
    client.patch("/api/v1/users/me", json={"weight_kg": 90}, headers=auth_headers)

    resp = client.post(
        "/api/v1/goals",
        json={"title": "Bajar a 80kg", "metric": "body_weight_kg", "target_value": 80},
        headers=auth_headers,
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["starting_value"] == 90
    assert body["progress_pct"] == 0
    assert body["achieved"] is False

    client.patch("/api/v1/users/me", json={"weight_kg": 85}, headers=auth_headers)
    resp = client.get("/api/v1/goals", headers=auth_headers)
    goal = resp.json()[0]
    assert goal["progress_pct"] == 50.0


def test_exercise_goal_requires_exercise_id(client, auth_headers):
    resp = client.post(
        "/api/v1/goals",
        json={
            "title": "Press banca 120kg",
            "metric": "exercise_max_weight",
            "target_value": 120,
        },
        headers=auth_headers,
    )
    assert resp.status_code == 422


def test_exercise_goal_achieved(client, auth_headers):
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

    resp = client.post(
        "/api/v1/goals",
        json={
            "title": "Press banca 100kg",
            "metric": "exercise_max_weight",
            "exercise_id": exercise_id,
            "target_value": 100,
        },
        headers=auth_headers,
    )
    goal_id = resp.json()["id"]

    session_id = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]
    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 100, "reps": 5},
        headers=auth_headers,
    )

    resp = client.get("/api/v1/goals", headers=auth_headers)
    goal = next(g for g in resp.json() if g["id"] == goal_id)
    assert goal["achieved"] is True
    assert goal["progress_pct"] == 100.0


def test_delete_goal(client, auth_headers):
    resp = client.post(
        "/api/v1/goals",
        json={"title": "Meta simple", "metric": "body_weight_kg", "target_value": 70},
        headers=auth_headers,
    )
    goal_id = resp.json()["id"]
    resp = client.delete(f"/api/v1/goals/{goal_id}", headers=auth_headers)
    assert resp.status_code == 204


def test_goals_require_auth(client):
    resp = client.get("/api/v1/goals")
    assert resp.status_code == 401


def test_calendar_overview(client, auth_headers):
    client.post(
        "/api/v1/goals",
        json={"title": "Meta simple", "metric": "body_weight_kg", "target_value": 70},
        headers=auth_headers,
    )
    resp = client.get("/api/v1/calendar/overview", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["upcoming_goals"]) == 1
    assert "recommended" in body["deload"]
    assert body["upcoming_record_predictions"] == []
