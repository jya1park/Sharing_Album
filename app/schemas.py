from datetime import datetime
from typing import Optional

from pydantic import BaseModel


# Auth schemas
class RegisterRequest(BaseModel):
    name: str
    nickname: str
    password: str


class LoginRequest(BaseModel):
    name: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    name: str
    nickname: str


class UserResponse(BaseModel):
    id: str
    name: str
    nickname: str
    created_at: datetime


# Photo schemas
class PhotoResponse(BaseModel):
    id: str
    original_filename: str
    thumbnail_url: str
    original_url: str
    file_size: int
    taken_at: Optional[datetime] = None
    uploaded_at: datetime
    month_folder: str
    media_type: str = "photo"
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
