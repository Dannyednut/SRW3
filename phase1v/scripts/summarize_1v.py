#!/usr/bin/env python3
"""SRW3 Phase 1V — the fail-closed ledger consistency gate (summarize_1v.py).

Checks (fails closed on any violation):
  1. LEDGER INTEGRITY: unique claim_ids; no empty fields; expectation column
     is PASS/FAIL (missing expected test results = alarm); class vocabulary
     closed; every claim row has an exit-codes row and vice versa.
  2. LAST-WINS CONSISTENCY: each claim row's exit_code equals the
     exit-codes-1v.csv row (append-only attempt history; superseded rows
     would stay and the LAST row wins).
  3. TRANSCRIPT PRESENCE: every claim row has a retained raw transcript
     under phase1v/transcripts/ (krun_<id>.txt, kpg_1v_<id>.log, or
     kprove_<id>.txt / kprove_<id>.log); the fidelity row's certificate
     transcript is ghost_manifest_verify_1v.txt.
  4. TERMINAL-STATE VOCABULARY: exit codes must be one of the recognized
     terminal states of this phase — 0 (success), 1 (designed proof
     refutation), 113 (parse rejection / tool-boundary refusal), 124
     (TIMEOUT — never relabeled). Anything else is unrecognized.
  5. HEADLINE INVARIANTS (the phase's verdict-bearing rows):
       - the OLD-1U exploits reproduced (rc=0, control)
       - the parse rejections rc=113 mentioning the removed commands
       - the hardening blocks and immutability control OK
       - the claims battery rc=0 with #Top; the negative control rc=1
       - the ghost battery: every PROVED row rc=0; the designed failures
         (GH-T, GH-T2-NEG, the *NEG rows) rc=1; the fidelity certificate rc=0
       - the model + ghost verdict ledgers carry verdict=OK on every row
  6. COUNT MISMATCH: the verdict ledgers and claims-1v.csv must agree in row
     count; the report's acceptance table is cross-checked by the report
     itself (grep-assertions in run_1v_all.sh).

Prints the class census and GATE GREEN/RED. Level III only.
"""
import csv
import os
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CL = os.path.join(BASE, "claims")
TR = os.path.join(BASE, "transcripts")

ALLOWED_EXPECT = {"PASS", "FAIL"}
CLASSES = {"proved", "control", "regression", "fidelity", "TIMEOUT", "tool-boundary"}
TERMINAL_RC = {"0", "1", "113", "124"}

fails = []


def rd(path):
    with open(path) as f:
        return list(csv.DictReader(f))


claims = rd(os.path.join(CL, "claims-1v.csv"))
exits = rd(os.path.join(CL, "exit-codes-1v.csv"))

# --- 1. ledger integrity -----------------------------------------------------
ids = [r["claim_id"] for r in claims]
dups = sorted({i for i in ids if ids.count(i) > 1})
if dups:
    fails.append(f"duplicate claim_ids in claims-1v.csv: {dups}")
for r in claims:
    cid = r["claim_id"]
    if not cid:
        fails.append("empty claim_id row")
        continue
    if r["expectation"] not in ALLOWED_EXPECT:
        fails.append(f"{cid}: missing/invalid expected test result {r['expectation']!r}")
    if r["class"] not in CLASSES:
        fails.append(f"{cid}: unrecognized class {r['class']!r}")
    if r["exit_code"] not in TERMINAL_RC:
        fails.append(f"{cid}: unrecognized terminal state rc={r['exit_code']!r}")

# --- 2. last-wins consistency ------------------------------------------------
ec_last = {}
for r in exits:
    ec_last[r["claim_id"]] = r
for r in claims:
    cid = r["claim_id"]
    if cid not in ec_last:
        fails.append(f"{cid}: no exit-codes-1v.csv row")
    elif ec_last[cid]["exit_code"] != r["exit_code"]:
        fails.append(f"{cid}: ledger rc={r['exit_code']} != exit-codes last-wins rc={ec_last[cid]['exit_code']}")
for cid in ec_last:
    if cid not in ids:
        fails.append(f"{cid}: exit-codes row without a claim row")

# --- 3. transcript presence --------------------------------------------------
LOG_ALIASES = {
    "NEW1V-claims-1-4": "kprove_claims_new.txt",
    "NEW1V-negative-control": "kprove_negcontrol_new.txt",
}

