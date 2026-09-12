"""Seed data the demo cannot run without."""

from sqlalchemy import select

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models import User

from .config import settings


def seed_operator() -> None:
    """Create the default operator account if there is no operator yet.

    Operators are never self-registered — /auth/register only makes clients — so
    without this nobody could log into the operator screen on a fresh database.
    """
    with SessionLocal() as db:
        existing = db.scalars(select(User).where(User.role == "operator")).first()
        if existing:
            return
        db.add(
            User(
                login=settings.operator_login,
                email=None,
                password_hash=hash_password(settings.operator_password),
                role="operator",
            )
        )
        db.commit()
