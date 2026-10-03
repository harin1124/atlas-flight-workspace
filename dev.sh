#!/usr/bin/env bash
#
# dev.sh — 로컬 개발 환경 기동 스크립트
#   1) Colima(Docker 런타임) 시작
#   2) Colima 가 정상 기동되면 DB 컨테이너 재시작
#
# 컨테이너명은 ~/.config/atlas-flight/.env 의 DB_CONTAINER 값을 쓴다 (없으면 atlas-localdb).
#
# 환경변수
#   ATLAS_ENV_FILE   .env 경로 (기본 ~/.config/atlas-flight/.env)
#
# 모든 명령이 성공하면 0(정상) 으로 종료하고,
# 도중에 실패하면 해당 지점에서 멈추고 0 이 아닌 코드로 종료한다.

set -euo pipefail

ENV_FILE="${ATLAS_ENV_FILE:-$HOME/.config/atlas-flight/.env}"

# ── .env 읽기: source 하지 않고 KEY=VALUE 만 파싱 ─────────────────
# 앱은 이 파일을 .properties 로 읽으므로 따옴표·export 를 해석하지 않는다 (값 그대로 사용)
env_get() {
  local line
  line="$(grep -E "^[[:space:]]*$1[[:space:]]*=" "$ENV_FILE" 2>/dev/null | tail -1)"
  [ -n "$line" ] || return 1
  line="${line#*=}"
  line="${line#"${line%%[![:space:]]*}"}"   # 앞 공백 제거 (properties 와 동일)
  [ -n "$line" ] || return 1
  printf '%s' "$line"
}

CONTAINER="$(env_get DB_CONTAINER || echo atlas-localdb)"

echo "▶ Colima 시작 중…"
colima start

echo "▶ Colima 상태 확인…"
colima status

echo "▶ docker restart ${CONTAINER}…"
docker restart "$CONTAINER"

echo "✅ 모든 명령이 정상적으로 완료되었습니다."
