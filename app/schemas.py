from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class PhotoResponse(BaseModel):
    id: str
    original_filename: str
    thumbnail_url: str
    original_url: str
    file_size: int
    taken_at: Optional[datetime] = None
    uploaded_at: datetime
    month_folder: str
    is_favorite: bool = False
    uploader_name: str = ""


class PhotoListResponse(BaseModel):
    month: str
    photos: list[PhotoResponse]
    total: int


class MonthListResponse(BaseModel):
    months: list[str]


class MessageResponse(BaseModel):
    message: str
