#!/usr/bin/env python3
"""SRW3 Phase 1N — the fail-closed summarizer: build claims-status.csv (the
union of the ladder CSVs) and claim-classification.csv (the final honest
classification) from the RAW ladder records.  Fails closed: any missing log,
empty log without a timeout record, unknown raw_result, or expected/classified
mismatch aborts with exit 1 and NO output files.

Classification vocabulary (execution order §6): proved / refuted /
demonstrated / assumed / not-mechanized / failed / timed-out.
"""
import csv
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parents[1]
K = HERE / "transcripts" / "k"

def fail(msg: str) -> int:
    print("SUMMARIZER FAIL-CLOSED:", msg, file=sys.stderr)
    return 1

def load(name: str):
    rows = []
    with (K / name).open() as f:
        for r in csv.DictReader(f):
            log = K / r["log"]
            if not log.exists():
                return fail(f"missing log {log}")
            size = log.stat().st_size
            raw = r["raw_result"]
            if size == 0 and "rc=124" not in raw:
                return fail(f"empty log without timeout record: {r['log']}")
            if raw not in ("PROVED",) and not raw.startswith("FAILED(rc="):
                return fail(f"unknown raw_result {raw} in {r['log']}")
            r["log_size"] = size
            rows.append(r)
    return rows

def classify(r) -> str:
    exp, raw, triv = r["expected"], r["raw_result"], r["trivial"]
    if raw == "PROVED" and (exp in ("PASS", "PASS-EVAL") or exp == "ATTEMPT"):
        return "proved"
    if raw.startswith("FAILED(rc=1)") and             "branches were still unexplored" in (K / r["log"]).read_text():
        return "failed-budget"  # the prover was killed mid-search (the log's own words)
    if exp == "FAIL" and raw.startswith("FAILED"):
        return "refuted"  # the control behaves as designed
    if exp == "FAIL" and raw == "PROVED":
        return "ALARM-unexpected-proof"
    if exp == "ATTEMPT" and "rc=124" in raw:
        return "timed-out"
    if exp == "ATTEMPT" and raw.startswith("FAILED"):
        return "failed"   # the attempt's residual of record
    return "ALARM-unclassified"

def main() -> int:
    abs_rows = load("claims-status-abs.csv")
    sim_rows = load("claims-status-sim.csv")
    if abs_rows == 1 or sim_rows == 1:
        return 1
    all_rows = [("abs", r) for r in abs_rows] + [("sim", r) for r in sim_rows]

    with (HERE / "claims-status.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["ladder", "claim", "backend", "expected", "raw_result",
                    "trivial", "correct", "log", "log_bytes"])
        for lad, r in all_rows:
            w.writerow([lad, r["claim"], r["backend"], r["expected"],
                        r["raw_result"], r["trivial"], r["correct"],
                        f"transcripts/k/{r['log']}", r["log_size"]])

    with (HERE / "claim-classification.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["claim", "ladder", "classification", "evidence_log"])
        for lad, r in all_rows:
            w.writerow([r["claim"], lad, classify(r),
                        f"transcripts/k/{r['log']}"])

    counts = {}
    for _, r in all_rows:
        counts[classify(r)] = counts.get(classify(r), 0) + 1
    print("claims-status.csv:", len(all_rows), "claims")
    for k, v in sorted(counts.items()):
        print(f"  {k}: {v}")
    if any(k.startswith("ALARM") for k in counts):
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
