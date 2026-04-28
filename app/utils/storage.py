import mimetypes
import shutil
import tempfile
from pathlib import Path

from app.config import PHOTOS_DIR, GCS_BUCKET, USE_GCS

_gcs_client = None
_gcs_bucket = None


def _get_bucket():
    global _gcs_client, _gcs_bucket
    if _gcs_bucket is None:
        from google.cloud import storage
        _gcs_client = storage.Client()
        _gcs_bucket = _gcs_client.bucket(GCS_BUCKET)
    return _gcs_bucket


def save_original(source_path: Path, dest_key: str) -> None:
    """Save original file to GCS (if enabled) or local disk."""
    if USE_GCS:
        bucket = _get_bucket()
        blob = bucket.blob(dest_key)
        content_type = mimetypes.guess_type(str(source_path))[0] or "application/octet-stream"
        blob.upload_from_filename(str(source_path), content_type=content_type)
    else:
        dest_path = PHOTOS_DIR / dest_key
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        if source_path.resolve() != dest_path.resolve():
            shutil.copy2(str(source_path), str(dest_path))


def download_original(dest_key: str) -> Path | None:
    """Download original file from GCS to a temp file. Returns temp path or None."""
    if USE_GCS:
        bucket = _get_bucket()
        blob = bucket.blob(dest_key)
        if not blob.exists():
            return None
        ext = dest_key.rsplit(".", 1)[-1] if "." in dest_key else "bin"
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}")
        blob.download_to_filename(tmp.name)
        return Path(tmp.name)
    return None


def get_original_path(dest_key: str) -> Path | None:
    """Get local path for original file. Returns None if using GCS."""
    if USE_GCS:
        return None
    path = PHOTOS_DIR / dest_key
    return path if path.exists() else None


def delete_original(dest_key: str) -> None:
    """Delete original file from GCS or local disk."""
    if USE_GCS:
        bucket = _get_bucket()
        blob = bucket.blob(dest_key)
        blob.delete()
    else:
        file_path = PHOTOS_DIR / dest_key
        if file_path.exists():
            file_path.unlink()
