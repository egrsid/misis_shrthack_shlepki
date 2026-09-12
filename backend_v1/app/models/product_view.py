from datetime import datetime

from sqlalchemy import DateTime, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ProductView(Base):
    """One product a client has looked at.

    One row per client and product rather than one per tap: the history should
    read as "what I was looking at", not as a log with the same laptop twenty
    times in a row. Repeat visits bump the counter and the timestamp.
    """

    __tablename__ = "product_views"
    __table_args__ = (UniqueConstraint("user_id", "product_id", name="uq_view_user_product"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True)
    # Stable slug from the app's catalogue, not a per-launch UUID.
    product_id: Mapped[str] = mapped_column(String(64), index=True)
    product_name: Mapped[str] = mapped_column(String(200))
    price: Mapped[int | None] = mapped_column(Integer, nullable=True)
    views_count: Mapped[int] = mapped_column(Integer, default=1)

    last_viewed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
