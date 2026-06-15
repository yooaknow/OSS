import streamlit as st
import requests
import os

BACKEND_URL = os.getenv("BACKEND_URL", "http://back:8000")

st.set_page_config(
    page_title="국내 여행지 추천",
    page_icon="✈️",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# ── 스타일 ────────────────────────────────────────────────────────────────────
st.markdown("""
<style>
    .main-title  { font-size:2.4rem; font-weight:800; color:#1a5276; text-align:center; }
    .sub-title   { font-size:1.1rem; color:#555; text-align:center; margin-bottom:1.5rem; }
    .dest-card   { background:#f0f7ff; border-radius:12px; padding:1.2rem;
                   border-left:5px solid #2980b9; margin-bottom:0.8rem; }
    .highlight   { font-size:0.88rem; color:#333; }
    .badge       { display:inline-block; background:#2980b9; color:#fff;
                   border-radius:20px; padding:2px 10px; font-size:0.8rem; margin:2px; }
</style>
""", unsafe_allow_html=True)

st.markdown('<p class="main-title">✈️ 국내 여행지 추천 서비스</p>', unsafe_allow_html=True)
st.markdown(
    '<p class="sub-title">여행 스타일을 입력하면 딱 맞는 국내 여행지 3곳을 추천해 드립니다!</p>',
    unsafe_allow_html=True,
)

st.divider()

# ── 입력 폼 ───────────────────────────────────────────────────────────────────
col_left, col_right = st.columns(2, gap="large")

with col_left:
    st.subheader("🎯 여행 스타일")
    activity = st.selectbox(
        "선호 활동 유형",
        ["자연/힐링", "역사/문화", "맛집탐방", "액티비티", "쇼핑"],
        help="가장 하고 싶은 활동을 선택하세요",
    )
    season = st.radio(
        "여행 계절",
        ["봄", "여름", "가을", "겨울"],
        horizontal=True,
    )
    party_size = st.radio(
        "여행 인원",
        ["혼자", "2명", "3-4명", "5명 이상"],
        horizontal=True,
    )

with col_right:
    st.subheader("📋 여행 조건")
    duration = st.selectbox(
        "여행 기간",
        ["당일치기", "1박2일", "2박3일", "3박 이상"],
    )
    budget = st.radio(
        "예산 수준 (1인 기준)",
        ["알뜰하게", "적당하게", "여유롭게"],
        horizontal=True,
        help="교통비 + 숙박비 + 식비 포함 기준",
    )

    st.markdown("")
    st.markdown("")

    # 백엔드 상태 표시
    try:
        health = requests.get(f"{BACKEND_URL}/health", timeout=3).json()
        db_icon = "🟢" if health.get("db_connected") else "🟡"
        st.caption(f"서버: 🟢 정상  DB: {db_icon} {'연결됨' if health.get('db_connected') else '대기중'}")
    except Exception:
        st.caption("서버: 🔴 연결 안됨")

st.divider()

# ── 추천 버튼 ─────────────────────────────────────────────────────────────────
if st.button("🔍 여행지 추천받기", type="primary", use_container_width=True):
    payload = {
        "party_size": party_size,
        "duration": duration,
        "activity": activity,
        "budget": budget,
        "season": season,
    }

    with st.spinner("맞춤 여행지를 찾는 중..."):
        try:
            resp = requests.post(f"{BACKEND_URL}/recommend", json=payload, timeout=10)

            if resp.status_code == 200:
                data = resp.json()
                st.success(f"✅ {data['summary']}")
                st.subheader(f"🏆 {season} {activity} 추천 여행지 TOP 3")

                cols = st.columns(3, gap="medium")
                medals = ["🥇", "🥈", "🥉"]

                for i, rec in enumerate(data["recommendations"]):
                    with cols[i]:
                        st.markdown(
                            f'<div class="dest-card">'
                            f'<h3>{medals[i]} {rec["name"]}</h3>'
                            f'<p class="highlight"><em>{rec["description"]}</em></p>'
                            f'</div>',
                            unsafe_allow_html=True,
                        )

                        st.markdown("**🏛 주요 명소**")
                        for h in rec["highlights"]:
                            st.markdown(f"- {h}")

                        st.metric("💰 예상 비용 (1인)", rec["estimated_cost"])

                        st.info(f"👥 **인원 팁:** {rec['party_tip']}")
                        st.markdown(rec["duration_note"])
                        st.warning(f"💡 **Tip:** {rec['tip']}")

            else:
                st.error(f"추천 오류: {resp.status_code} — {resp.text}")

        except requests.exceptions.ConnectionError:
            st.error(
                f"백엔드 서버({BACKEND_URL})에 연결할 수 없습니다. "
                "Docker 컨테이너가 실행 중인지 확인하세요."
            )
        except Exception as e:
            st.error(f"오류 발생: {e}")

# ── 추천 기록 ─────────────────────────────────────────────────────────────────
st.divider()
with st.expander("📋 최근 추천 기록 (FastAPI → MySQL)"):
    if st.button("기록 불러오기", key="history_btn"):
        try:
            resp = requests.get(f"{BACKEND_URL}/history?limit=8", timeout=5)
            if resp.status_code == 200:
                history = resp.json().get("history", [])
                if history:
                    for item in history:
                        st.markdown(
                            f"**{item['created_at']}** &nbsp;|&nbsp; "
                            f"{item['season']} {item['activity']} &nbsp;|&nbsp; "
                            f"{item['party_size']} · {item['duration']} · {item['budget']}"
                        )
                else:
                    st.info("아직 추천 기록이 없습니다. 추천을 먼저 실행해 보세요!")
            elif "error" in resp.json():
                st.warning("DB 미연결 상태입니다. 기록 저장은 MySQL 연결 후 가능합니다.")
        except Exception as e:
            st.warning(f"기록을 불러올 수 없습니다: {e}")
