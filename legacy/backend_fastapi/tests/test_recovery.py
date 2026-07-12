def test_recovery_index_requires_checkin(client, auth_headers):
    resp = client.get("/api/v1/recovery/index", headers=auth_headers)
    assert resp.status_code == 404


def test_upsert_checkin_and_get_index(client, auth_headers):
    resp = client.put(
        "/api/v1/recovery/checkins",
        json={"checkin_date": "2026-07-02", "sleep_hours": 8, "perceived_fatigue": 2},
        headers=auth_headers,
    )
    assert resp.status_code == 200

    resp = client.get("/api/v1/recovery/index", headers=auth_headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["level"] == "recovered"
    assert body["recovery_index"] >= 80


def test_high_fatigue_low_sleep_gives_low_index(client, auth_headers):
    client.put(
        "/api/v1/recovery/checkins",
        json={"checkin_date": "2026-07-02", "sleep_hours": 2, "perceived_fatigue": 10},
        headers=auth_headers,
    )
    resp = client.get("/api/v1/recovery/index", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["level"] == "high_fatigue_risk"


def test_checkin_upsert_uses_latest_date(client, auth_headers):
    client.put(
        "/api/v1/recovery/checkins",
        json={"checkin_date": "2026-07-01", "sleep_hours": 4, "perceived_fatigue": 9},
        headers=auth_headers,
    )
    client.put(
        "/api/v1/recovery/checkins",
        json={"checkin_date": "2026-07-02", "sleep_hours": 8, "perceived_fatigue": 1},
        headers=auth_headers,
    )
    resp = client.get("/api/v1/recovery/index", headers=auth_headers)
    assert resp.json()["checkin_date"] == "2026-07-02"


def test_recovery_requires_auth(client):
    resp = client.get("/api/v1/recovery/index")
    assert resp.status_code == 401
