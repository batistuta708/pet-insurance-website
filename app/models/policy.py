from app import db

class Policy(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    pet_id = db.Column(db.Integer, db.ForeignKey('pet.id'))
    coverage_amount = db.Column(db.Float, nullable=False)
    premium = db.Column(db.Float, nullable=False)
