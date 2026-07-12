from datetime import date, timedelta


def _register_and_login(client, email: str, name: str) -> dict:
    client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password123", "name": name},
    )
    resp = client.post(
        "/api/v1/auth/login",
        data={"username": email, "password": "password123"},
    )
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _create_challenge(client, headers, metric="total_volume_kg") -> dict:
    today = date.today()
    resp = client.post(
        "/api/v1/challenges",
        json={
            "name": "Reto de volumen",
            "description": "A ver quien levanta mas",
            "metric": metric,
            "starts_on": (today - timedelta(days=1)).isoformat(),
            "ends_on": (today + timedelta(days=7)).isoformat(),
        },
        headers=headers,
    )
    return resp


def _log_session_with_set(client, headers, weight, reps):
    session_id = client.post("/api/v1/workouts", json={}, headers=headers).json()["id"]
    # necesita un ejercicio existente
    from app.models.exercise import Exercise
    from tests.conftest import TestingSessionLocal

    db = TestingSessionLocal()
    ex = db.query(Exercise).first()
    if ex is None:
        ex = Exercise(
            slug="press-banca",
            name="Press banca",
            muscle_group="Pecho",
            primary_muscles=["Pectoral"],
            secondary_muscles=[],
            equipment=["Barra"],
            difficulty="intermediate",
            movement_type="compound",
            description="",
            instructions=["Baja", "Sube"],
            tips=[],
            common_mistakes=[],
            variants=[],
            benefits=[],
        )
        db.add(ex)
        db.commit()
        db.refresh(ex)
    exercise_id = ex.id
    db.close()
    client.post(
        f"/api/v1/workouts/{session_id}/sets",
        json={
            "exercise_id": exercise_id,
            "set_number": 1,
            "weight_kg": weight,
            "reps": reps,
        },
        headers=headers,
    )


def test_create_challenge_auto_joins_owner(client):
    headers = _register_and_login(client, "owner@appgym.com", "Owner")
    resp = _create_challenge(client, headers)
    assert resp.status_code == 201
    body = resp.json()
    assert body["is_owner"] is True
    assert body["participant_count"] == 1
    assert len(body["invite_code"]) == 6
    assert len(body["leaderboard"]) == 1
    assert body["leaderboard"][0]["is_me"] is True


def test_join_by_invite_code_and_leaderboard_ranks_by_volume(client):
    owner = _register_and_login(client, "owner@appgym.com", "Owner")
    created = _create_challenge(client, owner).json()
    code = created["invite_code"]
    challenge_id = created["id"]

    rival = _register_and_login(client, "rival@appgym.com", "Rival")
    joined = client.post(
        "/api/v1/challenges/join",
        json={"invite_code": code},
        headers=rival,
    )
    assert joined.status_code == 200
    assert joined.json()["participant_count"] == 2

    # owner: volumen 100*5=500 ; rival: 60*5=300 -> owner primero
    _log_session_with_set(client, owner, weight=100, reps=5)
    _log_session_with_set(client, rival, weight=60, reps=5)

    detail = client.get(f"/api/v1/challenges/{challenge_id}", headers=owner).json()
    board = detail["leaderboard"]
    assert board[0]["name"] == "Owner"
    assert board[0]["value"] == 500
    assert board[0]["rank"] == 1
    assert board[1]["name"] == "Rival"
    assert board[1]["value"] == 300


def test_join_with_bad_code_returns_404(client):
    headers = _register_and_login(client, "u@appgym.com", "U")
    resp = client.post(
        "/api/v1/challenges/join",
        json={"invite_code": "ZZZZZZ"},
        headers=headers,
    )
    assert resp.status_code == 404


def test_owner_cannot_leave_but_can_delete(client):
    owner = _register_and_login(client, "owner@appgym.com", "Owner")
    challenge_id = _create_challenge(client, owner).json()["id"]

    leave = client.delete(f"/api/v1/challenges/{challenge_id}/leave", headers=owner)
    assert leave.status_code == 400

    deleted = client.delete(f"/api/v1/challenges/{challenge_id}", headers=owner)
    assert deleted.status_code == 204
    assert client.get("/api/v1/challenges", headers=owner).json() == []


def test_non_owner_can_leave(client):
    owner = _register_and_login(client, "owner@appgym.com", "Owner")
    code = _create_challenge(client, owner).json()["invite_code"]
    rival = _register_and_login(client, "rival@appgym.com", "Rival")
    challenge_id = client.post(
        "/api/v1/challenges/join", json={"invite_code": code}, headers=rival
    ).json()["id"]

    leave = client.delete(f"/api/v1/challenges/{challenge_id}/leave", headers=rival)
    assert leave.status_code == 204
    assert client.get("/api/v1/challenges", headers=rival).json() == []


def test_non_member_cannot_view_challenge(client):
    owner = _register_and_login(client, "owner@appgym.com", "Owner")
    challenge_id = _create_challenge(client, owner).json()["id"]
    stranger = _register_and_login(client, "stranger@appgym.com", "Stranger")
    resp = client.get(f"/api/v1/challenges/{challenge_id}", headers=stranger)
    assert resp.status_code == 404


def test_reject_end_before_start(client):
    headers = _register_and_login(client, "u@appgym.com", "U")
    today = date.today()
    resp = client.post(
        "/api/v1/challenges",
        json={
            "name": "Mal reto",
            "metric": "total_reps",
            "starts_on": today.isoformat(),
            "ends_on": (today - timedelta(days=1)).isoformat(),
        },
        headers=headers,
    )
    assert resp.status_code == 422
