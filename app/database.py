import sqlite3

from sqlmodel import SQLModel, Session, create_engine

from app.config import DATABASE_URL
import app.models  # noqa: F401 - ensure all models are registered with SQLModel

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

    # Check if photo table exists before migrating
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='photo'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(photo)")
        columns = {row[1] for row in cursor.fetchall()}

        if "uploader_name" not in columns:
            cursor.execute("ALTER TABLE photo ADD COLUMN uploader_name TEXT DEFAULT ''")
            conn.commit()

    # Migrate user table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='user'")
    if cursor.fetchone():
        cursor.execute("PRAGMA table_info(user)")
        columns = {row[1] for row in cursor.fetchall()}

        if "nickname" not in columns:
            cursor.execute("ALTER TABLE user ADD COLUMN nickname TEXT DEFAULT ''")
            conn.commit()

    conn.close()


def get_session():
    with Session(engine) as session:
        yield session
