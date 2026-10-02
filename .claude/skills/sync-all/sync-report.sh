#!/usr/bin/env bash
#
# sync-report.sh — sync.sh 를 실행하고, 모듈별로 새로 들어온 커밋 메시지를 모아 출력한다.
#   1) 실행 전 각 모듈의 HEAD 를 기록
#   2) 프로젝트 루트의 sync.sh 실행 (출력은 그대로 전달)
#   3) HEAD 가 바뀐 모듈: <이전>..HEAD 커밋 (제목+본문, 머지 커밋 제외)
#      pull 하지 못한 모듈: HEAD..@{u} 의 아직 받지 못한 커밋
#
# sync.sh 는 브랜치를 바꾸지 않으므로 실행 전후 HEAD 비교만으로 들어온 범위가 정확히 나온다.

set -uo pipefail

# 스킬 폴더(.claude/skills/sync-all) 기준으로 프로젝트 루트로 이동
cd "$(dirname "$0")/../../.."

PREFIX="${SYNC_PREFIX:-atlas-flight-}"

# 실행 전 HEAD 기록 (bash 3.2 호환 — 병렬 배열)
NAMES=(); BEFORE=()
for p in "$PREFIX"*/; do
  [ -d "$p" ] || continue
  p="${p%/}"
  [ -e "$p/.git" ] || continue
  NAMES+=("$p")
  BEFORE+=("$(git -C "$p" rev-parse HEAD 2>/dev/null)")
done

echo "=== sync.sh 출력 ==="
NO_COLOR=1 ./sync.sh
echo
echo "=== 모듈별 커밋 ==="

[ ${#NAMES[@]} -eq 0 ] && { echo "(대상 모듈 없음)"; exit 0; }

found=0
for i in "${!NAMES[@]}"; do
  d="${NAMES[$i]}"; before="${BEFORE[$i]}"
  after="$(git -C "$d" rev-parse HEAD 2>/dev/null)"
  branch="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [ -n "$before" ] && [ "$before" != "$after" ]; then
    cnt="$(git -C "$d" rev-list --count --no-merges "$before..$after")"
    printf '\n### %s (%s) 새로 들어온 커밋 %s개 · %s..%s\n' \
      "$d" "$branch" "$cnt" "${before:0:7}" "${after:0:7}"
    git -C "$d" log --no-merges --format='- %h %s%n%b' "$before..$after"
    found=1
  fi

  # pull 실패·생략 등으로 upstream 보다 뒤처진 경우
  if git -C "$d" rev-parse --verify --quiet '@{u}' >/dev/null 2>&1; then
    pending="$(git -C "$d" rev-list --count --no-merges 'HEAD..@{u}')"
    if [ "$pending" -gt 0 ]; then
      printf '\n### %s (%s) 받지 못한 커밋 %s개 · HEAD..@{u}\n' "$d" "$branch" "$pending"
      git -C "$d" log --no-merges --format='- %h %s%n%b' 'HEAD..@{u}'
      found=1
    fi
  fi
done

[ "$found" -eq 0 ] && echo "(새로 들어오거나 받지 못한 커밋 없음)"
exit 0
