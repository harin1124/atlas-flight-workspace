#!/usr/bin/env bash
#
# db-setup.sh — 모듈별 MariaDB 스키마·계정·권한 점검 및 생성
#   모든 값은 ~/.config/atlas-flight/.env 에서 읽는다 (각 모듈 앱도 spring.config.import 로 같은 파일을 읽음)
#     스키마명: <MODULE>_DB_SCHEMA     (atlas-flight-core-data → CORE_DATA_DB_SCHEMA)
#     계정명:   <MODULE>_DB_USERNAME
#     비밀번호: DB_PASSWORD            — 전 모듈 공통
#   대상: .env 에 <MODULE>_DB_SCHEMA 가 있거나, 모듈 application 설정이 ${<MODULE>_DB_SCHEMA} 를 참조하는 모듈
#
# 모듈마다:
#   1) 모듈 계정으로 스키마 접속 시도 → 성공하면 그대로 둔다
#   2) 실패하면 root 로 CREATE DATABASE / CREATE USER / GRANT (모두 IF NOT EXISTS, 멱등)
#   3) 모듈 계정으로 다시 접속해 검증
#
# 옵션:
#   --dry-run        접속 점검만 하고, 실행할 SQL 은 출력만 (비밀번호 마스킹)
#   --sync-password  계정은 있는데 비밀번호가 다르면 .env 값으로 ALTER USER
#
# 환경변수:
#   ATLAS_ENV_FILE   .env 경로 (기본 ~/.config/atlas-flight/.env)
#   SYNC_PREFIX      모듈 폴더 접두사 (기본 atlas-flight-)

set -uo pipefail

# 스킬 폴더(.claude/skills/db-setup) 기준으로 프로젝트 루트로 이동
cd "$(dirname "$0")/../../.."

DRY_RUN=0; SYNC_PW=0
for a in "$@"; do
  case "$a" in
    --dry-run)       DRY_RUN=1 ;;
    --sync-password) SYNC_PW=1 ;;
    *) echo "알 수 없는 옵션: $a" >&2; exit 2 ;;
  esac
done

# ── 색상 설정 (터미널이 아니면 자동 비활성화) ──────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m';  DIM=$'\033[2m';   RESET=$'\033[0m'
  RED=$'\033[31m';  GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; CYAN=$'\033[36m';  GRAY=$'\033[90m'
else
  BOLD=; DIM=; RESET=; RED=; GREEN=; YELLOW=; BLUE=; CYAN=; GRAY=
fi

ENV_FILE="${ATLAS_ENV_FILE:-$HOME/.config/atlas-flight/.env}"
PREFIX="${SYNC_PREFIX:-atlas-flight-}"
EXAMPLE=".claude/skills/db-setup/env.example"

# ── .env 읽기: source 하지 않고 KEY=VALUE 만 파싱 ─────────────────
# 앱은 이 파일을 .properties 로 읽으므로 따옴표·export 를 해석하지 않는다 (값 그대로 사용)
env_get() {
  local line
  line="$(grep -E "^[[:space:]]*$1[[:space:]]*=" "$ENV_FILE" 2>/dev/null | tail -1)"
  [ -n "$line" ] || return 1
  line="${line#*=}"
  line="${line#"${line%%[![:space:]]*}"}"   # 앞 공백 제거 (properties 와 동일)
  printf '%s' "$line"
}

# .env 가 없으면 템플릿을 그대로 복사해 만든다 (비밀번호는 비어 있으므로 채운 뒤 다시 실행)
if [ ! -f "$ENV_FILE" ]; then
  mkdir -p "$(dirname "$ENV_FILE")" && cp "$EXAMPLE" "$ENV_FILE" && chmod 600 "$ENV_FILE" || {
    printf "${RED}✖ %s 생성 실패${RESET}\n" "$ENV_FILE"; exit 1; }
  printf "${YELLOW}✚ %s 가 없어 템플릿으로 새로 만들었습니다.${RESET}\n" "$ENV_FILE"
  printf "  ${DIM}DB_ROOT_PASSWORD · DB_PASSWORD 를 채운 뒤 다시 실행하세요.${RESET}\n"
  exit 1
