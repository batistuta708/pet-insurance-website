"""Shared account helpers for the website and the API."""
from flask import current_app

from app import db
from app.models.claim import Claim
from app.models.claim_photo import ClaimPhoto
from app.models.pet import Pet


def apply_admin_flag(user):
    """Grant admin to emails listed in ADMIN_EMAILS (used on Render, where there is no shell)."""
    if not user.is_admin and user.email.lower() in current_app.config.get("ADMIN_EMAILS", set()):
        user.is_admin = True
        db.session.commit()


def delete_claims_for_policy(policy_id):
    claim_ids = [c.id for c in Claim.query.filter_by(policy_id=policy_id).all()]
    if claim_ids:
        ClaimPhoto.query.filter(ClaimPhoto.claim_id.in_(claim_ids)).delete(synchronize_session=False)
        Claim.query.filter(Claim.id.in_(claim_ids)).delete(synchronize_session=False)


def delete_pet(pet):
    """Deletes a pet with its policy, claims and claim photos (caller commits)."""
    if pet.policy:
        delete_claims_for_policy(pet.policy.id)
        db.session.delete(pet.policy)
    db.session.delete(pet)


def delete_user(user):
    for pet in Pet.query.filter_by(owner_id=user.id).all():
        delete_pet(pet)
    db.session.delete(user)


# Image types accepted for claim photos, recognised by their first bytes.
_SIGNATURES = (
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n", "image/png"),
)


def detect_image_type(data):
    for signature, mime in _SIGNATURES:
        if data.startswith(signature):
            return mime
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None
