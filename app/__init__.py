import os

from flask import Flask
from flask_login import LoginManager
from flask_sqlalchemy import SQLAlchemy
from flask_wtf.csrf import CSRFProtect

db = SQLAlchemy()
csrf = CSRFProtect()
login_manager = LoginManager()
login_manager.login_view = "auth.login"
login_manager.login_message_category = "info"


def create_app(config_object="app.config.Config"):
    app = Flask(__name__, instance_relative_config=True)
    app.config.from_object(config_object)
    os.makedirs(app.instance_path, exist_ok=True)

    db.init_app(app)
    csrf.init_app(app)
    login_manager.init_app(app)

    # Import models so SQLAlchemy knows every table before create_all()
    from app.models import claim, pet, policy  # noqa: F401
    from app.models.user import User

    @login_manager.user_loader
    def load_user(user_id):
        return db.session.get(User, int(user_id))

    # Register blueprints
    from app.routes.admin_routes import admin_bp
    from app.routes.auth_routes import auth_bp
    from app.routes.dashboard_routes import dashboard
    from app.routes.main_routes import main_bp
    from app.routes.quote_routes import quote_bp

    app.register_blueprint(main_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(quote_bp, url_prefix="/quote")
    app.register_blueprint(dashboard)
    app.register_blueprint(admin_bp, url_prefix="/admin")

    # Create tables on startup so it also works under gunicorn, not only `python run.py`
    with app.app_context():
        db.create_all()

    return app
