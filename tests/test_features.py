"""Claim photos, claim review by admins, password change, pet editing, Play pages."""
import io

import pytest

from app import create_app, db
from app.models.claim import Claim
from app.models.claim_photo import ClaimPhoto
from app.models.user import User

API = "/api/v1"
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 64


class TestConfig:
    TESTING = True
    SECRET_KEY = "test"
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    WTF_CSRF_ENABLED = False
    ADMIN_EMAILS = {"boss@example.com"}
    MAX_CONTENT_LENGTH = 6 * 1024 * 1024


@pytest.fixture
def client():
    app = create_app(TestConfig)
    with app.app_context():
        yield app.test_client()
        db.session.remove()  # release the connection so DROP TABLE is not blocked
        db.drop_all()


def register(client, email="owner@example.com", password="password123"):
    resp = client.post(f"{API}/auth/register", json={"email": email, "password": password})
    assert resp.status_code == 201, resp.get_json()
    return {"Authorization": f"Bearer {resp.get_json()['token']}"}


def new_claim(client, h, name="Rex"):
    pet = client.post(f"{API}/pets", json={"name": name, "type": "Dog", "age": 3}, headers=h).get_json()
    claim = client.post(f"{API}/claims", json={
        "policy_id": pet["policy"]["id"], "description": "Vet visit for a sore paw", "amount": 80,
    }, headers=h).get_json()
    return pet, claim


def upload(client, h, claim_id, data, filename="bill.png"):
    return client.post(f"{API}/claims/{claim_id}/photo", headers=h,
                       data={"photo": (io.BytesIO(data), filename)},
                       content_type="multipart/form-data")


# ---------- Play Store pages ----------

def test_delete_account_page_and_footer(client):
    page = client.get("/delete-account")
    assert page.status_code == 200 and b"batistutatinami@gmail.com" in page.data
    home = client.get("/").data
    assert b"/delete-account" in home and b"no real insurance" in home


# ---------- claim photos ----------

def test_photo_upload_and_download(client):
    h = register(client)
    _, claim = new_claim(client, h)
    assert claim["has_photo"] is False

    resp = upload(client, h, claim["id"], PNG)
    assert resp.status_code == 201 and resp.get_json()["has_photo"] is True

    got = client.get(f"{API}/claims/{claim['id']}/photo", headers=h)
    assert got.status_code == 200 and got.data == PNG and got.mimetype == "image/png"
    assert got.headers["X-Content-Type-Options"] == "nosniff"

    # replacing keeps a single photo
    assert upload(client, h, claim["id"], JPEG).status_code == 201
    assert ClaimPhoto.query.count() == 1
    assert client.get(f"{API}/claims/{claim['id']}/photo", headers=h).mimetype == "image/jpeg"
    assert client.get(f"{API}/claims", headers=h).get_json()[0]["has_photo"] is True


def test_photo_rejects_bad_input(client):
    h = register(client)
    _, claim = new_claim(client, h)
    assert upload(client, h, claim["id"], b"<script>alert(1)</script>", "x.png").status_code == 400
    assert client.post(f"{API}/claims/{claim['id']}/photo", headers=h).status_code == 400
    too_big = PNG + b"\x00" * (5 * 1024 * 1024)
    assert upload(client, h, claim["id"], too_big).status_code == 413
    assert ClaimPhoto.query.count() == 0


def test_photos_are_private(client):
    h1 = register(client, "one@example.com")
    h2 = register(client, "two@example.com")
    _, claim = new_claim(client, h1)
    upload(client, h1, claim["id"], PNG)
    assert upload(client, h2, claim["id"], PNG).status_code == 404
    assert client.get(f"{API}/claims/{claim['id']}/photo", headers=h2).status_code == 404
    assert client.get(f"{API}/claims/{claim['id']}/photo").status_code == 401


