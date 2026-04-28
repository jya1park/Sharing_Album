import hashlib
import mimetypes
import shutil
import tempfile
import uuid
from datetime import datetime, timezone, timedelta
from pathlib import Path

from fastapi import APIRouter, Depends, Form, HTTPException, Query, UploadFile, File, status
from fastapi.responses import FileResponse, RedirectResponse
from PIL import Image
from sqlmodel import Session, select

from app.config import (
    PHOTOS_DIR,
    MAX_FILE_SIZE_BYTES,
    ALLOWED_EXTENSIONS,
    ALLOWED_VIDEO_EXTENSIONS,
)
from app.auth import get_current_user
from app.database import get_session
from app.models import Photo, User, UserFavorite
from app.schemas import PhotoResponse, PhotoListResponse, MonthListResponse, MessageResponse
from app.utils.exif import extract_taken_date
from app.utils.image import compress_and_resize, generate_thumbnail
from app.utils.video import generate_video_thumbnail
from app.utils.storage import save_original, get_original_url, get_original_path, delete_original

router = APIRouter()


def _build_photo_response(photo: Photo, user_id: str = "", session: Session = None) -> PhotoResponse:
    visible_list = photo.visible_to.split(",") if photo.visible_to else None
    is_fav = False
    if session and user_id:
        fav = session.exec(
            select(UserFavorite)
            .where(UserFavorite.user_id == user_id, UserFavorite.photo_id == photo.id)
        ).first()
        is_fav = fav is not None
    return PhotoResponse(
        id=photo.id,
        original_filename=photo.original_filename,
        thumbnail_url=f"/photos/{photo.id}/file?type=thumbnail",
        original_url=f"/photos/{photo.id}/file?type=original",
        file_size=photo.file_size,
        taken_at=photo.taken_at,
        uploaded_at=photo.uploaded_at,
        month_folder=photo.month_folder,
        media_type=photo.media_type,
        is_favorite=is_fav,
        uploader_name=photo.uploader_name,
        visible_to=visible_list,
    )


def _filter_visible(photos: list[Photo], user_id: str) -> list[Photo]:
    """Filter photos based on visibility. Admin and uploader always see their own."""
    result = []
    for p in photos:
        if p.visible_to is None:
            result.append(p)
        elif user_id in p.visible_to.split(","):
            result.append(p)
        elif p.uploader_id == user_id:
            result.append(p)
        # else: not visible to this user
    return result


