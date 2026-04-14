from pathlib import Path

from PIL import Image, ImageOps

from app.config import THUMBNAIL_SIZE, MAX_IMAGE_LONG_SIDE, IMAGE_QUALITY


def compress_and_resize(source_path: Path, dest_path: Path) -> int:
    """Resize large images and compress to JPEG.

    - If the longest side exceeds MAX_IMAGE_LONG_SIDE (2048px), resize
      proportionally.
    - Apply EXIF orientation correction.
    - Save as JPEG with configured quality.

    Returns the saved file size in bytes.
    """
    dest_path.parent.mkdir(parents=True, exist_ok=True)

    with Image.open(source_path) as img:
        img = ImageOps.exif_transpose(img)

        # Resize if the longest side exceeds the limit
        width, height = img.size
        long_side = max(width, height)
        if long_side > MAX_IMAGE_LONG_SIDE:
            ratio = MAX_IMAGE_LONG_SIDE / long_side
            new_width = int(width * ratio)
            new_height = int(height * ratio)
            img = img.resize((new_width, new_height), Image.LANCZOS)

        # Convert to RGB for JPEG output
        if img.mode in ("RGBA", "P", "LA"):
            img = img.convert("RGB")

        img.save(dest_path, "JPEG", quality=IMAGE_QUALITY, optimize=True)

    return dest_path.stat().st_size


def generate_thumbnail(source_path: Path, dest_path: Path) -> None:
    """Generate a thumbnail from the (already processed) image.

    Creates a 300x300 max thumbnail with LANCZOS resampling.
    """
    dest_path.parent.mkdir(parents=True, exist_ok=True)

    with Image.open(source_path) as img:
        img = ImageOps.exif_transpose(img)
        img.thumbnail(THUMBNAIL_SIZE, Image.LANCZOS)

        if img.mode in ("RGBA", "P", "LA"):
            img = img.convert("RGB")

        img.save(dest_path, "JPEG", quality=IMAGE_QUALITY, optimize=True)
