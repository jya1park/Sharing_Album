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
echo "  1. 프로젝트 파일을 VM에 복사 (gcloud compute scp 또는 git clone)"
echo "  2. docker build -t bodeumi ."
echo "  3. docker run -d --name bodeumi -p 8000:8000 -v /data:/data --restart unless-stopped bodeumi"
echo "  4. http://<VM_외부IP>:8000/docs 에서 확인"
