import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    # Set SECRET_KEY in .env for any real deployment; the fallback is for local development only.
    SECRET_KEY = os.environ.get("SECRET_KEY") or "dev-only-change-me"
    # Defaults to a SQLite file in the instance/ folder (not committed to git).
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL") or "sqlite:///pet_insurance.db"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
