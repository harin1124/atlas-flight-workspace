#!/usr/bin/env bash
#
# sync.sh — 모든 모듈을 현재 활성화된 브랜치 기준으로 동기화
#   대상: 스크립트 위치에서 atlas-flight-* 폴더 중 git 저장소인 것 (SYNC_PREFIX 로 접두사 변경 가능)
#   각 저장소마다:
#     1) fetch --all --prune  → 새 브랜치 반영 + 삭제된 원격 브랜치 정리(브랜치 목록 최신화)
#     2) pull --ff-only       → 현재 브랜치를 빨리 감기로만 갱신(머지 커밋 방지)
#
# upstream(추적 정보)이 없는 브랜치는 origin/<브랜치>가 있으면 자동으로 연결한다.
# 한 모듈이 실패해도 나머지는 계속 진행하고, 마지막에 요약을 출력한다.

set -uo pipefail

# 스크립트 위치를 기준으로 동작 (어디서 실행하든 동일하게 동작)
cd "$(dirname "$0")"

# ── 색상 설정 (터미널이 아니면 자동 비활성화) ──────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m';  DIM=$'\033[2m';   RESET=$'\033[0m'
  RED=$'\033[31m';  GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; CYAN=$'\033[36m';  GRAY=$'\033[90m'
else
  BOLD=; DIM=; RESET=; RED=; GREEN=; YELLOW=; BLUE=; CYAN=; GRAY=
fi

# ── 모듈 탐색: 접두사로 시작하는 폴더 중 git 저장소만 대상 ─────────
# 메타 레포 자체가 git 저장소라 rev-parse 는 하위 폴더도 참으로 판정하므로,
# 폴더 바로 아래 .git 존재 여부로 판별한다 (worktree 의 .git 파일도 인정).
PREFIX="${SYNC_PREFIX:-atlas-flight-}"
MODULES=(); EXCLUDED=()
for p in "$PREFIX"*/; do
  [ -d "$p" ] || continue
  p="${p%/}"
  if [ -e "$p/.git" ]; then
    MODULES+=("$p")
  else
    EXCLUDED+=("$p")
  fi
done

