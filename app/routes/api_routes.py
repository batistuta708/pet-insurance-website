"""JSON API used by the mobile app.

Authentication: POST /api/v1/auth/login (or /register) returns a token.
Send it on every other request as:  Authorization: Bearer <token>
Errors always look like: {"error": "message"} with a 4xx status code.
"""
from functools import wraps

from flask import Blueprint, Response, current_app, g, jsonify, request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from werkzeug.security import check_password_hash, generate_password_hash

from app import db
from app.models.claim import Claim
from app.models.claim_photo import ClaimPhoto
from app.models.pet import Pet
from app.models.policy import Policy
from app.models.user import User
from app.utils.accounts import apply_admin_flag, delete_pet as _delete_pet_cascade
from app.utils.accounts import delete_user, detect_image_type
from app.utils.premium_calculator import DEFAULT_COVERAGE, calculate_monthly_premium

api_bp = Blueprint("api", __name__)

PET_TYPES = ("Dog", "Cat", "Other")
TOKEN_MAX_AGE_SECONDS = 60 * 60 * 24 * 30  # 30 days
MAX_PHOTO_BYTES = 5 * 1024 * 1024
MIN_PASSWORD_LENGTH = 8


# ---------- helpers ----------

def _serializer():
    return URLSafeTimedSerializer(current_app.config["SECRET_KEY"], salt="api-auth")


def make_token(user):
    return _serializer().dumps({"uid": user.id})


def error(message, status=400):
    return jsonify({"error": message}), status


def json_body():
    return request.get_json(silent=True) or {}


def token_required(view):
    @wraps(view)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return error("Missing or invalid Authorization header.", 401)
        try:
            data = _serializer().loads(header[7:], max_age=TOKEN_MAX_AGE_SECONDS)
        except SignatureExpired:
            return error("Session expired. Please log in again.", 401)
        except BadSignature:
            return error("Invalid token.", 401)
        user = db.session.get(User, data.get("uid"))
        if user is None:
            return error("Invalid token.", 401)
        g.api_user = user
        return view(*args, **kwargs)

    return wrapper


def validate_pet_input(data):
    """Returns (name, type, age, error_message)."""
    name = str(data.get("name") or "").strip()
    pet_type = str(data.get("type") or "").strip().capitalize()
    try:
        age = int(data.get("age"))
    except (TypeError, ValueError):
        age = -1
    if not name or len(name) > 50:
        return None, None, None, "Pet name is required (max 50 characters)."
    if pet_type not in PET_TYPES:
        return None, None, None, "Pet type must be Dog, Cat or Other."
    if not 0 <= age <= 30:
        return None, None, None, "Pet age must be a whole number between 0 and 30."
    return name, pet_type, age, None


def user_json(user):
    return {"id": user.id, "email": user.email, "is_admin": bool(user.is_admin)}


def policy_json(policy):
    return {
        "id": policy.id,
        "pet_id": policy.pet_id,
        "pet_name": policy.pet.name if policy.pet else None,
        "coverage_amount": policy.coverage_amount,
        "monthly_premium": policy.premium,
    }


def pet_json(pet):
    return {
        "id": pet.id,
        "name": pet.name,
        "type": pet.type,
        "age": pet.age,
        "policy": policy_json(pet.policy) if pet.policy else None,
    }


def claim_json(claim, policy):
    return {
        "id": claim.id,
        "policy_id": claim.policy_id,
        "pet_name": policy.pet.name if policy and policy.pet else None,
        "description": claim.description,
        "amount": claim.amount,
        "status": claim.status,
        "has_photo": ClaimPhoto.query.filter_by(claim_id=claim.id).first() is not None,
    }


def user_policies(user):
    return (
        Policy.query.join(Pet, Policy.pet_id == Pet.id)
        .filter(Pet.owner_id == user.id)
        .order_by(Policy.id)
        .all()
    )


# ---------- auth ----------

