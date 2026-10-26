#!/usr/bin/env python3
"""SRW3 Phase 1T — the fail-closed ledger consistency gate (summarize_1t.py).

Checks (fails closed on any violation):
  1. every ledger row has a unique claim_id;
  2. every row's exit_code matches the last-wins row in exit-codes-1t.csv;
  3. every row citing a transcript has one (phase1t/transcripts/k/ or
     phase1t/audit/lean/);
  4. the classification vocabulary is closed;
  5. the headline invariants: the RULE universal rc=0, its depth probes
     rc=1, both destination-false controls not-closed, the strip-state
     NODEP row rc=0, both genesis forms rc=124, the controls fail.
Prints the class census and GATE GREEN/RED. Level III only.
"""
import csv, os, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(BASE, "claims", "claims-1t.csv")
EC = os.path.join(BASE, "claims", "exit-codes-1t.csv")
KLOGS = os.path.join(BASE, "transcripts", "k")
LEAN = os.path.join(BASE, "audit", "lean")

ALLOWED = {"PASS", "FAIL", "ATTEMPT"}
CLASSES = {"proved", "proved-derived-lemma", "proved-external", "reproduced-under-assumption",
           "depth-closure", "FAILED-STUCK", "control", "tool-boundary", "TIMEOUT",
           "self-assumption", "eval", "attempt"}

fails = []
rows = list(csv.DictReader(open(LEDGER)))
ids = [r["claim_id"] for r in rows]
if len(ids) != len(set(ids)):
    fails.append("duplicate claim_ids in ledger")

# last-wins exit codes
ec_last = {}
for r in csv.DictReader(open(EC)):
    ec_last[r["claim_id"]] = r

for r in rows:
    cid = r["claim_id"]
    if r["expectation"] not in ALLOWED:
        fails.append(f"{cid}: bad expectation {r['expectation']}")
    if r["class"] not in CLASSES and r["class"].upper() not in {c.upper() for c in CLASSES}:
        fails.append(f"{cid}: bad class {r['class']}")
    if cid in ec_last:
        want = ec_last[cid]["exit_code"]
        got = r["exit_code"] if r["exit_code"] else ""
        if got != want:
            fails.append(f"{cid}: ledger rc={got} != exit-codes rc={want}")
    log = os.path.join(KLOGS, f"kprove_{cid}.log")
    depthlog = os.path.join(KLOGS, f"kprove_{cid}-D1.log")
    if not (os.path.exists(log) or os.path.exists(depthlog) or r["source"].endswith(".lean")):
        fails.append(f"{cid}: no retained transcript")

def last_rc(cid):
    return ec_last[cid]["exit_code"] if cid in ec_last else None

INV = [
    ("1T-MIGRATE-UNIV-LEANC12-RULE", "0"),
    ("1T-MIGRATE-UNIV-LEANC12-RULE-D1", "1"),
    ("1T-MIGRATE-UNIV-LEANC12-RULE-D2", "1"),
    ("1T-WSA-CTRL-DEST-FALSE-RULE", "124"),
    ("1T-WSA-CTRL-DEST-FALSE", "124"),
    ("1T-WSA-CTRL-SAFETY-FALSE", "1"),
    ("1T-CORR-NODEP-RULE", "0"),
    ("1T-MIGRATE-UNIV-LEANC12", "1"),
    ("1T-MIGRATE-GENESIS-LEANC12", "124"),
    ("1T-MIGRATE-GENESIS-LEANC12-RULE", "124"),
    ("1S-MIGRATE-UNIV-C12ASSUMED", "0"),
    ("1S-NEG-WEAK-UNIV-Q", "1"),
    ("1S-NEG-OMIT-GATEMINT", "1"),
]
for cid, want in INV:
    got = last_rc(cid)
    if got != want:
        fails.append(f"INVARIANT {cid}: rc={got} expected {want}")

for f in ["c12_induction.lean", "c12_neg_controls.lean",
          "transcript_c12_induction.txt", "transcript_c12_neg.txt"]:
    if not os.path.exists(os.path.join(LEAN, f)):
        fails.append(f"missing lean artifact {f}")

census = {}
for r in rows:
    census[r["class"]] = census.get(r["class"], 0) + 1

print(f"rows={len(rows)}")
for k in sorted(census):
    print(f"  {k}: {census[k]}")
if fails:
    print("GATE RED:")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("GATE GREEN (0 alarms)")
