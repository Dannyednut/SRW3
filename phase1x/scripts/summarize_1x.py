#!/usr/bin/env python3
"""SRW3 Phase 1X — the strict fail-closed ledger gate (summarize_1x.py).

Hardening over summarize_1w.py (whose verdict-ledger row-count check accepted
the SHARED set {46, 48, 94} for EITHER ledger — a model ledger with 48 rows
or a ghost ledger with 46 rows would have passed that check):

  S1. EXACT PER-LEDGER COUNTS, independently pinned:
        ghost verdict ledger : exactly 48 rows (47 claims + 1 fidelity row,
                               the count DERIVED from the pinned inventory)
        model verdict ledger : exactly 46 rows
        claims-1x.csv        : exactly 94 rows
        exit-codes-1x.csv    : exactly 94 rows
      No shared acceptance set; each ledger is checked against its own
      constant.
  S2. EXACT CLAIM-ID INVENTORY per ledger (set equality against the pinned
      inventories): a ledger with the right row count but one claim omitted
      and another duplicated (or substituted) FAILS — count alone is not
      identity. Duplicates inside a ledger are rejected; the claims ledger
      must equal the union of the model and ghost inventories exactly
      (94 unique IDs, nothing more, nothing less).
  S3. STATUS VOCABULARY (the 1X classification, preserved specifically):
      every ghost row carries an expected status from the closed vocabulary
      {PROVED, FAILED, FAILED-STUCK, TIMEOUT, NOT-RUN, BLOCKED, ...} and an
      observed status field from the same vocabulary; ghost-GH-T must be
      FAILED-STUCK with the stuck signature present in its observed field
      (the Phase 1W ledger used the broader FAILED label — cross-reference
      recorded, 1W files untouched).
  S4. NON-RELABELLING: designed-failure rows (ghost-GH-T, ghost-GH-T2-NEG,
      ghost-*-NEG) must NEVER carry rc=0 or status PROVED; rc=0 kprove rows
      must carry the '#Top=' closure marker in the observed field.
  S5. Carried from 1W (still enforced): unique claim IDs; no empty fields;
      expectation PASS/FAIL; closed class vocabulary; last-wins exit-code
      consistency; transcript presence (Phase 1X paths; fixture-provenance
      model rows point at their immutable Phase 1W transcripts); terminal
      rc vocabulary {0,1,113,124}; verdict ledgers all-OK; headline
      invariants.

Usage: summarize_1x.py [--root DIR]   (default: the Phase 1X repo layout;
      --root is for fixture-based negative controls ONLY — it must point at
      a sandbox copy, never at historical phase data for mutation.)
Prints the class census and GATE GREEN/RED. Level III only.
"""
import argparse
import csv
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.dirname(os.path.dirname(HERE))  # repo root
CLM_JSON = os.path.join(os.path.dirname(HERE), "claims")

ALLOWED_EXPECT = {"PASS", "FAIL"}
CLASSES = {"proved", "control", "regression", "fidelity", "TIMEOUT", "tool-boundary"}
TERMINAL_RC = {"0", "1", "113", "124"}
STATUS_VOCAB = {"PROVED", "FAILED", "FAILED-STUCK", "TIMEOUT", "NOT-RUN", "BLOCKED",
                "INVALID-SUCCESS", "UNKNOWN"}
DESIGNED = {"ghost-GH-T", "ghost-GH-T2-NEG", "ghost-SRW3G2-GH2-NEG",
            "ghost-SRW3G3-GH3-NEG", "ghost-SRW3G4-GH4-NEG"}

fails = []


def rd(path):
    with open(path) as f:
        return [r for r in (line.rstrip("\n").split(",", 6) for line in f) if r and r[0] != "tag"]


def ghost_expected_ids():
    inv = json.load(open(os.path.join(CLM_JSON, "expected-ghost-inventory.json")))
    ids = {}
    for suite in ("main", "cm2_alias", "cm3_auth", "gen_full"):
        s = inv[suite]
        for lab in s["labels"]:
            ids[f"{s['tag_prefix']}{lab}"] = s["expected_status"][lab]
    for extra in inv["main"]["extra_rows"]:
        ids[extra["tag"]] = extra["expected_status"]
    return ids


