FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for Pillow/HEIF
RUN apt-get update && apt-get install -y --no-install-recommends \
    libheif-dev \
    libffi-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

# Create directories for data persistence
RUN mkdir -p /data/photos

# Use /data for persistent storage (mount a disk here)
ENV DATABASE_URL="sqlite:////data/bodeumi.db"
ENV PHOTOS_DIR="/data/photos"

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
