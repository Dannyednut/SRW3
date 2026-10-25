#!/usr/bin/env python3
# SRW3 Phase 1S — reconcile claims.csv with the runner's exit-codes (last-wins),
# applying the final expectations for the rows whose dispositions changed.
# Fail-closed: any claim in exit-codes but not in claims.csv (or vice versa)
# is reported. Never relabels a PASS into a FAIL or vice versa without the
# note recording the evidence.
import csv
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
EC = HERE / "claims" / "exit-codes-1s.csv"
CLAIMS = HERE / "claims" / "claims.csv"

# final expectations of record (post-run dispositions; each carries its reason)
FINAL = {
    # the attempts/residuals of record (honest non-closures)
    "1S-C1.2-UNIV": ("ATTEMPT", "attempt"),
    "1S-STATEREL-IMAGE": ("ATTEMPT", "attempt"),
    "1S-MIGRATE-UNIV": ("ATTEMPT", "attempt"),
    "1S-MIGRATE-GENESIS-C12ASSUMED": ("ATTEMPT", "attempt"),
    "1S-MIGRATE-DEST-NEG": ("FAIL", "attempt"),
    "1S-MIGRATE-DEST-NEG-CONCRETE": ("FAIL", "attempt"),
    # the closure under the disclosed assumption
    "1S-MIGRATE-UNIV-C12ASSUMED": ("PASS-ASSUMED", "attempt"),
    # the erasure-blindness finding (the first draft was mislabeled MUST-FAIL)
    "1S-NEG-TAGBREAK-CORR-IMAGE": ("PASS", "eval"),
}

rows = list(csv.DictReader(CLAIMS.open()))
by_id = {r["claim_id"]: r for r in rows}
last_rc = {}
for line in EC.open().readlines()[1:]:
    line = line.strip()
    if not line:
        continue
    cid, rc, budget, wall = line.split(",")[:4]
    last_rc[cid] = rc

problems = []
for cid, rc in last_rc.items():
    if cid not in by_id:
        problems.append(f"exit-codes row {cid} absent from claims.csv")
for r in rows:
    cid = r["claim_id"]
    if cid in FINAL:
        r["expectation"], r["class"] = FINAL[cid]
    if cid in last_rc:
        r["exit_code"] = last_rc[cid]

if problems:
    print("FAIL-CLOSED:")
    for p in problems:
        print("  " + p)
    sys.exit(1)

with CLAIMS.open("w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["claim_id", "expectation", "class", "source",
                                       "exit_code", "budget_s", "note"])
    w.writeheader()
    w.writerows(rows)
print(f"reconciled {len(rows)} claims; exit codes filled for {len(last_rc)}")
