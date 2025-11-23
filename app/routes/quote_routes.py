from flask import Blueprint, render_template, request, flash, redirect, url_for
from flask_login import login_required, current_user
from app.models.pet import Pet
from app.models.policy import Policy
from app import db

quote_bp = Blueprint('quote', __name__)

@quote_bp.route('/', methods=['GET', 'POST'])
@login_required
def get_quote():
    if request.method == 'POST':
        pet_name = request.form.get('pet_name')
        pet_type = request.form.get('pet_type')
        pet_age = int(request.form.get('pet_age'))

        # Create new pet
        new_pet = Pet(name=pet_name, type=pet_type, age=pet_age, owner_id=current_user.id)
        db.session.add(new_pet)
        db.session.commit()

        # Simple premium calculation
        base_premium = 20
        age_factor = 1 + (pet_age / 10)
        type_factor = 1.2 if pet_type.lower() == "dog" else 1.1 if pet_type.lower() == "cat" else 1.3
        premium = base_premium * age_factor * type_factor

        # Create policy
        new_policy = Policy(pet_id=new_pet.id, coverage_amount=1000, premium=premium)
        db.session.add(new_policy)
        db.session.commit()

        flash(f"Quote generated! Monthly premium: ${premium:.2f}", "success")
        return redirect(url_for('dashboard.user_dashboard'))

    return render_template('get_quote.html')
