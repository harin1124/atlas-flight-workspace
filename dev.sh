#!/usr/bin/env bash
#
# dev.sh — 로컬 개발 환경 기동 스크립트
#   1) Colima(Docker 런타임) 시작
#   2) Colima 가 정상 기동되면 bplte-mariadb 컨테이너 재시작
#
# 모든 명령이 성공하면 0(정상) 으로 종료하고,
# 도중에 실패하면 해당 지점에서 멈추고 0 이 아닌 코드로 종료한다.

set -euo pipefail

echo "▶ Colima 시작 중…"
colima start

echo "▶ Colima 상태 확인…"
colima status

echo "▶ docker restart bplte-mariadb…"
docker restart bplte-mariadb

echo "✅ 모든 명령이 정상적으로 완료되었습니다."