@api_bp.post("/auth/register")
def register():
    data = json_body()
    email = str(data.get("email") or "").strip().lower()
    password = str(data.get("password") or "")
    if "@" not in email or len(email) > 120:
        return error("Please enter a valid email address.")
    if len(password) < MIN_PASSWORD_LENGTH:
        return error(f"Password must be at least {MIN_PASSWORD_LENGTH} characters.")
    if User.query.filter_by(email=email).first():
        return error("An account with that email already exists.", 409)
    user = User(email=email, password=generate_password_hash(password))
    db.session.add(user)
    db.session.commit()
    apply_admin_flag(user)
    return jsonify({"token": make_token(user), "user": user_json(user)}), 201


@api_bp.post("/auth/login")
def login():
    data = json_body()
    email = str(data.get("email") or "").strip().lower()
    password = str(data.get("password") or "")
    user = User.query.filter_by(email=email).first()
    if not user or not check_password_hash(user.password, password):
        return error("Invalid email or password.", 401)
    apply_admin_flag(user)
    return jsonify({"token": make_token(user), "user": user_json(user)})


@api_bp.get("/me")
@token_required
def me():
    return jsonify(user_json(g.api_user))


@api_bp.delete("/me")
@token_required
def delete_account():
    """Permanently deletes the account and all its pets, policies and claims (Google Play requirement)."""
    delete_user(g.api_user)
    db.session.commit()
    return "", 204


@api_bp.post("/me/password")
@token_required
def change_password():
    data = json_body()
    current = str(data.get("current_password") or "")
    new = str(data.get("new_password") or "")
    if not check_password_hash(g.api_user.password, current):
        # 403, not 401: the session is fine, the password typed is wrong.
        return error("Your current password is incorrect.", 403)
    if len(new) < MIN_PASSWORD_LENGTH:
        return error(f"New password must be at least {MIN_PASSWORD_LENGTH} characters.")
    if new == current:
        return error("New password must be different from the current one.")
    g.api_user.password = generate_password_hash(new)
    db.session.commit()
    return "", 204


# ---------- quotes ----------

@api_bp.post("/quote")
def quote():
    """Price preview without saving anything. Public, so the app can show prices before sign-up."""
    data = json_body()
    pet_type = str(data.get("type") or "").strip().capitalize()
    try:
        age = int(data.get("age"))
    except (TypeError, ValueError):
        age = -1
    if pet_type not in PET_TYPES or not 0 <= age <= 30:
        return error("Provide type (Dog, Cat or Other) and age between 0 and 30.")
    return jsonify({
        "type": pet_type,
        "age": age,
        "monthly_premium": calculate_monthly_premium(pet_type, age),
        "coverage_amount": DEFAULT_COVERAGE,
    })


# ---------- pets ----------

@api_bp.get("/pets")
@token_required
def list_pets():
    pets = Pet.query.filter_by(owner_id=g.api_user.id).order_by(Pet.id).all()
    return jsonify([pet_json(p) for p in pets])


@api_bp.post("/pets")
@token_required
def create_pet():
    """Adds a pet and creates its policy at the quoted premium."""
    name, pet_type, age, msg = validate_pet_input(json_body())
    if msg:
        return error(msg)
    pet = Pet(name=name, type=pet_type, age=age, owner_id=g.api_user.id)
    db.session.add(pet)
    db.session.flush()
    db.session.add(Policy(
        pet_id=pet.id,
        coverage_amount=DEFAULT_COVERAGE,
        premium=calculate_monthly_premium(pet_type, age),
    ))
    db.session.commit()
    return jsonify(pet_json(pet)), 201


def _own_pet_or_404(pet_id):
    pet = db.session.get(Pet, pet_id)
    if pet is None or pet.owner_id != g.api_user.id:
        return None
    return pet


@api_bp.delete("/pets/<int:pet_id>")
@token_required
def delete_pet(pet_id):
    pet = _own_pet_or_404(pet_id)
    if pet is None:
        return error("Pet not found.", 404)
    _delete_pet_cascade(pet)
    db.session.commit()
    return "", 204


