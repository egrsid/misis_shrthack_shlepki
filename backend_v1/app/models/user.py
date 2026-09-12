from datetime import datetime

from sqlalchemy import DateTime, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class User(Base):
    """A client or an operator.

    `issues.user_id` points at this table's id. There is no foreign key on
    purpose: demo databases created before this table existed hold issues with
    arbitrary user ids, and a constraint would make them unreadable.
    """

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # Stored lowercase so "Ivan" and "ivan" cannot both register.
    login: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(200), unique=True, nullable=True)
    # "pbkdf2_sha256$iterations$salt$digest" — never the password itself.
    password_hash: Mapped[str] = mapped_column(String(200))
    role: Mapped[str] = mapped_column(String(20), index=True, default="client")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
