"""Recover photo records from GCS bucket into DB.
Run inside Docker: sudo docker exec bodeumi python3 /app/recover_from_gcs.py
"""
import hashlib
import uuid
import mimetypes
from datetime import datetime, timezone, timedelta

from google.cloud import storage

KST = timezone(timedelta(hours=9))
IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "heic", "heif"}
VIDEO_EXTENSIONS = {"mp4", "mov", "avi", "mkv", "webm"}

DB_PATH = "/data/bodeumi.db"
BUCKET_NAME = "bodme-photo"
THUMB_DIR = "/data/photos"


def main():
    import sqlite3
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Ensure table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='photo'")
    if not cursor.fetchone():
        print("Error: photo table does not exist. Start the server first.")
        return

    # Get existing file_paths to avoid duplicates
    existing = set()
    for row in cursor.execute("SELECT file_path FROM photo"):
        existing.add(row[0])
    print(f"Existing records in DB: {len(existing)}")

    # List GCS bucket
    client = storage.Client()
    bucket = client.bucket(BUCKET_NAME)
    blobs = list(bucket.list_blobs())
    print(f"Files in GCS: {len(blobs)}")

    recovered = 0
    skipped = 0

    for blob in blobs:
        name = blob.name  # e.g. "2026-04/original/abc123.jpg"

        # Only process files in */original/*
        if "/original/" not in name:
            continue

        if name in existing:
            skipped += 1
            continue

        parts = name.split("/")
        if len(parts) != 3:
            continue

        month_folder = parts[0]  # "2026-04"
        filename = parts[2]      # "abc123.jpg"
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

        if ext in VIDEO_EXTENSIONS:
            media_type = "video"
        elif ext in IMAGE_EXTENSIONS:
            media_type = "photo"
        else:
            continue

        # Generate thumbnail path (may or may not exist locally)
        thumb_name = filename.rsplit(".", 1)[0] + "_thumb.jpg"
        thumb_path = f"{month_folder}/thumbnails/{thumb_name}"

        # Use blob metadata for size and time
        file_size = blob.size or 0
        uploaded_at = blob.updated or datetime.now(KST)
        if uploaded_at.tzinfo:
            uploaded_at = uploaded_at.astimezone(KST).replace(tzinfo=None)

        photo_id = str(uuid.uuid4())
        file_hash = hashlib.md5(f"{name}{file_size}".encode()).hexdigest()

        cursor.execute(
            """INSERT INTO photo (id, filename, original_filename, file_path,
               thumbnail_path, file_hash, file_size, taken_at, uploaded_at,
               month_folder, media_type, is_favorite, uploader_name,
               visible_to, album_id, uploader_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                photo_id,
                filename,
                filename,  # original_filename unknown, use stored name
                name,      # file_path = GCS key
                thumb_path,
                file_hash,
                file_size,
                None,      # taken_at unknown
                uploaded_at.isoformat(),
                month_folder,
                media_type,
                0,         # is_favorite
                "",        # uploader_name unknown
                None,      # visible_to = all
                None,      # album_id
                None,      # uploader_id
            ),
        )
        recovered += 1

    conn.commit()
    conn.close()
    print(f"Recovered: {recovered}, Skipped (already exists): {skipped}")


if __name__ == "__main__":
    main()
