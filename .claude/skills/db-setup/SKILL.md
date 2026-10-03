---
name: db-setup
description: 로컬 MariaDB(atlas-localdb)에 모듈별 스키마·계정·권한이 준비됐는지 점검하고, 없으면 생성한다. 스키마명(<MODULE>_DB_SCHEMA)·계정명(<MODULE>_DB_USERNAME)·공통 비밀번호(DB_PASSWORD)는 모두 ~/.config/atlas-flight/.env 에서 읽는다 (각 모듈 앱도 같은 파일을 읽음). "DB 셋팅", "스키마 만들어줘", "DB 계정 생성", "로컬 DB 초기 설정", "DB 접속 안 돼" 같은 요청에 사용한다.
allowed-tools: Bash(./.claude/skills/db-setup/db-setup.sh:*)
---

# 모듈별 DB 셋팅

DB 접속 정보는 `~/.config/atlas-flight/.env` 한 곳에서 관리한다.
각 모듈 앱은 `spring.config.import` 로 이 파일을 읽고, `./.claude/skills/db-setup/db-setup.sh` 도 같은 파일을 읽는다.

| 키 | 용도 |
|---|---|
| `<MODULE>_DB_SCHEMA` | 모듈 스키마명 (`atlas-flight-core-data` → `CORE_DATA_DB_SCHEMA`) |
| `<MODULE>_DB_USERNAME` | 모듈 접속 계정 |
| `DB_PASSWORD` | 전 모듈 공통 비밀번호 |
| `DB_HOST` / `DB_PORT` | 앱 접속 주소 (앱 기본값 localhost:3306) |
| `DB_ROOT_PASSWORD` | 스키마·계정 생성용 root 비밀번호 (스킬만 사용) |

대상 모듈: `.env` 에 `<MODULE>_DB_SCHEMA` 가 있거나, 모듈 application 설정이 `${<MODULE>_DB_SCHEMA}` 를 참조하는 모듈.

모듈마다:
1. `<MODULE>_DB_USERNAME` + `DB_PASSWORD` 로 `<MODULE>_DB_SCHEMA` 접속 시도
2. 실패하면 root 로 `CREATE DATABASE` / `CREATE USER` / `GRANT` 후 재접속 검증

모든 생성 SQL 은 `IF NOT EXISTS` 라 여러 번 실행해도 안전하다. 전체 키 목록은 같은 폴더의 `env.example` 참고.

## 실행 순서

1. 먼저 `--dry-run` 으로 실행해 무엇이 만들어질지 확인한다.
   ```
   NO_COLOR=1 ./.claude/skills/db-setup/db-setup.sh --dry-run
   ```
2. 결과에 "예정"(생성할 것)이 없으면 그대로 보고하고 끝낸다.
3. "예정"이 있으면 생성될 스키마·계정을 사용자에게 보여 주고 확인을 받은 뒤 옵션 없이 실행한다.
4. "기존 계정 비밀번호 불일치"가 나오면 `--sync-password`(기존 계정 비밀번호를 .env 값으로 변경)를 쓸지 사용자에게 묻는다. 묻지 않고 붙이지 않는다.

## 사전 조건 오류 대응

- `.env` 없음 → 스크립트가 `env.example` 을 그대로 복사해 `~/.config/atlas-flight/.env` 를 만들고(권한 600) 멈춘다. `DB_ROOT_PASSWORD` · `DB_PASSWORD` 를 채운 뒤 다시 실행하라고 안내한다. 비밀번호를 대신 채우거나 출력하지 않는다.
- Docker 데몬·컨테이너 미기동 → `./dev.sh` 실행을 안내한다.

## 보고 형식

스크립트 출력만 근거로 짧게 보고한다.

1. **한 줄 총평** — 정상/생성/예정/실패 수.
2. **생성·예정 모듈** — 모듈마다 스키마명과 새로 만든(만들) 항목(스키마·계정·권한·비밀번호).
3. **주의 필요** — 해당할 때만: 실패 모듈과 원인 한 줄 (`<MODULE>_DB_SCHEMA`/`_DB_USERNAME` 누락, root 접속 실패, 비밀번호 불일치 등).
4. 모두 정상이면 "모든 모듈 DB 정상" 한 줄로 끝낸다.
