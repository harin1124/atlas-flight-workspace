# Core Data API Endpoint Document

작성 기준: `atlas-flight-core-data` 모듈 컨트롤러/서비스 코드 기준

## 1. Endpoint Summary

| Domain | Method | Path | 설명 |
| --- | --- | --- | --- |
| 국가 코드 | GET | `/countries` | 사용 중인 국가 코드 목록 |
| 국가 코드 | GET | `/countries/{countryCd}` | 국가 코드 단건 조회 |
| 국가 코드 | POST | `/countries` | 국가 코드 등록 |
| 언어 코드 | GET | `/languages` | 사용 중인 언어 코드 목록 |
| 언어 코드 | GET | `/languages/{languageCd}` | 언어 코드 단건 조회 |
| 언어 코드 | POST | `/languages` | 언어 코드 등록 |
| 전화 국가 코드 | GET | `/phones?countryCd={countryCd}` | 국가별 전화 코드 목록 |
| 전화 국가 코드 | GET | `/phones/{countryCd}/{phoneCd}` | 전화 코드 단건 조회 |
| 전화 국가 코드 | POST | `/phones` | 전화 코드 등록 |
| 공항 코드 | GET | `/airports?countryCd={countryCd}` | 국가별 공항 코드 목록 |
| 공항 코드 | GET | `/airports/{iataCd}` | 공항 코드 단건 조회 |
| 공항 코드 | POST | `/airports` | 공항 코드 등록 |
| 공통 코드 | GET | `/common-codes?upCd={upCd}` | 상위 코드별 공통 코드 목록 |
| 공통 코드 | GET | `/common-codes/{upCd}/{cd}` | 공통 코드 단건 조회 |
| 공통 코드 | POST | `/common-codes` | 공통 코드 등록 |
| 국가-언어 매핑 | GET | `/country-languages?countryCd={countryCd}` | 국가별 국가-언어 매핑 목록 |
| 국가-언어 매핑 | GET | `/country-languages/{countryCd}/{languageCd}` | 국가-언어 매핑 단건 조회 |
| 국가-언어 매핑 | POST | `/country-languages` | 국가-언어 매핑 등록 |

## 2. 국가 코드 API

### GET `/countries`

사용 중인 국가 코드 목록을 조회합니다.

처리 조건:

| 항목 | 값 |
| --- | --- |
| 필터 | `useYn = "Y"` |
| 정렬 | `countryCd ASC` |

응답 데이터: `Country[]`

```json
{
  "resultCode": "ATF200",
  "resultMessage": "정상 처리되었습니다.",
  "resultDetailMessage": "",
  "data": [
    {
      "id": 1,
      "countryCd": "KR",
      "countryCd3": "KOR",
      "countryKorNm": "대한민국",
      "countryEngNm": "Republic of Korea",
      "nationalityKorNm": "한국",
      "nationalityEngNm": "South Korean",
      "regionCd": "AS",
      "countryLanguages": [],
      "useYn": "Y",
      "regDt": "2026-05-01T00:00:00",
      "rgtrId": "system",
      "mdfcnDt": "2026-05-01T00:00:00",
      "mdfrId": "system"
    }
  ]
}
```

### GET `/countries/{countryCd}`

국가 코드 alpha-2 기준으로 단건 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `countryCd` | Path | Y | 국가 코드 ISO 3166-1 alpha-2 | `KR` |

응답 데이터: `Country`

### POST `/countries`

국가 코드를 등록합니다.

Request body:

| Field | Type | 필수 | 제약 | 설명 | 예시 |
| --- | --- | --- | --- | --- | --- |
| `countryCd` | string | Y | length 2 | 국가 코드 ISO 3166-1 alpha-2 | `KR` |
| `countryCd3` | string | Y | length 3 | 국가 코드 ISO 3166-1 alpha-3 | `KOR` |
| `countryKorNm` | string | Y | max 100 | 국가 한국어 이름 | `대한민국` |
| `countryEngNm` | string | Y | max 100 | 국가 영어 이름 | `Republic of Korea` |
| `nationalityKorNm` | string | N | max 100 | 국적 한국어 이름 | `한국` |
| `nationalityEngNm` | string | N | max 100 | 국적 영어 이름 | `South Korean` |
| `regionCd` | string | N | max 10 | 대륙 코드 | `AS` |
| `useYn` | string | N | max 1 | 사용 여부. 미입력 시 `Y` | `Y` |

