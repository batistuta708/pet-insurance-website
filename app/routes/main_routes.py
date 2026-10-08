from flask import Blueprint, render_template

from app.utils.premium_calculator import DEFAULT_COVERAGE, calculate_monthly_premium

main_bp = Blueprint('main', __name__)

@main_bp.route('/')
def index():
    # Starting values for the quote tag; the page updates them live via /api/v1/quote.
    from_prices = {t: calculate_monthly_premium(t, 0) for t in ("Dog", "Cat", "Other")}
    return render_template('index.html', start_price=calculate_monthly_premium("Dog", 3),
                           from_prices=from_prices, coverage=DEFAULT_COVERAGE)

@main_bp.route('/coverage')
def coverage():
    prices = {t: [calculate_monthly_premium(t, a) for a in (1, 5, 10)] for t in ("Dog", "Cat", "Other")}
    return render_template('coverage.html', prices=prices, coverage=DEFAULT_COVERAGE)

@main_bp.route('/about')
def about():
    return render_template('about.html')

@main_bp.route('/contact')
def contact():
    return render_template('contact.html')

@main_bp.route('/privacy')
def privacy():
    return render_template('privacy.html')


@main_bp.route('/delete-account')
def delete_account():
    return render_template('delete_account.html')
