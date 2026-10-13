---
name: security-audit
description: atlas-flight 모듈의 보안을 점검하고 수정안을 제안한다. 의존성 취약점(OSV 조회 + Spring Boot BOM 기준 목표 버전), 코드 취약점(인증·인가, JWT, 비밀번호 저장, SQL injection, 입력 검증), 설정·비밀값(하드코딩 비밀값, CORS, 쿠키, 운영 위험 설정)을 다룬다. 파일은 수정하지 않고 _workspace 에 점검 결과와 수정 제안을 남긴다. 제안한 해소 버전은 sandbox 복사본에 적용해 해석·취약점·빌드 회귀를 검증한다. "보안 점검", "취약점 확인", "보안 감사", "CVE 확인", "의존성 보안 패치 검토", "security-audit" 요청에 사용한다. 모듈 이름을 인자로 받으며(예: auth gateway frontend), 없으면 전체 모듈을 점검한다.
allowed-tools: Bash(python3 .claude/skills/security-audit/scripts/collect_deps.py:*), Bash(python3 .claude/skills/security-audit/scripts/osv_check.py:*), Bash(python3 .claude/skills/security-audit/scripts/bom_versions.py:*), Bash(python3 .claude/skills/security-audit/scripts/verify_patch.py:*)
---

# 보안 점검 + 수정 제안

점검 대상 인자: `$ARGUMENTS` (비어 있으면 `atlas-flight-*` 전체 — 백엔드와 프론트엔드)

## 결과서가 갖춰야 할 것

사용자가 요청한 사항이다. 결과서 작성 규칙은 `references/report-format.md` 에 있다. 4단계 시작 전에 읽는다.

1. 판정 근거를 상세히 쓴다. P1·P2 는 배경·문제·확인 근거(코드 발췌)·공격 시나리오·영향·공격 조건을 모두 쓴다.
2. 발견 사항과 수정 방법을 한 섹션에 쓴다. 같은 수정으로 해결되는 발견 사항은 `SEC-n` 섹션 하나로 묶는다.
3. 섹션마다 "수정 후 확인 방법"을 쓴다.
4. 의존성 수정 제안은 sandbox 검증(5단계)을 통과한 것만 쓴다. 검증 결과를 제안 바로 아래에 둔다.

## 금지 사항

- 소스·`build.gradle`·`package.json`·`yarn.lock`·설정 파일을 수정하지 않는다. 수정안은 `result.md` 에만 쓴다.
- 커밋·푸시하지 않는다.
- 이전 점검 보고서의 목표 버전을 재사용하지 않는다. 취약점과 최신 버전은 매번 다시 조회한다.
- 파일 쓰기는 이번 점검의 `_workspace` 작업 폴더 안에서만 한다.
- 검증되지 않은 버전을 수정 제안으로 확정하지 않는다. 의존성 제안은 5단계 검증을 통과해야 한다.

## 절차

### 1. 작업 폴더와 계획서

1. `date +%F` 로 오늘 날짜를 구한다.
2. `_workspace/<날짜>-보안-점검/` 폴더를 만든다. 같은 이름이 있으면 `-2`, `-3` 을 붙인다.
3. `plan.md` 를 작성한다. 구조는 `docs/workspace-convention.md` 3절을 따른다.
   - 범위에 점검 대상 모듈과 점검 영역(의존성·코드·설정)을 적는다.
   - 범위 밖에 "파일 수정, 커밋"을 적는다.

### 2. 의존성 취약점

1. 의존성을 수집한다.
   ```bash
   python3 .claude/skills/security-audit/scripts/collect_deps.py --out _workspace/<폴더>/deps $ARGUMENTS
   ```
   - ✖ 로 표시된 모듈은 `deps/raw/<모듈>.txt` 를 읽고 원인을 기록한다. 점검은 나머지 모듈로 계속한다.
2. OSV 로 취약점을 조회한다.
   ```bash
   python3 .claude/skills/security-audit/scripts/osv_check.py --out _workspace/<폴더>/deps
   ```
3. Boot 계열별 최신 패치와 관리 버전을 조회한다. `--boot` 에는 현재 쓰는 Boot 버전과 후보 버전을 모두 넣는다.
   ```bash
   python3 .claude/skills/security-audit/scripts/bom_versions.py --boot-lines --boot <현재 버전들> <후보 버전들>
   ```
   - 취약 라이브러리가 기본 목록에 없으면 `--grep <이름>` 으로 다시 조회한다.
   - Boot 가 관리하지 않는 라이브러리는 `--latest <group:artifact>` 로 최신 버전을 조회한다.