```json
{
  "countryCd": "KR",
  "countryCd3": "KOR",
  "countryKorNm": "대한민국",
  "countryEngNm": "Republic of Korea",
  "nationalityKorNm": "한국",
  "nationalityEngNm": "South Korean",
  "regionCd": "AS",
  "useYn": "Y"
}
```

중복 체크:

| Field | 조건 |
| --- | --- |
| `countryCd` | 기존 국가 코드와 중복 불가 |
| `countryCd3` | 기존 alpha-3 국가 코드와 중복 불가 |

## 3. 언어 코드 API

### GET `/languages`

사용 중인 언어 코드 목록을 조회합니다.

| 항목 | 값 |
| --- | --- |
| 필터 | `useYn = "Y"` |
| 정렬 | `languageCd ASC` |

응답 데이터: `Language[]`

### GET `/languages/{languageCd}`

언어 코드 ISO 639-1 기준으로 단건 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `languageCd` | Path | Y | 언어 코드 ISO 639-1 | `ko` |

응답 데이터: `Language`

### POST `/languages`

언어 코드를 등록합니다.

Request body:

| Field | Type | 필수 | 제약 | 설명 | 예시 |
| --- | --- | --- | --- | --- | --- |
| `languageCd` | string | Y | length 2 | 언어 코드 ISO 639-1 | `ko` |
| `languageCd3` | string | N | length 3 | 언어 코드 ISO 639-2 | `kor` |
| `languageKorNm` | string | Y | max 100 | 언어 한국어 이름 | `한국어` |
| `languageEngNm` | string | Y | max 100 | 언어 영어 이름 | `Korean` |
| `rtlYn` | string | N | max 1 | 우좌쓰기 여부. 미입력 시 `N` | `N` |
| `useYn` | string | N | max 1 | 사용 여부. 미입력 시 `Y` | `Y` |

```json
{
  "languageCd": "ko",
  "languageCd3": "kor",
  "languageKorNm": "한국어",
  "languageEngNm": "Korean",
  "rtlYn": "N",
  "useYn": "Y"
}
```

중복 체크:

| Field | 조건 |
| --- | --- |
| `languageCd` | 기존 언어 코드와 중복 불가 |
| `languageCd3` | 값이 있는 경우 기존 ISO 639-2 언어 코드와 중복 불가 |

## 4. 전화 국가 코드 API

### GET `/phones?countryCd={countryCd}`

국가별 사용 중인 전화 코드를 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `countryCd` | Query | Y | 국가 코드 alpha-2 | `KR` |

처리 조건:

| 항목 | 값 |
| --- | --- |
| 필터 | `countryCd = 요청값`, `useYn = "Y"` |
| 정렬 | `sortOrder ASC` |

응답 데이터: `Phone[]`

### GET `/phones/{countryCd}/{phoneCd}`

전화 코드를 단건 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `countryCd` | Path | Y | 국가 코드 alpha-2 | `KR` |
| `phoneCd` | Path | Y | 전화 코드. `+` 제외 숫자 | `82` |

응답 데이터: `Phone`

### POST `/phones`

전화 국가 코드를 등록합니다.

Request body:

| Field | Type | 필수 | 제약 | 설명 | 예시 |
| --- | --- | --- | --- | --- | --- |
| `countryCd` | string | Y | length 2 | 국가 코드 alpha-2 | `KR` |
| `phoneCd` | string | Y | max 10 | 전화 코드. E.164, `+` 제외 숫자 | `82` |
| `useYn` | string | N | max 1 | 사용 여부. 미입력 시 `Y` | `Y` |
| `sortOrder` | number | N | int | 정렬 순서. 미입력 시 Java int 기본값 `0` | `1` |

```json
{
  "countryCd": "KR",
  "phoneCd": "82",
  "useYn": "Y",
  "sortOrder": 1
}
```

중복 체크: `countryCd + phoneCd` 조합 중복 불가

## 5. 공항 코드 API

### GET `/airports?countryCd={countryCd}`

국가별 사용 중인 공항 코드를 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `countryCd` | Query | Y | 국가 코드 alpha-2 | `KR` |

처리 조건:

| 항목 | 값 |
| --- | --- |
| 필터 | `country.countryCd = 요청값`, `useYn = "Y"` |
| 정렬 | `iataCd ASC` |

