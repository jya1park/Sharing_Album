from datetime import datetime
from typing import Optional

from PIL import Image
from PIL.ExifTags import Base as ExifBase


def extract_taken_date(image: Image.Image) -> Optional[datetime]:
    """Extract shooting date from EXIF data.

    Tries DateTimeOriginal first, then DateTime.
    Returns None if EXIF date is unavailable.
    """
    try:
        exif_data = image.getexif()
        if not exif_data:
            return None

        for tag_id in [ExifBase.DateTimeOriginal, ExifBase.DateTime]:
            date_str = exif_data.get(tag_id)
            if date_str:
                return datetime.strptime(str(date_str), "%Y:%m:%d %H:%M:%S")

        return None
    except Exception:
        return None
