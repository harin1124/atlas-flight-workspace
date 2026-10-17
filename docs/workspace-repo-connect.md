# 워크스페이스 레포 연결

`atlas-flight/` 폴더 아래에 모듈(`atlas-flight-*`)을 clone 해서 쓰던 사람이 `atlas-flight/` 폴더 자체를 워크스페이스 레포에 연결하는 방법이다.

```
atlas-flight/              ← 여기에 워크스페이스 레포를 연결한다
  atlas-flight-auth/       ← 기존 모듈 (그대로 둔다)
  atlas-flight-core-lib/
  ...
```

- 워크스페이스 레포: `https://github.com/harin1124/atlas-flight-workspace.git`
- 워크스페이스 레포는 모듈 폴더를 추적하지 않는다 (`.gitignore` 에 `/atlas-flight-*/`).
- 모듈 폴더는 옮기거나 바꾸지 않는다.

---

## 1. 원격 연결

`atlas-flight/` 폴더에서 실행한다.

```bash
git init -b main
git remote add origin https://github.com/harin1124/atlas-flight-workspace.git
git fetch origin
```

> Windows 는 Git Bash 에서 실행하고, `git fetch` 전에 `git config core.autocrlf false` 를 먼저 실행한다.
> `.sh` 파일이 CRLF 로 바뀌면 실행되지 않는다.

## 2. 겹치는 파일 확인

워크스페이스 레포에 있는 파일이 폴더에 이미 있으면 다음 단계가 실패한다.

```bash
git ls-tree -r --name-only origin/main | while read -r f; do [ -e "$f" ] && echo "$f"; done
```

출력된 파일이 있으면 폴더 밖으로 옮긴다. 출력이 없으면 3단계로 간다.

```bash
mkdir -p ~/atlas-flight-backup
mv CLAUDE.md ~/atlas-flight-backup/   # 출력된 파일마다 실행
```

## 3. 워크스페이스 레포 받기

```bash
git checkout -t origin/main
```

## 4. 확인

```bash
git status
```

`Your branch is up to date with 'origin/main'` 이 나오면 완료다.
모듈 폴더가 목록에 나오지 않아야 한다.

---

## 되돌리기

`atlas-flight/` 폴더에서 `.git` 만 지운다.

```bash
rm -rf .git
```

> 모듈 폴더 안에서 실행하면 그 모듈의 git 이력이 지워진다. 반드시 `atlas-flight/` 폴더에서 실행한다.
