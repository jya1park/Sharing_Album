import uuid
from datetime import datetime
from typing import Optional

from sqlmodel import SQLModel, Field


class Photo(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    filename: str  # stored filename (UUID-based, e.g. "a1b2c3.jpg")
    original_filename: str  # user's original filename
    file_path: str  # relative path: 2026-04/original/a1b2c3.jpg
    thumbnail_path: str  # relative path: 2026-04/thumbnails/a1b2c3_thumb.jpg
    file_hash: str = Field(index=True)  # MD5 hash for dedup
    file_size: int  # bytes (after compression)
    taken_at: Optional[datetime] = None  # EXIF shooting date
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)
    month_folder: str = Field(index=True)  # "2026-04" for monthly queries

    # Phase 2 expansion fields (nullable for now)
    album_id: Optional[str] = Field(default=None, index=True)
    uploader_id: Optional[str] = Field(default=None, index=True)
