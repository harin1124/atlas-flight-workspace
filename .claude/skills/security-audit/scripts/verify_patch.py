#!/usr/bin/env python3
"""수정 제안을 sandbox 복사본에 적용해 문제가 없는지 검증한다. 원본 모듈은 건드리지 않는다.

준비:
  <작업폴더>/proposal/<모듈 폴더명>/<상대경로>  — 제안을 반영한 파일 (원본을 복사해 수정한 것)
  예: proposal/atlas-flight-auth/build.gradle, proposal/atlas-flight-frontend/package.json
  프론트엔드 전이 의존성은 proposal/atlas-flight-frontend/yarn-up.txt 에 패키지 이름을 한 줄에 하나씩 쓴다.
  적용 후 복사본에서 `yarn up -R <패키지>` 로 기존 범위 안 최신 버전으로 올린다.

사용법:
  python3 verify_patch.py --work <작업폴더> [--expect 아티팩트=버전 ...] [--with-tests] [--keep-sandbox]

  --expect        적용 후 반드시 해석되어야 하는 버전. 아티팩트 이름 또는 group:artifact (예: tomcat-embed-core=11.0.27)
  --with-tests    백엔드 test 태스크까지 실행한다. @SpringBootTest 가 로컬 DB 에 접속하고 Flyway 마이그레이션을
                  실행하므로 사용자 확인 후에만 켠다
  --keep-sandbox  검증 후 sandbox 복사본을 지우지 않는다

검증 항목 (적용 전 = before, 적용 후 = after, 둘 다 sandbox 에서 같은 방식으로 실행):
  1. 기대 버전 해석 여부
  2. 의존성 변경 목록, major·minor 변경 표시 (릴리스 노트 확인 대상)
  3. 취약점 비교 — 해소, 잔존, 신규
  4. 백엔드 compileJava·compileTestJava(·test), 프론트엔드 install·build·lint — before 도 실패하면 환경 문제로 본다
결과: <작업폴더>/verify/report.md, proposal.diff, 로그
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from collect_deps import ROOT, PREFIX, jdk17_home  # noqa: E402

CORE_LIB = PREFIX + "core-lib"
NODE22 = "source ~/.nvm/nvm.sh >/dev/null 2>&1 && nvm use 22 >/dev/null 2>&1; "
SEV = ["CRITICAL", "HIGH", "MODERATE", "LOW", "UNKNOWN"]


def run(cmd, cwd, log, env=None):
    proc = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, shell=isinstance(cmd, str),
                          executable="/bin/bash" if isinstance(cmd, str) else None)
    log.write_text(f"$ {cmd}\n\n{proc.stdout}\n{proc.stderr}", encoding="utf-8")
    return proc.returncode


def is_backend(p):
    return (p / "build.gradle").exists() or (p / "build.gradle.kts").exists()


def vparts(v):
    return [int(x) if x.isdigit() else x for x in re.split(r"[.\-+]", v)]


def jump(a, b):
    pa, pb = vparts(a), vparts(b)
    if pa[:1] != pb[:1]:
        return "major"
    if pa[:2] != pb[:2]:
        return "minor"
    return "patch"


def prepare(work, proposal_mods):
    sandbox = work / "sandbox"
    if sandbox.exists():
        shutil.rmtree(sandbox)
    mods = set(proposal_mods)
    if CORE_LIB in mods:  # core-lib 변경은 모든 백엔드 소비 모듈로 검증한다
        mods |= {p.name for p in ROOT.iterdir() if p.name.startswith(PREFIX) and is_backend(p)}
    if any(is_backend(ROOT / m) for m in mods):
        mods.add(CORE_LIB)  # settings.gradle 이 ../atlas-flight-core-lib 를 참조한다
    for side in ("before", "after"):
        for m in sorted(mods):
            dst = sandbox / side / m
            dst.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["rsync", "-a", "--exclude", "build", "--exclude", ".gradle", "--exclude", "node_modules",
                            "--exclude", "dist", "--exclude", ".git", f"{ROOT / m}/", f"{dst}/"], check=True)
    for m in proposal_mods:
        src = work / "proposal" / m
        subprocess.run(["rsync", "-a", f"{src}/", f"{sandbox / 'after' / m}/"], check=True)
    return sandbox, sorted(mods)


def write_diff(work, sandbox, proposal_mods):
    out = []
    for m in proposal_mods:
        for f in sorted(p for p in (work / "proposal" / m).rglob("*") if p.is_file()):
            rel = f.relative_to(work / "proposal" / m)
            proc = subprocess.run(["diff", "-u", "--label", f"a/{m}/{rel}", "--label", f"b/{m}/{rel}",
                                   str(sandbox / "before" / m / rel), str(f)], capture_output=True, text=True)
            out.append(proc.stdout or f"# {m}/{rel}: 원본과 같음\n")
    (work / "verify" / "proposal.diff").write_text("".join(out), encoding="utf-8")


def frontend_install(tree, mods, logs, side):
    res = {}
    for m in mods:
        if (tree / m / "package.json").exists():
            # --immutable 은 쓰지 않는다. 설치된 yarn 버전이 다르면 내장 patch hash 만 바뀌어도 실패한다
            code = run(NODE22 + "corepack yarn install", tree / m, logs / f"{side}-{m}-install.log")
            up = tree / m / "yarn-up.txt"
            if side == "after" and code == 0 and up.exists():
                pkgs = " ".join(x.strip() for x in up.read_text(encoding="utf-8").splitlines() if x.strip())
                up.unlink()
                code = run(NODE22 + f"corepack yarn up -R {pkgs}", tree / m, logs / f"{side}-{m}-yarn-up.log")
            res[m] = code
    return res


def collect(tree, out, mods):
    subprocess.run([sys.executable, str(HERE / "collect_deps.py"), "--root", str(tree), "--out", str(out), *mods],
                   check=True, capture_output=True)
    proc = subprocess.run([sys.executable, str(HERE / "osv_check.py"), "--out", str(out)],
                          check=True, capture_output=True, text=True)
    (out / "osv-table.md").write_text(proc.stdout, encoding="utf-8")
    deps = json.loads((out / "deps.json").read_text(encoding="utf-8"))
    vulns = json.loads((out / "vulns.json").read_text(encoding="utf-8"))
    return deps, vulns


def build_module(tree, m, logs, side, with_tests):
    path = tree / m
    if is_backend(path):
        java = jdk17_home()
        # ':' 를 붙여 루트 프로젝트 태스크만 실행한다. core-lib 는 compileJava 의존성으로만 빌드된다
        tasks = ":compileJava :compileTestJava" + (" :test" if with_tests else "")
        prefix = f"JAVA_HOME='{java}' " if java else ""
        prop = f" -Porg.gradle.java.installations.paths='{java}'" if java else ""
        code = run(f"{prefix}./gradlew {tasks} --continue{prop}", path, logs / f"{side}-{m}-gradle.log")
        result = {"build": code}
        if with_tests:
            t = {"tests": 0, "failures": 0, "errors": 0, "skipped": 0}
            for x in (path / "build" / "test-results" / "test").glob("TEST-*.xml"):
                root = ET.parse(x).getroot()
                for k in t:
                    t[k] += int(root.get(k, 0))
            result["tests"] = t
        return result
    if (path / "package.json").exists():
        return {"build": run(NODE22 + "corepack yarn build", path, logs / f"{side}-{m}-build.log"),
                "lint": run(NODE22 + "corepack yarn lint", path, logs / f"{side}-{m}-lint.log")}
    return {}


def index_vulns(vulns):
    """(모듈, 패키지, 취약점 id) -> (버전, 심각도)"""
    idx = {}
    for r in vulns:
        for m in r["modules"]:
            for v in r["vulns"]:
                idx[(m, r["package"], v["id"])] = (r["version"], v["severity"])
    return idx


def flat(deps, m):
    d = deps.get(m, {}).get("deps", {})
    return {k: (v if isinstance(v, str) else ",".join(v)) for k, v in d.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True)
    ap.add_argument("--expect", nargs="*", default=[])
    ap.add_argument("--with-tests", action="store_true")
    ap.add_argument("--keep-sandbox", action="store_true")
    opts = ap.parse_args()

    work = Path(opts.work).resolve()
    proposal_dir = work / "proposal"
    if not proposal_dir.is_dir():
        sys.exit(f"제안 폴더 없음: {proposal_dir}")
    proposal_mods = sorted(p.name for p in proposal_dir.iterdir() if p.is_dir() and p.name.startswith(PREFIX))
    unknown = [m for m in proposal_mods if not (ROOT / m).is_dir()]
    if not proposal_mods or unknown:
        sys.exit(f"proposal/ 아래 모듈 폴더 확인 필요 (없는 모듈: {unknown})")

    verify = work / "verify"
    logs = verify / "logs"
    if verify.exists():
        shutil.rmtree(verify)
    logs.mkdir(parents=True)

    print("1/5 sandbox 준비")
    sandbox, mods = prepare(work, proposal_mods)
    write_diff(work, sandbox, proposal_mods)
    targets = [m for m in mods if m != CORE_LIB or m in proposal_mods]

    print("2/5 프론트엔드 install")
    install = {s: frontend_install(sandbox / s, targets, logs, s) for s in ("before", "after")}

    print("3/5 의존성 해석·취약점 조회")
    deps, vulns = {}, {}
    for s in ("before", "after"):
        deps[s], vulns[s] = collect(sandbox / s, verify / s, targets)

    print("4/5 빌드" + ("·테스트" if opts.with_tests else ""))
    # 모듈들이 sandbox 안 core-lib 복사본 하나를 공유하므로 순차로 빌드한다 (병렬이면 class 파일이 깨진다)
    builds = {s: {m: build_module(sandbox / s, m, logs, s, opts.with_tests) for m in targets}
              for s in ("before", "after")}

    print("5/5 보고서 작성")
    # Boot 플러그인이 없는 라이브러리(core-lib)는 소비 모듈의 Boot BOM 이 버전을 덮어쓴다.
    # 라이브러리 자체 해석 버전은 런타임과 다르므로 판정에서 빼고 참고로만 보인다
    libs = {m for m in targets if deps["after"].get(m, {}).get("library")}
    lines = ["# 수정 제안 검증 결과", "",
             f"- 제안 모듈: {', '.join(proposal_mods)}",
             f"- 검증 모듈: {', '.join(targets)}",
             f"- 테스트 실행: {'예' if opts.with_tests else '아니오 (컴파일만)'}",
             "- 변경 내용: `verify/proposal.diff`", ""]
    verdict = []

    # 1. 기대 버전
    lines += ["## 1. 기대 버전 해석", ""]
    if opts.expect:
        lines += ["| 기대 | 모듈 | 실제 | 판정 |", "|---|---|---|---|"]
        for e in opts.expect:
            name, want = e.split("=", 1)
            found = False
            for m in targets:
                for coord, ver in flat(deps["after"], m).items():
                    if coord == name or coord.endswith(":" + name) or coord == name.split(":")[-1]:
                        found = True
                        if m in libs:
                            lines.append(f"| `{e}` | {m.removeprefix(PREFIX)} | {ver} | 참고 (라이브러리) |")
                            continue
                        ok = ver == want
                        if not ok:
                            verdict.append(f"기대 버전 불일치: {m} {coord} {ver} (기대 {want})")
                        lines.append(f"| `{e}` | {m.removeprefix(PREFIX)} | {ver} | {'✔' if ok else '✖'} |")
            if not found:
                verdict.append(f"기대 아티팩트 없음: {name}")
                lines.append(f"| `{e}` | - | 없음 | ✖ |")
    else:
        lines.append("- 지정 없음")
    lines.append("")

    # 2. 의존성 변경
    lines += ["## 2. 의존성 변경", "",
              "major·minor 변경과 추가·제거만 표로 보인다. patch 변경은 건수만 적는다. major·minor 변경은 릴리스 노트·업그레이드 가이드 확인 대상이다.", ""]
    for m in targets:
        b, a = flat(deps["before"], m), flat(deps["after"], m)
        rows = []
        for k in sorted(set(b) | set(a)):
            if b.get(k) == a.get(k):
                continue
            if k not in b:
                rows.append(("추가", k, "-", a[k]))
            elif k not in a:
                rows.append(("제거", k, b[k], "-"))
            else:
                j = jump(b[k].split(",")[0], a[k].split(",")[0])
                rows.append(("**" + j + "**" if j != "patch" else j, k, b[k], a[k]))
        patch_n = sum(1 for r in rows if r[0] == "patch")
        rows = [r for r in rows if r[0] != "patch"]
        lines.append(f"### {m.removeprefix(PREFIX)} — major·minor {sum(1 for r in rows if r[0].startswith('**'))}개, "
                     f"추가·제거 {sum(1 for r in rows if r[0] in ('추가', '제거'))}개, patch {patch_n}개"
                     + (" (라이브러리 — 참고)" if m in libs else ""))
        if rows:
            rows.sort(key=lambda r: (0 if r[0].startswith("**") else 1 if r[0] in ("추가", "제거") else 2, r[1]))
            lines += ["", "| 변경 | 의존성 | 적용 전 | 적용 후 |", "|---|---|---|---|"]
            lines += [f"| {r[0]} | `{r[1]}` | {r[2]} | {r[3]} |" for r in rows]
        lines.append("")

    # 3. 취약점 비교
    ib, ia = index_vulns(vulns["before"]), index_vulns(vulns["after"])
    kb = {k for k in ib if k[0] not in libs}
    ka = {k for k in ia if k[0] not in libs}
    lib_after = {k for k in ia if k[0] in libs}
    resolved, remaining, new = kb - ka, kb & ka, ka - kb

    def count(keys, idx):
        c = {s: 0 for s in SEV}
        for k in keys:
            c[idx[k][1] if idx[k][1] in c else "UNKNOWN"] += 1
        return " / ".join(f"{s[0]}{c[s]}" for s in SEV[:4])

    lines += ["## 3. 취약점 비교 (모듈별 건수 합계, C/H/M/L)", "",
              "| 구분 | 건수 | 심각도 |", "|---|---:|---|",
              f"| 적용 전 | {len(kb)} | {count(kb, ib)} |",
              f"| 적용 후 | {len(ka)} | {count(ka, ia)} |",
              f"| 해소 | {len(resolved)} | {count(resolved, ib)} |",
              f"| 잔존 | {len(remaining)} | {count(remaining, ia)} |",
              f"| **신규** | {len(new)} | {count(new, ia)} |", ""]
    if libs:
        lines += [f"- 라이브러리 모듈({', '.join(m.removeprefix(PREFIX) for m in sorted(libs))})은 집계에서 뺐다. "
                  f"적용 후 라이브러리 자체 해석 기준 {len(lib_after)}건 ({count(lib_after, ia)}) — 런타임 미포함", ""]
    for title, keys, idx in (("신규 취약점", new, ia), ("잔존 취약점", remaining, ia)):
        if keys:
            lines += [f"### {title}", "", "| 모듈 | 패키지 | 버전 | 심각도 | ID |", "|---|---|---|---|---|"]
            for m, p, i in sorted(keys, key=lambda k: (SEV.index(idx[k][1]) if idx[k][1] in SEV else 4, k)):
                lines.append(f"| {m.removeprefix(PREFIX)} | `{p}` | {idx[(m, p, i)][0]} | {idx[(m, p, i)][1]} | {i} |")
            lines.append("")
    if new:
        verdict.append(f"신규 취약점 {len(new)}건")
    if any(ia[k][1] in ("CRITICAL", "HIGH") for k in remaining):
        verdict.append("Critical·High 잔존")

    # 4. 빌드·테스트
    lines += ["## 4. 빌드·테스트", "",
              "| 모듈 | 단계 | 적용 전 | 적용 후 | 판정 |", "|---|---|---|---|---|"]

    def mark(code):
        return "✔" if code == 0 else f"✖ (exit {code})"

    for m in targets:
        steps = []
        if m in install["before"]:
            steps.append(("install", install["before"][m], install["after"][m]))
        for k in ("build", "lint"):
            if k in builds["before"][m]:
                steps.append((k if k != "build" or not is_backend(sandbox / "before" / m) else "compile",
                              builds["before"][m][k], builds["after"][m][k]))
        for step, b, a in steps:
            if a == 0:
                j = "통과"
            elif b != 0:
                j = "환경 문제 (적용 전도 실패)"
            else:
                j = "**회귀**"
                verdict.append(f"{m.removeprefix(PREFIX)} {step} 회귀")
            lines.append(f"| {m.removeprefix(PREFIX)} | {step} | {mark(b)} | {mark(a)} | {j} |")
        if opts.with_tests and "tests" in builds["after"][m]:
            tb, ta = builds["before"][m]["tests"], builds["after"][m]["tests"]
            fb, fa = tb["failures"] + tb["errors"], ta["failures"] + ta["errors"]
            j = "통과" if fa == 0 else ("환경 문제 (적용 전도 실패)" if fb >= fa else "**회귀**")
            if j == "**회귀**":
                verdict.append(f"{m.removeprefix(PREFIX)} 테스트 회귀")
            lines.append(f"| {m.removeprefix(PREFIX)} | test | {tb['tests']}건 중 실패 {fb} | "
                         f"{ta['tests']}건 중 실패 {fa} | {j} |")
    lines += ["", "로그: `verify/logs/<before|after>-<모듈>-<단계>.log`", ""]

    head = ["## 판정", ""]
    head += [f"- ✖ {v}" for v in verdict] if verdict else ["- ✔ 기대 버전 반영, 신규 취약점 없음, Critical·High 잔존 없음, 빌드 회귀 없음"]
    head += ["- major·minor 변경 의존성은 2절 목록으로 릴리스 노트를 확인한다", ""]
    lines[6:6] = head
    (verify / "report.md").write_text("\n".join(lines), encoding="utf-8")

    if not opts.keep_sandbox:
        shutil.rmtree(sandbox)
    print("\n".join(head))
    print(f"보고서: {verify / 'report.md'}")


if __name__ == "__main__":
    main()