@api_bp.patch("/pets/<int:pet_id>")
@token_required
def update_pet(pet_id):
    """Edit name, type and/or age; the policy premium is recalculated."""
    pet = _own_pet_or_404(pet_id)
    if pet is None:
        return error("Pet not found.", 404)
    data = json_body()
    merged = {
        "name": data.get("name", pet.name),
        "type": data.get("type", pet.type),
        "age": data.get("age", pet.age),
    }
    name, pet_type, age, msg = validate_pet_input(merged)
    if msg:
        return error(msg)
    pet.name, pet.type, pet.age = name, pet_type, age
    if pet.policy:
        pet.policy.premium = calculate_monthly_premium(pet_type, age)
    db.session.commit()
    return jsonify(pet_json(pet))


# ---------- policies ----------

@api_bp.get("/policies")
@token_required
def list_policies():
    return jsonify([policy_json(p) for p in user_policies(g.api_user)])


# ---------- claims ----------

@api_bp.get("/claims")
@token_required
def list_claims():
    policies = {p.id: p for p in user_policies(g.api_user)}
    if not policies:
        return jsonify([])
    claims = (
        Claim.query.filter(Claim.policy_id.in_(policies.keys()))
        .order_by(Claim.id.desc())
        .all()
    )
    return jsonify([claim_json(c, policies.get(c.policy_id)) for c in claims])


@api_bp.post("/claims")
@token_required
def create_claim():
    data = json_body()
    try:
        policy_id = int(data.get("policy_id"))
    except (TypeError, ValueError):
        return error("policy_id is required.")
    policy = db.session.get(Policy, policy_id)
    if policy is None or policy.pet is None or policy.pet.owner_id != g.api_user.id:
        return error("Policy not found.", 404)

    description = str(data.get("description") or "").strip()
    if len(description) < 10:
        return error("Please describe what happened (at least 10 characters).")
    try:
        amount = round(float(data.get("amount")), 2)
    except (TypeError, ValueError):
        amount = 0
    if not 0 < amount <= policy.coverage_amount:
        return error(f"Amount must be more than 0 and at most {policy.coverage_amount:.2f}.")

    claim = Claim(policy_id=policy.id, description=description, amount=amount, status="Pending")
    db.session.add(claim)
    db.session.commit()
    return jsonify(claim_json(claim, policy)), 201


def _own_claim_or_none(claim_id):
    claim = db.session.get(Claim, claim_id)
    if claim is None:
        return None, None
    policy = db.session.get(Policy, claim.policy_id)
    if policy is None or policy.pet is None or policy.pet.owner_id != g.api_user.id:
        return None, None
    return claim, policy


@api_bp.post("/claims/<int:claim_id>/photo")
@token_required
def upload_claim_photo(claim_id):
    """Attach (or replace) the photo of a claim. Multipart form field: "photo"."""
    claim, policy = _own_claim_or_none(claim_id)
    if claim is None:
        return error("Claim not found.", 404)
    upload = request.files.get("photo")
    if upload is None:
        return error('Send the image as a multipart form field named "photo".')
    data = upload.read(MAX_PHOTO_BYTES + 1)
    if len(data) > MAX_PHOTO_BYTES:
        return error("Photo is too large (maximum 5 MB).", 413)
    mime = detect_image_type(data)
    if mime is None:
        return error("Photo must be a JPEG, PNG or WebP image.")
    photo = ClaimPhoto.query.filter_by(claim_id=claim.id).first()
    if photo is None:
        photo = ClaimPhoto(claim_id=claim.id, mime_type=mime, data=data)
        db.session.add(photo)
    else:
        photo.mime_type, photo.data = mime, data
    db.session.commit()
    return jsonify(claim_json(claim, policy)), 201


@api_bp.get("/claims/<int:claim_id>/photo")
@token_required
def get_claim_photo(claim_id):
    claim, _ = _own_claim_or_none(claim_id)
    photo = ClaimPhoto.query.filter_by(claim_id=claim.id).first() if claim else None
    if photo is None:
        return error("Photo not found.", 404)
    return Response(photo.data, mimetype=photo.mime_type,
                    headers={"Cache-Control": "private, max-age=3600",
                             "X-Content-Type-Options": "nosniff"})


@api_bp.errorhandler(404)
def not_found(_):
    return error("Not found.", 404)


@api_bp.errorhandler(405)
def method_not_allowed(_):
    return error("Method not allowed.", 405)
