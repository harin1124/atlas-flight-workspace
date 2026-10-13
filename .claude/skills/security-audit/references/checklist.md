# 코드·설정 점검표

각 항목은 "확인 방법"으로 위치를 찾고, "판정 기준"으로 판단한다.
검색 결과가 0건이어도 점검 대상 파일을 직접 읽어 확인한다. 검색어는 출발점일 뿐이다.
모든 검색은 대상 모듈의 `src/main` 만 본다. 테스트 코드는 제외한다.

## A. 인증·인가

### A1. 게이트웨이 공개 경로
- 확인 방법: `atlas-flight-gateway` 의 `gateway.auth.public-paths` 설정과 `JwtAuthFilter`
- 판정 기준
  - 공개 경로는 로그인 전에 꼭 필요한 API 만 포함한다 (가입·로그인·로그아웃·아이디 중복 확인)
  - `/**` 같은 넓은 패턴이 없어야 한다
  - 메서드 없이 경로만 적은 항목은 모든 메서드를 공개한다. 의도한 것인지 확인한다

### A2. `X-User-Id` 헤더 위조
- 확인 방법: `JwtAuthFilter` 가 헤더를 설정하는 코드, 서비스의 `CurrentUserArgumentResolver`
- 판정 기준
  - 게이트웨이는 클라이언트가 보낸 `X-User-Id` 를 제거하거나 덮어써야 한다
  - 공개 경로로 통과한 요청에도 클라이언트의 `X-User-Id` 가 그대로 전달되면 위조 가능
  - 서비스 포트(8086 등)에 게이트웨이를 거치지 않고 접근할 수 있으면 헤더 위조가 가능하다. 배포 구성에서 차단되는지 후속 확인 항목으로 남긴다

### A3. JWT 발급·검증
- 확인 방법: `grep -rn "Jwts\.\|signWith\|parseSignedClaims\|verifyWith" --include='*.java'`
- 판정 기준
  - 서명 키는 설정값(`${JWT_SECRET}`)에서 읽고, HS256 기준 32바이트 이상이어야 한다
  - 검증 시 서명·만료를 모두 확인한다. `parseUnsecuredClaims` 같은 무서명 파싱이 없어야 한다
  - 액세스 토큰 만료 시간이 과도하게 길지 않아야 한다 (기준: 1시간 이하 권장)
  - auth 와 gateway 가 같은 키·알고리즘을 쓰는지 확인한다

### A4. 비밀번호 저장
- 확인 방법: `grep -rn "MessageDigest\|PasswordEncoder\|BCrypt\|Argon2" --include='*.java'`
- 판정 기준
  - 비밀번호는 `BCryptPasswordEncoder`·`Argon2PasswordEncoder` 같은 느린 해시로 저장한다
  - `MessageDigest`(SHA-256, MD5 등) 단일 해시는 취약으로 판정한다. 솔트 유무와 무관하다
  - 비교는 상수 시간 비교(`MessageDigest.isEqual`, `PasswordEncoder.matches`)를 쓴다

### A5. 서비스 인가
- 확인 방법: 컨트롤러의 `@CurrentUser` 사용처, 경로 변수로 받은 사용자 ID
- 판정 기준
  - 다른 사용자의 데이터를 조회·수정하는 API 는 경로 변수 대신 `@CurrentUser` 값으로 소유자를 확인한다
  - `/{customerId}` 같은 경로 변수를 그대로 신뢰하면 IDOR 로 판정한다

## B. 입력 처리

### B1. SQL injection
- 확인 방법: `grep -rnE "nativeQuery|JdbcTemplate|createQuery|createNativeQuery|\\$\\{" --include='*.java' --include='*.xml'`
- 판정 기준
  - 쿼리 문자열에 사용자 입력을 `+` 나 `String.format` 으로 붙이면 취약
  - 파라미터 바인딩(`:name`, `?`)만 쓰면 안전
  - 정렬 컬럼·방향을 입력으로 받으면 허용 목록 검증이 있어야 한다

### B2. 요청 검증
- 확인 방법: `@RequestBody` 사용처
- 판정 기준
  - `@RequestBody` 에는 `@Valid` 또는 `@Validated` 가 붙어야 한다
  - DTO 필드에 길이·형식 제약(`@Size`, `@Pattern`, `@Email` 등)이 있어야 한다

### B3. 예외 응답 노출
- 확인 방법: `@RestControllerAdvice` 클래스 (core-lib 공통 예외 처리 포함)
- 판정 기준
  - 응답에 스택 트레이스, 예외 클래스명, SQL 메시지를 담지 않는다
  - `e.getMessage()` 를 그대로 응답에 넣는 경우 내부 정보 노출 여부를 확인한다

## C. 설정·비밀값

