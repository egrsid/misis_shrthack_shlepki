from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes.issues import router as issues_router
from app.core.database import init_db
from app.models import Issue  # Imports models before create_all.

init_db()

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


app.include_router(issues_router)
