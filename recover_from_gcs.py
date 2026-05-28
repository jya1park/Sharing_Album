"""Recover photo/video records from GCS and regenerate thumbnails.

Usage (run inside Docker):
  sudo docker cp ~/Sharing_Album/recover_from_gcs.py bodeumi:/app/recover_from_gcs.py
  sudo docker exec bodeumi python3 /app/recover_from_gcs.py
"""
import hashlib
import os
import subprocess
import uuid
from datetime import datetime, timezone, timedelta
from pathlib import Path

from google.cloud import storage
from PIL import Image, ImageOps

KST = timezone(timedelta(hours=9))
IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "heic", "heif"}
VIDEO_EXTENSIONS = {"mp4", "mov", "avi", "mkv", "webm"}

DB_PATH = "/data/bodeumi.db"
BUCKET_NAME = "bodme-photo"
PHOTOS_DIR = Path("/data/photos")
THUMB_SIZE = (300, 300)


def recover_db(conn, blobs):
    """Step 1: Restore photo records from GCS into DB."""
    print("\n=== Step 1: DB 복구 ===")
    cursor = conn.cursor()

    existing = set()
    for row in cursor.execute("SELECT file_path FROM photo"):
        existing.add(row[0])
    print(f"기존 DB 레코드: {len(existing)}개")

    recovered = 0
    skipped = 0

    for blob in blobs:
        name = blob.name
        if "/original/" not in name:
            continue
        if name in existing:
            skipped += 1
            continue

        parts = name.split("/")
        if len(parts) != 3:
            continue

        month_folder = parts[0]
        filename = parts[2]
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

        if ext in VIDEO_EXTENSIONS:
            media_type = "video"
        elif ext in IMAGE_EXTENSIONS:
            media_type = "photo"
        else:
            continue

        thumb_name = filename.rsplit(".", 1)[0] + "_thumb.jpg"
        thumb_path = f"{month_folder}/thumbnails/{thumb_name}"

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
                photo_id, filename, filename, name, thumb_path, file_hash,
                file_size, None, uploaded_at.isoformat(), month_folder,
                media_type, 0, "", None, None, None,
            ),
        )
        recovered += 1

    conn.commit()
    print(f"복구: {recovered}개, 스킵(이미 존재): {skipped}개")


def regenerate_thumbnails(blobs):
    """Step 2: Download originals from GCS and generate missing thumbnails."""
    print("\n=== Step 2: 썸네일 재생성 ===")

    originals = [b for b in blobs if "/original/" in b.name]
    total = len(originals)
    done = 0
    created = 0
    failed = 0

    for blob in originals:
        parts = blob.name.split("/")
        if len(parts) != 3:
            continue

        month = parts[0]
        filename = parts[2]
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

        thumb_name = filename.rsplit(".", 1)[0] + "_thumb.jpg"
        thumb_path = PHOTOS_DIR / month / "thumbnails" / thumb_name

        done += 1

        if thumb_path.exists():
            continue

        thumb_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = f"/tmp/{filename}"

        try:
            blob.download_to_filename(tmp)

            if ext in VIDEO_EXTENSIONS:
                subprocess.run(
                    [
                        "ffmpeg", "-i", tmp,
                        "-vframes", "1",
                        "-vf", f"scale={THUMB_SIZE[0]}:{THUMB_SIZE[1]}:force_original_aspect_ratio=increase,crop={THUMB_SIZE[0]}:{THUMB_SIZE[1]}",
                        "-q:v", "5", "-y", str(thumb_path),
                    ],
                    capture_output=True, timeout=30,
                )
            else:
                img = Image.open(tmp)
                img = ImageOps.exif_transpose(img)
                img.thumbnail(THUMB_SIZE)
                if img.mode in ("RGBA", "P"):
                    img = img.convert("RGB")
                img.save(str(thumb_path), "JPEG", quality=85)

            created += 1
        except Exception as e:
            print(f"  실패: {filename} - {e}")
            failed += 1
        finally:
            if os.path.exists(tmp):
                os.remove(tmp)

        if done % 10 == 0:
            print(f"  진행: {done}/{total} (생성: {created}, 실패: {failed})")

    print(f"완료: 총 {total}개 중 {created}개 썸네일 생성, {failed}개 실패")


def main():
    import sqlite3

    print("=" * 50)
    print("  보드미 GCS 데이터 복구 스크립트")
    print("=" * 50)

    # Connect DB
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='photo'")
    if not cursor.fetchone():
        print("Error: photo 테이블이 없습니다. 서버를 먼저 시작하세요.")
        conn.close()
        return

    # List GCS files
    print(f"\nGCS 버킷 스캔 중: gs://{BUCKET_NAME}/")
    client = storage.Client()
    bucket = client.bucket(BUCKET_NAME)
    blobs = list(bucket.list_blobs())
    originals = [b for b in blobs if "/original/" in b.name]
    print(f"GCS 원본 파일: {len(originals)}개")

    # Step 1: Recover DB
    recover_db(conn, blobs)
    conn.close()

    # Step 2: Regenerate thumbnails
    regenerate_thumbnails(blobs)

    print("\n" + "=" * 50)
    print("  복구 완료!")
    print("=" * 50)


if __name__ == "__main__":
    main()
