import logging
import shutil
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import PHOTOS_DIR, GCS_BUCKET
from app.database import create_db_and_tables
from app.routers import auth, photos
from app.utils.storage import storage_mode

logger = logging.getLogger("uvicorn.error")

# Register HEIC/HEIF support
try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
except ImportError:
    pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    PHOTOS_DIR.mkdir(parents=True, exist_ok=True)
    if GCS_BUCKET:
        logger.info("Storage: originals go to GCS bucket '%s'", GCS_BUCKET)
    else:
        logger.warning(
            "Storage: GCS_BUCKET is not set - originals are saved on the local disk (%s)", PHOTOS_DIR
        )
    yield


app = FastAPI(
    title="Bodeumi API",
    description="Baby photo sharing app for families",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(photos.router, prefix="/photos", tags=["Photos"])


@app.get("/health")
async def health_check():
    disk = shutil.disk_usage(PHOTOS_DIR)
    return {
        "status": "ok",
        "storage": storage_mode(),
        "gcs_bucket": GCS_BUCKET or None,
        "disk_free_gb": round(disk.free / 1024**3, 1),
    }
