
🐾 Pet Insurance Website
A modern Flask-powered web application for pet insurance management.
This project provides a clean, modular structure suitable for learning, portfolio use, and production-ready deployment.

 Preview
(Add screenshots here if you want — tell me and I’ll generate them.)

 Features
 Landing page showcasing pet insurance services

 Pet insurance plans UI (Basic, Standard, Premium)

 Online claim submission

 Contact form

 Responsive, modern UI using Bootstrap

 Modular Flask structure (Blueprint-ready)

Easily extendable (database, auth, admin panel)

 Production deployment-ready (Gunicorn, Render/Heroku/Docker)

Project Structure

pet-insurance-website/
│
├── app/
│   ├── __init__.py         # App factory + configuration
│   ├── routes.py           # All main routes
│   ├── forms.py            # WTForms (Contact, Claims)
│   ├── models.py           # Database models (if using SQLAlchemy)
│   │
│   ├── static/
│   │   ├── css/            # Stylesheets
│   │   ├── js/             # Custom scripts
│   │   └── images/         # Icons, banners, pet images
│   │
│   └── templates/
│       ├── base.html       # Master layout
│       ├── index.html      # Home page
│       ├── plans.html      # Pet insurance plans
│       ├── claim.html      # New claim page
│       ├── contact.html    # Contact form
│       └── layout.html     # Shared layouts / components
│
├── run.py                  # App entry point
├── requirements.txt        # Dependencies
└── README.md               # Documentation

Tech Stack

Python 3.8+

Flask (core framework)

WTForms (form handling)

Flask-WTF (CSRF protection)

Bootstrap 5 (frontend styling)

Jinja2 (templating engine)

Installation & Setup
1 Clone the project

git clone https://github.com/batistuta708/pet-insurance-website.git
cd pet-insurance-website

Create and activate a virtual environment

Mac / Linux

python3 -m venv venv
source venv/bin/activate


Windows

python -m venv venv
venv\Scripts\activate

3️ Install dependencies
pip install -r requirements.txt

4️ Run the application
flask run


Your application is now accessible at:
 http://127.0.0.1:5000/

 Environment Variables

Create a .env file in the project root:

FLASK_ENV=development
SECRET_KEY=your-super-secret-key


You can generate a secure key with:

python -c "import secrets; print(secrets.token_hex(32))"

 Database Setup (optional)

If using SQLAlchemy:

Create database models in models.py

Initialize the database:

from app import create_app, db
app = create_app()
app.app_context().push()
db.create_all()

Running Tests (optional)

If you add tests, run them using:

pytest

 Deployment Guide
Deploy to Render

Create a new web service

Use gunicorn run:app as start command

Add environment variables

Deploy

Deploy with Docker

Create a file named Dockerfile:

FROM python:3.10
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["gunicorn", "run:app", "-b", "0.0.0.0:5000"]


Build and run:

docker build -t pet-insurance .
docker run -p 5000:5000 pet-insurance

Contributing

Pull requests are welcome. If you'd like major changes, open an issue to discuss what you’d like to modify.

 License

This project is open-source and available under the MIT License.

Author

Batistuta Indiazi
Pet Insurance Project • Flask Developer
GitHub: Batistuta708
