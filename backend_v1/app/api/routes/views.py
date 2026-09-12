from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.models import ProductView, User
from app.schemas.view import ProductViewCreate, ProductViewOut

router = APIRouter(tags=["views"])


def ensure_user(db: Session, user_id: int) -> None:
    if not db.get(User, user_id):
        raise HTTPException(status_code=404, detail="Пользователь не найден")


@router.post(
    "/users/{user_id}/views",
    response_model=ProductViewOut,
    status_code=status.HTTP_201_CREATED,
)
def record_view(user_id: int, payload: ProductViewCreate, db: Session = Depends(get_db)):
    """Record that a client opened a product.

    Viewing the same product again bumps the counter instead of adding a row, so
    the history reads as a list of products, not a tap log.
    """
    ensure_user(db, user_id)

    view = db.scalars(
        select(ProductView).where(
            ProductView.user_id == user_id,
            ProductView.product_id == payload.product_id,
        )
    ).first()

    if view:
        view.views_count += 1
        view.product_name = payload.product_name
        view.price = payload.price
    else:
        view = ProductView(
            user_id=user_id,
            product_id=payload.product_id,
            product_name=payload.product_name,
            price=payload.price,
        )
        db.add(view)

    db.commit()
    db.refresh(view)
    return view


@router.get("/users/{user_id}/views", response_model=list[ProductViewOut])
def list_views(user_id: int, limit: int = 50, db: Session = Depends(get_db)):
    """One client's own history, most recently viewed first."""
    ensure_user(db, user_id)
    return db.scalars(
        select(ProductView)
        .where(ProductView.user_id == user_id)
        .order_by(ProductView.last_viewed_at.desc(), ProductView.id.desc())
        .limit(max(1, min(limit, 200)))
    ).all()


@router.delete("/users/{user_id}/views", status_code=status.HTTP_204_NO_CONTENT)
def clear_views(user_id: int, db: Session = Depends(get_db)):
    ensure_user(db, user_id)
    db.execute(delete(ProductView).where(ProductView.user_id == user_id))
    db.commit()
