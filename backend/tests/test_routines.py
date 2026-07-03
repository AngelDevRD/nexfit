from app.models.exercise import Exercise
from tests.conftest import TestingSessionLocal


def _seed_exercise() -> int:
    db = TestingSessionLocal()
    exercise = Exercise(
        slug="curl-barra",
        name="Curl con barra",
        muscle_group="Bíceps",
        primary_muscles=["Bíceps braquial"],
        secondary_muscles=[],
        equipment=["Barra"],
        difficulty="beginner",
        movement_type="isolation",
        description="Curl base.",
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
    return exercise_id


def test_create_and_get_routine(client, auth_headers):
    exercise_id = _seed_exercise()
    payload = {
        "name": "Push Pull Legs",
        "goal": "hypertrophy",
        "days_per_week": 3,
        "days": [
            {
                "day_index": 1,
                "name": "Día 1 - Tren superior",
                "muscle_focus": "Bíceps",
                "exercises": [
                    {
                        "exercise_id": exercise_id,
                        "order": 1,
                        "target_sets": 4,
                        "target_reps_min": 8,
                        "target_reps_max": 12,
                    }
                ],
            }
        ],
    }
    resp = client.post("/api/v1/routines", json=payload, headers=auth_headers)
    assert resp.status_code == 201
    body = resp.json()
    assert body["name"] == "Push Pull Legs"
    assert len(body["days"]) == 1
    assert body["days"][0]["exercises"][0]["exercise"]["slug"] == "curl-barra"

    routine_id = body["id"]
    resp = client.get(f"/api/v1/routines/{routine_id}", headers=auth_headers)
    assert resp.status_code == 200


def test_routine_not_owned_returns_404(client, auth_headers):
    resp = client.get("/api/v1/routines/999", headers=auth_headers)
    assert resp.status_code == 404


def test_delete_routine(client, auth_headers):
    resp = client.post(
        "/api/v1/routines",
        json={"name": "Simple", "days_per_week": 1, "days": []},
        headers=auth_headers,
    )
    routine_id = resp.json()["id"]
    resp = client.delete(f"/api/v1/routines/{routine_id}", headers=auth_headers)
    assert resp.status_code == 204
    resp = client.get(f"/api/v1/routines/{routine_id}", headers=auth_headers)
    assert resp.status_code == 404
