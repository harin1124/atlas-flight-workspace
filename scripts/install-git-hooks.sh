#!/usr/bin/env bash
#
# install-git-hooks.sh — 메타 레포와 모든 모듈에 공용 git 훅(scripts/git-hooks) 적용
#   대상: 메타 레포 + 스크립트 상위 폴더의 atlas-flight-* 중 git 저장소 (HOOKS_PREFIX 로 접두사 변경 가능)
#   방식: 각 저장소의 로컬 core.hooksPath 를 scripts/git-hooks 절대 경로로 설정
#         → 훅 수정 시 재설치 없이 모든 저장소에 즉시 반영
#
# 해제: ./scripts/install-git-hooks.sh --uninstall

set -uo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
HOOKS_DIR="$ROOT/scripts/git-hooks"
PREFIX="${HOOKS_PREFIX:-atlas-flight-}"
MODE="${1:-install}"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; GRAY=$'\033[90m'; RESET=$'\033[0m'
else
  GREEN=; YELLOW=; GRAY=; RESET=
fi

chmod +x "$HOOKS_DIR"/*

# 메타 레포 판별과 동일하게 폴더 바로 아래 .git 존재 여부로 판별 (sync.sh 참고)
REPOS=(".")
for p in "$PREFIX"*/; do
  [ -d "$p" ] || continue
  p="${p%/}"
  [ -e "$p/.git" ] && REPOS+=("$p")
done

for repo in "${REPOS[@]}"; do
  name="$repo"; [ "$repo" = "." ] && name="(meta) $(basename "$ROOT")"
  current="$(git -C "$repo" config --local --get core.hooksPath || true)"

  if [ "$MODE" = "--uninstall" ]; then
    if [ "$current" = "$HOOKS_DIR" ]; then
      git -C "$repo" config --local --unset core.hooksPath
      echo "${GREEN}✓${RESET} $name ${GRAY}해제${RESET}"
    else
      echo "${GRAY}- $name 설치되지 않음${RESET}"
    fi
    continue
  fi

  # 다른 훅 경로(husky 등)를 쓰고 있으면 덮어쓰지 않는다
  if [ -n "$current" ] && [ "$current" != "$HOOKS_DIR" ]; then
    echo "${YELLOW}! $name 건너뜀 — 이미 core.hooksPath=$current 사용 중${RESET}"
    continue
  fi
  git -C "$repo" config --local core.hooksPath "$HOOKS_DIR"
  echo "${GREEN}✓${RESET} $name"
done

[ "$MODE" = "--uninstall" ] || echo "${GRAY}core.hooksPath → $HOOKS_DIR${RESET}"
