import os

from dotenv import load_dotenv

load_dotenv()


def _database_url():
    url = os.environ.get("DATABASE_URL")
    if not url:
        return "sqlite:///pet_insurance.db"
    # Name the driver explicitly (psycopg 3) so "postgres://" and "postgresql://"
    # URLs both work regardless of which driver SQLAlchemy would pick by default.
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url[len(prefix):]
    return url


class Config:
    # Set SECRET_KEY in .env for any real deployment; the fallback is for local development only.
    SECRET_KEY = os.environ.get("SECRET_KEY") or "dev-only-change-me"
    # Uses DATABASE_URL when set (e.g. Render PostgreSQL); otherwise a SQLite file in instance/.
    SQLALCHEMY_DATABASE_URI = _database_url()
    # Drop dead connections after the database restarts or idles (managed Postgres does this).
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True}
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    # Comma-separated emails that become admins when they register or log in.
    ADMIN_EMAILS = {
        e.strip().lower() for e in os.environ.get("ADMIN_EMAILS", "").split(",") if e.strip()
    }
    # Largest upload accepted (claim photos are limited to 5 MB in the API).
    MAX_CONTENT_LENGTH = 6 * 1024 * 1024
