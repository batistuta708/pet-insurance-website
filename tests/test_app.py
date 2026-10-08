import pytest

from app import create_app, db
from app.models.policy import Policy
from app.models.user import User
from app.utils.premium_calculator import calculate_monthly_premium


class TestConfig:
    TESTING = True
    SECRET_KEY = "test"
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    WTF_CSRF_ENABLED = False


@pytest.fixture
def client():
    app = create_app(TestConfig)
    with app.app_context():
        yield app.test_client()
        db.session.remove()  # release the connection so DROP TABLE is not blocked
        db.drop_all()


def register_and_login(client, email="owner@example.com", password="password123"):
    client.post("/register", data={"email": email, "password": password})
    return client.post("/login", data={"email": email, "password": password})


@pytest.mark.parametrize("path", ["/", "/coverage", "/about", "/contact", "/privacy", "/login", "/register"])
def test_public_pages_load(client, path):
    assert client.get(path).status_code == 200


def test_protected_pages_redirect_to_login(client):
    for path in ["/quote/", "/dashboard", "/admin/"]:
        resp = client.get(path)
        assert resp.status_code == 302 and "/login" in resp.headers["Location"]


def test_register_login_and_quote_flow(client):
    resp = register_and_login(client)
    assert resp.status_code == 302 and resp.headers["Location"].endswith("/dashboard")

    resp = client.post("/quote/", data={"pet_name": "Rex", "pet_type": "Dog", "pet_age": "3"})
    assert resp.status_code == 302
    policy = Policy.query.one()
    assert policy.pet.name == "Rex" and policy.premium == calculate_monthly_premium("Dog", 3)
    assert b"Rex" in client.get("/dashboard").data


def test_duplicate_email_rejected(client):
    client.post("/register", data={"email": "a@example.com", "password": "password123"})
    resp = client.post("/register", data={"email": "a@example.com", "password": "password123"})
    assert resp.status_code == 400 and User.query.count() == 1


def test_invalid_quote_rejected(client):
    register_and_login(client)
    resp = client.post("/quote/", data={"pet_name": "Rex", "pet_type": "Dog", "pet_age": "abc"})
    assert resp.status_code == 400 and Policy.query.count() == 0


def test_admin_requires_admin_flag(client):
    register_and_login(client)
    assert client.get("/admin/").status_code == 403
    user = User.query.one()
    user.is_admin = True
    db.session.commit()
    assert client.get("/admin/").status_code == 200


def test_premium_calculation():
    assert calculate_monthly_premium("Dog", 0) == 24.0
    assert calculate_monthly_premium("cat", 10) == 44.0
    assert calculate_monthly_premium("Rabbit", 5) == 39.0
