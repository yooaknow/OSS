#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  deploy.sh  ─  단 하나의 명령으로 최신화 → 빌드 → 푸시 → 실행
#
#  사용법 (레포 클론 후 EC2 에서 실행):
#    bash deploy.sh
#
#  이 스크립트는 다음을 자동으로 수행합니다:
#    1. Docker 미설치 시 자동 설치 (Ubuntu / Amazon Linux 2)
#    2. GitHub 최신 코드 강제 동기화 (로컬 변경사항 전부 덮어씀)
#    3. DockerHub 로그인
#    4. 백엔드 / 프론트엔드 / All-in-One 이미지 빌드
#    5. 세 이미지 DockerHub 푸시
#    6. 기존 컨테이너 및 볼륨 완전 삭제
#    7. 새 컨테이너 실행
#    8. 접속 URL 안내
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

DOCKER_USER="yooahreaum"
TAG="latest"
BACK_IMAGE="${DOCKER_USER}/travel-back:${TAG}"
FRONT_IMAGE="${DOCKER_USER}/travel-front:${TAG}"
ALL_IMAGE="${DOCKER_USER}/travel-all:${TAG}"
CONTAINER_NAME="travel-app"
MYSQL_VOLUME="travel_mysql_data"

# ── 색상 출력 헬퍼 ────────────────────────────────────────────────
GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; RESET="\033[0m"
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

# ── 스크립트 위치 기준 프로젝트 루트 ────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 국내 여행지 추천 서비스 — 빌드 & 배포 스크립트"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── [Step 1] Docker 설치 확인 및 자동 설치 ──────────────────────
if ! command -v docker &>/dev/null; then
    warn "Docker 가 설치되어 있지 않습니다. 자동 설치를 시작합니다..."

    if command -v apt-get &>/dev/null; then
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

# ── [Step 2] GitHub 최신 코드 강제 동기화 ───────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "[Step 2] GitHub 최신 코드 강제 동기화"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v git &>/dev/null && [ -d ".git" ]; then
    git fetch origin
    git reset --hard origin/main
    success "GitHub origin/main 기준으로 강제 동기화 완료"
else
    warn "git 저장소가 아니거나 git 미설치 — 코드 동기화 건너뜀"
fi

# ── [Step 3] DockerHub 로그인 ────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "[Step 3] DockerHub 로그인 (${DOCKER_USER})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker login
success "DockerHub 로그인 완료"

# ── [Step 4] 이미지 빌드 ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "[Step 4-1] 백엔드 이미지 빌드 → ${BACK_IMAGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker build ./back -t "${BACK_IMAGE}"
success "백엔드 이미지 빌드 완료"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "[Step 4-2] 프론트엔드 이미지 빌드 → ${FRONT_IMAGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker build ./front -t "${FRONT_IMAGE}"
success "프론트엔드 이미지 빌드 완료"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "[Step 4-3] All-in-One 이미지 빌드 → ${ALL_IMAGE}"
info "          (MySQL + FastAPI + Streamlit 단일 컨테이너)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker build -f Dockerfile.all -t "${ALL_IMAGE}" .
success "All-in-One 이미지 빌드 완료"

# ── [Step 5] DockerHub 푸시 ──────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "[Step 5] 이미지 DockerHub 푸시"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker push "${BACK_IMAGE}"
success "${BACK_IMAGE} 푸시 완료"

docker push "${FRONT_IMAGE}"
success "${FRONT_IMAGE} 푸시 완료"

docker push "${ALL_IMAGE}"
success "${ALL_IMAGE} 푸시 완료"

# ── [Step 6] 기존 컨테이너 및 볼륨 완전 삭제 ────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "[Step 6] 기존 컨테이너 및 MySQL 볼륨 삭제"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker stop "${CONTAINER_NAME}" 2>/dev/null && \
    success "기존 컨테이너 중지" || true
docker rm   "${CONTAINER_NAME}" 2>/dev/null && \
    success "기존 컨테이너 삭제" || true
docker volume rm "${MYSQL_VOLUME}" 2>/dev/null && \
    success "MySQL 볼륨 삭제 (새 이미지로 DB 재초기화)" || true

# ── [Step 7] 새 컨테이너 실행 ───────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "[Step 7] 새 컨테이너 실행"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p 8501:8501 \
    -p 8000:8000 \
    -v "${MYSQL_VOLUME}:/var/lib/mysql" \
    "${ALL_IMAGE}"

success "컨테이너 시작 완료"

# ── [Step 8] 접속 URL 출력 ───────────────────────────────────────
PUBLIC_IP=$(curl -s --max-time 3 \
    http://169.254.169.254/latest/meta-data/public-ipv4 \
    2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN} 빌드 & 배포 완료!${RESET}"
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
echo " DockerHub 이미지:"
echo "   ${BACK_IMAGE}"
echo "   ${FRONT_IMAGE}"
echo "   ${ALL_IMAGE}"
echo ""
echo " EC2 보안그룹 인바운드 허용 확인:"
echo "   포트 8501 (Streamlit) / 8000 (FastAPI)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
