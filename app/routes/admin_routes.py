from flask import Blueprint, abort, render_template
from flask_login import current_user, login_required

from app.models.pet import Pet
from app.models.policy import Policy
from app.models.user import User

admin_bp = Blueprint("admin", __name__)


@admin_bp.route("/")
@login_required
def admin_dashboard():
    if not current_user.is_admin:
        abort(403)

    users = User.query.all()
    pets = Pet.query.all()
    policies = Policy.query.all()

    return render_template("admin_dashboard.html", users=users, pets=pets, policies=policies)