@router.post("/upload", response_model=PhotoResponse, status_code=status.HTTP_201_CREATED)
async def upload_photo(
    file: UploadFile = File(...),
    visible_to: str = Form(""),
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Upload a photo or video."""

    if not user.can_upload:
        raise HTTPException(status_code=403, detail="Upload permission denied")

    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename is required")

    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"File type '{ext}' not allowed. Allowed: {', '.join(ALLOWED_EXTENSIONS)}",
        )

    is_video = ext in ALLOWED_VIDEO_EXTENSIONS

    # Stream to temp file and compute hash simultaneously
    md5 = hashlib.md5()
    file_size_raw = 0
    with tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}") as tmp:
        while chunk := await file.read(1024 * 1024):
            file_size_raw += len(chunk)
            if file_size_raw > MAX_FILE_SIZE_BYTES:
                Path(tmp.name).unlink(missing_ok=True)
                raise HTTPException(
                    status_code=400,
                    detail=f"File too large. Maximum size: {MAX_FILE_SIZE_BYTES // (1024 * 1024)}MB",
                )
            md5.update(chunk)
            tmp.write(chunk)
        tmp_path = Path(tmp.name)

    file_hash = md5.hexdigest()
    existing = session.exec(select(Photo).where(Photo.file_hash == file_hash)).first()
    if existing:
        tmp_path.unlink(missing_ok=True)
        raise HTTPException(status_code=409, detail="This file has already been uploaded")

    try:
        now = datetime.now(timezone(timedelta(hours=9))).replace(tzinfo=None)
        taken_at = None

        if is_video:
            # Video: keep original extension, no resize
            stored_ext = ext
            month_folder = now.strftime("%Y-%m")
        else:
            # Photo: extract EXIF, will be saved as jpg
            stored_ext = "jpg"
            with Image.open(tmp_path) as img:
                taken_at = extract_taken_date(img)
            reference_date = taken_at if taken_at else now
            month_folder = reference_date.strftime("%Y-%m")

        stored_name = f"{uuid.uuid4()}.{stored_ext}"
        thumb_name = f"{stored_name.rsplit('.', 1)[0]}_thumb.jpg"

        original_dir = PHOTOS_DIR / month_folder / "original"
        thumbnail_dir = PHOTOS_DIR / month_folder / "thumbnails"

        original_path = original_dir / stored_name
        thumbnail_path = thumbnail_dir / thumb_name

        original_key = f"{month_folder}/original/{stored_name}"
        thumb_key = f"{month_folder}/thumbnails/{thumb_name}"

        if is_video:
            file_size = file_size_raw
            save_original(tmp_path, original_key)
            generate_video_thumbnail(tmp_path, thumbnail_path)
        else:
            file_size = compress_and_resize(tmp_path, original_path)
            save_original(original_path, original_key)
            generate_thumbnail(original_path, thumbnail_path)

    finally:
        tmp_path.unlink(missing_ok=True)

    photo = Photo(
        filename=stored_name,
        original_filename=file.filename,
        file_path=f"{month_folder}/original/{stored_name}",
        thumbnail_path=f"{month_folder}/thumbnails/{thumb_name}",
        file_hash=file_hash,
        file_size=file_size,
        taken_at=taken_at,
        uploaded_at=now,
        month_folder=month_folder,
        media_type="video" if is_video else "photo",
        uploader_name=user.nickname,
        uploader_id=user.id,
        visible_to=visible_to.strip() if visible_to.strip() else None,
    )
    session.add(photo)
    session.commit()
    session.refresh(photo)

    return _build_photo_response(photo, user.id, session)


@router.get("/months", response_model=MonthListResponse)
async def list_months(session: Session = Depends(get_session)):
    """List all available months that have photos, sorted descending."""
    statement = select(Photo.month_folder).distinct().order_by(Photo.month_folder.desc())
    months = session.exec(statement).all()
    return MonthListResponse(months=list(months))


@router.get("/recent", response_model=list[PhotoResponse])
async def list_recent(
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Get most recently uploaded photos across all months."""
    statement = select(Photo).order_by(Photo.uploaded_at.desc()).limit(limit * 2)
    photos = session.exec(statement).all()
    visible = _filter_visible(photos, user.id)
    return [_build_photo_response(p, user.id, session) for p in visible[:limit]]


@router.get("/favorites", response_model=list[PhotoResponse])
async def list_favorites(
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Get current user's favorited photos."""
    fav_ids = session.exec(
        select(UserFavorite.photo_id).where(UserFavorite.user_id == user.id)
    ).all()
    if not fav_ids:
        return []
    statement = (
        select(Photo)
        .where(Photo.id.in_(fav_ids))
        .order_by(Photo.uploaded_at.desc())
    )
    photos = session.exec(statement).all()
    visible = _filter_visible(photos, user.id)
    return [_build_photo_response(p, user.id, session) for p in visible]


@router.put("/{photo_id}/favorite", response_model=PhotoResponse)
async def toggle_favorite(
    photo_id: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Toggle favorite status for current user."""
    photo = session.get(Photo, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")

    existing = session.exec(
        select(UserFavorite)
        .where(UserFavorite.user_id == user.id, UserFavorite.photo_id == photo_id)
    ).first()

    if existing:
        session.delete(existing)
    else:
        session.add(UserFavorite(user_id=user.id, photo_id=photo_id))

    session.commit()
    return _build_photo_response(photo, user.id, session)


@router.get("/", response_model=PhotoListResponse)
async def list_photos(
    month: str = Query(..., pattern=r"^\d{4}-\d{2}$", description="Month in YYYY-MM format"),
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """List all photos for a given month."""
    statement = (
        select(Photo)
        .where(Photo.month_folder == month)
        .order_by(Photo.uploaded_at.desc())
    )
    photos = session.exec(statement).all()
    visible = _filter_visible(photos, user.id)

    return PhotoListResponse(
        month=month,
        photos=[_build_photo_response(p, user.id, session) for p in visible],
        total=len(visible),
    )


@router.put("/{photo_id}/visibility", response_model=PhotoResponse)
async def update_visibility(
    photo_id: str,
    visible_to: list[str] = [],
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Update photo visibility. Empty list = visible to all."""
    photo = session.get(Photo, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    is_owner = photo.uploader_id == user.id
    if user.role != "admin" and not (is_owner and user.can_set_visibility):
        raise HTTPException(status_code=403, detail="Permission denied")

    photo.visible_to = ",".join(visible_to) if visible_to else None
    session.add(photo)
    session.commit()
    session.refresh(photo)
    return _build_photo_response(photo, user.id, session)


@router.get("/{photo_id}", response_model=PhotoResponse)
async def get_photo(
    photo_id: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Get metadata for a single photo."""
    photo = session.get(Photo, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    return _build_photo_response(photo, user.id, session)


@router.get("/{photo_id}/file")
async def get_photo_file(
    photo_id: str,
    type: str = Query("original", pattern=r"^(original|thumbnail)$"),
    session: Session = Depends(get_session),
):
    """Serve the actual image/video file (original or thumbnail)."""
    photo = session.get(Photo, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")

    if type == "thumbnail":
        file_path = PHOTOS_DIR / photo.thumbnail_path
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="Thumbnail not found")
        return FileResponse(path=str(file_path), media_type="image/jpeg")

    # Original file
    signed_url = get_original_url(photo.file_path)
    if signed_url:
        return RedirectResponse(url=signed_url)

    local_path = get_original_path(photo.file_path)
    if local_path and local_path.exists():
        media_type = mimetypes.guess_type(str(local_path))[0] or "application/octet-stream"
        return FileResponse(
            path=str(local_path),
            media_type=media_type,
            filename=photo.original_filename,
        )

    raise HTTPException(status_code=404, detail="File not found")


@router.delete("/{photo_id}", response_model=MessageResponse)
async def delete_photo(
    photo_id: str,
    user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    """Delete a photo (file + thumbnail + DB record)."""
    photo = session.get(Photo, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")

    # Only admin or uploader with delete permission can delete
    is_owner = photo.uploader_id == user.id
    if user.role != "admin" and not (is_owner and user.can_delete):
        raise HTTPException(status_code=403, detail="Delete permission denied")

    try:
        delete_original(photo.file_path)
    except Exception:
        pass
    thumbnail_file = PHOTOS_DIR / photo.thumbnail_path
    if thumbnail_file.exists():
        thumbnail_file.unlink()

    session.delete(photo)
    session.commit()

    return MessageResponse(message=f"'{photo.original_filename}' deleted successfully")
