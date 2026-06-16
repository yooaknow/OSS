# Mood Brew

Streamlit + FastAPI + Docker 기반 카페 메뉴 추천 웹 애플리케이션입니다.

사용자가 날씨, 기분, 시간대, 단맛 선호도, 카페인 민감도를 선택하면 Streamlit 프론트엔드가 FastAPI 백엔드로 요청을 보내고, FastAPI가 조건에 맞는 음료와 디저트 조합을 추천합니다.

## 프로젝트 구조

```text
.
├── front/              # Streamlit 프론트엔드
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── assets/
├── back/               # FastAPI 백엔드
│   ├── main.py
│   ├── Dockerfile
│   └── requirements.txt
├── db/
│   └── init.sql        # MySQL 초기 테이블
├── docker-compose.yml
└── deploy.sh           # EC2 배포 스크립트
```

## 주요 기능

- Streamlit 화면에서 단계별 질문 입력
- FastAPI `/recommend` API 호출
- 입력값 기반 rule-based 추천 결과 생성
- 추천 음료, 디저트, 추천 이유, 태그 표시
- Docker Compose로 DB, 백엔드, 프론트엔드 분리 실행

## 추천 흐름

```text
사용자 입력
→ Streamlit
→ FastAPI /recommend 요청
→ 추천 결과 JSON 반환
→ Streamlit 결과 화면 표시
```

## 로컬 실행

```bash
docker compose up -d --build
```

접속 주소:

- Streamlit: `http://localhost:8501`
- FastAPI Docs: `http://localhost:8000/docs`

상태 확인:

```bash
docker compose ps
```

## EC2 배포

EC2 서버에서 저장소를 클론한 뒤 아래 명령으로 실행합니다.

```bash
bash deploy.sh
```

배포 스크립트는 최신 코드를 가져온 뒤 Docker 이미지를 빌드하고 `db`, `back`, `front` 컨테이너를 실행합니다.

필요한 경우 아래 옵션을 사용할 수 있습니다.

```bash
FULL_REBUILD=1 bash deploy.sh
PUSH_IMAGES=1 bash deploy.sh
RESET_VOLUMES=1 bash deploy.sh
PRUNE_DOCKER=1 bash deploy.sh
```

## API

### `POST /recommend`

요청 예시:

```json
{
  "weather": "맑음",
  "mood": "기분 좋음",
  "sweetness": 3,
  "caffeine_sensitivity": 4,
  "time_of_day": "오후"
}
```

응답 예시:

```json
{
  "recommendations": [],
  "top_menu": {
    "rank": 1,
    "name": "자몽 에이드",
    "dessert": "마카롱",
    "score": 91,
    "description": "카페인이 부담스러운 날에도 마시기 좋은 상큼한 음료입니다.",
    "reason": "맑은 날에는 가볍고 산뜻한 메뉴가 잘 맞습니다.",
    "tags": ["무카페인", "상큼함", "가벼움"]
  },
  "summary": "조건에 맞춰 자몽 에이드 + 마카롱 세트를 추천합니다."
}
```

## 데모 영상 확인 항목

- EC2 주소로 Streamlit 앱 접속
- 질문 선택을 통한 사용자 입력
- 마지막 선택 후 추천 결과 표시
- `docker compose ps`로 컨테이너 실행 상태 확인
- FastAPI Docs 또는 `/health`를 통한 백엔드 실행 확인
