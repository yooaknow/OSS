#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  deploy.sh  ─  단 하나의 명령으로 전체 프로젝트 배포
#
#  사용법 (EC2 또는 Docker 가 설치된 서버):
#    bash deploy.sh
#
#  이 스크립트는 다음을 자동으로 수행합니다:
#    1. Docker 미설치 시 자동 설치 (Ubuntu / Amazon Linux 2)
#    2. DockerHub 에서 All-in-One 이미지 pull
#    3. 기존 컨테이너 정리 후 새 컨테이너 시작
#    4. 접속 URL 안내
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

DOCKER_USER="yooahreaum"
IMAGE="${DOCKER_USER}/travel-all:latest"
CONTAINER_NAME="travel-app"
MYSQL_VOLUME="travel_mysql_data"

# ── 색상 출력 헬퍼 ────────────────────────────────────────────────
GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; RESET="\033[0m"
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 국내 여행지 추천 서비스 — 자동 배포 스크립트"
echo " 이미지: ${IMAGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── [Step 1] Docker 설치 확인 및 자동 설치 ──────────────────────
if ! command -v docker &>/dev/null; then
    warn "Docker 가 설치되어 있지 않습니다. 자동 설치를 시작합니다..."

    if command -v apt-get &>/dev/null; then
        # ── Ubuntu / Debian ─────────────────────────────────────
        info "Ubuntu/Debian 환경 감지 → Docker 설치 중..."
        sudo apt-get update -y -qq
        sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker "$USER" 2>/dev/null || true

    elif command -v yum &>/dev/null; then
        # ── Amazon Linux 2 / CentOS / RHEL ─────────────────────
        info "Amazon Linux/RHEL 환경 감지 → Docker 설치 중..."
        sudo yum update -y -q
        sudo yum install -y -q docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker "$USER" 2>/dev/null || true
    else
        echo "지원하지 않는 OS 입니다. Docker 를 수동으로 설치하세요."
        echo "  https://docs.docker.com/engine/install/"
        exit 1
    fi

    success "Docker 설치 완료."
    warn "그룹 권한 적용을 위해 스크립트를 다시 실행해 주세요:"
    echo "  bash deploy.sh"
    exit 0
fi

success "Docker $(docker --version | awk '{print $3}' | tr -d ',') 확인"

# ── [Step 2] 기존 컨테이너 정리 ─────────────────────────────────
info "기존 컨테이너(${CONTAINER_NAME}) 정리 중..."
docker stop  "${CONTAINER_NAME}" 2>/dev/null && \
    success "${CONTAINER_NAME} 컨테이너 중지" || true
docker rm    "${CONTAINER_NAME}" 2>/dev/null && \
    success "${CONTAINER_NAME} 컨테이너 삭제" || true

# ── [Step 3] 최신 이미지 Pull ────────────────────────────────────
echo ""
info "DockerHub 에서 이미지 다운로드 중..."
info "  ${IMAGE}"
docker pull "${IMAGE}"
success "이미지 pull 완료"

# ── [Step 4] 컨테이너 실행 ──────────────────────────────────────
echo ""
info "컨테이너 시작..."
docker run -d \
    --name  "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p 8501:8501 \
    -p 8000:8000 \
    -v "${MYSQL_VOLUME}:/var/lib/mysql" \
    "${IMAGE}"

success "컨테이너 시작 완료"

# ── [Step 5] 접속 URL 출력 ───────────────────────────────────────
# EC2 메타데이터에서 퍼블릭 IP 가져오기 (실패하면 로컬호스트)
PUBLIC_IP=$(curl -s --max-time 3 \
    http://169.254.169.254/latest/meta-data/public-ipv4 \
    2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN} 배포 완료!${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  Streamlit (프론트)  →  ${CYAN}http://${PUBLIC_IP}:8501${RESET}"
echo -e "  FastAPI   (백엔드)  →  ${CYAN}http://${PUBLIC_IP}:8000/docs${RESET}"
echo ""
echo " 유용한 명령어:"
echo "   docker ps                          # 실행 중인 컨테이너 확인"
echo "   docker logs -f ${CONTAINER_NAME}   # 실시간 로그"
echo "   docker stop  ${CONTAINER_NAME}     # 서비스 중지"
echo "   docker start ${CONTAINER_NAME}     # 서비스 재시작"
echo ""
echo " EC2 보안그룹 인바운드 허용 확인:"
echo "   포트 8501 (Streamlit) / 8000 (FastAPI)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
