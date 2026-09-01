---
name: table-design-artifact
description: DB 테이블/스키마 설계를 ERD·예시 데이터 아티팩트로 시각화할 때 사용한다. atlas-flight 표준 포맷(라이트 모드, IBM Plex, 직접 그린 ERD, 한글 컬럼명 그리드 테이블)을 적용해 HTML 아티팩트로 발행한다. "테이블 설계", "스키마 ERD", "DDL 시각화", "예시 데이터 보여줘" 같은 요청에서 트리거된다.
---

# 테이블 설계 아티팩트 표준 포맷

DB 스키마/테이블 설계를 사람이 검토·공유하기 좋은 **HTML 아티팩트**로 만든다. 아래 규격을 지켜 일관성을 유지한다. 완성 후 반드시 `Artifact` 도구로 발행하고 URL을 전달한다.

> 작성 전 `artifact-design`(및 다이어그램이 있으면 `artifact-diagramming`) 스킬을 먼저 로드한다. 아래 규격은 그 위에 얹는 이 프로젝트 전용 고정 규칙이다.

## 0. 원천 자료

- 대상 테이블의 실제 DDL(`_workspace/.../V1__*.sql` 등)과 각 컬럼 `COMMENT`를 근거로 삼는다. 값을 지어내지 말 것.
- 테이블·컬럼 명명은 `atlas-flight-core-lib/docs/db-convention.md`의 약어·접미사 규칙을 따른다.
- 예시 데이터는 항상 "설명용 예시"임을 페이지에 명시한다.

## 1. 페이지 구조 (섹션 순서 고정)

1. **헤더** — eyebrow(도메인) + 제목 + 1~2줄 설명 + 태그 pill
2. **① 관계도** — 도메인 핵심 관계를 직접 그린 SVG(개념 흐름: 소유 경계, 분리 설계, 승격/참조 등)
3. **② ERD** — 엔티티 카드 기반 상세 ERD
4. **③ 예시 데이터** — 시나리오 1건을 테이블 흐름으로
5. **④ INSERT 예시** — 핵심 경로 SQL (선택)

## 2. 디자인 토큰 (라이트 모드 기준 · 단일 테마)

다크 블록 없이 라이트 팔레트 하나로 고정한다. `body`에 명시적 배경을 준다.

```css
:root{
  --bg:#eaeff4; --surface:#ffffff; --surface-2:#f4f8fb;
  --ink:#14202b; --ink-2:#4a5b6b;
  --border:#dbe3ec; --border-strong:#c2ccd8;
  --formal:#1f6091; --formal-soft:#e4eef6;   /* 정식/주요 엔티티 */
  --draft:#a96c0c; --draft-soft:#f7edda;     /* 임시/보조 엔티티 */
  --good:#2f7d52; --good-soft:#e0f0e7;       /* 확정/정상 상태 */
  --th:#eef3f8; --th-ink:#33475a; --zebra:#f7fafc; --row-hover:#eaf1f8;
}
```

- 폰트: 본문·제목 `IBM Plex Sans`, 식별자·코드·컬럼명 `IBM Plex Mono` (Google Fonts `<link>`로 로드, 폴백 스택 명시).
- 성격이 다른 두 부류는 색으로 구분: 주요/정식 = `--formal`(파랑), 임시/보조 = `--draft`(호박).

## 3. ERD 규격 (직접 그린 inline SVG)

- **엔티티 = 카드**: 둥근 사각형. 헤더에 **테이블명(모노, `--formal`) + 그 아래 테이블 한글명**(DDL 테이블 `COMMENT`의 이름 부분, 예: `예약_여정`) + 얇은 구분선. 이어서 컬럼 목록.
- **컬럼 = 2줄**: 영문 컬럼명(모노, `--ink`) + 그 아래 **한글 컬럼명**(sans, ~9.5px, `--ink-2`). 한글은 `COMMENT`의 **이름 부분만**(`— 설명…` 제외).
  - 카드 폭 ~250, 행 높이 ~30(2줄), 좌측 패딩 일정. 여백을 넉넉히 둬 의도적으로 보이게 한다.
  - ERD엔 **핵심 컬럼만**(PK + FK + 대표 1~2개) 추려 4~5행. 전체 컬럼은 예시 데이터 테이블(4절)이 담당.
