#!/usr/bin/env python3
"""atlas-flight 모듈의 런타임 의존성을 수집해 deps.json 으로 저장한다.

- 백엔드: build.gradle 이 있는 atlas-flight-* 모듈의 runtimeClasspath 해석 결과
- 프론트엔드: package.json + yarn.lock 이 있는 모듈의 yarn.lock resolution

사용법:
  python3 collect_deps.py --out <디렉터리> [--root <모듈들이 있는 폴더>] [모듈명 ...]
  모듈명은 접두사 없이 써도 된다 (auth, gateway, frontend). 생략하면 전체.
  --root 는 기본값이 프로젝트 루트다. verify_patch.py 가 sandbox 복사본을 수집할 때 쓴다.

JDK 17 경로는 JAVA17_HOME 환경변수 > Homebrew openjdk@17 > 현재 JAVA_HOME 순으로 고른다.
(/usr/libexec/java_home -v 17 은 17 이상을 돌려주므로 쓰지 않는다.)
"""
import argparse
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
PREFIX = "atlas-flight-"
HOMEBREW_JDK17 = "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"

# group:artifact:requested[ -> resolved] 또는 group:artifact -> resolved (BOM 관리 버전)
GRADLE_DEP = re.compile(r"[+\\]--- ([\w.\-]+):([\w.\-]+)(?::([\w.\-+]+))?(?: -> ([\w.\-+]+))?")
YARN_RESOLUTION = re.compile(r'^\s+resolution: "(.+)@npm:([^"]+)"$')


def jdk17_home():
    for cand in (os.environ.get("JAVA17_HOME"), HOMEBREW_JDK17, os.environ.get("JAVA_HOME")):
        if cand and Path(cand).is_dir():
            return cand
    return None


def discover(root, names):
    mods = sorted(p for p in root.iterdir() if p.is_dir() and p.name.startswith(PREFIX))
    if names:
        wanted = {n if n.startswith(PREFIX) else PREFIX + n for n in names}
        missing = wanted - {p.name for p in mods}
        if missing:
            sys.exit(f"모듈 없음: {', '.join(sorted(missing))}")
        mods = [p for p in mods if p.name in wanted]
    backend = [p for p in mods if (p / "build.gradle").exists() or (p / "build.gradle.kts").exists()]
    frontend = [p for p in mods if (p / "package.json").exists() and (p / "yarn.lock").exists()]
    return backend, frontend


def gradle_meta(path):
    text = (path / "build.gradle").read_text(encoding="utf-8") if (path / "build.gradle").exists() else ""
    boot = re.search(r"org\.springframework\.boot['\"]\s+version\s+['\"]([^'\"]+)", text)
    cloud = re.search(r"springCloudVersion['\"]?\s*,?\s*[=:]?\s*['\"]([^'\"]+)", text) or \
        re.search(r"spring-cloud-dependencies:([\w.\-]+)", text)
    return {"boot": boot.group(1) if boot else None, "springCloud": cloud.group(1) if cloud else None,
            "library": boot is None}


def collect_backend(path, raw_dir, java_home):
    env = dict(os.environ)
    args = [str(path / "gradlew"), "-q", "dependencies", "--configuration", "runtimeClasspath"]
    if java_home:
        env["JAVA_HOME"] = java_home
        args.append(f"-Porg.gradle.java.installations.paths={java_home}")
    proc = subprocess.run(args, cwd=path, env=env, capture_output=True, text=True)
    (raw_dir / f"{path.name}.txt").write_text(proc.stdout + proc.stderr, encoding="utf-8")
    if proc.returncode != 0:
        return {"error": (proc.stderr or proc.stdout).strip().splitlines()[-5:]}
    deps = {}
    for g, a, req, res in GRADLE_DEP.findall(proc.stdout):
        version = res or req
        if version and not version.startswith("project"):
            deps[f"{g}:{a}"] = version
    return {"deps": deps}


def collect_frontend(path):
    deps = {}
    for line in (path / "yarn.lock").read_text(encoding="utf-8").splitlines():
        m = YARN_RESOLUTION.match(line)
        if m:
            deps.setdefault(m.group(1), set()).add(m.group(2))
    return {"deps": {k: sorted(v) for k, v in deps.items()}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--root", default=str(ROOT))
    ap.add_argument("modules", nargs="*")
    opts = ap.parse_args()

    out = Path(opts.out)
    raw_dir = out / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    root = Path(opts.root).resolve()
    backend, frontend = discover(root, opts.modules)
    java_home = jdk17_home()

    result = {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {p.name: pool.submit(collect_backend, p, raw_dir, java_home) for p in backend}
        for name, fut in futures.items():
            path = root / name
            result[name] = {"ecosystem": "Maven", **gradle_meta(path), **fut.result()}
    for p in frontend:
        result[p.name] = {"ecosystem": "npm", **collect_frontend(p)}

    (out / "deps.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"JDK: {java_home or '기본값'}")
    for name, info in result.items():
        if "error" in info:
            print(f"✖ {name}: 의존성 해석 실패 — raw/{name}.txt 확인")
            continue
        meta = f"Boot {info['boot']}" if info.get("boot") else ("라이브러리" if info["ecosystem"] == "Maven" else "npm")
        cloud = f", Cloud {info['springCloud']}" if info.get("springCloud") else ""
        print(f"✔ {name}: {meta}{cloud}, 의존성 {len(info['deps'])}개")
    print(f"저장: {out / 'deps.json'}")


if __name__ == "__main__":
    main()
