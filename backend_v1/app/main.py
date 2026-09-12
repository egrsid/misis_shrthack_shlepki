from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes.auth import router as auth_router
from app.api.routes.issues import router as issues_router
from app.api.routes.views import router as views_router
from app.core.database import init_db
from app.core.seed import seed_operator
from app.models import Issue, ProductView, User  # Imports models before create_all.

init_db()
seed_operator()

app = FastAPI(title="Tech Support Hackathon API", version="1.0.0")

# Convenient for a local Swift app during a hackathon. Restrict origins before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(auth_router)
app.include_router(issues_router)
app.include_router(views_router)
