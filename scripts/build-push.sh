#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  build-push.sh
#  백엔드 / 프론트엔드 / All-in-One 이미지를 빌드 후 DockerHub 푸시
#  실행: bash scripts/build-push.sh
#  (Windows는 Git Bash 또는 WSL 에서 실행)
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

DOCKER_USER="yooahreaum"
TAG="latest"

BACK_IMAGE="${DOCKER_USER}/travel-back:${TAG}"
FRONT_IMAGE="${DOCKER_USER}/travel-front:${TAG}"
ALL_IMAGE="${DOCKER_USER}/travel-all:${TAG}"

# ── 스크립트 위치 기준으로 프로젝트 루트로 이동 ──────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."
echo "작업 디렉터리: $(pwd)"

# ── Docker 로그인 ─────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Docker Hub 로그인"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker login

# ── [1/3] 백엔드 ─────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [1/3] 백엔드 이미지 빌드 → ${BACK_IMAGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker build ./back -t "${BACK_IMAGE}"
docker push "${BACK_IMAGE}"
echo "✔ 백엔드 푸시 완료"

# ── [2/3] 프론트엔드 ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [2/3] 프론트엔드 이미지 빌드 → ${FRONT_IMAGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker build ./front -t "${FRONT_IMAGE}"
docker push "${FRONT_IMAGE}"
echo "✔ 프론트엔드 푸시 완료"

# ── [3/3] All-in-One 통합 이미지 ────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [3/3] All-in-One 이미지 빌드 → ${ALL_IMAGE}"
echo "       (MySQL + FastAPI + Streamlit 단일 컨테이너)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker build -f Dockerfile.all -t "${ALL_IMAGE}" .
docker push "${ALL_IMAGE}"
echo "✔ All-in-One 푸시 완료"

# ── 완료 요약 ────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 모든 이미지 DockerHub 푸시 완료!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${BACK_IMAGE}"
echo "  ${FRONT_IMAGE}"
echo "  ${ALL_IMAGE}"
echo ""
echo " 배포하려면 EC2에서 실행:"
echo "  bash deploy.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
