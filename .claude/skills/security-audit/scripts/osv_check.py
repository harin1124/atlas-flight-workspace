#!/usr/bin/env python3
"""deps.json 의 패키지를 OSV(osv.dev)에 조회해 취약점과 해소 버전을 정리한다.

사용법:
  python3 osv_check.py --out <collect_deps.py 의 --out 디렉터리>
결과:
  <out>/vulns.json  패키지·버전별 취약점 상세
  표준출력          심각도순 Markdown 표 (패키지, 버전, 영향 모듈, 건수, 최소 해소 버전)
"""
import argparse
import json
import re
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

OSV = "https://api.osv.dev/v1"
SEVERITY_ORDER = {"CRITICAL": 0, "HIGH": 1, "MODERATE": 2, "MEDIUM": 2, "LOW": 3, "UNKNOWN": 4}


def post(url, body):
    req = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


def vkey(v):
    """버전 비교용 키. 숫자 부분은 숫자로, 나머지는 문자열로 비교한다."""
    parts = re.split(r"[.\-+]", v)
    return [(0, int(p), "") if p.isdigit() else (1, 0, p) for p in parts]


def fixed_for(detail, name, version):
    """현재 버전이 속한 영향 범위의 fixed 버전을 돌려준다. 없으면 None."""
    cur = vkey(version)
    candidates = []
    for aff in detail.get("affected", []):
        if aff.get("package", {}).get("name") != name:
            continue
        for rng in aff.get("ranges", []):
            introduced = None
            for ev in rng.get("events", []):
                if "introduced" in ev:
                    introduced = ev["introduced"]
                elif "fixed" in ev and introduced is not None:
                    lo_ok = introduced == "0" or vkey(introduced) <= cur
                    if lo_ok and cur < vkey(ev["fixed"]):
                        candidates.append(ev["fixed"])
                    introduced = None
    return min(candidates, key=vkey) if candidates else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    opts = ap.parse_args()
    out = Path(opts.out)
    deps = json.loads((out / "deps.json").read_text(encoding="utf-8"))

    # (ecosystem, name, version) -> 사용하는 모듈 목록
    usage = defaultdict(list)
    for module, info in deps.items():
        for name, ver in info.get("deps", {}).items():
            for v in (ver if isinstance(ver, list) else [ver]):
                usage[(info["ecosystem"], name, v)].append(module)
    keys = sorted(usage)

    hits = {}
    for i in range(0, len(keys), 1000):
        chunk = keys[i:i + 1000]
        res = post(f"{OSV}/querybatch", {"queries": [
            {"package": {"ecosystem": e, "name": n}, "version": v} for e, n, v in chunk]})
        for k, r in zip(chunk, res["results"]):
            ids = [x["id"] for x in r.get("vulns", [])]
            if ids:
                hits[k] = ids

    all_ids = sorted({i for ids in hits.values() for i in ids})
    with ThreadPoolExecutor(max_workers=8) as pool:
        details = dict(zip(all_ids, pool.map(lambda i: get(f"{OSV}/vulns/{i}"), all_ids)))

    rows, report = [], []
    for (eco, name, ver), ids in hits.items():
        vulns = []
        for i in ids:
            d = details[i]
            sev = (d.get("database_specific", {}).get("severity") or "UNKNOWN").upper()
            vulns.append({"id": i, "severity": sev, "summary": d.get("summary", ""),
                          "published": d.get("published", "")[:10], "aliases": d.get("aliases", []),
                          "fixed": fixed_for(d, name, ver)})
        vulns.sort(key=lambda x: SEVERITY_ORDER.get(x["severity"], 4))
        fixes = [v["fixed"] for v in vulns if v["fixed"]]
        need = max(fixes, key=vkey) if fixes else None
        worst = vulns[0]["severity"]
        report.append({"ecosystem": eco, "package": name, "version": ver, "modules": sorted(usage[(eco, name, ver)]),
                       "worst": worst, "minFixed": need, "unfixed": len(fixes) < len(vulns), "vulns": vulns})
        rows.append((SEVERITY_ORDER.get(worst, 4), name, ver))

    report.sort(key=lambda r: (SEVERITY_ORDER.get(r["worst"], 4), r["package"], vkey(r["version"])))
    (out / "vulns.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"조회 패키지 {len(keys)}개, 취약 패키지 {len(report)}개, 취약점 {len(all_ids)}건\n")
    if not report:
        return
    print("| 최고 심각도 | 패키지 | 버전 | 건수 | 최소 해소 버전 | 영향 모듈 |")
    print("|---|---|---|---:|---|---|")
    for r in report:
        counts = defaultdict(int)
        for v in r["vulns"]:
            counts[v["severity"][0]] += 1
        cnt = " ".join(f"{k}{n}" for k, n in sorted(counts.items(), key=lambda x: "CHMLU".index(x[0])))
        fix = (r["minFixed"] or "없음") + (" (일부 미수정)" if r["unfixed"] else "")
        mods = ", ".join(m.removeprefix("atlas-flight-") for m in r["modules"])
        print(f"| {r['worst']} | `{r['package']}` | {r['version']} | {cnt} | {fix} | {mods} |")
    print(f"\n상세: {out / 'vulns.json'}")


if __name__ == "__main__":
    main()
