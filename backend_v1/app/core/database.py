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


# Columns added after the first demo database was created. SQLite can append
# nullable columns in place, which keeps existing issues usable.
_ADDED_COLUMNS = {
    "final_reply": "TEXT",
    "slots": "TEXT",
    "missing": "TEXT",
    "request_id": "VARCHAR(36)",
}


def init_db() -> None:
    """Create tables and apply tiny additive SQLite changes for the hackathon MVP."""
    Base.metadata.create_all(bind=engine)

    # create_all does not add new columns to an existing SQLite table.
    if engine.dialect.name != "sqlite" or "issues" not in inspect(engine).get_table_names():
        return

    columns = {column["name"] for column in inspect(engine).get_columns("issues")}
    pending = {
        name: sql_type
        for name, sql_type in _ADDED_COLUMNS.items()
        if name not in columns
    }
    if not pending:
        return

    with engine.begin() as connection:
        for name, sql_type in pending.items():
            connection.execute(text(f"ALTER TABLE issues ADD COLUMN {name} {sql_type}"))
