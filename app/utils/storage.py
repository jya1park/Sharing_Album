import shutil
import mimetypes
from collections.abc import Iterator
from pathlib import Path

from app.config import PHOTOS_DIR, GCS_BUCKET, USE_GCS

_gcs_client = None
_gcs_bucket = None

STREAM_CHUNK_SIZE = 1024 * 1024


def _get_bucket():
    global _gcs_client, _gcs_bucket
    if _gcs_bucket is None:
        from google.cloud import storage
        _gcs_client = storage.Client()
        _gcs_bucket = _gcs_client.bucket(GCS_BUCKET)
    return _gcs_bucket


def storage_mode() -> str:
    return "gcs" if USE_GCS else "local"


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


def get_original_path(dest_key: str) -> Path | None:
    """Get local path for original file, if a local copy exists (in any mode)."""
    path = PHOTOS_DIR / dest_key
    return path if path.exists() else None


def get_gcs_original_size(dest_key: str) -> int | None:
    """Return size of the original in GCS, or None if missing / GCS disabled."""
    if not USE_GCS:
        return None
    blob = _get_bucket().get_blob(dest_key)
    return blob.size if blob is not None else None


def stream_gcs_original(dest_key: str, start: int, end: int) -> Iterator[bytes]:
    """Yield bytes [start, end] (inclusive) of a GCS original, chunk by chunk."""
    blob = _get_bucket().blob(dest_key)
    pos = start
    while pos <= end:
        chunk_end = min(pos + STREAM_CHUNK_SIZE - 1, end)
        yield blob.download_as_bytes(start=pos, end=chunk_end)
        pos = chunk_end + 1


def delete_original(dest_key: str) -> None:
    """Delete any local copy of the original, then the GCS copy."""
    file_path = PHOTOS_DIR / dest_key
    if file_path.exists():
        file_path.unlink()
    if USE_GCS:
        bucket = _get_bucket()
        blob = bucket.blob(dest_key)
        blob.delete()