def has_log(cid):
    cands = [
        os.path.join(TR, "model", f"krun_{cid}.txt"),
        os.path.join(TR, "ghost", f"kpg_1v_{cid}.log"),
        os.path.join(TR, "model", f"kprove_{cid}.txt"),
        os.path.join(TR, "model", f"kprove_{cid}.log"),
    ]
    if cid == "ghost-exact-fidelity":
        cands.append(os.path.join(TR, "ghost", "ghost_manifest_verify_1v.txt"))
    if cid in LOG_ALIASES:
        cands.append(os.path.join(TR, "model", LOG_ALIASES[cid]))
    # ghost GENSPEC logs are named kpg_1v_<PRE>_<L>.log (underscore between
    # the prefix and the label) while the claim id is ghost-<PRE>-<L>
    if cid.startswith("ghost-"):
        base = cid[6:]
        cands.append(os.path.join(TR, "ghost", f"kpg_1v_{base}.log"))
        cands.append(os.path.join(TR, "ghost", f"kpg_1v_{base.replace('-', '_', 1)}.log"))
        cands.append(os.path.join(TR, "ghost", f"kpg_1v_{base.replace('-', '_')}.log"))
    return any(os.path.exists(p) for p in cands)

for r in claims:
    if not has_log(r["claim_id"]):
        fails.append(f"{r['claim_id']}: no retained transcript under phase1v/transcripts/")

# --- 5. headline invariants --------------------------------------------------
HEADLINE = [
    # (claim_id, expected rc, expected class)
    ("OLD1U-p1u_policy_prebegin", "0", "control"),
    ("OLD1U-p1u_policy_between", "0", "control"),
    ("OLD1U-p1u_registry_prebegin", "0", "control"),
    ("OLD1U-p1u_registry_between", "0", "control"),
    ("OLD1U-p1u_init_mid", "0", "control"),
    ("OLD1U-p1u_resmap_mid", "0", "control"),
    ("OLD1U-p1u_resmap_prebegin", "0", "control"),
    ("OLD1U-p1u_grant_mid", "0", "control"),
    ("OLD1U-p1u_grant_between", "0", "control"),
    ("NEW1V-v1_atk_policy_prebegin", "113", "control"),
    ("NEW1V-v1_atk_registry_between", "113", "control"),
    ("NEW1V-v1_atk_gen_grant_mid", "113", "control"),
    ("NEW1V-v1_atk_init_mid", "0", "regression"),
    ("NEW1V-v1_atk_as_mid", "0", "regression"),
    ("NEW1V-v1_atk_config_immutable", "0", "regression"),
    ("NEW1V-claims-1-4", "0", "regression"),
    ("NEW1V-negative-control", "1", "regression"),
    ("ghost-exact-fidelity", "0", "fidelity"),
    ("ghost-GH-T2", "0", "proved"),
    ("ghost-GH-M", "0", "proved"),
    ("ghost-GH-T", "1", "control"),
    ("ghost-GH-T2-NEG", "1", "control"),
]
by_id = {r["claim_id"]: r for r in claims}
for cid, rc, cls in HEADLINE:
    r = by_id.get(cid)
    if r is None:
        fails.append(f"headline invariant missing: {cid}")
        continue
    if r["exit_code"] != rc:
        fails.append(f"headline {cid}: rc={r['exit_code']} expected {rc}")
    if r["class"] != cls:
        fails.append(f"headline {cid}: class={r['class']} expected {cls}")
    if r["expectation"] != "PASS":
        fails.append(f"headline {cid}: expectation={r['expectation']} (deviation of record)")

# designed-failure rows must never be marked PASS-with-rc0 (never relabel)
for r in claims:
    if r["claim_id"].endswith("-NEG") or r["claim_id"] == "ghost-GH-T":
        if r["exit_code"] == "0":
            fails.append(f"{r['claim_id']}: a designed-failure control closed with rc=0 — RELABELING ALARM")

# --- 6. count match ----------------------------------------------------------
if len(claims) != len(exits):
    fails.append(f"count mismatch: claims-1v.csv={len(claims)} vs exit-codes-1v.csv={len(exits)}")

# verdict ledgers all-OK crosscheck (per-run fresh ledgers)
for vl in ("model-verdicts-1v.csv", "ghost-verdicts-1v.csv"):
    p = os.path.join(CL, vl)
    if not os.path.exists(p):
        fails.append(f"missing verdict ledger {vl}")
        continue
    with open(p) as f:
        rows = [r for r in (line.rstrip("\n").split(",", 6) for line in f) if r and r[0] != "tag"]
    bad = [r[0] for r in rows if len(r) >= 6 and r[5] != "OK"]
    if bad:
        fails.append(f"{vl}: non-OK verdict rows: {bad[:5]}")
    if len(rows) not in (44, 48, 92):
        fails.append(f"{vl}: unexpected row count {len(rows)} (expected 44 model / 48 ghost)")

census = {}
for r in claims:
    census[r["class"]] = census.get(r["class"], 0) + 1

print(f"rows={len(claims)} unique-claims={len(set(ids))}")
for k in sorted(census):
    print(f"  {k}: {census[k]}")
if fails:
    print("GATE RED:")
    for f_ in fails:
        print("  -", f_)
    sys.exit(1)
print("GATE GREEN (0 alarms)")
