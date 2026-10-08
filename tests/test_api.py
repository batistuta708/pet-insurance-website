import pytest

from app import create_app, db

API = "/api/v1"


class TestConfig:
    TESTING = True
    SECRET_KEY = "test"
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    # CSRF stays ON here to prove the API is exempt from it


@pytest.fixture
def client():
    app = create_app(TestConfig)
    with app.app_context():
        yield app.test_client()
        db.session.remove()  # release the connection so DROP TABLE is not blocked
        db.drop_all()


def auth(client, email="owner@example.com", password="password123"):
    resp = client.post(f"{API}/auth/register", json={"email": email, "password": password})
    assert resp.status_code == 201, resp.get_json()
    return {"Authorization": f"Bearer {resp.get_json()['token']}"}


def test_register_login_me(client):
    h = auth(client)
    resp = client.post(f"{API}/auth/login", json={"email": "OWNER@example.com", "password": "password123"})
    assert resp.status_code == 200 and resp.get_json()["user"]["email"] == "owner@example.com"
    assert client.get(f"{API}/me", headers=h).get_json()["email"] == "owner@example.com"


def test_auth_errors(client):
    auth(client)
    assert client.post(f"{API}/auth/register", json={"email": "owner@example.com", "password": "password123"}).status_code == 409
    assert client.post(f"{API}/auth/register", json={"email": "bad", "password": "password123"}).status_code == 400
    assert client.post(f"{API}/auth/register", json={"email": "x@y.com", "password": "short"}).status_code == 400
    assert client.post(f"{API}/auth/login", json={"email": "owner@example.com", "password": "wrong"}).status_code == 401
    assert client.get(f"{API}/me").status_code == 401
    assert client.get(f"{API}/me", headers={"Authorization": "Bearer garbage"}).status_code == 401
    assert "error" in client.get(f"{API}/me").get_json()


def test_quote_preview_is_public(client):
    resp = client.post(f"{API}/quote", json={"type": "dog", "age": 3})
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["type"] == "Dog" and body["monthly_premium"] == 31.2 and body["coverage_amount"] == 1000
    assert client.post(f"{API}/quote", json={"type": "Dragon", "age": 3}).status_code == 400


def test_pet_lifecycle(client):
    h = auth(client)
    resp = client.post(f"{API}/pets", json={"name": "Rex", "type": "Dog", "age": 3}, headers=h)
    assert resp.status_code == 201
    pet = resp.get_json()
    assert pet["policy"]["monthly_premium"] == 31.2

    assert [p["name"] for p in client.get(f"{API}/pets", headers=h).get_json()] == ["Rex"]
    policies = client.get(f"{API}/policies", headers=h).get_json()
    assert policies[0]["pet_name"] == "Rex"

    assert client.post(f"{API}/pets", json={"name": "", "type": "Dog", "age": 3}, headers=h).status_code == 400
    assert client.post(f"{API}/pets", json={"name": "A", "type": "Dog", "age": "x"}, headers=h).status_code == 400

    assert client.delete(f"{API}/pets/{pet['id']}", headers=h).status_code == 204
    assert client.get(f"{API}/pets", headers=h).get_json() == []
    assert client.get(f"{API}/policies", headers=h).get_json() == []


def test_claims(client):
    h = auth(client)
    pet = client.post(f"{API}/pets", json={"name": "Tom", "type": "Cat", "age": 2}, headers=h).get_json()
    policy_id = pet["policy"]["id"]

    resp = client.post(f"{API}/claims", json={
        "policy_id": policy_id, "description": "Vet visit for an ear infection", "amount": 120.5,
    }, headers=h)
    assert resp.status_code == 201
    assert resp.get_json()["status"] == "Pending" and resp.get_json()["pet_name"] == "Tom"

    assert client.post(f"{API}/claims", json={"policy_id": policy_id, "description": "too short", "amount": 10}, headers=h).status_code == 400
    assert client.post(f"{API}/claims", json={"policy_id": policy_id, "description": "Very expensive surgery", "amount": 5000}, headers=h).status_code == 400

    claims = client.get(f"{API}/claims", headers=h).get_json()
    assert len(claims) == 1 and claims[0]["amount"] == 120.5


def test_users_cannot_touch_each_others_data(client):
    h1 = auth(client, "one@example.com")
    h2 = auth(client, "two@example.com")
    pet = client.post(f"{API}/pets", json={"name": "Rex", "type": "Dog", "age": 3}, headers=h1).get_json()

    assert client.get(f"{API}/pets", headers=h2).get_json() == []
    assert client.delete(f"{API}/pets/{pet['id']}", headers=h2).status_code == 404
    resp = client.post(f"{API}/claims", json={
        "policy_id": pet["policy"]["id"], "description": "Trying someone else's policy", "amount": 10,
    }, headers=h2)
    assert resp.status_code == 404


def test_unknown_api_route_returns_json(client):
    resp = client.get(f"{API}/nope")
    assert resp.status_code == 404 and resp.get_json() == {"error": "Not found."}


def test_delete_account_removes_everything(client):
    from app.models.claim import Claim
    from app.models.pet import Pet
    from app.models.policy import Policy
    from app.models.user import User

    h = auth(client)
    other = auth(client, "keep@example.com")
    pet = client.post(f"{API}/pets", json={"name": "Rex", "type": "Dog", "age": 3}, headers=h).get_json()
    client.post(f"{API}/pets", json={"name": "Stay", "type": "Cat", "age": 1}, headers=other)
    client.post(f"{API}/claims", json={"policy_id": pet["policy"]["id"], "description": "Vet visit for a sore paw", "amount": 50}, headers=h)

    assert client.delete(f"{API}/me", headers=h).status_code == 204
    assert client.get(f"{API}/me", headers=h).status_code == 401
    assert User.query.count() == 1 and Pet.query.count() == 1 and Policy.query.count() == 1 and Claim.query.count() == 0
