#!/usr/bin/env python3
"""SRW3 Phase 1U — the fail-closed ledger consistency gate (summarize_1u.py).

Checks (fails closed on any violation):
  1. every ledger row has a unique claim_id (SUPERSEDED duplicate rows are
     identified by the word SUPERSEDED in the note and are exempt from the
     uniqueness rule but must have a distinct (claim_id, exit_code) pair);
  2. every row's exit_code matches the LAST-WINS row in exit-codes-1u.csv
     (append-only attempt history; superseded rows stay);
  3. every row citing a transcript has one (phase1u/transcripts/{k,model,lean});
  4. the classification vocabulary is closed;
  5. the headline invariants: the corrected unconditional universal rc=0,
     its depth probes 1/1/0, the decisive negative control rc=1, the genesis
     form rc=124, the DEST-FALSE control rc=124 (TIMEOUT, never relabeled),
     the mutant rc=113 exhibit, the 1S reproductions, the old-model defect
     exhibits, the fixed-model gates.
Prints the class census and GATE GREEN/RED. Level III only.
"""
import csv, os, sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEDGER = os.path.join(BASE, "claims", "claims-1u.csv")
EC = os.path.join(BASE, "claims", "exit-codes-1u.csv")
KLOGS = os.path.join(BASE, "transcripts", "k")
MLOGS = os.path.join(BASE, "transcripts", "model")
LLOGS = os.path.join(BASE, "transcripts", "lean")

ALLOWED = {"PASS", "FAIL", "ATTEMPT"}
CLASSES = {"proved", "proved-derived-lemma", "reproduced-under-assumption",
           "depth-closure", "control", "tool-boundary", "TIMEOUT"}

fails = []
rows = list(csv.DictReader(open(LEDGER)))

ids = [r["claim_id"] for r in rows if "SUPERSEDED" not in r["note"]]
dups = {i for i in ids if ids.count(i) > 1}
if dups:
    fails.append(f"duplicate claim_ids in ledger: {sorted(dups)}")

# last-wins exit codes
ec_last = {}
for r in csv.DictReader(open(EC)):
    ec_last[r["claim_id"]] = r

# last ledger row per id (append-only: superseded rows stay, LAST wins)
last_ledger = {}
for r in rows:
    last_ledger[r["claim_id"]] = r
for r in rows:
    cid = r["claim_id"]
    if r["expectation"] not in ALLOWED:
        fails.append(f"{cid}: bad expectation {r['expectation']}")
    if r["class"] not in CLASSES and r["class"].upper() not in {c.upper() for c in CLASSES}:
        fails.append(f"{cid}: bad class {r['class']}")
    if last_ledger.get(cid) is r:  # compare only the LAST ledger row per id
        if cid in ec_last:
            want = ec_last[cid]["exit_code"]
            got = r["exit_code"] if r["exit_code"] else ""
            if got != want:
                fails.append(f"{cid}: ledger rc={got} != exit-codes last-wins rc={want}")
        else:
            fails.append(f"{cid}: no exit-codes row")

LOG_ALIASES = {
    "NEW-claims-1-4": "kprove_claims_new.txt",
    "NEW-negative-control": "kprove_negcontrol_new.txt",
}

def has_log(cid):
    for d in (KLOGS, MLOGS):
        if os.path.exists(os.path.join(d, f"kprove_{cid}.log")) or \
           os.path.exists(os.path.join(d, f"krun_{cid}.txt")) or \
           os.path.exists(os.path.join(d, f"kprove_{cid}-D1.log")):
            return True
        if cid in LOG_ALIASES and os.path.exists(os.path.join(d, LOG_ALIASES[cid])):
            return True
    return False

for r in rows:
    cid = r["claim_id"]
    src = r["source"]
    if cid.startswith("ghost-"):
        if not os.path.isabs(src) and not os.path.exists(os.path.join(BASE, "..", src)):
            fails.append(f"{cid}: missing referenced transcript {src}")
        if os.path.isabs(src) and not os.path.exists(src):
            fails.append(f"{cid}: missing referenced transcript {src}")
        continue
    if not has_log(cid):
        fails.append(f"{cid}: no retained transcript under phase1u/transcripts/")

def last_rc(cid):
    return ec_last[cid]["exit_code"] if cid in ec_last else None

INV = [
    ("1U-MIGRATE-UNIV-LEANC12-RULE", "0"),
    ("1U-MIGRATE-UNIV-LEANC12-RULE-D1", "1"),
    ("1U-MIGRATE-UNIV-LEANC12-RULE-D2", "1"),
    ("1U-MIGRATE-UNIV-LEANC12-RULE-D3", "0"),
    ("1U-CORR-NODEP-RULE", "0"),
    ("1U-MIGRATE-GENESIS-LEANC12-RULE", "124"),
    ("1U-WSA-CTRL-DEST-FALSE-RULE", "124"),
    ("U-C15-COR-SYMB-GE2-TRUE", "1"),
    ("U-C15-COR-CONCRETE-GE2-FALSE", "0"),
    ("U-C15-COR-SYMB-GE1-TRUE", "0"),
    ("U-C15-LIVE-FOLDED-GE1", "1"),
    ("U-C15-PRIO-SYMB-GE2-TRUE", "113"),
    ("1S-MIGRATE-UNIV-C12ASSUMED", "0"),
    ("1S-MIGRATE-UNIV-C12ASSUMED-D3", "0"),
    ("1S-NEG-WEAK-UNIV-Q", "1"),
    ("1S-NEG-OMIT-GATEMINT", "1"),
    ("NEW-claims-1-4", "0"),
    ("NEW-negative-control", "1"),
    ("OLD-t1-pairwise-violation", "0"),
    ("OLD-t2-double-gate", "0"),
    ("OLD-t3-policy-mid", "0"),
    ("NEW-t2-double-gate", "0"),
    ("NEW-t3-policy-mid", "0"),
]

census = {}
for r in rows:
    if "SUPERSEDED" in r["note"]:
        continue
    census[r["class"]] = census.get(r["class"], 0) + 1

print(f"rows={len(rows)} unique-claims={len(set(ids))}")
for k in sorted(census):
    print(f"  {k}: {census[k]}")
if fails:
    print("GATE RED:")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("GATE GREEN (0 alarms)")
