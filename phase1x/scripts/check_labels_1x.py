#!/usr/bin/env python3
"""SRW3 Phase 1X — the label-inventory assertion tool (check_labels_1x.py).

Asserts that a splitter's output equals the PINNED expected inventory
(phase1x/claims/expected-ghost-inventory.json) — BEFORE any K proof is
invoked. This is the R13 fix: the batch no longer derives its claim list
from the splitter without pinning the expectation.

Checks (each failure is reported by name and exits nonzero):
  1. SPLITTER-OUTPUT-READABLE: the labels file exists and contains no NUL or
     other control garbage.
  2. SPLITTER-OUTPUT-EMPTY: an empty list refuses to run an empty battery.
  3. NO-DUPLICATE-LABELS: the splitter emitted no label twice (an omitted
     claim shortens the battery; a duplicated one double-counts it).
  4. EXACT-SET-EQUALITY: emitted set == expected set (normalized as sets —
     ordering is not semantically relevant — but duplicates are still
     rejected by check 3).
  5. EXACT-COUNT: emitted count == expected count (derived from the
     inventory, not a free-standing constant).
  6. SPEC-FILES-COMPLETE: for every EXPECTED label, the per-claim spec file
     exists in the specs dir (main: c_<L>.k; gen: <PRE>_<L>.k).
  7. SPEC-FILES-EXACT: no UNEXPECTED spec files in the specs dir (a spec
     file without an expected label is as much a defect as a label without
     a spec file).

Modes:
  --check   assert a splitter result (labels file + specs dir) — default.
  --emit    print "<LABEL> <STATUS>" lines from the inventory in the
            committed order (the runner's per-claim expectation source).

Exit codes: 0 = assertion passed / emit OK; 3 = assertion FAILED (with a
named reason on stderr); 2 = usage error.
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CLM = os.path.join(os.path.dirname(HERE), "claims")
INV = os.path.join(CLM, "expected-ghost-inventory.json")

SUITES = ("main", "cm2_alias", "cm3_auth", "gen_full")


def load_inventory():
    with open(INV) as f:
        return json.load(f)


inv = load_inventory()


def suite_spec_file(suite, s):
    if suite == "main":
        return f"c_{s}.k"
    pre = inv[suite]["obs_module"]
    return f"{pre}_{s}.k"


def emit(suite):
    s = inv[suite]
    for lab in s["labels"]:
        print(f"{lab} {s['expected_status'][lab]}")
    return 0


def check(suite, labels_file, specs_dir):
    s = inv[suite]
    expected = s["labels"]
    fails = []

    # 1. readable
    if not os.path.exists(labels_file):
        print("ASSERTION FAILED: SPLITTER-OUTPUT-READABLE "
              f"(no such file: {labels_file})", file=sys.stderr)
        return 3
    raw = open(labels_file, errors="replace").read()
    if any(c in raw for c in "\x00\x01\x02\x03\x04\x05"):
        fails.append("SPLITTER-OUTPUT-READABLE: control characters in output")
    labels = raw.split()

    # 2. empty
    if not labels:
        print("ASSERTION FAILED: SPLITTER-OUTPUT-EMPTY "
              "(splitter produced no labels — refusing to run an empty battery)",
              file=sys.stderr)
        return 3

    # 3. duplicates
    seen, dups = set(), set()
    for lab in labels:
        (dups.add(lab) if lab in seen else seen.add(lab))
    if dups:
        fails.append(f"NO-DUPLICATE-LABELS: duplicated label(s) {sorted(dups)}")

    # 4. exact set equality
    exp_set, got_set = set(expected), set(labels)
    missing = sorted(exp_set - got_set)
    extra = sorted(got_set - exp_set)
    if missing:
        fails.append(f"EXACT-SET-EQUALITY: MISSING expected label(s) {missing}")
    if extra:
        fails.append(f"EXACT-SET-EQUALITY: UNEXPECTED label(s) {extra}")

    # 5. exact count
    if len(labels) != len(expected):
        fails.append(f"EXACT-COUNT: splitter emitted {len(labels)} label(s), "
                     f"inventory pins {len(expected)}")

    # 6+7. spec files complete / exact
    if specs_dir:
        if suite == "main":
            expected_files = {f"c_{lab}.k" for lab in expected}
        else:
            pre = s["obs_module"]
            expected_files = {f"{pre}_{lab}.k" for lab in expected}
        for lab in expected:
            p = os.path.join(specs_dir, suite_spec_file(suite, lab))
            if not os.path.exists(p):
                fails.append(f"SPEC-FILES-COMPLETE: missing spec file {p}")
        actual_k = {fn for fn in os.listdir(specs_dir) if fn.endswith(".k")}
        for fn in sorted(actual_k - expected_files):
            fails.append(f"SPEC-FILES-EXACT: unexpected spec file {fn}")

    if fails:
        for f_ in fails:
            print(f"ASSERTION FAILED: {f_}", file=sys.stderr)
        return 3
    print(f"LABELCHECK OK: suite={suite} labels={len(labels)} "
          f"(pinned inventory match, no dups, no extras)")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--suite", choices=SUITES, required=True)
    ap.add_argument("--labels-file", default=None)
    ap.add_argument("--specs-dir", default=None)
    ap.add_argument("--emit", action="store_true")
    a = ap.parse_args()
    if a.emit:
        sys.exit(emit(a.suite))
    if not a.labels_file:
        print("usage: --check requires --labels-file", file=sys.stderr)
        sys.exit(2)
    sys.exit(check(a.suite, a.labels_file, a.specs_dir))


if __name__ == "__main__":
    main()
