from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import settings

engine = create_engine(
    settings.database_url,
    connect_args={"check_same_thread": False},  # required by SQLite + FastAPI
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def init_db() -> None:
    """Create tables and apply tiny additive SQLite changes for the hackathon MVP."""
    Base.metadata.create_all(bind=engine)

    # create_all does not add new columns to an existing SQLite table.
    # This keeps existing demo issues when final_reply is introduced.
    if engine.dialect.name != "sqlite" or "issues" not in inspect(engine).get_table_names():
        return

    columns = {column["name"] for column in inspect(engine).get_columns("issues")}
    if "final_reply" not in columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE issues ADD COLUMN final_reply TEXT"))
