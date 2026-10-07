from flask import Blueprint, flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required

from app import db
from app.models.pet import Pet
from app.models.policy import Policy
from app.utils.premium_calculator import DEFAULT_COVERAGE, calculate_monthly_premium

quote_bp = Blueprint("quote", __name__)

PET_TYPES = ("Dog", "Cat", "Other")


@quote_bp.route("/", methods=["GET", "POST"])
@login_required
def get_quote():
    if request.method == "POST":
        pet_name = (request.form.get("pet_name") or "").strip()
        pet_type = request.form.get("pet_type") or ""
        try:
            pet_age = int(request.form.get("pet_age", ""))
        except ValueError:
            pet_age = -1

        if not pet_name or pet_type not in PET_TYPES or not 0 <= pet_age <= 30:
            flash("Please enter a pet name, choose a type, and an age between 0 and 30.", "danger")
            return render_template("get_quote.html"), 400

        premium = calculate_monthly_premium(pet_type, pet_age)

        new_pet = Pet(name=pet_name, type=pet_type, age=pet_age, owner_id=current_user.id)
        db.session.add(new_pet)
        db.session.flush()  # gives new_pet an id without a second commit
        db.session.add(Policy(pet_id=new_pet.id, coverage_amount=DEFAULT_COVERAGE, premium=premium))
        db.session.commit()

        flash(f"Quote generated! Monthly premium: ${premium:.2f}", "success")
        return redirect(url_for("dashboard.user_dashboard"))

    return render_template("get_quote.html")