4. 결과를 아래 규칙으로 해석한다.
   - **core-lib**: `java-library` 모듈이다. core-lib 자체의 해석 버전은 서비스 모듈의 Boot BOM 이 덮어쓴다.
     - `vulns.json` 에서 영향 모듈이 core-lib 하나뿐인 행은 "런타임 미포함"으로 따로 기록한다.
     - core-lib 가 `api` 로 전파하는 라이브러리 중 Boot BOM 이 관리하지 않는 것(예: springdoc)은 서비스 모듈에 그대로 들어간다. 서비스 모듈 행으로 판정한다.
   - **프론트엔드**: `yarn.lock` 전체를 조회하므로 빌드 도구가 섞인다. 판정 전 Node 22 로 `corepack yarn why <패키지>` 를 실행해 devDependency 경로인지 확인한다.
   - "일부 미수정"으로 표시된 패키지는 `vulns.json` 에서 수정 버전이 없는 취약점을 찾아 별도로 기록한다.

### 3. 목표 버전 결정 (BOM 우선)

1. Boot 계열을 정한다.
   - 지원 종료일을 확인한다 (WebSearch: `endoflife.date spring-boot`). 6개월 안에 OSS 지원이 끝나는 계열은 다음 계열을 권장한다.
   - 모든 서비스 모듈을 같은 Boot 패치 버전으로 맞추는 안을 기본으로 한다.
2. Boot 계열을 바꾸면 Spring Cloud 릴리스 트레인 호환 버전을 확인한다 (WebSearch: `Spring Cloud release train Spring Boot <계열> compatibility`). `springCloudVersion` 을 쓰는 모듈만 해당한다.
3. 후보 Boot 버전의 관리 버전을 `vulns.json` 의 최소 해소 버전(`minFixed`)과 비교한다.
4. 관리 버전이 해소하지 못하는 라이브러리만 직접 지정한다.
   - Boot 관리 라이브러리: `ext['<속성>.version'] = '<버전>'` (속성 이름은 `bom_versions.py` 출력 그대로)
   - Boot 비관리 라이브러리: `dependencyManagement { dependencies { dependency '<group:artifact:버전>' } }`
   - 직접 지정 버전은 해당 라이브러리의 같은 계열 최신 안정 버전으로 한다.
5. 프론트엔드는 직접 의존성이면 `package.json` 버전을, 전이 의존성이면 `resolutions` 항목을 제안한다.

### 4. 코드·설정 점검

1. `references/checklist.md` 와 `references/report-format.md` 를 읽는다.
2. 백엔드 A~C 절 점검은 서브에이전트(general-purpose)에 맡기고, 그동안 2·3·5단계 의존성 작업을 한다.
   - 서브에이전트에게 읽기 전용임을 명시한다. 파일 수정·빌드·커밋을 금지한다.
   - `references/report-format.md` 3절의 발견 사항 블록 형식으로 보고하게 한다. 각 발견 사항에 수정 방법과 수정 후 확인 방법도 함께 쓰게 한다.
   - E절 영향도 확인 질문(인증 방식, HTTP/2·AJP·WebSocket, actuator, 정적 리소스, Bouncy Castle 직접 사용, 파일 업로드, SpEL)도 함께 맡긴다.
3. 프론트엔드 D절은 직접 점검한다. `yarn.lock` 의존 경로 확인만으로 D절을 대신하지 않는다.
4. 서브에이전트 보고를 그대로 옮기지 않는다. P1·P2 판정은 해당 코드를 직접 열어 다시 확인한다.
   - 라이브러리 동작에 기대는 판정은 Gradle 캐시의 `-sources.jar` 로 확인한다. 예: `unzip -p <sources.jar> <클래스 경로>.java`
   - 서비스 간 호출(Feign 등)이 얽힌 항목은 호출하는 쪽 코드도 확인한다. 수정 방법이 호출부를 깨지 않아야 한다.
5. 발견 사항에 ID 를 붙인다. 코드는 `CODE-n`, 설정은 `CONF-n` 이다.
6. 같은 수정으로 해결되는 발견 사항을 `SEC-n` 섹션으로 묶는다. 섹션 우선순위는 포함 항목 중 가장 높은 것이다.

### 5. 수정 제안 검증

제안한 버전으로 올려도 문제가 없는지 sandbox 복사본에서 확인한다. 원본 모듈은 건드리지 않는다.

1. 제안 파일을 만든다.
   - 원본을 `_workspace/<폴더>/proposal/<모듈 폴더명>/<상대경로>` 로 복사한다. 예: `proposal/atlas-flight-auth/build.gradle`
   - 복사본에 3단계에서 정한 변경을 적용한다.
   - 프론트엔드는 `package.json` 만 바꾼다. `yarn.lock` 은 검증 스크립트가 install 로 갱신한다.
   - 프론트엔드 전이 의존성은 `proposal/atlas-flight-frontend/yarn-up.txt` 에 패키지 이름을 한 줄에 하나씩 쓴다. 검증 스크립트가 `yarn up -R` 로 올린다.
2. 테스트 실행 여부를 사용자에게 묻는다.
   - 모듈 테스트는 `@SpringBootTest` 라서 로컬 DB 에 접속하고 Flyway 마이그레이션을 실행한다.
   - 사용자가 동의하지 않으면 컴파일까지만 검증한다.
