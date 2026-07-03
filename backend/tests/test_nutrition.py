def test_upsert_and_get_log(client, auth_headers):
    payload = {
        "log_date": "2026-07-01",
        "calories": 2500,
        "protein_g": 180,
        "carbs_g": 250,
        "fat_g": 70,
        "water_ml": 3000,
    }
    resp = client.put("/api/v1/nutrition/logs", json=payload, headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["calories"] == 2500

    resp = client.get("/api/v1/nutrition/logs/2026-07-01", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["protein_g"] == 180


def test_upsert_updates_existing_log(client, auth_headers):
    payload = {"log_date": "2026-07-01", "calories": 2000}
    client.put("/api/v1/nutrition/logs", json=payload, headers=auth_headers)
    resp = client.put(
        "/api/v1/nutrition/logs",
        json={**payload, "calories": 2600},
        headers=auth_headers,
    )
    assert resp.json()["calories"] == 2600

    resp = client.get("/api/v1/nutrition/logs", headers=auth_headers)
    assert len(resp.json()) == 1


def test_get_log_not_found(client, auth_headers):
    resp = client.get("/api/v1/nutrition/logs/2026-01-01", headers=auth_headers)
    assert resp.status_code == 404


def test_delete_log(client, auth_headers):
    client.put(
        "/api/v1/nutrition/logs",
        json={"log_date": "2026-07-02", "calories": 2200},
        headers=auth_headers,
    )
    resp = client.delete("/api/v1/nutrition/logs/2026-07-02", headers=auth_headers)
    assert resp.status_code == 204
    resp = client.get("/api/v1/nutrition/logs/2026-07-02", headers=auth_headers)
    assert resp.status_code == 404


def test_nutrition_requires_auth(client):
    resp = client.get("/api/v1/nutrition/logs")
    assert resp.status_code == 401
