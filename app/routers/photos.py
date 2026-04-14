import hashlib
import tempfile
import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from fastapi.responses import FileResponse
from PIL import Image
from sqlmodel import Session, select

from app.config import (
    PHOTOS_DIR,
    MAX_FILE_SIZE_BYTES,
    ALLOWED_EXTENSIONS,
)
from app.database import get_session
from app.models import Photo
from app.schemas import PhotoResponse, PhotoListResponse, MonthListResponse, MessageResponse
from app.utils.exif import extract_taken_date
from app.utils.image import compress_and_resize, generate_thumbnail

router = APIRouter()


def _build_photo_response(photo: Photo) -> PhotoResponse:
    return PhotoResponse(
        id=photo.id,
        original_filename=photo.original_filename,
        thumbnail_url=f"/photos/{photo.id}/file?type=thumbnail",
        original_url=f"/photos/{photo.id}/file?type=original",
        file_size=photo.file_size,
        taken_at=photo.taken_at,
        uploaded_at=photo.uploaded_at,
        month_folder=photo.month_folder,
    )


@router.post("/upload", response_model=PhotoResponse, status_code=status.HTTP_201_CREATED)
async def upload_photo(
    file: UploadFile = File(...),
    session: Session = Depends(get_session),
):
    """Upload a photo. Large images are automatically resized and compressed."""

    # 1. Validate file extension
    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename is required")

    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"File type '{ext}' not allowed. Allowed: {', '.join(ALLOWED_EXTENSIONS)}",
        )

    # 2. Read file content and check size
    content = await file.read()
    if len(content) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size: {MAX_FILE_SIZE_BYTES // (1024 * 1024)}MB",
        )

    # 3. Compute MD5 hash for dedup
    file_hash = hashlib.md5(content).hexdigest()

    existing = session.exec(
        select(Photo).where(Photo.file_hash == file_hash)
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail="This photo has already been uploaded",
        )

    # 4. Save to temp file for Pillow processing
    with tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}") as tmp:
        tmp.write(content)
        tmp_path = Path(tmp.name)

    try:
        # 5. Extract EXIF date
        with Image.open(tmp_path) as img:
            taken_at = extract_taken_date(img)

        now = datetime.utcnow()
        reference_date = taken_at if taken_at else now
        month_folder = reference_date.strftime("%Y-%m")

        # 6. Generate UUID filename
        stored_name = f"{uuid.uuid4()}.jpg"
        thumb_name = f"{stored_name.rsplit('.', 1)[0]}_thumb.jpg"

        original_dir = PHOTOS_DIR / month_folder / "original"
        thumbnail_dir = PHOTOS_DIR / month_folder / "thumbnails"

        original_path = original_dir / stored_name
        thumbnail_path = thumbnail_dir / thumb_name

        # 7. Resize/compress and save original
        file_size = compress_and_resize(tmp_path, original_path)

        # 8. Generate thumbnail
        generate_thumbnail(original_path, thumbnail_path)

    finally:
        # Clean up temp file
        tmp_path.unlink(missing_ok=True)

    # 9. Create DB record
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
    )
    session.add(photo)
    session.commit()
    session.refresh(photo)

    return _build_photo_response(photo)


@router.get("/months", response_model=MonthListResponse)
async def list_months(session: Session = Depends(get_session)):
    """List all available months that have photos, sorted descending."""
    statement = select(Photo.month_folder).distinct().order_by(Photo.month_folder.desc())
    months = session.exec(statement).all()
    return MonthListResponse(months=list(months))


@router.get("/", response_model=PhotoListResponse)
async def list_photos(
    month: str = Query(..., pattern=r"^\d{4}-\d{2}$", description="Month in YYYY-MM format"),
    session: Session = Depends(get_session),
):
    """List all photos for a given month."""
    statement = (
        select(Photo)
        .where(Photo.month_folder == month)
        .order_by(Photo.taken_at.desc(), Photo.uploaded_at.desc())
    )
    photos = session.exec(statement).all()

    return PhotoListResponse(
        month=month,
        photos=[_build_photo_response(p) for p in photos],
        total=len(photos),
    )


@router.get("/{photo_id}", response_model=PhotoResponse)
async def get_photo(photo_id: str, session: Session = Depends(get_session)):
    """Get metadata for a single photo."""
    photo = session.get(Photo, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    return _build_photo_response(photo)


@router.get("/{photo_id}/file")
async def get_photo_file(
    photo_id: str,
    type: str = Query("original", pattern=r"^(original|thumbnail)$"),
    session: Session = Depends(get_session),
):
    """Serve the actual image file (original or thumbnail)."""
    photo = session.get(Photo, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")

    if type == "thumbnail":
        file_path = PHOTOS_DIR / photo.thumbnail_path
    else:
        file_path = PHOTOS_DIR / photo.file_path

    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on disk")

    return FileResponse(
        path=str(file_path),
        media_type="image/jpeg",
        filename=photo.original_filename if type == "original" else None,
    )


@router.delete("/{photo_id}", response_model=MessageResponse)
async def delete_photo(photo_id: str, session: Session = Depends(get_session)):
    """Delete a photo (file + thumbnail + DB record)."""
    photo = session.get(Photo, photo_id)
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")

    # Delete files from disk
    original_file = PHOTOS_DIR / photo.file_path
    thumbnail_file = PHOTOS_DIR / photo.thumbnail_path

    if original_file.exists():
        original_file.unlink()
    if thumbnail_file.exists():
        thumbnail_file.unlink()

    # Delete DB record
    session.delete(photo)
    session.commit()

    return MessageResponse(message=f"Photo '{photo.original_filename}' deleted successfully")