### C1. 하드코딩 비밀값
- 확인 방법
  - `grep -rnE "(password|secret|key|token)\s*[:=]" --include='*.yaml' --include='*.yml' --include='*.properties' src/main/resources`
  - `git ls-files | grep -E "\.env$|\.pem$|\.key$|\.p12$|\.jks$"`
  - `grep -rnE "(password|secret)\s*=\s*\"[^\"]+\"" --include='*.java'`
- 판정 기준
  - 비밀값은 `${...}` 자리표시자로 `~/.config/atlas-flight/.env` 에서 읽어야 한다
  - 기본값이 붙은 자리표시자(`${JWT_SECRET:abc123}`)도 하드코딩으로 판정한다
  - 비밀값 파일이 git 에 추적되면 취약으로 판정한다

### C2. CORS
- 확인 방법: `grep -rnE "allowedOrigin|CorsConfiguration|@CrossOrigin" --include='*.java'`, gateway yaml 의 cors 설정
- 판정 기준
  - `allowedOriginPatterns("*")` 와 `allowCredentials(true)` 를 함께 쓰면 취약
  - 허용 출처는 프론트엔드 주소 목록으로 제한한다
  - CORS 는 gateway 한 곳에서만 처리하는지 확인한다. 서비스마다 다르면 불일치로 기록한다

### C3. 쿠키
- 확인 방법: `grep -rnE "new Cookie|ResponseCookie|setHttpOnly|setSecure|SameSite" --include='*.java'`
- 판정 기준
  - 토큰 쿠키는 `HttpOnly`, `Secure`, `SameSite` 를 모두 설정한다
  - 로컬 개발 때문에 `Secure` 를 끈다면 프로파일별로 분리되어 있어야 한다

### C4. 운영 위험 설정
- 확인 방법: 각 모듈 `application*.yaml`
- 판정 기준 (해당하면 기록)
  - `spring.jpa.hibernate.ddl-auto` 가 `update`·`create`·`create-drop`
  - `spring.jpa.show-sql: true`, 보안 패키지 로그 레벨 `DEBUG`·`TRACE`
  - springdoc·Swagger UI 가 프로파일 구분 없이 열려 있음
  - actuator 엔드포인트를 `*` 로 노출
  - `server.error.include-stacktrace`·`include-message` 가 `always`

### C5. 로그 내 민감정보
- 확인 방법: `grep -rnE "log\.(info|debug|warn|error)\(.*(password|token|secret|jwt)" -i --include='*.java'`
- 판정 기준
  - 비밀번호·토큰·비밀값을 로그에 남기면 취약

## D. 프론트엔드

### D1. 토큰 저장 위치
- 확인 방법: `grep -rn "localStorage\|sessionStorage" src`
- 판정 기준
  - 액세스·리프레시 토큰을 `localStorage`·`sessionStorage` 에 저장하면 취약 (XSS 시 탈취)
  - 표시용 정보(이름, 아이디)만 저장하면 허용. 저장 항목을 목록으로 기록한다

### D2. XSS
- 확인 방법: `grep -rnE "dangerouslySetInnerHTML|innerHTML|eval\(|new Function\(" src`
- 판정 기준
  - 사용자 입력이나 API 응답을 HTML 로 그대로 삽입하면 취약

### D3. 번들 노출 비밀값
- 확인 방법: `grep -rn "VITE_" src .env* 2>/dev/null`
- 판정 기준
  - `VITE_` 변수는 번들에 포함된다. API 키·비밀값을 담으면 취약

## E. 영향도 판단 기준 (의존성 취약점)

취약점의 영향 기능을 프로젝트가 쓰는지 확인하고 우선순위를 정한다.

| 취약점 유형 | 사용 여부 확인 방법 | 미사용 시 |
|---|---|---|
| Tomcat FORM·Digest·Basic 인증 | `formLogin`, `httpBasic`, `DigestAuthenticationFilter` 검색 | 우선순위 낮춤 |
| Tomcat HTTP/2·AJP·WebSocket | `server.http2.enabled`, AJP 커넥터, `@ServerEndpoint` 검색 | 우선순위 낮춤 |
| Spring Boot Actuator | `spring-boot-starter-actuator` 의존성 | 우선순위 낮춤 |
| Spring MVC 정적 리소스 | `addResourceHandlers`, `static/` 폴더 | 우선순위 낮춤 |
| Jackson 파싱 DoS | 외부 JSON 을 받는 API 존재 여부 (대부분 해당) | 유지 |
| Bouncy Castle 인증서·ASN.1 | 직접 사용 여부. 전이 의존성뿐이면 호출 경로 확인 | 우선순위 낮춤 |
| 프론트엔드 빌드 도구(vite, tar, postcss 등) | `yarn why <패키지>` 로 devDependency 여부 확인 | 런타임 영향 없음으로 표시 |

- 우선순위를 낮춰도 목록에서 빼지 않는다. "영향 낮음"과 근거를 함께 기록한다.
- 판단 근거가 불확실하면 "영향 있음"으로 둔다.