3. 검증을 실행한다. `--expect` 에는 직접 지정한 버전과 핵심 목표 버전을 넣는다.
   ```bash
   python3 .claude/skills/security-audit/scripts/verify_patch.py --work _workspace/<폴더> --expect tomcat-embed-core=<버전> spring-boot=<버전> [--with-tests]
   ```
   - 적용 전(before)과 적용 후(after) 복사본을 같은 방식으로 검증해 비교한다.
   - 결과: `verify/report.md`, `verify/proposal.diff`, `verify/logs/`
4. `verify/report.md` 의 판정을 확인한다.

   | 항목 | 통과 기준 | 실패 시 조치 |
   |---|---|---|
   | 기대 버전 해석 | 모든 `--expect` 가 ✔ | 지정 방식(`ext` 속성 이름, `dependencyManagement`)을 고친다 |
   | 신규 취약점 | 0건 | 해당 라이브러리 버전을 다시 고른다 |
   | Critical·High 잔존 | 0건, 또는 수정 버전이 없는 항목만 | 직접 지정을 추가한다 |
   | 빌드·lint 회귀 | 회귀 0건 | 로그로 원인을 찾고 버전을 낮추거나 코드 변경을 제안에 추가한다 |
   | 테스트 회귀 | 회귀 0건 | 위와 같다 |

   - "환경 문제 (적용 전도 실패)"는 회귀가 아니다. 원인(DB 미기동 등)을 결과서에 적는다.
   - 실패하면 제안 파일을 고치고 3번부터 다시 실행한다. 3회 안에 통과하지 못하면 남은 문제를 결과서에 적고 사용자에게 보고한다.
5. major·minor 로 바뀐 의존성의 호환성을 확인한다.
   - `verify/report.md` 2절에서 major·minor 변경 목록을 본다.
   - 각 항목의 릴리스 노트·업그레이드 가이드를 WebSearch 로 찾는다. 예: `Spring Boot 4.1 release notes`, `Flyway 12 breaking changes`
   - 프로젝트 코드·설정에 해당하는 변경(제거된 속성, 기본값 변경, 삭제된 API)을 검색해 영향 여부를 판정한다.
   - 컴파일이 통과해도 기본값 변경은 런타임에서만 드러난다. 해당 항목은 "런타임 확인 필요"로 결과서에 적는다.

### 6. 영향도 판단

1. `references/checklist.md` E절 표로 의존성 취약점의 실제 사용 여부를 확인한다.
2. 코드·설정 발견 사항은 공격 조건(인증 필요 여부, 외부 노출 여부)을 함께 적는다.
3. 우선순위를 다음 3단계로 매긴다.
   - **P1 즉시**: 외부에서 공격 가능하고, 심각도 Critical·High
   - **P2 다음 작업**: 공격 조건이 제한적이거나 Medium
   - **P3 정리**: 영향 낮음(미사용 기능), Low, 빌드 도구
4. P1 의존성 취약점은 `DEP-n` 상세 블록을 쓴다. 형식은 코드 발견 사항 블록과 같다.

### 7. 결과서

1. `references/report-format.md` 의 구조와 규칙으로 `result.md` 를 쓴다.
2. 다 쓴 뒤 아래 항목을 점검한다.
   - [ ] P1·P2 발견 사항마다 배경·문제·확인 근거·공격 시나리오·영향·공격 조건이 있다
   - [ ] 확인 근거에 실제 코드 발췌와 `파일:줄` 이 있다
   - [ ] SEC 섹션마다 수정 방법과 수정 후 확인 방법이 있다
   - [ ] 별도 "코드·설정 수정 제안" 절이 없다
   - [ ] 의존성 수정 제안 바로 아래에 제안 검증 결과가 있다
   - [ ] 요약의 P1·P2 건수가 본문 블록 수와 같다
   - [ ] 프론트엔드 D절 결과가 있다

### 8. 사용자 보고

`docs/answer-guide.md` 문체로 채팅에 짧게 보고한다.

1. 결론 한 줄: P1 건수와 가장 시급한 조치
2. P1 목록 (최대 5개, SEC-n·DEP-n ID 포함)
3. 권장 Boot 버전과 직접 지정 라이브러리, 제안 검증 판정
4. `result.md` 링크
5. 마지막 질문: 수정 제안 중 어떤 항목을 적용할지

## 참고

- JDK 17 경로: `collect_deps.py` 가 `JAVA17_HOME` > Homebrew `openjdk@17` > `JAVA_HOME` 순으로 고른다. Windows 에서는 `JAVA17_HOME` 을 지정한다.
- 프론트엔드 명령은 Node 22 가 필요하다: `source ~/.nvm/nvm.sh && nvm use 22`
- OSV 는 GitHub Advisory 데이터를 포함한다. 심각도는 GHSA `database_specific.severity` 값을 쓴다.
