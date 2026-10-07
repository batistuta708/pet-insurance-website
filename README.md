# Pet Insurance Website

A Flask web application for pet insurance: users register, add their pets, get an
instant monthly premium quote, and see their pets and policies on a dashboard.
Admins get an overview of all users, pets and policies.

## Features

- Landing, coverage, about and contact pages
- Account registration and login (Flask-Login, hashed passwords, CSRF protection)
- Instant quote: premium calculated from pet type and age, saved as a policy
- User dashboard listing pets and policies
- Admin dashboard (users with `is_admin = True`)

**Not built yet:** claim submission (the `Claim` model exists, no pages yet),
editing/deleting pets, multiple plan tiers, payments.

## Project structure

```
pet-insurance-website/
├── app/
│   ├── __init__.py              # App factory, extensions, blueprint registration
│   ├── config.py                # Settings (reads .env)
│   ├── models/                  # User, Pet, Policy, Claim
│   ├── routes/                  # main, auth, quote, dashboard, admin blueprints
│   ├── utils/premium_calculator.py
│   ├── static/                  # css, js, images
│   └── templates/
├── tests/test_app.py
├── run.py
└── requirements.txt
```

## Setup

```bash
git clone https://github.com/batistuta708/pet-insurance-website.git
cd pet-insurance-website
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create a `.env` file in the project root:

```
SECRET_KEY=<output of: python -c "import secrets; print(secrets.token_hex(32))">
FLASK_DEBUG=1
# DATABASE_URL=postgresql://...   (optional; defaults to SQLite in instance/)
```

Run it:

```bash
python run.py
```

Open http://127.0.0.1:5000/. Database tables are created automatically on start.

To make a user an admin:

```bash
flask --app run shell
>>> from app.models.user import User; from app import db
>>> u = User.query.filter_by(email="you@example.com").first(); u.is_admin = True; db.session.commit()
```

## Tests

```bash
pytest
```

## Deployment

Start command for Render/Heroku-style hosts: `gunicorn run:app`.
Set `SECRET_KEY` (and ideally `DATABASE_URL` for a persistent database) as environment variables.

## Author

Batistuta Indiazi — GitHub: [batistuta708](https://github.com/batistuta708)

## License

MIT
