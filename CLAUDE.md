@docs/workspace-convention.md
@docs/commit-convention.md
@docs/answer-guide.md

## 규칙
- 중간 산출물(작업 계획서, 수행 결과서 등)은 `_workspace/`에 둔다 — 상세 규칙은 위 workspace-convention.md 참고.
- 에이전트는 `.claude/agents/`, 스킬은 `.claude/skills/`에 정의한다.
- 커밋 메시지는 메타 레포·하위 모듈 모두 commit-convention.md 를 따른다 (제목·본문 명사형).
- 답변은 answer-guide.md 를 따른다 (결론 먼저, 한 문장 한 내용, 질문에는 변경 작업 금지). 스킬·에이전트가 출력 형식을 정해도 문체 규칙은 적용한다.
