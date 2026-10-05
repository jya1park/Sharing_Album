#!/bin/bash
# ============================================
# Google Compute Engine 배포 스크립트
# VM에 SSH 접속 후 실행하세요
# ============================================

set -e

echo "=== 1. Docker 설치 ==="
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo systemctl enable docker
sudo usermod -aG docker $USER

echo "=== 2. 데이터 디렉토리 생성 ==="
sudo mkdir -p /data/photos
sudo chown -R $USER:$USER /data

echo "=== 3. 방화벽 규칙 (8000 포트) ==="
echo "GCP 콘솔에서 방화벽 규칙을 추가하거나 아래 명령어를 로컬에서 실행하세요:"
echo "  gcloud compute firewall-rules create allow-bodeumi \\"
echo "    --allow tcp:8000 --target-tags=bodeumi-server"
echo ""

echo "=== 완료! ==="
echo "다음 단계:"
echo "  1. git clone https://github.com/jya1park/Sharing_Album.git && cd Sharing_Album"
echo "  2. bash deploy/run.sh   (GCS_BUCKET=bodme-photo 로 컨테이너를 띄웁니다)"
echo "  3. curl http://localhost:8000/health 에서 \"storage\": \"gcs\" 확인"
