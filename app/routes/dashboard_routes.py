from flask import Blueprint, render_template
from flask_login import current_user, login_required

from app.models.claim import Claim
from app.models.pet import Pet

dashboard = Blueprint("dashboard", __name__)


@dashboard.route("/dashboard")
@login_required
def user_dashboard():
    pets = Pet.query.filter_by(owner_id=current_user.id).order_by(Pet.id).all()
    policy_pets = {pet.policy.id: pet for pet in pets if pet.policy}
    claims = []
    if policy_pets:
        for claim in (Claim.query.filter(Claim.policy_id.in_(policy_pets.keys()))
                      .order_by(Claim.id.desc()).all()):
            claims.append({"claim": claim, "pet_name": policy_pets[claim.policy_id].name})
    return render_template("dashboard.html", pets=pets, claims=claims)