응답 데이터: `Airport[]`

응답 참고:

| Field | 비고 |
| --- | --- |
| `country` | `Country` 객체로 포함될 수 있음 |
| `countryCd` | 엔티티 getter로 계산되어 포함될 수 있음 |
| `airportTypeCd` | `airportType.id.cd`에서 계산 |
| `airportStatCd` | `airportStat.id.cd`에서 계산 |
| `airportType`, `airportStat` | `@JsonIgnoreProperties`로 응답에서 제외 |

### GET `/airports/{iataCd}`

IATA 코드 기준으로 공항을 단건 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `iataCd` | Path | Y | IATA 코드 | `ICN` |

응답 데이터: `Airport`

### POST `/airports`

공항 코드를 등록합니다.

Request body:

| Field | Type | 필수 | 제약 | 설명 | 예시 |
| --- | --- | --- | --- | --- | --- |
| `iataCd` | string | Y | length 3 | IATA 코드 | `ICN` |
| `icaoCd` | string | N | length 4 | ICAO 코드 | `RKSI` |
| `airportKorNm` | string | Y | max 100 | 공항 한국어 이름 | `인천국제공항` |
| `airportEngNm` | string | Y | max 100 | 공항 영어 이름 | `Incheon International Airport` |
| `airportNatNm` | string | N | max 100 | 공항 현지어 이름 |  |
| `countryCd` | string | Y | length 2 | 국가 코드 alpha-2 | `KR` |
| `cityCd` | string | N | max 10 | 도시 코드 | `SEL` |
| `latitude` | number | N | decimal | 위도 WGS84 | `37.469075` |
| `longitude` | number | N | decimal | 경도 WGS84 | `126.450517` |
| `timezone` | string | N | max 50 | IANA 타임존 | `Asia/Seoul` |
| `airportTypeCd` | string | Y | max 10 | 공항 유형 코드. `COMMON_CODE`의 `UP_CD=AIRPORT_TYPE` | `I` |
| `airportStatCd` | string | Y | max 10 | 공항 상태 코드. `COMMON_CODE`의 `UP_CD=AIRPORT_STAT` | `OP` |
| `useYn` | string | N | max 1 | 사용 여부. 미입력 시 `Y` | `Y` |

```json
{
  "iataCd": "ICN",
  "icaoCd": "RKSI",
  "airportKorNm": "인천국제공항",
  "airportEngNm": "Incheon International Airport",
  "airportNatNm": null,
  "countryCd": "KR",
  "cityCd": "SEL",
  "latitude": 37.469075,
  "longitude": 126.450517,
  "timezone": "Asia/Seoul",
  "airportTypeCd": "I",
  "airportStatCd": "OP",
  "useYn": "Y"
}
```

중복/참조 체크:

| 항목 | 조건 |
| --- | --- |
| `iataCd` | 기존 IATA 코드와 중복 불가 |
| `icaoCd` | 값이 있는 경우 기존 ICAO 코드와 중복 불가 |
| `countryCd` | 기존 국가 코드가 있어야 함 |
| `airportTypeCd` | `UP_CD=AIRPORT_TYPE` 공통 코드가 있어야 함 |
| `airportStatCd` | `UP_CD=AIRPORT_STAT` 공통 코드가 있어야 함 |

## 6. 공통 코드 API

### GET `/common-codes?upCd={upCd}`

상위 코드별 사용 중이고 미삭제 상태인 공통 코드 목록을 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `upCd` | Query | Y | 상위 코드 | `REGION` |

처리 조건:

| 항목 | 값 |
| --- | --- |
| 필터 | `id.upCd = 요청값`, `useYn = "Y"`, `delYn = "N"` |
| 정렬 | `sortOrder ASC` |

응답 데이터: `CommonCode[]`

응답 예시:

```json
{
  "resultCode": "ATF200",
  "resultMessage": "정상 처리되었습니다.",
  "resultDetailMessage": "",
  "data": [
    {
      "id": {
        "upCd": "REGION",
        "cd": "AS"
      },
      "cdKorNm": "아시아",
      "cdEngNm": "Asia",
      "description": null,
      "sortOrder": 1,
      "useYn": "Y",
      "delYn": "N",
      "regDt": "2026-05-01T00:00:00",
      "rgtrId": "system",
      "mdfcnDt": "2026-05-01T00:00:00",
      "mdfrId": "system"
    }
  ]
}
```

