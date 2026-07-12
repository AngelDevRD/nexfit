from app.models.exercise import Exercise
from tests.conftest import TestingSessionLocal


def _seed_exercise() -> int:
    db = TestingSessionLocal()
    exercise = Exercise(
        slug="sentadilla",
        name="Sentadilla",
        muscle_group="Piernas",
        primary_muscles=["Cuadriceps"],
        secondary_muscles=[],
        equipment=["Barra"],
        difficulty="intermediate",
        movement_type="compound",
        description="Sentadilla base.",
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


def _second_user_headers(client):
    client.post(
        "/api/v1/auth/register",
        json={
            "email": "second@appgym.com",
            "password": "password123",
            "name": "Second User",
        },
    )
    resp = client.post(
        "/api/v1/auth/login",
        data={"username": "second@appgym.com", "password": "password123"},
    )
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _seed_source_data(client, auth_headers, exercise_id):
    routine_resp = client.post(
        "/api/v1/routines",
        json={
            "name": "Rutina Full Body",
            "days_per_week": 1,
            "days": [
                {
                    "day_index": 1,
                    "name": "Día 1",
                    "exercises": [{"exercise_id": exercise_id, "order": 1}],
                }
            ],
        },
        headers=auth_headers,
    )
    routine_id = routine_resp.json()["id"]

    session_resp = client.post(
        "/api/v1/workouts",
        json={"routine_id": routine_id},
        headers=auth_headers,
    )
    session_id = session_resp.json()["id"]
    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 100, "reps": 5},
        headers=auth_headers,
    )
    client.put(
        "/api/v1/nutrition/logs",
        json={"log_date": "2026-01-01", "calories": 2000},
        headers=auth_headers,
    )
    client.put(
        "/api/v1/recovery/checkins",
        json={"checkin_date": "2026-01-01", "sleep_hours": 7.5, "perceived_fatigue": 4},
        headers=auth_headers,
    )
    return routine_id, session_id


def test_export_contains_all_sections(client, auth_headers):
    exercise_id = _seed_exercise()
    _seed_source_data(client, auth_headers, exercise_id)

    resp = client.get("/api/v1/users/me/export", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    data = body["data"]
    assert data["profile"]["email"] == "test@appgym.com"
    assert len(data["routines"]) == 1
    assert len(data["workout_sessions"]) == 1
    assert len(data["workout_sessions"][0]["sets"]) == 1
    assert len(data["nutrition_logs"]) == 1
    assert len(data["daily_checkins"]) == 1


def test_import_creates_records_for_current_user(client, auth_headers):
    exercise_id = _seed_exercise()
    _seed_source_data(client, auth_headers, exercise_id)

    export_body = client.get("/api/v1/users/me/export", headers=auth_headers).json()

    target_headers = _second_user_headers(client)
    resp = client.post(
        "/api/v1/users/me/import", json=export_body, headers=target_headers
    )
    assert resp.status_code == 200
    summary = resp.json()
    assert summary["routines_created"] == 1
    assert summary["workout_sessions_created"] == 1
    assert summary["workout_sets_created"] == 1
    assert summary["nutrition_logs_created"] == 1
    assert summary["daily_checkins_created"] == 1

    routines = client.get("/api/v1/routines", headers=target_headers).json()
    assert len(routines) == 1

    workouts = client.get("/api/v1/workouts", headers=target_headers).json()
    assert len(workouts) == 1
    assert workouts[0]["routine_id"] == routines[0]["id"]


def test_import_skips_duplicate_dates(client, auth_headers):
    exercise_id = _seed_exercise()
    _seed_source_data(client, auth_headers, exercise_id)
    export_body = client.get("/api/v1/users/me/export", headers=auth_headers).json()

    target_headers = _second_user_headers(client)
    client.post("/api/v1/users/me/import", json=export_body, headers=target_headers)
    # Importar el mismo archivo de nuevo: nutrition/checkin de esa fecha ya existen.
    resp = client.post(
        "/api/v1/users/me/import", json=export_body, headers=target_headers
    )
    summary = resp.json()
    assert summary["nutrition_logs_created"] == 0
    assert summary["nutrition_logs_skipped"] == 1
    assert summary["daily_checkins_created"] == 0
    assert summary["daily_checkins_skipped"] == 1
    # Rutinas/sesiones no tienen unique constraint -> se duplican, comportamiento esperado.
    assert summary["routines_created"] == 1
