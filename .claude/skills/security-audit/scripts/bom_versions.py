#!/usr/bin/env python3
"""Spring Boot 버전별 관리 의존성 버전과 Maven Central 최신 버전을 조회한다.

사용법:
  python3 bom_versions.py --boot 4.0.8 4.1.1          # Boot 버전별 관리 버전 비교표
  python3 bom_versions.py --boot 4.1.1 --grep netty   # 속성 이름 필터 (기본: 주요 라이브러리)
  python3 bom_versions.py --latest org.apache.tomcat.embed:tomcat-embed-core org.bouncycastle:bcprov-jdk18on
  python3 bom_versions.py --boot-lines                # Boot 계열(major.minor)별 최신 패치

Boot 가 관리하는 버전은 build.gradle 에서 ext['<속성>'] / set('<속성>', ...) 로 덮어쓸 수 있다.
속성 이름은 이 스크립트가 출력하는 이름(예: tomcat.version)을 그대로 쓴다.
"""
import argparse
import re
import urllib.request

CENTRAL = "https://repo1.maven.org/maven2"
DEFAULT_KEYS = ["tomcat", "spring-framework", "spring-security", "jackson-bom", "jackson-2-bom",
                "netty", "commons-lang3", "commons-codec", "logback", "snakeyaml", "hibernate",
                "flyway", "mariadb", "spring-data-bom", "reactor-bom", "micrometer"]


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read().decode()


def versions_of(coord):
    g, a = coord.split(":")
    meta = fetch(f"{CENTRAL}/{g.replace('.', '/')}/{a}/maven-metadata.xml")
    return re.findall(r"<version>([^<]+)</version>", meta)


def stable(vs):
    return [v for v in vs if re.fullmatch(r"[\d.]+", v)]


def key(v):
    return [int(x) for x in v.split(".")]


def boot_props(version):
    pom = fetch(f"{CENTRAL}/org/springframework/boot/spring-boot-dependencies/{version}/spring-boot-dependencies-{version}.pom")
    return dict(re.findall(r"<([\w.\-]+)\.version>([^<]+)</", pom))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot", nargs="*", default=[])
    ap.add_argument("--grep", nargs="*")
    ap.add_argument("--latest", nargs="*", default=[])
    ap.add_argument("--boot-lines", action="store_true")
    opts = ap.parse_args()

    if opts.boot_lines:
        lines = {}
        for v in stable(versions_of("org.springframework.boot:spring-boot-dependencies")):
            mm = ".".join(v.split(".")[:2])
            if mm not in lines or key(v) > key(lines[mm]):
                lines[mm] = v
        print("| Boot 계열 | 최신 패치 |\n|---|---|")
        for mm in sorted(lines, key=key)[-4:]:
            print(f"| {mm} | {lines[mm]} |")
        print()

    if opts.boot:
        props = {v: boot_props(v) for v in opts.boot}
        names = sorted({k for p in props.values() for k in p})
        filters = opts.grep if opts.grep else DEFAULT_KEYS
        names = [n for n in names if any(f in n for f in filters)]
        print("| 속성 | " + " | ".join(f"Boot {v}" for v in opts.boot) + " |")
        print("|---|" + "---|" * len(opts.boot))
        for n in names:
            print(f"| `{n}.version` | " + " | ".join(props[v].get(n, "-") for v in opts.boot) + " |")
        print()

    if opts.latest:
        print("| 좌표 | 최신 안정 버전 |\n|---|---|")
        for c in opts.latest:
            vs = stable(versions_of(c))
            print(f"| `{c}` | {max(vs, key=key) if vs else '-'} |")


if __name__ == "__main__":
    main()
