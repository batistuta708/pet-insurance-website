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
- JSON API at `/api/v1` (token auth) for the mobile app: auth, quotes, pets, policies, claims, account deletion
- Flutter mobile app in [`mobile/`](mobile/README.md), including the Google Play release steps

**Not built yet:** claim submission on the website (it works in the app),
editing/deleting pets, multiple plan tiers, payments.

## Project structure

```
pet-insurance-website/
├── app/
│   ├── __init__.py              # App factory, extensions, blueprint registration
│   ├── config.py                # Settings (reads .env)
│   ├── models/                  # User, Pet, Policy, Claim
│   ├── routes/                  # main, auth, quote, dashboard, admin, api blueprints
│   ├── utils/premium_calculator.py
│   ├── static/                  # css, js, images
│   └── templates/
├── mobile/                      # Flutter app (see mobile/README.md)
├── tests/                       # test_app.py (website), test_api.py (JSON API)
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

## JSON API (summary)

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/v1/auth/register` | – | `{email, password}` → `{token, user}` |
| POST | `/api/v1/auth/login` | – | `{email, password}` → `{token, user}` |
| GET / DELETE | `/api/v1/me` | Bearer | Current user / delete account and all data |
| POST | `/api/v1/quote` | – | `{type, age}` → price preview |
| GET / POST | `/api/v1/pets` | Bearer | List pets / add pet (creates its policy) |
| DELETE | `/api/v1/pets/<id>` | Bearer | Remove pet, its policy and claims |
| GET | `/api/v1/policies` | Bearer | List policies |
| GET / POST | `/api/v1/claims` | Bearer | List claims / `{policy_id, description, amount}` |

Errors are `{"error": "message"}` with a 4xx status. Tokens last 30 days.

## Deployment

Start command for Render/Heroku-style hosts: `gunicorn run:app`.
Set `SECRET_KEY` (and ideally `DATABASE_URL` for a persistent database) as environment variables.

## Author

Batistuta Indiazi — GitHub: [batistuta708](https://github.com/batistuta708)

## License

MIT
