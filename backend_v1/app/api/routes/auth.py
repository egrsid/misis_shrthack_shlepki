from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.security import hash_password, verify_password
from app.models import User
from app.schemas.auth import LoginRequest, RegisterRequest, UserOut

router = APIRouter(prefix="/auth", tags=["auth"])

# No tokens or sessions: the app keeps the returned user id for the rest of the
# demo. Credentials live in the database and are hashed; issue endpoints are still
# open, which is a deliberate hackathon limitation, not an oversight.


def find_user(db: Session, login: str) -> User | None:
    return db.scalars(select(User).where(User.login == login)).first()


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    """Register a client. Operator accounts are seeded, never self-registered."""
    if find_user(db, payload.login):
        raise HTTPException(status_code=409, detail="Такой логин уже занят")

    email_taken = db.scalars(
        select(User).where(func.lower(User.email) == payload.email)
    ).first()
    if email_taken:
        raise HTTPException(status_code=409, detail="Такая почта уже зарегистрирована")

    user = User(
        login=payload.login,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role="client",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=UserOut)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = find_user(db, payload.login)
    # The same message for an unknown login and a wrong password, so the response
    # does not reveal which logins exist.
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Неверный логин или пароль")

    if payload.role and user.role != payload.role:
        raise HTTPException(
            status_code=403,
            detail="Этот аккаунт не подходит для выбранной роли",
        )
    return user
