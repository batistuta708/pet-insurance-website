from flask import Blueprint, render_template
from flask_login import login_required, current_user

dashboard = Blueprint('dashboard', __name__)

# Import models **inside route functions** to avoid circular import
@dashboard.route('/dashboard')
@login_required
def user_dashboard():
    from app.models.pet import Pet
    from app.models.policy import Policy

    pets = Pet.query.filter_by(owner_id=current_user.id).all()
    policies = [pet.policy for pet in pets if pet.policy]

    return render_template('dashboard.html', pets=pets, policies=policies)
