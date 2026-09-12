"""Contracts for registration and login."""

import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

Role = Literal["client", "operator"]

_EMAIL_PATTERN = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")


class RegisterRequest(BaseModel):
    login: str = Field(min_length=3, max_length=64)
    email: str = Field(max_length=200)
    password: str = Field(min_length=5, max_length=128)

    @field_validator("login")
    @classmethod
    def normalise_login(cls, value: str) -> str:
        # Lowercase, so "Ivan" and "ivan" are the same account.
        cleaned = value.strip().lower()
        if not cleaned:
            raise ValueError("Введите логин")
        return cleaned

    @field_validator("email")
    @classmethod
    def check_email(cls, value: str) -> str:
        cleaned = value.strip().lower()
        # Validated with a regex instead of EmailStr to avoid adding a dependency.
        if not _EMAIL_PATTERN.match(cleaned):
            raise ValueError("Введите корректную почту")
        return cleaned


class LoginRequest(BaseModel):
    login: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)
    # When set, logging in with the other role is refused: a client must not get
    # in through the operator screen.
    role: Role | None = None

    @field_validator("login")
    @classmethod
    def normalise_login(cls, value: str) -> str:
        return value.strip().lower()


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    login: str
    email: str | None
    role: Role
    created_at: datetime
