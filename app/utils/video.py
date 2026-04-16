import subprocess
from pathlib import Path

from app.config import THUMBNAIL_SIZE


def generate_video_thumbnail(video_path: Path, thumbnail_path: Path) -> None:
    """Extract first frame from video and save as JPEG thumbnail."""
    thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
    w, h = THUMBNAIL_SIZE

    subprocess.run(
        [
            "ffmpeg", "-i", str(video_path),
            "-vframes", "1",
            "-vf", f"scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h}",
            "-q:v", "5",
            "-y",
            str(thumbnail_path),
        ],
        capture_output=True,
        timeout=30,
    )

    if not thumbnail_path.exists():
        # Fallback: try without crop filter
        subprocess.run(
            [
                "ffmpeg", "-i", str(video_path),
                "-vframes", "1",
                "-vf", f"scale={w}:{h}",
                "-q:v", "5",
                "-y",
                str(thumbnail_path),
            ],
            capture_output=True,
            timeout=30,
        )
