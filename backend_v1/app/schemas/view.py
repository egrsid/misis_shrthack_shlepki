"""Contracts for a client's product viewing history."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ProductViewCreate(BaseModel):
    product_id: str = Field(min_length=1, max_length=64)
    product_name: str = Field(min_length=1, max_length=200)
    price: int | None = Field(default=None, ge=0)


class ProductViewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    product_id: str
    product_name: str
    price: int | None
    views_count: int
    last_viewed_at: datetime
