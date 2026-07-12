def test_context_preview_with_no_history(client, auth_headers):
    resp = client.get("/api/v1/coach/context-preview", headers=auth_headers)
    assert resp.status_code == 200
    context = resp.json()["context"]
    assert "Meses entrenando en la app: 0" in context
    assert "Todavia no tiene records personales registrados" in context


def test_context_preview_with_records(client, auth_headers):
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

    resp = client.get("/api/v1/coach/context-preview", headers=auth_headers)
    assert resp.status_code == 200
    assert "Press banca con barra 100" in resp.json()["context"]


def test_chat_returns_503_without_llm_configured(client, auth_headers, monkeypatch):
    # Forzar "sin proveedor IA" independientemente de lo que haya en .env real.
    from app.core.config import get_settings

    monkeypatch.setattr(get_settings(), "llm_api_key", None)
    resp = client.post(
        "/api/v1/coach/chat",
        json={"message": "¿Por qué no mejoro en press banca?"},
        headers=auth_headers,
    )
    assert resp.status_code == 503
    assert "LLM_API_KEY" in resp.json()["detail"]


def test_chat_requires_auth(client):
    resp = client.post("/api/v1/coach/chat", json={"message": "hola"})
    assert resp.status_code == 401


def _test_user_id():
    from app.models.user import User
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    user_id = db.query(User).filter(User.email == "test@appgym.com").first().id
    db.close()
    return user_id


def test_get_activity_log_groups_by_date(client, auth_headers):
    from datetime import date

    from app.services.digital_twin import get_activity_log
    from tests.conftest import TestingSessionLocal

    client.put(
        "/api/v1/nutrition/logs",
        json={"log_date": "2026-01-01", "calories": 1800},
        headers=auth_headers,
    )
    client.put(
        "/api/v1/recovery/checkins",
        json={"checkin_date": "2026-01-05", "sleep_hours": 8.0, "perceived_fatigue": 2},
        headers=auth_headers,
    )

    db = TestingSessionLocal()
    log = get_activity_log(db, _test_user_id(), date(2026, 1, 1), date(2026, 1, 5))
    db.close()

    assert "2026-01-01" in log
    assert "1800 kcal" in log
    assert "2026-01-05" in log
    assert "8.0hs de sueno" in log


def test_get_activity_log_no_data(client, auth_headers):
    from datetime import date

    from app.services.digital_twin import get_activity_log
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    log = get_activity_log(db, _test_user_id(), date(2020, 1, 1), date(2020, 1, 3))
    db.close()

    assert "No hay datos registrados entre 2020-01-01 y 2020-01-03" in log


def test_get_activity_log_caps_long_range(client, auth_headers):
    from datetime import date

    from app.services.digital_twin import get_activity_log
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    log = get_activity_log(db, _test_user_id(), date(2020, 1, 1), date(2020, 12, 31))
    db.close()

    assert "rango acotado a los ultimos 90 dias" in log