### GET `/common-codes/{upCd}/{cd}`

공통 코드를 단건 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `upCd` | Path | Y | 상위 코드 | `REGION` |
| `cd` | Path | Y | 코드 | `AS` |

응답 데이터: `CommonCode`

### POST `/common-codes`

공통 코드를 등록합니다.

Request body:

| Field | Type | 필수 | 제약 | 설명 | 예시 |
| --- | --- | --- | --- | --- | --- |
| `upCd` | string | Y | min 1, max 10 | 상위 코드 | `REGION` |
| `cd` | string | Y | min 1, max 10 | 코드 | `AS` |
| `cdKorNm` | string | Y | min 1, max 50 | 코드 한국어 이름 | `아시아` |
| `cdEngNm` | string | N | max 100 | 코드 영문 이름 | `Asia` |
| `description` | string | N | max 300 | 설명 |  |
| `sortOrder` | number | Y | int | 정렬 순서 | `1` |
| `useYn` | string | N | max 1 | 사용 여부. 미입력 시 `Y` | `Y` |

```json
{
  "upCd": "REGION",
  "cd": "AS",
  "cdKorNm": "아시아",
  "cdEngNm": "Asia",
  "description": null,
  "sortOrder": 1,
  "useYn": "Y"
}
```

기본값:

| Field | 기본값 |
| --- | --- |
| `useYn` | `Y` |
| `delYn` | `N` |

중복 체크: `upCd + cd` 조합 중복 불가

## 7. 국가-언어 매핑 API

### GET `/country-languages?countryCd={countryCd}`

국가별 미삭제 국가-언어 매핑 목록을 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `countryCd` | Query | Y | 국가 코드 alpha-2 | `KR` |

처리 조건:

| 항목 | 값 |
| --- | --- |
| 필터 | `countryCd = 요청값`, `delYn = "N"` |
| 정렬 | `sortOrder ASC` |

응답 데이터: `CountryLanguage[]`

### GET `/country-languages/{countryCd}/{languageCd}`

국가-언어 매핑을 단건 조회합니다.

| Parameter | 위치 | 필수 | 설명 | 예시 |
| --- | --- | --- | --- | --- |
| `countryCd` | Path | Y | 국가 코드 alpha-2 | `KR` |
| `languageCd` | Path | Y | 언어 코드 ISO 639-1 | `ko` |

응답 데이터: `CountryLanguage`

### POST `/country-languages`

국가-언어 매핑을 등록합니다.

Request body:

| Field | Type | 필수 | 제약 | 설명 | 예시 |
| --- | --- | --- | --- | --- | --- |
| `countryCd` | string | Y | length 2 | 국가 코드 alpha-2 | `KR` |
| `languageCd` | string | Y | length 2 | 언어 코드 ISO 639-1 | `ko` |
| `officialYn` | string | N | max 1 | 공식어 여부. 미입력 시 `N` | `Y` |
| `primaryYn` | string | N | max 1 | 주요 언어 여부. 미입력 시 `N` | `Y` |
| `sortOrder` | number | N | int | 정렬 순서. 미입력 시 Java int 기본값 `0` | `1` |
| `delYn` | string | N | max 1 | 삭제 여부. 미입력 시 `N` | `N` |

```json
{
  "countryCd": "KR",
  "languageCd": "ko",
  "officialYn": "Y",
  "primaryYn": "Y",
  "sortOrder": 1,
  "delYn": "N"
}
```

중복 체크: `countryCd + languageCd` 조합 중복 불가

## 8. 응답 모델 요약

조회 API는 별도 Response DTO가 아니라 JPA Entity를 그대로 반환합니다.

### Country

| Field | Type | 설명 |
| --- | --- | --- |
| `id` | number | 내부 PK |
| `countryCd` | string | ISO 3166-1 alpha-2 |
| `countryCd3` | string | ISO 3166-1 alpha-3 |
| `countryKorNm` | string | 국가 한국어 이름 |
| `countryEngNm` | string | 국가 영어 이름 |
| `nationalityKorNm` | string | 국적 한국어 이름 |
| `nationalityEngNm` | string | 국적 영어 이름 |
| `regionCd` | string | 대륙 코드 |
| `countryLanguages` | array | 국가-언어 매핑 목록 |
| `useYn` | string | 사용 여부 |
| `regDt` | string | 등록 일시 |
| `rgtrId` | string | 등록자 ID |
| `mdfcnDt` | string | 수정 일시 |
| `mdfrId` | string | 수정자 ID |

