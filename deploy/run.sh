#!/bin/bash
# ============================================
# 보드미 서버 빌드 + (재)시작
# VM에서 저장소 폴더 안에서 실행: bash deploy/run.sh
#
# 원본 사진/동영상은 GCS 버킷에 저장됩니다.
# GCS_BUCKET 없이 컨테이너를 띄우면 원본이 VM 디스크에 쌓이므로
# docker run 을 직접 치지 말고 항상 이 스크립트를 사용하세요.
# ============================================

set -e

cd "$(dirname "$0")/.."

GCS_BUCKET="${GCS_BUCKET:-bodme-photo}"
DATA_DIR="$(pwd)/data"
mkdir -p "$DATA_DIR"

echo "=== 이미지 빌드 ==="
sudo docker build -t bodeumi .

echo "=== 기존 컨테이너 정리 ==="
sudo docker stop bodeumi 2>/dev/null || true
sudo docker rm bodeumi 2>/dev/null || true

echo "=== 컨테이너 실행 (GCS_BUCKET=$GCS_BUCKET, 데이터: $DATA_DIR) ==="
sudo docker run -d --name bodeumi -p 8000:8000 \
  -v "$DATA_DIR:/data" \
  -e GCS_BUCKET="$GCS_BUCKET" \
  --log-opt max-size=10m --log-opt max-file=3 \
  --restart always bodeumi

echo "=== 이전 이미지 정리 ==="
sudo docker image prune -f

sleep 3
echo "=== 상태 확인 ==="
curl -s http://localhost:8000/health
echo