def model_expected_ids():
    doc = json.load(open(os.path.join(CLM_JSON, "expected-model-inventory.json")))
    return set(doc["claim_ids"]), doc["model_verdict_rows_expected"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=DEFAULT_ROOT)
    a = ap.parse_args()
    ROOT = a.root
    CL = os.path.join(ROOT, "phase1x", "claims")
    TR = os.path.join(ROOT, "phase1x", "transcripts")

    gids = ghost_expected_ids()
    gcount = len(gids)                       # 48 = 47 claims + 1 fidelity row
    mids, mcount = model_expected_ids()

    # --- load ledgers -------------------------------------------------------
    p_ghost = os.path.join(CL, "ghost-verdicts-1x.csv")
    p_model = os.path.join(CL, "model-verdicts-1x.csv")
    p_claims = os.path.join(CL, "claims-1x.csv")
    p_exits = os.path.join(CL, "exit-codes-1x.csv")
    for p in (p_ghost, p_model, p_claims, p_exits):
        if not os.path.exists(p):
            fails.append(f"missing ledger: {p}")

    ghost_rows = rd(p_ghost) if os.path.exists(p_ghost) else []
    model_rows = rd(p_model) if os.path.exists(p_model) else []
    claims = list(csv.DictReader(open(p_claims))) if os.path.exists(p_claims) else []
    exits = list(csv.DictReader(open(p_exits))) if os.path.exists(p_exits) else []

    # --- S1 exact per-ledger counts ----------------------------------------
    if len(ghost_rows) != gcount:
        fails.append(f"ghost ledger: {len(ghost_rows)} rows, exactly {gcount} required (47 claims + 1 fidelity, derived from the pinned inventory)")
    if len(model_rows) != mcount:
        fails.append(f"model ledger: {len(model_rows)} rows, exactly {mcount} required")
    if len(claims) != len(gids) + len(mids):
        fails.append(f"claims-1x.csv: {len(claims)} rows, exactly {len(gids) + len(mids)} required")
    if len(exits) != len(claims):
        fails.append(f"exit-codes-1x.csv: {len(exits)} rows vs claims {len(claims)}")

    # --- S2 exact claim-ID inventories -------------------------------------
    got_g = [r[0] for r in ghost_rows]
    dups_g = sorted({i for i in got_g if got_g.count(i) > 1})
    if dups_g:
        fails.append(f"ghost ledger duplicate tags: {dups_g}")
    miss_g = sorted(set(gids) - set(got_g))
    extra_g = sorted(set(got_g) - set(gids))
    if miss_g:
        fails.append(f"ghost ledger MISSING expected claim(s): {miss_g}")
    if extra_g:
        fails.append(f"ghost ledger UNEXPECTED claim(s): {extra_g}")

    got_m = [r[0] for r in model_rows]
    dups_m = sorted({i for i in got_m if got_m.count(i) > 1})
    if dups_m:
        fails.append(f"model ledger duplicate tags: {dups_m}")
    miss_m = sorted(mids - set(got_m))
    extra_m = sorted(set(got_m) - mids)
    if miss_m:
        fails.append(f"model ledger MISSING expected claim(s): {miss_m}")
    if extra_m:
        fails.append(f"model ledger UNEXPECTED claim(s): {extra_m}")

    ids = [r["claim_id"] for r in claims]
    dups_c = sorted({i for i in ids if ids.count(i) > 1})
    if dups_c:
        fails.append(f"claims-1x.csv duplicate claim_ids: {dups_c}")
    miss_c = sorted((set(gids) | mids) - set(ids))
    extra_c = sorted(set(ids) - (set(gids) | mids))
    if miss_c:
        fails.append(f"claims-1x.csv MISSING expected claim(s): {miss_c}")
    if extra_c:
        fails.append(f"claims-1x.csv UNEXPECTED claim(s): {extra_c}")

    # --- S3/S4/S5 per-row checks (ghost ledger) ----------------------------
    for r in ghost_rows:
        tag, vclass, rc, expected, observed, verdict, note = (r + [""] * 7)[:7]
        if len(r) < 6:
            fails.append(f"ghost row malformed: {r[:2]}")
            continue
        if not all((tag, vclass, rc, expected, observed, verdict)):
            fails.append(f"{tag}: empty field in ghost ledger")
        if verdict != "OK":
            fails.append(f"{tag}: ghost verdict row not OK")
        st = expected.split("(")[-1].rstrip(")") if "(" in expected else ""
        if not st:
            fails.append(f"{tag}: expected column lacks the status form 'rc=N (STATUS)': {expected!r}")
        elif st not in STATUS_VOCAB:
            fails.append(f"{tag}: expected status {st!r} outside the closed vocabulary")
        obs_st = ""
        for tok in observed.split():
            if tok.startswith("status="):
                obs_st = tok[7:]
        if not obs_st:
            fails.append(f"{tag}: observed field lacks status=… ({observed!r})")
        elif obs_st not in STATUS_VOCAB:
            fails.append(f"{tag}: observed status {obs_st!r} outside the closed vocabulary")
        # S4 non-relabelling + closure evidence
        if tag in DESIGNED:
            if rc == "0" or obs_st == "PROVED":
                fails.append(f"{tag}: designed-failure row closed/rc=0 — RELABELING ALARM")
        elif rc == "0" and obs_st not in ("PROVED", "TIMEOUT", "BLOCKED"):
            fails.append(f"{tag}: rc=0 row without a successful classification ({obs_st})")
        if rc == "0" and "#Top=" not in observed and vclass == "kprove":
            fails.append(f"{tag}: rc=0 kprove row without the #Top closure marker in observed")
        if rc not in TERMINAL_RC:
            fails.append(f"{tag}: unrecognized terminal rc={rc!r}")
        # S3 the GH-T specific preservation
        if tag == "ghost-GH-T":
            if obs_st != "FAILED-STUCK":
                fails.append(f"ghost-GH-T: observed status {obs_st!r}, the evidence-based classification is FAILED-STUCK (register R5)")
            elif "stuck=0" in observed or "backenderr=0" in observed:
                fails.append(f"ghost-GH-T: FAILED-STUCK claimed without the stuck signature in observed ({observed!r})")

    # --- claims ledger integrity (as 1W) -----------------------------------
    by_id = {}
    for r in claims:
        cid = r["claim_id"]
        by_id[cid] = r
        if r["expectation"] not in ALLOWED_EXPECT:
            fails.append(f"{cid}: missing/invalid expected test result {r['expectation']!r}")
        if r["class"] not in CLASSES:
            fails.append(f"{cid}: unrecognized class {r['class']!r}")
        if r["exit_code"] not in TERMINAL_RC:
            fails.append(f"{cid}: unrecognized terminal state rc={r['exit_code']!r}")

    # last-wins consistency
    ec_last = {r["claim_id"]: r for r in exits}
    for cid, r in by_id.items():
        if cid not in ec_last:
            fails.append(f"{cid}: no exit-codes-1x.csv row")
        elif ec_last[cid]["exit_code"] != r["exit_code"]:
            fails.append(f"{cid}: ledger rc={r['exit_code']} != exit-codes last-wins rc={ec_last[cid]['exit_code']}")
    for cid in ec_last:
        if cid not in by_id:
            fails.append(f"{cid}: exit-codes row without a claim row")

    # transcript presence (Phase 1X paths; fixture-provenance model rows
    # legitimately point at their immutable Phase 1W transcripts — the
    # provenance is recorded per row in the source column)
    for r in claims:
        cid = r["claim_id"]
        cands = []
        if cid.startswith("ghost-"):
            base = cid[6:]
            cands += [os.path.join(TR, "ghost", f"kpg_1x_{base}.log"),
                      os.path.join(TR, "ghost", f"kpg_1x_{base.replace('-', '_', 1)}.log"),
                      os.path.join(TR, "ghost", f"kpg_1x_{base.replace('-', '_')}.log")]
            if cid == "ghost-exact-fidelity":
                cands.append(os.path.join(TR, "ghost", "ghost_manifest_verify_1x.txt"))
        else:
            cands += [os.path.join(TR, "model", f"krun_{cid}.txt"),
                      os.path.join(TR, "model", f"kprove_{cid}.txt"),
                      os.path.join(TR, "model", f"kprove_{cid}.log")]
            if r.get("source", "").startswith("fixture:"):
                WTR = os.path.join(ROOT, "phase1w", "transcripts")
                cands += [os.path.join(WTR, "model", f"krun_{cid}.txt"),
                          os.path.join(WTR, "model", f"kprove_{cid}.txt"),
                          os.path.join(WTR, "model", f"kprove_{cid}.log")]
                # the 1W composite rows' transcript aliases (as in summarize_1w.py)
                ALIASES = {"NEW1W-claims-1-4": "kprove_claims_1w.txt",
                           "NEW1W-negative-control": "kprove_negcontrol_1w.txt"}
                if cid in ALIASES:
                    cands.append(os.path.join(WTR, "model", ALIASES[cid]))
        if not any(os.path.exists(p) for p in cands):
            fails.append(f"{cid}: no retained Phase 1X transcript")

    # headline invariants (ghost rows of record)
    HEADLINE = [
        ("ghost-exact-fidelity", "0", "fidelity"),
        ("ghost-GH-T2", "0", "proved"),
        ("ghost-GH-M", "0", "proved"),
        ("ghost-GH-T", "1", "control"),
        ("ghost-GH-T2-NEG", "1", "control"),
    ]
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

    # designed-failure rows must never be PASS-with-rc0 (never relabel)
    for r in claims:
        if r["claim_id"] in DESIGNED and r["exit_code"] == "0":
            fails.append(f"{r['claim_id']}: a designed-failure control closed with rc=0 — RELABELING ALARM")

    census = {}
    for r in claims:
        census[r["class"]] = census.get(r["class"], 0) + 1

    print(f"rows={len(claims)} unique-claims={len(set(ids))} "
          f"(ghost={len(ghost_rows)}/{gcount} model={len(model_rows)}/{mcount})")
    for k in sorted(census):
        print(f"  {k}: {census[k]}")
    if fails:
        print("GATE RED:")
        for f_ in fails:
            print("  -", f_)
        sys.exit(1)
    print("GATE GREEN (0 alarms)")
    print("REMINDER: GATE GREEN asserts the EVIDENCE matches the expected verdict "
          "inventory; it is NOT a completeness claim (PARTIALLY COMPLETE).")


if __name__ == "__main__":
    main()
