import uuid
from datetime import datetime
from typing import Optional

from sqlmodel import SQLModel, Field


class User(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    name: str = Field(index=True, sa_column_kwargs={"unique": True})
    nickname: str = Field(default="")
    password_hash: str
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Photo(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    filename: str
    original_filename: str
    file_path: str
    thumbnail_path: str
    file_hash: str = Field(index=True)
    file_size: int
    taken_at: Optional[datetime] = None
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)
    month_folder: str = Field(index=True)

    is_favorite: bool = Field(default=False, index=True)
    uploader_name: str = Field(default="")

    album_id: Optional[str] = Field(default=None, index=True)
    uploader_id: Optional[str] = Field(default=None, index=True)