fi

CONTAINER="$(env_get DB_CONTAINER || echo atlas-localdb)"
ROOT_USER="$(env_get DB_ROOT_USERNAME || echo root)"
ROOT_PW="$(env_get DB_ROOT_PASSWORD || true)"
pw="$(env_get DB_PASSWORD || true)"

if [ -z "$pw" ]; then
  printf "${RED}✖ %s 에 DB_PASSWORD(전 모듈 공통 비밀번호)가 없습니다.${RESET}\n" "$ENV_FILE"
  exit 1
fi

# ── 컨테이너·클라이언트 확인 ───────────────────────────────────────
if ! docker info >/dev/null 2>&1; then
  printf "${RED}✖ Docker 데몬에 연결할 수 없습니다.${RESET} ${DIM}./dev.sh 로 Colima·DB 를 먼저 기동하세요.${RESET}\n"
  exit 1
fi
if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
  printf "${RED}✖ 컨테이너 '%s' 가 실행 중이 아닙니다.${RESET} ${DIM}./dev.sh 또는 docker start %s${RESET}\n" \
    "$CONTAINER" "$CONTAINER"
  exit 1
fi
CLI="$(docker exec "$CONTAINER" sh -c 'command -v mariadb || command -v mysql' 2>/dev/null | head -1)"
if [ -z "$CLI" ]; then
  printf "${RED}✖ 컨테이너 '%s' 안에 mariadb/mysql 클라이언트가 없습니다.${RESET}\n" "$CONTAINER"
  exit 1
fi

# 비밀번호는 MYSQL_PWD 로 넘겨 명령행(ps)에 남기지 않는다
# run_sql <user> <password> <sql> [schema]
run_sql() {
  docker exec -i -e MYSQL_PWD="$2" "$CONTAINER" \
    "$CLI" -h 127.0.0.1 -u"$1" -N -B ${4:+-D "$4"} -e "$3" 2>&1
}

# SQL 문자열 리터럴 이스케이프 (\ 와 ')
sql_str() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/''/g"; }

valid_ident() { printf '%s' "$1" | grep -qE '^[A-Za-z0-9_]+$'; }

ROOT_CHECKED=0
ensure_root() {
  [ "$ROOT_CHECKED" -eq 1 ] && return 0
  if [ -z "$ROOT_PW" ]; then
    ROOT_ERR="DB_ROOT_PASSWORD 미설정"; return 1
  fi
  if ! run_sql "$ROOT_USER" "$ROOT_PW" "SELECT 1" >/dev/null; then
    ROOT_ERR="root 접속 실패 (DB_ROOT_PASSWORD 확인)"; return 1
  fi
  ROOT_CHECKED=1
}

# ── 모듈 application 설정이 ${<KEY>_DB_SCHEMA} 를 참조하는지 ─────────
references_schema_key() {
  cat "$1"/src/main/resources/application.{yaml,yml,properties} 2>/dev/null \
    | grep -vE '^[[:space:]]*#' | grep -q "\${$2_DB_SCHEMA[:}]"
}

print_header() {
  local title="$1"
  printf "\n${BLUE}╭─ ${BOLD}▶ %s${RESET}${BLUE} %s╮${RESET}\n" \
    "$title" "$(printf '─%.0s' $(seq 1 $((54 - ${#title}))))"
}

# 요약용 병렬 배열 (bash 3.2 호환)
S_NAME=(); S_SCHEMA=(); S_KIND=(); S_NOTE=()
add_result() { S_NAME+=("$1"); S_SCHEMA+=("$2"); S_KIND+=("$3"); S_NOTE+=("$4"); }

[ "$DRY_RUN" -eq 1 ] && printf "${YELLOW}DRY-RUN — 접속 점검만 하고 변경 SQL 은 실행하지 않습니다.${RESET}\n"
printf "${DIM}env: %s · container: %s${RESET}\n" "$ENV_FILE" "$CONTAINER"

