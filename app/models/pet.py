from app import db

class Pet(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(64), nullable=False)
    species = db.Column(db.String(32), nullable=False)  # dog, cat, etc.
    breed = db.Column(db.String(64))
    age = db.Column(db.Integer)
    weight = db.Column(db.Float)
    created_at = db.Column(db.DateTime, default=db.func.now())
    
    # Foreign keys
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    # Relationships
    policies = db.relationship('Policy', backref='insured_pet', lazy=True)