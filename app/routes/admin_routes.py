from functools import wraps

from flask import Blueprint, Response, abort, flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required

from app import db
from app.models.claim import Claim
from app.models.claim_photo import ClaimPhoto
from app.models.pet import Pet
from app.models.policy import Policy
from app.models.user import User

admin_bp = Blueprint("admin", __name__)

CLAIM_STATUSES = ("Pending", "Approved", "Rejected")


def admin_required(view):
    @wraps(view)
    @login_required
    def wrapper(*args, **kwargs):
        if not current_user.is_admin:
            abort(403)
        return view(*args, **kwargs)

    return wrapper


@admin_bp.route("/")
@admin_required
def admin_dashboard():
    users = User.query.order_by(User.id).all()
    pets = Pet.query.order_by(Pet.id).all()
    policies = Policy.query.order_by(Policy.id).all()

    claims = Claim.query.order_by(Claim.id.desc()).all()
    photo_ids = {p.claim_id for p in ClaimPhoto.query.with_entities(ClaimPhoto.claim_id).all()}
    policies_by_id = {p.id: p for p in policies}
    claim_rows = []
    for c in claims:
        policy = policies_by_id.get(c.policy_id)
        pet = policy.pet if policy else None
        claim_rows.append({
            "claim": c,
            "pet_name": pet.name if pet else "—",
            "owner_email": pet.owner.email if pet and pet.owner else "—",
            "coverage": policy.coverage_amount if policy else None,
            "has_photo": c.id in photo_ids,
        })
    pending = sum(1 for c in claims if c.status == "Pending")

    return render_template(
        "admin_dashboard.html",
        users=users, pets=pets, policies=policies,
        claim_rows=claim_rows, pending_count=pending, statuses=CLAIM_STATUSES,
    )


@admin_bp.post("/claims/<int:claim_id>/status")
@admin_required
def set_claim_status(claim_id):
    claim = db.session.get(Claim, claim_id) or abort(404)
    status = request.form.get("status", "")
    if status not in CLAIM_STATUSES:
        abort(400)
    claim.status = status
    db.session.commit()
    flash(f"Claim #{claim.id} marked as {status}.", "success")
    return redirect(url_for("admin.admin_dashboard") + "#claims")


@admin_bp.get("/claims/<int:claim_id>/photo")
@admin_required
def claim_photo(claim_id):
    photo = ClaimPhoto.query.filter_by(claim_id=claim_id).first() or abort(404)
    return Response(photo.data, mimetype=photo.mime_type,
                    headers={"X-Content-Type-Options": "nosniff"})