### Language

| Field | Type | 설명 |
| --- | --- | --- |
| `id` | number | 내부 PK |
| `languageCd` | string | ISO 639-1 |
| `languageCd3` | string | ISO 639-2 |
| `languageKorNm` | string | 언어 한국어 이름 |
| `languageEngNm` | string | 언어 영어 이름 |
| `rtlYn` | string | 우좌쓰기 여부 |
| `useYn` | string | 사용 여부 |
| `regDt` | string | 등록 일시 |
| `rgtrId` | string | 등록자 ID |
| `mdfcnDt` | string | 수정 일시 |
| `mdfrId` | string | 수정자 ID |

### Phone

| Field | Type | 설명 |
| --- | --- | --- |
| `id` | number | 내부 PK |
| `countryCd` | string | 국가 코드 alpha-2 |
| `phoneCd` | string | 전화 코드 |
| `useYn` | string | 사용 여부 |
| `sortOrder` | number | 정렬 순서 |
| `regDt` | string | 등록 일시 |
| `rgtrId` | string | 등록자 ID |
| `mdfcnDt` | string | 수정 일시 |
| `mdfrId` | string | 수정자 ID |

### Airport

| Field | Type | 설명 |
| --- | --- | --- |
| `id` | number | 내부 PK |
| `iataCd` | string | IATA 코드 |
| `icaoCd` | string | ICAO 코드 |
| `airportKorNm` | string | 공항 한국어 이름 |
| `airportEngNm` | string | 공항 영어 이름 |
| `airportNatNm` | string | 공항 현지어 이름 |
| `country` | object | 국가 객체 |
| `countryCd` | string | 계산 필드 |
| `cityCd` | string | 도시 코드 |
| `latitude` | number | 위도 |
| `longitude` | number | 경도 |
| `timezone` | string | IANA 타임존 |
| `airportTypeCd` | string | 계산 필드 |
| `airportStatCd` | string | 계산 필드 |
| `useYn` | string | 사용 여부 |
| `regDt` | string | 등록 일시 |
| `rgtrId` | string | 등록자 ID |
| `mdfcnDt` | string | 수정 일시 |
| `mdfrId` | string | 수정자 ID |

### CommonCode

| Field | Type | 설명 |
| --- | --- | --- |
| `id.upCd` | string | 상위 코드 |
| `id.cd` | string | 코드 |
| `cdKorNm` | string | 코드 한국어 이름 |
| `cdEngNm` | string | 코드 영문 이름 |
| `description` | string | 설명 |
| `sortOrder` | number | 정렬 순서 |
| `useYn` | string | 사용 여부 |
| `delYn` | string | 삭제 여부 |
| `regDt` | string | 등록 일시 |
| `rgtrId` | string | 등록자 ID |
| `mdfcnDt` | string | 수정 일시 |
| `mdfrId` | string | 수정자 ID |

### CountryLanguage

| Field | Type | 설명 |
| --- | --- | --- |
| `id` | number | 내부 PK |
| `countryCd` | string | 국가 코드 alpha-2 |
| `languageCd` | string | 언어 코드 ISO 639-1 |
| `officialYn` | string | 공식어 여부 |
| `primaryYn` | string | 주요 언어 여부 |
| `sortOrder` | number | 정렬 순서 |
| `delYn` | string | 삭제 여부 |
| `regDt` | string | 등록 일시 |
| `rgtrId` | string | 등록자 ID |
| `mdfcnDt` | string | 수정 일시 |
| `mdfrId` | string | 수정자 ID |

## 9. 참고 사항

| 항목 | 내용 |
| --- | --- |
| 인증/인가 | core-data 모듈 코드상 별도 SecurityConfig가 확인되지 않았습니다. Gateway 또는 상위 계층 정책은 별도 확인 필요합니다. |
| Swagger | 각 컨트롤러에 `@Tag`, `@Operation`, 요청 DTO에 `@Schema`가 선언되어 있습니다. |
| 등록자/수정자 | JPA Auditing으로 자동 입력됩니다. 현재 `AuditorProvider` 기본값은 `SYSTEM`입니다. |
| Update/Delete API | 현재 core-data 컨트롤러에는 수정/삭제 엔드포인트가 없습니다. |
