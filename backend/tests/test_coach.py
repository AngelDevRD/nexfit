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
