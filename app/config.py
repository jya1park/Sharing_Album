import os
from pathlib import Path

# Database
DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./bodeumi.db")

# Storage
PHOTOS_DIR: Path = Path(os.getenv("PHOTOS_DIR", "./photos"))
THUMBNAIL_SIZE: tuple[int, int] = (300, 300)

# Image processing
MAX_IMAGE_LONG_SIDE: int = 2048
IMAGE_QUALITY: int = 85

# Upload limits
MAX_FILE_SIZE_MB: int = 20
MAX_FILE_SIZE_BYTES: int = MAX_FILE_SIZE_MB * 1024 * 1024
ALLOWED_EXTENSIONS: set[str] = {"jpg", "jpeg", "png", "heic", "heif"}
