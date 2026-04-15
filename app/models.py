import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlmodel import SQLModel, Field

KST = timezone(timedelta(hours=9))


def _now_kst() -> datetime:
    return datetime.now(KST).replace(tzinfo=None)


class User(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    name: str = Field(index=True, sa_column_kwargs={"unique": True})
    nickname: str = Field(default="")
    password_hash: str
    role: str = Field(default="member")  # "admin" or "member"
    can_upload: bool = Field(default=True)
    can_delete: bool = Field(default=True)
    can_download: bool = Field(default=True)
    created_at: datetime = Field(default_factory=_now_kst)


class Photo(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    filename: str
    original_filename: str
    file_path: str
    thumbnail_path: str
    file_hash: str = Field(index=True)
    file_size: int
    taken_at: Optional[datetime] = None
    uploaded_at: datetime = Field(default_factory=_now_kst)
    month_folder: str = Field(index=True)

    media_type: str = Field(default="photo")  # "photo" or "video"
    is_favorite: bool = Field(default=False, index=True)
    uploader_name: str = Field(default="")

    album_id: Optional[str] = Field(default=None, index=True)
    uploader_id: Optional[str] = Field(default=None, index=True)
