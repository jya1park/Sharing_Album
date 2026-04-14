import sqlite3

from sqlmodel import SQLModel, Session, create_engine

from app.config import DATABASE_URL

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False,
)


def create_db_and_tables():
    SQLModel.metadata.create_all(engine)
    _migrate()


def _migrate():
    """Add missing columns to existing tables."""
    db_path = DATABASE_URL.replace("sqlite:///", "")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("PRAGMA table_info(photo)")
    columns = {row[1] for row in cursor.fetchall()}

    if "uploader_name" not in columns:
        cursor.execute("ALTER TABLE photo ADD COLUMN uploader_name TEXT DEFAULT ''")
        conn.commit()

    conn.close()


def get_session():
    with Session(engine) as session:
        yield session