if [ ${#EXCLUDED[@]} -gt 0 ]; then
  printf "${DIM}git 저장소가 아니라 제외: %s${RESET}\n" "${EXCLUDED[*]}"
fi
if [ ${#MODULES[@]} -eq 0 ]; then
  printf "${YELLOW}⚠ '%s*' 로 시작하는 git 저장소가 없습니다.${RESET}\n" "$PREFIX"
  exit 0
fi

# 요약용 병렬 배열
declare -a S_NAME S_BRANCH S_KIND S_NOTE
n_ok=0; n_fail=0; n_skip=0; n_added=0; n_removed=0

# 모듈 헤더 박스 출력
print_header() {
  local title="$1"
  printf "\n${BLUE}╭─ ${BOLD}▶ %s${RESET}${BLUE} %s╮${RESET}\n" \
    "$title" "$(printf '─%.0s' $(seq 1 $((54 - ${#title}))))"
}

for d in "${MODULES[@]}"; do
  print_header "$d"

  branch="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  printf "  ${GRAY}브랜치${RESET}  ${CYAN}%s${RESET}\n" "$branch"

  # ── fetch + 브랜치 변동 감지 ──────────────────────────────────
  printf "  ${GRAY}fetch  ${RESET}"
  before="$(git -C "$d" for-each-ref --format='%(refname:short)' refs/remotes)"
  git -C "$d" fetch --all --prune --quiet
  after="$(git -C "$d" for-each-ref --format='%(refname:short)' refs/remotes)"

  added="$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort))"
  removed="$(comm -23 <(echo "$before" | sort) <(echo "$after" | sort))"
  a_cnt=0; r_cnt=0
  [ -n "$added" ]   && a_cnt=$(echo "$added"   | grep -c .)
  [ -n "$removed" ] && r_cnt=$(echo "$removed" | grep -c .)

  if [ -z "$added" ] && [ -z "$removed" ]; then
    printf "${DIM}변동 없음${RESET}\n"
  else
    printf "${GREEN}+%d${RESET} / ${RED}-%d${RESET}\n" "$a_cnt" "$r_cnt"
    if [ -n "$added" ]; then
      echo "$added"   | sed "s/^/         ${GREEN}🌱 /;s/\$/${RESET}/"
    fi
    if [ -n "$removed" ]; then
      echo "$removed" | sed "s/^/         ${RED}🗑  /;s/\$/${RESET}/"
    fi
  fi
  ((n_added += a_cnt)); ((n_removed += r_cnt))

  # 요약 note
  note=""
  [ "$a_cnt" -gt 0 ] && note="🌱+$a_cnt"
  [ "$r_cnt" -gt 0 ] && note="$note 🗑-$r_cnt"

  # ── upstream 자동 연결 ───────────────────────────────────────
  if ! git -C "$d" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    if git -C "$d" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      printf "  ${GRAY}upstream${RESET} ${DIM}미설정 → origin/%s 연결${RESET}\n" "$branch"
      git -C "$d" branch --set-upstream-to="origin/$branch" "$branch" >/dev/null
    else
      printf "  ${YELLOW}⚠ origin/%s 없음 — pull 생략${RESET}\n" "$branch"
      S_NAME+=("$d"); S_BRANCH+=("$branch"); S_KIND+=("SKIP"); S_NOTE+=("원격 없음 $note")
      ((n_skip++))
      continue
    fi
  fi

  # ── pull ─────────────────────────────────────────────────────
  printf "  ${GRAY}pull   ${RESET}"
  out="$(git -C "$d" pull --ff-only 2>&1)"
  if [ $? -eq 0 ]; then
    if echo "$out" | grep -qE "Fast-forward|Updating|업데이트 중"; then
      files=$(echo "$out" | grep -cE '\|')
      printf "${GREEN}⬆ 업데이트됨${RESET} ${DIM}(%s개 파일)${RESET}\n" "$files"
      S_NAME+=("$d"); S_BRANCH+=("$branch"); S_KIND+=("UPDATED"); S_NOTE+=("$note")
    else
      printf "${DIM}이미 최신${RESET}\n"
      S_NAME+=("$d"); S_BRANCH+=("$branch"); S_KIND+=("OK"); S_NOTE+=("$note")
    fi
    ((n_ok++))
  else
    printf "${RED}✖ 실패 (충돌/비-FF — 수동 확인 필요)${RESET}\n"
    S_NAME+=("$d"); S_BRANCH+=("$branch"); S_KIND+=("FAIL"); S_NOTE+=("$note")
    ((n_fail++))
  fi
done

# ── 요약 ───────────────────────────────────────────────────────
# 정렬 폭 계산
name_w=0; br_w=0
for i in "${!S_NAME[@]}"; do
  [ ${#S_NAME[$i]}   -gt $name_w ] && name_w=${#S_NAME[$i]}
  [ ${#S_BRANCH[$i]} -gt $br_w ]   && br_w=${#S_BRANCH[$i]}
done

printf "\n${BOLD}${BLUE}╭──────────────────────────────────────────────╮${RESET}\n"
printf "${BOLD}${BLUE}│${RESET}  ${BOLD}📦 동기화 요약${RESET}                              ${BOLD}${BLUE}│${RESET}\n"
printf "${BOLD}${BLUE}╰──────────────────────────────────────────────╯${RESET}\n"

for i in "${!S_NAME[@]}"; do
  case "${S_KIND[$i]}" in
    UPDATED) icon="${GREEN}⬆${RESET}"; label="${GREEN}업데이트${RESET}" ;;
    OK)      icon="${GREEN}✔${RESET}"; label="${DIM}최신${RESET}" ;;
    FAIL)    icon="${RED}✖${RESET}";   label="${RED}실패${RESET}" ;;
    SKIP)    icon="${YELLOW}⊘${RESET}"; label="${YELLOW}건너뜀${RESET}" ;;
    *)       icon="•"; label="" ;;
  esac
  printf "  %b  ${BOLD}%-*s${RESET}  ${CYAN}%-*s${RESET}  %b  ${GRAY}%s${RESET}\n" \
    "$icon" "$name_w" "${S_NAME[$i]}" "$br_w" "${S_BRANCH[$i]}" "$label" "${S_NOTE[$i]}"
done

# 합계
printf "  ${DIM}%s${RESET}\n" "──────────────────────────────────────────────"
printf "  ${GREEN}%d 성공${RESET} ${DIM}·${RESET} ${RED}%d 실패${RESET} ${DIM}·${RESET} ${YELLOW}%d 건너뜀${RESET}   ${DIM}|${RESET}   ${GREEN}🌱 신규 %d${RESET} ${DIM}·${RESET} ${RED}🗑 삭제 %d${RESET}\n" \
  "$n_ok" "$n_fail" "$n_skip" "$n_added" "$n_removed"
echo
