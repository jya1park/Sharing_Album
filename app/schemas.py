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
    role: str = "member"
    can_upload: bool = True
    can_delete: bool = True
    can_download: bool = True
    can_set_visibility: bool = False


class UserResponse(BaseModel):
    id: str
    name: str
    nickname: str
    role: str = "member"
    can_upload: bool = True
    can_delete: bool = True
    can_download: bool = True
    can_set_visibility: bool = False
    created_at: datetime


class UpdatePermissionRequest(BaseModel):
    can_upload: Optional[bool] = None
    can_delete: Optional[bool] = None
    can_download: Optional[bool] = None
    can_set_visibility: Optional[bool] = None


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
    visible_to: Optional[list[str]] = None


class PhotoListResponse(BaseModel):
    month: str
    photos: list[PhotoResponse]
    total: int


class MonthListResponse(BaseModel):
    months: list[str]


class MessageResponse(BaseModel):
    message: str
