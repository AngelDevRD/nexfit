from app.models.exercise import Exercise
from tests.conftest import TestingSessionLocal


def _seed_one_exercise():
    db = TestingSessionLocal()
    db.add(
        Exercise(
            slug="sentadilla-barra",
            name="Sentadilla con barra",
            muscle_group="Cuádriceps",
            primary_muscles=["Cuádriceps"],
            secondary_muscles=["Glúteos"],
            equipment=["Barra"],
            difficulty="intermediate",
            movement_type="compound",
            description="Ejercicio base de pierna.",
            instructions=["Bajá", "Subí"],
            tips=[],
            common_mistakes=[],
            variants=[],
            benefits=[],
        )
    )
    db.commit()
    db.close()


def test_list_exercises_empty(client):
    resp = client.get("/api/v1/exercises")
    assert resp.status_code == 200
    assert resp.json() == []


def test_list_and_get_exercise(client):
    _seed_one_exercise()
    resp = client.get("/api/v1/exercises")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1
    assert body[0]["slug"] == "sentadilla-barra"

    exercise_id = body[0]["id"]
    resp = client.get(f"/api/v1/exercises/{exercise_id}")
    assert resp.status_code == 200
    assert resp.json()["name"] == "Sentadilla con barra"


def test_filter_by_muscle_group(client):
    _seed_one_exercise()
    resp = client.get("/api/v1/exercises", params={"muscle_group": "Pecho"})
    assert resp.status_code == 200
    assert resp.json() == []

    resp = client.get("/api/v1/exercises", params={"muscle_group": "Cuádriceps"})
    assert len(resp.json()) == 1


def test_get_exercise_not_found(client):
    resp = client.get("/api/v1/exercises/999")
    assert resp.status_code == 404
