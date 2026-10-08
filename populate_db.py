from app import create_app, db
from app.models.user import User
from app.models.pet import Pet
from app.models.policy import Policy
from werkzeug.security import generate_password_hash

app = create_app()

with app.app_context():
    # Clear existing data
    db.drop_all()
    db.create_all()

    # Create users
    admin_user = User(
        email="admin@example.com",
        password=generate_password_hash("admin123"),
        is_admin=True,
    )
    normal_user = User(
        email="user@example.com",
        password=generate_password_hash("user123"),
        is_admin=False,
    )

    db.session.add_all([admin_user, normal_user])
    db.session.flush()  # flush to get user IDs

    # Create pets
    pets = [
        Pet(name="Buddy", type="Dog", age=3, owner=admin_user),
        Pet(name="Mittens", type="Cat", age=2, owner=admin_user),
        Pet(name="Charlie", type="Dog", age=4, owner=normal_user),
        Pet(name="Luna", type="Cat", age=1, owner=normal_user),
    ]
    db.session.add_all(pets)
    db.session.flush()  # flush to get pet IDs

    # Create policies
    policies = [
        Policy(pet=pets[0], coverage_amount=1500, premium=70),
        Policy(pet=pets[1], coverage_amount=1200, premium=60),
        Policy(pet=pets[2], coverage_amount=1800, premium=80),
        Policy(pet=pets[3], coverage_amount=1000, premium=50),
    ]
    db.session.add_all(policies)
    db.session.commit()

    print("Database populated:")
    print("Users: admin@example.com / user@example.com")
    print("Passwords: admin123 / user123")
    print("Pets and policies added for both users.")
