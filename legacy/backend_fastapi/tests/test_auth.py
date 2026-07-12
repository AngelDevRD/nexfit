def test_register_and_login(client):
    resp = client.post(
        "/api/v1/auth/register",
        json={"email": "user@appgym.com", "password": "password123", "name": "User"},
    )
    assert resp.status_code == 201
    assert "access_token" in resp.json()

    resp = client.post(
        "/api/v1/auth/login",
        data={"username": "user@appgym.com", "password": "password123"},
    )
    assert resp.status_code == 200
    assert "access_token" in resp.json()


def test_register_duplicate_email(client):
    payload = {"email": "dup@appgym.com", "password": "password123", "name": "User"}
    client.post("/api/v1/auth/register", json=payload)
    resp = client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 409


def test_login_wrong_password(client):
    client.post(
        "/api/v1/auth/register",
        json={"email": "wrong@appgym.com", "password": "password123", "name": "User"},
    )
    resp = client.post(
        "/api/v1/auth/login",
        data={"username": "wrong@appgym.com", "password": "badpassword"},
    )
    assert resp.status_code == 401


def test_me_requires_token(client):
    resp = client.get("/api/v1/auth/me")
    assert resp.status_code == 401


def test_me_with_token(client, auth_headers):
    resp = client.get("/api/v1/auth/me", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["email"] == "test@appgym.com"
