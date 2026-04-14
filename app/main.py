from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import PHOTOS_DIR
from app.database import create_db_and_tables
from app.routers import photos

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

app.include_router(photos.router, prefix="/photos", tags=["Photos"])


@app.get("/health")
async def health_check():
    return {"status": "ok"}
