#!/usr/bin/env python3
"""SRW3 Phase 1X — the Run A vs Run B logical-verdict comparison (WS-C).

Compares TWO ghost verdict ledgers (tag,class,rc,expected,observed,verdict,note)
produced by independent runs of the hardened battery (run_1x_ghost.sh). The
comparison is LOGICAL only: expected + observed-STATUS fields must match
exactly per claim; rc must match; wall-clock timings (wall=…s) and any
environment-absolute paths in the note field are EXCLUDED by design (the
1W-disclosed path-only drift allowance).

Exit 0 iff every claim's (rc, expected, observed-status) pair is identical
across the two runs AND both ledgers have the same tag set. Level III only.

Usage: compare_runs_1x.py --a RUNA.csv --b RUNB.csv [--out REPORT.md]
"""
import argparse
import csv
import sys

STATUS_VOCAB_ERR = "status vocabulary"


def load(path):
    rows = {}
    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("tag,"):
                continue
            parts = line.split(",", 6)
            tag, vclass, rc, expected, observed, verdict, note = (parts + [""] * 7)[:7]
            obs_st = ""
            for tok in observed.split():
                if tok.startswith("status="):
                    obs_st = tok[len("status="):]
            rows[tag] = {"class": vclass, "rc": rc, "expected": expected,
                         "status": obs_st, "verdict": verdict}
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", required=True)
    ap.add_argument("--b", required=True)
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    ra, rb = load(a.a), load(a.b)
    lines = []
    ta, tb = set(ra), set(rb)
    ok = True
    if ta != tb:
        ok = False
        for t in sorted(ta - tb):
            lines.append(f"MISMATCH  {t}: present only in A")
        for t in sorted(tb - ta):
            lines.append(f"MISMATCH  {t}: present only in B")
    common = sorted(ta & tb)
    for t in common:
        x, y = ra[t], rb[t]
        if (x["rc"], x["expected"], x["status"]) != (y["rc"], y["expected"], y["status"]):
            ok = False
            lines.append(f"MISMATCH  {t}: A=({x['rc']},{x['expected']},{x['status']}) "
                         f"B=({y['rc']},{y['expected']},{y['status']})")
    nsuite = {"main": 0, "cm2_alias": 0, "cm3_auth": 0, "gen_full": 0, "fidelity": 0}
    for t in common:
        if "SRW3G2" in t:
            nsuite["cm2_alias"] += 1
        elif "SRW3G3" in t:
            nsuite["cm3_auth"] += 1
        elif "SRW3G4" in t:
            nsuite["gen_full"] += 1
        elif t == "ghost-exact-fidelity":
            nsuite["fidelity"] += 1
        else:
            nsuite["main"] += 1
    head = [f"tags: A={len(ta)} B={len(tb)} common={len(common)}",
            f"suite census (common): {nsuite}",
            f"compared fields per claim: rc, expected, observed STATUS (wall-clock and "
            f"environment paths excluded by design)"]
    verdict = "RUNS LOGICALLY IDENTICAL" if ok else "RUNS DIFFER"
    lines.append(verdict)
    out_lines = head + [""] + lines
    text = "\n".join(out_lines) + "\n"
    if a.out:
        with open(a.out, "w") as f:
            f.write(text)
    print(text, end="")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