def test_deleting_pet_or_account_removes_photos(client):
    h = register(client)
    pet, claim = new_claim(client, h)
    upload(client, h, claim["id"], PNG)
    assert client.delete(f"{API}/pets/{pet['id']}", headers=h).status_code == 204
    assert ClaimPhoto.query.count() == 0 and Claim.query.count() == 0

    _, claim = new_claim(client, h, "Tom")
    upload(client, h, claim["id"], PNG)
    assert client.delete(f"{API}/me", headers=h).status_code == 204
    assert ClaimPhoto.query.count() == 0 and User.query.count() == 0


# ---------- admin claim review ----------

def web_login(client, email, password="password123"):
    return client.post("/login", data={"email": email, "password": password})


def test_admin_email_gets_admin_and_reviews_claims(client):
    h = register(client)                    # normal user files a claim with a photo
    _, claim = new_claim(client, h)
    upload(client, h, claim["id"], PNG)

    register(client, "BOSS@example.com")    # listed in ADMIN_EMAILS (case-insensitive)
    assert User.query.filter_by(email="boss@example.com").one().is_admin

    web_login(client, "boss@example.com")
    page = client.get("/admin/")
    assert page.status_code == 200
    assert b"1 pending" in page.data and b"owner@example.com" in page.data
    assert client.get(f"/admin/claims/{claim['id']}/photo").data == PNG

    resp = client.post(f"/admin/claims/{claim['id']}/status", data={"status": "Approved"})
    assert resp.status_code == 302
    assert client.get(f"{API}/claims", headers=h).get_json()[0]["status"] == "Approved"
    assert client.post(f"/admin/claims/{claim['id']}/status", data={"status": "Paid!"}).status_code == 400


def test_non_admin_cannot_review_claims(client):
    h = register(client)
    _, claim = new_claim(client, h)
    web_login(client, "owner@example.com")
    assert client.post(f"/admin/claims/{claim['id']}/status", data={"status": "Approved"}).status_code == 403
    assert client.get(f"/admin/claims/{claim['id']}/photo").status_code == 403
    assert Claim.query.one().status == "Pending"


def test_admin_dashboard_with_no_claims(client):
    register(client, "boss@example.com")
    web_login(client, "boss@example.com")
    assert b"No claims yet" in client.get("/admin/").data


# ---------- password change ----------

def test_change_password(client):
    h = register(client)
    url = f"{API}/me/password"
    assert client.post(url, json={"current_password": "wrong", "new_password": "newpassword1"}, headers=h).status_code == 403
    assert client.post(url, json={"current_password": "password123", "new_password": "short"}, headers=h).status_code == 400
    assert client.post(url, json={"current_password": "password123", "new_password": "password123"}, headers=h).status_code == 400
    assert client.post(url, json={"current_password": "password123", "new_password": "newpassword1"}, headers=h).status_code == 204

    login = lambda pw: client.post(f"{API}/auth/login", json={"email": "owner@example.com", "password": pw})
    assert login("password123").status_code == 401
    assert login("newpassword1").status_code == 200


# ---------- edit pet ----------

def test_edit_pet_recalculates_premium(client):
    h = register(client)
    pet = client.post(f"{API}/pets", json={"name": "Rex", "type": "Dog", "age": 3}, headers=h).get_json()
    old = pet["policy"]["monthly_premium"]

    resp = client.patch(f"{API}/pets/{pet['id']}", json={"name": "Rexy", "age": 8}, headers=h)
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["name"] == "Rexy" and body["age"] == 8 and body["type"] == "Dog"
    assert body["policy"]["monthly_premium"] > old

    assert client.patch(f"{API}/pets/{pet['id']}", json={"age": 99}, headers=h).status_code == 400
    assert client.patch(f"{API}/pets/{pet['id']}", json={"type": "Dragon"}, headers=h).status_code == 400
    other = register(client, "two@example.com")
    assert client.patch(f"{API}/pets/{pet['id']}", json={"name": "Mine"}, headers=other).status_code == 404
