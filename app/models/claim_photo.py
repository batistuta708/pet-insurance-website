from datetime import datetime, timezone

from app import db


class ClaimPhoto(db.Model):
    """One photo per claim (e.g. a vet bill), stored in the database so it survives redeploys."""

    id = db.Column(db.Integer, primary_key=True)
    claim_id = db.Column(db.Integer, db.ForeignKey("claim.id"), unique=True, nullable=False)
    mime_type = db.Column(db.String(30), nullable=False)
    data = db.Column(db.LargeBinary, nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
