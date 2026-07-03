from datetime import datetime, timedelta, timezone

from app.models.exercise import Exercise
from app.models.user import User
from app.models.workout import WorkoutSession, WorkoutSet
from tests.conftest import TestingSessionLocal


def _seed_exercises() -> dict[str, int]:
    db = TestingSessionLocal()
    ids = {}
    for slug, name, muscle_group in [
        ("press-banca-barra", "Press banca con barra", "Pecho"),
        ("remo-barra", "Remo con barra", "Espalda"),
        ("curl-barra", "Curl con barra", "Bíceps"),
    ]:
        exercise = Exercise(
            slug=slug,
            name=name,
            muscle_group=muscle_group,
            primary_muscles=[muscle_group],
            secondary_muscles=[],
            equipment=["Barra"],
            difficulty="beginner",
            movement_type="compound",
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
        ids[slug] = exercise.id
    db.close()
    return ids


def test_muscle_analysis_ranks_relative_to_own_history(client, auth_headers):
    ids = _seed_exercises()
    session_id = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]

    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={
            "exercise_id": ids["press-banca-barra"],
            "set_number": 1,
            "weight_kg": 100,
            "reps": 10,
        },
        headers=auth_headers,
    )
    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={
            "exercise_id": ids["remo-barra"],
            "set_number": 1,
            "weight_kg": 20,
            "reps": 5,
        },
        headers=auth_headers,
    )

    resp = client.get("/api/v1/stats/muscle-analysis", headers=auth_headers)
    assert resp.status_code == 200
    entries = {e["muscle_group"]: e for e in resp.json()}

    assert entries["Pecho"]["level"] == "alto"
    assert entries["Bíceps"]["level"] == "muy_bajo"
    assert entries["Bíceps"]["total_volume"] == 0


def test_muscle_analysis_requires_auth(client):
    resp = client.get("/api/v1/stats/muscle-analysis")
    assert resp.status_code == 401


def test_strength_profile(client, auth_headers):
    ids = _seed_exercises()
    session_id = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]

    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={
            "exercise_id": ids["press-banca-barra"],
            "set_number": 1,
            "weight_kg": 80,
            "reps": 8,
        },
        headers=auth_headers,
    )
    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={
            "exercise_id": ids["press-banca-barra"],
            "set_number": 2,
            "weight_kg": 100,
            "reps": 6,
        },
        headers=auth_headers,
    )

    resp = client.get("/api/v1/stats/strength-profile", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()

    assert len(body["max_strength_by_exercise"]) == 1
    assert body["max_strength_by_exercise"][0]["max_weight_kg"] == 100
    assert body["weekly_volume_kg"] == 80 * 8 + 100 * 6
    muscle_freq = {
        e["muscle_group"]: e["sessions"] for e in body["weekly_frequency_by_muscle"]
    }
    assert muscle_freq["Pecho"] == 1


def test_exercise_progress(client, auth_headers):
    ids = _seed_exercises()
    exercise_id = ids["press-banca-barra"]

    session1 = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]
    client.post(
        f"/api/v1/workouts/{session1}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 80, "reps": 8},
        headers=auth_headers,
    )
    session2 = client.post("/api/v1/workouts", json={}, headers=auth_headers).json()[
        "id"
    ]
    client.post(
        f"/api/v1/workouts/{session2}/sets",
        json={"exercise_id": exercise_id, "set_number": 1, "weight_kg": 90, "reps": 6},
        headers=auth_headers,
    )

    resp = client.get(f"/api/v1/stats/progress/{exercise_id}", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 2
    assert body[0]["max_weight_kg"] == 80
    assert body[1]["max_weight_kg"] == 90


def test_exercise_progress_not_found(client, auth_headers):
    resp = client.get("/api/v1/stats/progress/999", headers=auth_headers)
    assert resp.status_code == 404


def _get_test_user_id() -> int:
    db = TestingSessionLocal()
    user = db.query(User).filter(User.email == "test@appgym.com").first()
    user_id = user.id
    db.close()
    return user_id


def _insert_session_on(
    user_id: int, exercise_id: int, days_ago: int, weight_kg: float, reps: int
) -> None:
    db = TestingSessionLocal()
    started_at = datetime.now(timezone.utc) - timedelta(days=days_ago)
    session = WorkoutSession(user_id=user_id, started_at=started_at)
    session.sets.append(
        WorkoutSet(
            exercise_id=exercise_id, set_number=1, weight_kg=weight_kg, reps=reps
        )
    )
    db.add(session)
    db.commit()
    db.close()


def test_training_streak(client, auth_headers):
    ids = _seed_exercises()
    user_id = _get_test_user_id()

    _insert_session_on(
        user_id, ids["press-banca-barra"], days_ago=2, weight_kg=80, reps=8
    )
    _insert_session_on(
        user_id, ids["press-banca-barra"], days_ago=1, weight_kg=80, reps=8
    )
    _insert_session_on(
        user_id, ids["press-banca-barra"], days_ago=0, weight_kg=80, reps=8
    )

    resp = client.get("/api/v1/stats/streak", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["current_streak_days"] == 3
    assert body["longest_streak_days"] == 3


def test_training_streak_broken(client, auth_headers):
    ids = _seed_exercises()
    user_id = _get_test_user_id()

    _insert_session_on(
        user_id, ids["press-banca-barra"], days_ago=10, weight_kg=80, reps=8
    )
    _insert_session_on(
        user_id, ids["press-banca-barra"], days_ago=9, weight_kg=80, reps=8
    )

    resp = client.get("/api/v1/stats/streak", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["current_streak_days"] == 0
    assert body["longest_streak_days"] == 2


def test_training_streak_no_sessions(client, auth_headers):
    resp = client.get("/api/v1/stats/streak", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body == {
        "current_streak_days": 0,
        "longest_streak_days": 0,
        "last_trained_at": None,
    }


def test_tonnage_history(client, auth_headers):
    ids = _seed_exercises()
    user_id = _get_test_user_id()

    _insert_session_on(
        user_id, ids["press-banca-barra"], days_ago=0, weight_kg=100, reps=10
    )
    _insert_session_on(
        user_id, ids["press-banca-barra"], days_ago=14, weight_kg=50, reps=10
    )

    resp = client.get(
        "/api/v1/stats/tonnage",
        params={"period": "week", "periods": 3},
        headers=auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 3
    assert body[-1]["total_tonnage_kg"] == 1000.0
    assert body[0]["total_tonnage_kg"] == 500.0


def test_tonnage_history_requires_auth(client):
    resp = client.get("/api/v1/stats/tonnage")
    assert resp.status_code == 401