- **키 배지**: `PK`=채운 배지(`--formal`, 흰 글자), `FK`/`UK`=외곽선 배지(`--ink-2`). 우측 정렬, 영문명 줄에 맞춤.
- **허브 강조**: 중심 테이블은 `--formal-soft` 배경 + 두꺼운 테두리.
- **관계선 = 까마귀발**: 부모 쪽 단일 막대(1), 자식 쪽 세 갈래(N).
  - **자식 쪽 세 갈래는 카드 가장자리에 "맞물리게" — 절대 카드 안쪽을 침범하지 않는다.** many 마커는 apex(뾰족점)를 선 쪽에, 세 갈래 끝을 `refX`로 카드 모서리에 놓아 갈래가 여백에 머물게 한다. `markerUnits="userSpaceOnUse"`로 크기 고정. 예:
    ```html
    <marker id="many" markerUnits="userSpaceOnUse" markerWidth="15" markerHeight="15"
      refX="13" refY="7.5" orient="auto">
      <path d="M1,7.5 L13,2 M1,7.5 L13,7.5 M1,7.5 L13,13"
        style="stroke:var(--formal);fill:none" stroke-width="1.6" stroke-linecap="round"/>
    </marker>
    ```
  - 관계선 그룹은 **카드보다 먼저** 그려 카드가 위에 오게(선 끝이 카드에 깔끔히 물림). 직교 라우팅, 교차 최소화(불가피한 교차는 서로 다른 x 채널로 분리).
- **타 서비스 참조**: 물리 FK 없음 → **점선 고스트 노드 + 점선 화살표**로 표기하고, 화살표에 동작 라벨(예: `조회·계산·적재`).
- **분리 설계**: 애그리거트에 속하지 않는 임시 테이블은 점선 구분선 아래 `--draft` 점선 카드로 관계선 없이 배치.
- 범례(legend)로 `PK / FK·UK / 1:N / 정의 참조 / 임시(분리)` 표기. `role="img"` + `aria-label` 필수.

## 4. 예시 데이터 테이블 규격

- **완전한 그리드**: 가로·세로 구분선 모두. `th,td`에 `border-right`(마지막 열 제외) + `border-bottom`.
- **헤더 2줄**: 영문 컬럼명(모노) + 그 아래 **한글 컬럼명**.
  - 한글명은 DDL `COMMENT`의 **이름 부분만** 쓴다 — `— 설명…` 뒤는 제외.
  - 예: `COMMENT '예약_상태_코드 — CREATED/HELD/...'` → 헤더엔 `BKNG_STTS_CD` / `예약_상태_코드`.

    ```html
    <th>BKNG_STTS_CD<small>예약_상태_코드</small></th>
    ```
    ```css
    thead th small{display:block;margin-top:3px;font-family:"IBM Plex Sans",sans-serif;
      font-weight:400;font-size:10.5px;color:var(--ink-2)}
    ```
- **각 테이블 = 카드(step)**: 상단에 테이블명 + 단계 설명 + `N rows` 칩. 정식=파랑 밑줄, 임시=호박 밑줄.
- 코드/유형/상태 값은 **pill**(색: 상태=`good`, 유형=`formal`, 게스트/비회원=`draft`). 숫자는 우측 정렬 + `tabular-nums`. `NULL`은 흐린 이탤릭.
- 넓은 표는 `overflow-x:auto` 컨테이너로 감싼다(본문 가로 스크롤 금지).
- 값은 축약 표기 가능(`ITN...A001O`), 감사 컬럼(REG_DT/RGTR_ID/…)은 생략 가능하되 그 사실을 각주로 남긴다. 합계·롤업 값은 자식 행 합과 일치시킨다.

## 5. 발행

- `Artifact` 도구로 발행하고 URL을 사용자에게 전달한다. 수정 시 같은 `file_path`(또는 `url`)로 **같은 링크 갱신**.
- 로컬 검증이 필요하면 프로젝트 폴더 안에 임시 복사본을 두고 미리보기한 뒤 삭제한다(스크래치패드 `file://`은 정적 스냅샷이라 렌더 확인이 안 될 수 있음).
- `<title>`은 짧은 고유 명사구, favicon은 이모지 1개.

## 참고

이 포맷의 기준 구현: booking 도메인 "예약 스키마 지도" 아티팩트 (관계도 + ERD + 예시 데이터 + INSERT). 새 도메인도 동일 골격을 재사용한다.
