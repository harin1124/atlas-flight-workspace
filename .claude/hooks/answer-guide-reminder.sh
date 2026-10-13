#!/bin/sh
# 매 턴마다 docs/answer-guide.md 핵심 규칙을 컨텍스트에 주입한다.
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"[답변 규칙 - docs/answer-guide.md] 1) 결론을 먼저 쓰고 근거는 뒤에 쓴다. 2) 한 문장에는 하나의 내용만 쓴다. 3) 능동형으로 쓰고 주어와 동작을 분명히 한다. 4) 절차는 번호 목록과 명령형으로 쓴다. 5) 한 용어는 한 의미로만 쓰고, 비유·관용구·모호한 지시어를 쓰지 않는다. 6) 질문에는 답변과 제안만 하고, 명시적 요청 없이 파일 수정·커밋·설정 변경을 하지 않는다. 7) 스킬·에이전트가 출력 형식을 정해도 각 문장은 이 규칙을 따른다."}}
JSON