for p in "$PREFIX"*/; do
  [ -d "$p" ] || continue
  d="${p%/}"
  key="$(printf '%s' "${d#"$PREFIX"}" | tr '[:lower:]-' '[:upper:]_')"
  schema="$(env_get "${key}_DB_SCHEMA" || true)"
  user="$(env_get "${key}_DB_USERNAME" || true)"

  # .env 에도 없고 앱 설정도 참조하지 않으면 DB 를 쓰지 않는 모듈 — 조용히 제외
  if [ -z "$schema" ] && ! references_schema_key "$d" "$key"; then
    continue
  fi

  print_header "$d"
  printf "  ${GRAY}스키마${RESET}  ${CYAN}%s${RESET} ${DIM}(%s_DB_SCHEMA)${RESET}\n" "${schema:-?}" "$key"
  printf "  ${GRAY}계정  ${RESET}  ${CYAN}%s${RESET} ${DIM}(%s_DB_USERNAME)${RESET}\n" "${user:-?}" "$key"

  if [ -z "$schema" ] || [ -z "$user" ]; then
    missing=""
    [ -z "$schema" ] && missing="${key}_DB_SCHEMA"
    [ -z "$user" ]   && missing="${missing:+$missing, }${key}_DB_USERNAME"
    printf "  ${RED}✖ .env 에 %s 가 없습니다${RESET}\n" "$missing"
    add_result "$d" "${schema:--}" FAIL "$missing 미설정"
    continue
  fi
  if ! valid_ident "$schema" || ! valid_ident "$user"; then
    printf "  ${RED}✖ 스키마/계정명에 허용되지 않는 문자가 있습니다 (영문·숫자·_ 만)${RESET}\n"
    add_result "$d" "$schema" FAIL "식별자 형식 오류"
    continue
  fi

  # ── 1) 모듈 계정으로 접속 시도 ────────────────────────────────
  printf "  ${GRAY}접속  ${RESET}  "
  if out="$(run_sql "$user" "$pw" "SELECT 1" "$schema")"; then
    printf "${GREEN}✔ 정상${RESET}\n"
    add_result "$d" "$schema" OK ""
    continue
  fi
  printf "${YELLOW}실패${RESET} ${DIM}%s${RESET}\n" "$(printf '%s' "$out" | tail -1)"

  # ── 2) root 로 상태 조회 후 생성 ──────────────────────────────
  if ! ensure_root; then
    printf "  ${RED}✖ %s — 생성 불가${RESET}\n" "$ROOT_ERR"
    add_result "$d" "$schema" FAIL "$ROOT_ERR"
    continue
  fi

  schema_exists="$(run_sql "$ROOT_USER" "$ROOT_PW" \
    "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$schema'")"
  user_exists="$(run_sql "$ROOT_USER" "$ROOT_PW" \
    "SELECT COUNT(*) FROM mysql.user WHERE User='$user' AND Host='%'")"

  pw_sql="$(sql_str "$pw")"
  SQLS=(); SHOWN=(); notes=""
  if [ "$schema_exists" = "0" ]; then
    SQLS+=("CREATE DATABASE IF NOT EXISTS \`$schema\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
    SHOWN+=("${SQLS[${#SQLS[@]}-1]}"); notes="스키마"
  fi
  if [ "$user_exists" = "0" ]; then
    SQLS+=("CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$pw_sql'")
    SHOWN+=("CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '****'"); notes="${notes:+$notes·}계정"
  elif [ "$SYNC_PW" -eq 1 ]; then
    SQLS+=("ALTER USER '$user'@'%' IDENTIFIED BY '$pw_sql'")
    SHOWN+=("ALTER USER '$user'@'%' IDENTIFIED BY '****'"); notes="${notes:+$notes·}비밀번호"
  fi
  SQLS+=("GRANT ALL PRIVILEGES ON \`$schema\`.* TO '$user'@'%'" "FLUSH PRIVILEGES")
  SHOWN+=("${SQLS[${#SQLS[@]}-2]}" "FLUSH PRIVILEGES"); notes="${notes:+$notes·}권한"

  for s in "${SHOWN[@]}"; do printf "  ${GRAY}SQL   ${RESET}  ${DIM}%s;${RESET}\n" "$s"; done

  if [ "$DRY_RUN" -eq 1 ]; then
    hint=""
    [ "$user_exists" != "0" ] && [ "$SYNC_PW" -eq 0 ] && hint=" (기존 계정 — 비밀번호 불일치면 --sync-password)"
    add_result "$d" "$schema" PLAN "생성 예정: $notes$hint"
    continue
  fi

  joined=""
  for s in "${SQLS[@]}"; do joined="$joined$s; "; done
  if ! out="$(run_sql "$ROOT_USER" "$ROOT_PW" "$joined")"; then
    printf "  ${RED}✖ 생성 실패${RESET} ${DIM}%s${RESET}\n" "$(printf '%s' "$out" | tail -1)"
    add_result "$d" "$schema" FAIL "SQL 실행 실패"
    continue
  fi

  # ── 3) 재접속 검증 ────────────────────────────────────────────
  printf "  ${GRAY}재접속${RESET}  "
  if run_sql "$user" "$pw" "SELECT 1" "$schema" >/dev/null; then
    printf "${GREEN}✔ 정상${RESET}\n"
    add_result "$d" "$schema" CREATED "$notes"
  else
    printf "${RED}✖ 실패${RESET}\n"
    if [ "$user_exists" != "0" ] && [ "$SYNC_PW" -eq 0 ]; then
      add_result "$d" "$schema" FAIL "기존 계정 비밀번호 불일치 추정 — --sync-password"
    else
      add_result "$d" "$schema" FAIL "생성 후에도 접속 실패"
    fi
  fi
done

# ── 요약 ───────────────────────────────────────────────────────
if [ ${#S_NAME[@]} -eq 0 ]; then
  printf "\n${YELLOW}⚠ 대상 모듈이 없습니다 — .env 에 <MODULE>_DB_SCHEMA 를 추가하세요.${RESET}\n"
  exit 0
fi

name_w=0; sc_w=0
for i in "${!S_NAME[@]}"; do
  [ ${#S_NAME[$i]}   -gt $name_w ] && name_w=${#S_NAME[$i]}
  [ ${#S_SCHEMA[$i]} -gt $sc_w ]   && sc_w=${#S_SCHEMA[$i]}
done

printf "\n${BOLD}${BLUE}╭──────────────────────────────────────────────╮${RESET}\n"
printf "${BOLD}${BLUE}│${RESET}  ${BOLD}🗄  DB 셋팅 요약${RESET}                             ${BOLD}${BLUE}│${RESET}\n"
printf "${BOLD}${BLUE}╰──────────────────────────────────────────────╯${RESET}\n"

n_ok=0; n_new=0; n_plan=0; n_fail=0
for i in "${!S_NAME[@]}"; do
  case "${S_KIND[$i]}" in
    OK)      icon="${GREEN}✔${RESET}"; label="${DIM}정상${RESET}";      ((n_ok++)) ;;
    CREATED) icon="${GREEN}✚${RESET}"; label="${GREEN}생성${RESET}";    ((n_new++)) ;;
    PLAN)    icon="${YELLOW}…${RESET}"; label="${YELLOW}예정${RESET}";  ((n_plan++)) ;;
    FAIL)    icon="${RED}✖${RESET}";   label="${RED}실패${RESET}";      ((n_fail++)) ;;
  esac
  printf "  %b  ${BOLD}%-*s${RESET}  ${CYAN}%-*s${RESET}  %b  ${GRAY}%s${RESET}\n" \
    "$icon" "$name_w" "${S_NAME[$i]}" "$sc_w" "${S_SCHEMA[$i]}" "$label" "${S_NOTE[$i]}"
done

printf "  ${DIM}%s${RESET}\n" "──────────────────────────────────────────────"
printf "  ${GREEN}%d 정상${RESET} ${DIM}·${RESET} ${GREEN}%d 생성${RESET} ${DIM}·${RESET} ${YELLOW}%d 예정${RESET} ${DIM}·${RESET} ${RED}%d 실패${RESET}\n" \
  "$n_ok" "$n_new" "$n_plan" "$n_fail"
echo

[ "$n_fail" -eq 0 ]
