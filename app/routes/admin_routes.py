from flask import Blueprint, render_template
from flask_login import login_required, current_user
from app.models.user import User
from app.models.pet import Pet
from app.models.policy import Policy

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/')
@login_required
def admin_dashboard():
    if not current_user.is_admin:
        return "Access Denied", 403

    users = User.query.all()
    pets = Pet.query.all()
    policies = Policy.query.all()

    return render_template('admin_dashboard.html', users=users, pets=pets, policies=policies)
