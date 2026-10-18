# atlas-flight-workspace

atlas-flight 항공 예약 서비스의 워크스페이스 레포다.
모든 모듈이 함께 쓰는 툴링, 문서, Claude Code 설정을 관리한다.

- 워크스페이스 레포는 모듈 폴더(`atlas-flight-*`)를 추적하지 않는다 (`.gitignore` 에 `/atlas-flight-*/`).
- 각 모듈은 독립 GitHub 레포다. 모듈은 이 폴더 아래에 clone 한다.

---

## 1. 폴더 구조

```
atlas-flight/
  .claude/              Claude Code 설정 (스킬·에이전트·훅·미리보기)
  docs/                 워크스페이스 공통 컨벤션 문서
  scripts/              Git 훅과 훅 설치 스크립트
  _workspace/           작업 산출물 (커밋하지 않음)
  atlas-flight-*/       모듈 (각각 독립 레포, 추적하지 않음)
  CLAUDE.md             Claude Code 공통 지시
  dev.sh                로컬 개발 환경 기동
  sync.sh               워크스페이스 레포·모든 모듈 동기화
  db-dictionary.html    DB 약어 사전 화면
  flowchart.html        항공 예매 스윔레인
```

---

## 2. 모듈 목록

| 모듈 | 역할 | DB 스키마 |
|---|---|---|
| [atlas-flight-auth](https://github.com/qoralswn82/atlas-flight-auth) | 인증·토큰 발급 | `ATF_AUTH` |
| [atlas-flight-booking](https://github.com/harin1124/atlas-flight-booking) | 예약 | `ATF_BOOKING` |
| [atlas-flight-core-data](https://github.com/harin1124/atlas-flight-core-data) | 공통 기준 정보 (국가·언어 코드 등) | `ATF_CORE_DATA` |
| [atlas-flight-core-lib](https://github.com/qoralswn82/atlas-flight-core-lib) | 공통 라이브러리, DB 컨벤션·약어 사전 | — |
| [atlas-flight-customer](https://github.com/harin1124/atlas-flight-customer) | 회원·승객 | `ATF_CUSTOMER` |
| [atlas-flight-flightway](https://github.com/qoralswn82/atlas-flight-flightway) | 운항 정보, 운항편 정보 | `ATF_FLIGHTWAY` |
| [atlas-flight-frontend](https://github.com/harin1124/atlas-flight-frontend) | 웹 프론트엔드 (React·Vite) | — |
| [atlas-flight-gateway](https://github.com/harin1124/atlas-flight-gateway) | API 게이트웨이 | — |
| [atlas-flight-inventory](https://github.com/harin1124/atlas-flight-inventory) | 재고 (좌석 등) | `ATF_INVENTORY` |
| [atlas-flight-policy](https://github.com/qoralswn82/atlas-flight-policy) | 정책 및 운임 규칙 (유류세 등) | `ATF_POLICY` |

백엔드 모듈은 Java 17 · Spring Boot · Gradle 을 쓴다.

---

## 3. 시작하기

### 3.1 사전 요구사항

- Git (Windows 는 Git Bash)
- Colima 와 Docker CLI — 로컬 MariaDB 컨테이너(`atlas-localdb`) 실행용
- JDK 17
- Node.js 와 Yarn — frontend 모듈용

### 3.2 설정 절차

단계마다 두 방법 중 하나를 고른다.

- **직접**: 터미널에서 명령을 실행한다.
- **Claude**: 이 폴더에서 Claude Code 를 열고 요청한다.

명령은 모두 워크스페이스 루트(`atlas-flight/`)에서 실행한다.

#### 1) 워크스페이스 레포 연결

- **직접**: [docs/workspace-repo-connect.md](docs/workspace-repo-connect.md) 의 절차를 따른다.
- **Claude**: 이 단계는 직접 한다. 워크스페이스 레포를 받기 전에는 Claude 설정(`CLAUDE.md`·스킬)이 폴더에 없다.

#### 2) 모듈 clone

- **직접**: 필요한 모듈을 이 폴더 아래에 clone 한다. 레포 주소는 2절 표를 참고한다.
  ```bash
  git clone https://github.com/harin1124/atlas-flight-booking.git
  ```
- **Claude**: "booking, inventory 모듈 clone 해줘" 처럼 요청한다.

#### 3) Git 훅 설치

- **직접**:
  ```bash
  ./scripts/install-git-hooks.sh
  ```
- **Claude**: "git 훅 설치해줘" 라고 요청한다.

훅은 clone 한 모듈에만 설치된다. 모듈을 새로 clone 하면 이 단계를 다시 실행한다.

#### 4) `.env` 준비

- **직접**:
  1. 템플릿을 복사한다.
     ```bash
     mkdir -p ~/.config/atlas-flight
     cp .claude/skills/db-setup/env.example ~/.config/atlas-flight/.env
     chmod 600 ~/.config/atlas-flight/.env
     ```
  2. `DB_ROOT_PASSWORD`, `DB_PASSWORD`, `JWT_SECRET`, `CRYPTO_SECRET_KEY` 를 채운다.
- **Claude**: `/db-setup` 을 실행한다. `.env` 가 없으면 스킬이 템플릿을 복사해 파일을 만들고 멈춘다. 비밀값은 Claude 가 채우지 않는다. 2번 항목은 직접 채운다.

키 설명은 4절을 참고한다.

#### 5) 로컬 DB 기동

- **직접**:
  ```bash
  ./dev.sh
  ```
- **Claude**: "로컬 DB 띄워줘" 라고 요청한다.

#### 6) 모듈별 스키마·계정 생성

- **직접**:
  1. 생성 예정 항목을 확인한다.
     ```bash
     ./.claude/skills/db-setup/db-setup.sh --dry-run
     ```
  2. 확인한 항목을 생성한다.
     ```bash
     ./.claude/skills/db-setup/db-setup.sh
     ```
- **Claude**: `/db-setup` 을 실행하거나 "DB 셋팅해줘" 라고 요청한다. Claude 는 dry-run 결과를 보여 주고, 확인을 받은 뒤 생성한다.

생성 SQL 은 모두 `IF NOT EXISTS` 형태다. 여러 번 실행해도 안전하다.

---

## 4. 환경 변수 (`.env`)

모든 모듈 앱과 스킬은 `~/.config/atlas-flight/.env` 한 파일을 읽는다.
앱은 `spring.config.import` 로 이 파일을 읽는다.

| 키 | 용도 |
|---|---|
| `DB_CONTAINER` | MariaDB 컨테이너명 (기본 `atlas-localdb`) |
| `DB_HOST` / `DB_PORT` | 앱 DB 접속 주소 |
| `DB_ROOT_PASSWORD` | 스키마·계정 생성용 root 비밀번호 (`db-setup` 스킬만 사용) |
| `DB_PASSWORD` | 모든 모듈 공통 DB 비밀번호 |
| `<MODULE>_DB_SCHEMA` | 모듈 스키마명 |
| `<MODULE>_DB_USERNAME` | 모듈 DB 계정 |
| `JWT_SECRET` | JWT 서명 키 |
| `CRYPTO_SECRET_KEY` | 암호화 키 |

- 전체 키 목록은 [.claude/skills/db-setup/env.example](.claude/skills/db-setup/env.example) 에 있다.
- `.env` 가 없으면 `db-setup` 스킬이 템플릿으로 파일을 만든다. 비밀번호는 직접 채운다.
- `.env` 는 커밋하지 않는다. 파일 권한은 600 으로 둔다.

---

## 5. 스크립트

자주 쓰는 작업은 스크립트를 직접 실행하거나 Claude 에게 요청한다.

| 작업 | 직접 | Claude |
|---|---|---|
| 로컬 DB 기동 (Colima 시작, DB 컨테이너 재시작) | `./dev.sh` | "로컬 DB 띄워줘" |
| 워크스페이스 레포·모든 모듈 동기화 (`fetch --prune` + `pull --ff-only`) | `./sync.sh` | `/sync-all` — 동기화 후 새 커밋을 모듈별로 요약한다 |
| commit-msg 훅 설치 | `./scripts/install-git-hooks.sh` | "git 훅 설치해줘" |
| commit-msg 훅 해제 | `./scripts/install-git-hooks.sh --uninstall` | "git 훅 해제해줘" |
| 모듈별 스키마·계정 점검·생성 | `./.claude/skills/db-setup/db-setup.sh` | `/db-setup` |

---

## 6. Claude Code 활용

### 6.1 스킬 (`.claude/skills/`)

| 스킬 | 용도 | 호출 예 |
|---|---|---|
| `db-setup` | 모듈별 스키마·계정·권한을 점검하고 없으면 만든다 | "DB 셋팅해줘" |
| `security-audit` | 의존성·코드·설정의 보안 취약점을 점검한다 | "보안 점검", `/security-audit auth` |
| `sync-all` | 모든 레포를 pull 하고 새 커밋을 모듈별로 요약한다 | "싱크", "뭐 업데이트됐는지 알려줘" |
| `table-design-artifact` | 테이블 설계를 ERD·예시 데이터 아티팩트로 만든다 | "테이블 설계 보여줘" |

### 6.2 에이전트 (`.claude/agents/`)

| 에이전트 | 용도 |
|---|---|
| `backend-developer` | 백엔드 모듈을 분석하거나 수정한다 |
| `frontend-developer` | frontend 모듈을 분석하거나 수정한다 |
| `code-reviewer` | 변경 코드를 정확성·재사용성·컨벤션 기준으로 검토한다 |
| `db-convention-reviewer` | 엔티티·DDL 의 테이블·컬럼명이 DB 컨벤션을 따르는지 검토한다 |

### 6.3 그 밖의 설정

- `CLAUDE.md` — 모든 작업에 적용하는 공통 지시다.
- `.claude/hooks/answer-guide-reminder.sh` — 요청마다 답변 가이드 규칙을 Claude 에게 알린다.
- `.claude/launch.json` — frontend 개발 서버 미리보기 설정이다.
- `.claude/settings.local.json` — 개인 설정이다. 커밋하지 않는다.

---

## 7. 문서·도구

| 문서 | 내용 |
|---|---|
| [docs/commit-convention.md](docs/commit-convention.md) | 커밋 메시지 규칙 (`type(module): 명사형 제목`) |
| [docs/answer-guide.md](docs/answer-guide.md) | Claude 답변 문체·작업 범위 규칙 |
| [docs/workspace-convention.md](docs/workspace-convention.md) | `_workspace/` 산출물 규칙 |
| [docs/workspace-repo-connect.md](docs/workspace-repo-connect.md) | 워크스페이스 레포 연결 방법 |
| [docs/core-data-endpoints.md](docs/core-data-endpoints.md) | core-data API 엔드포인트 목록 |
| `atlas-flight-core-lib/docs/db-convention.md` | DB 명명·DDL 규칙 |

- `db-dictionary.html` — 브라우저로 연다. 단어 검색과 컬럼명 조합을 지원한다. core-lib 모듈을 clone 해야 데이터가 보인다.
- `flowchart.html` — 브라우저로 연다. 항공 예매 흐름을 스윔레인으로 보여 준다.

---

## 8. 자주 겪는 문제

| 증상 | 해결 |
|---|---|
| `Docker 데몬에 연결할 수 없습니다` | `./dev.sh` 를 실행한다 |
| `root 접속 실패 (DB_ROOT_PASSWORD 확인)` | `.env` 의 `DB_ROOT_PASSWORD` 를 컨테이너 root 비밀번호와 맞춘다 |
| `기존 계정 비밀번호 불일치` | `db-setup` 을 `--sync-password` 옵션으로 실행한다 |
| 커밋이 commit-msg 훅에서 거부됨 | 출력된 사유를 보고 [커밋 컨벤션](docs/commit-convention.md) 에 맞게 고친다 |
| Windows 에서 `.sh` 가 실행되지 않음 | `git config core.autocrlf false` 를 설정하고 다시 checkout 한다 |
