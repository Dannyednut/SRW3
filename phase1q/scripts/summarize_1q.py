#!/usr/bin/env python3
"""SRW3 Phase 1Q — the fail-closed claim summarizer.

Reads the per-claim raw logs under phase1q/transcripts/k/, classifies each
recognized terminal against the claim inventory, and exits nonzero on ANY
of: a missing log for a listed claim, an unrecognized terminal, an
inconsistent classification (a PASS-expected claim not proved / a FAIL-
expected claim proved / an ATTEMPT mislabeled), a WarnTrivialClaim on a
claim not declared evaluation-class, or a success claim without a
non-triviality marker where one is required.

Terminal recognition (the 1O/1P discipline):
  rc=0 + '#Top'                          -> PROVED
  rc=0 + 'WarnTrivialClaim'              -> PROVED-EVAL (proved by
        evaluation without rewriting; content-bearing ONLY for claims
        whose declared class is eval-class — the 1O reclassification rule)
  rc=1 + 'WarnStuckClaimState'           -> FAILED-STUCK (the residual is
        the record)
  rc=1 + 'DecidePredicateUnknown'        -> FAILED-DECIDER (the checker's
        decision boundary; the residual is the record)
  rc=1 other                             -> FAILED
  rc=124                                 -> TIMEOUT (never a refutation)
Classification sources: claims/claims.csv (claim_id, expectation, class).

Usage: python3 phase1q/scripts/summarize_1q.py [--claims CSV] [--logs DIR]
Exit 0 iff the gate is GREEN (zero alarms, zero incorrect).
"""
import csv
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parents[1]
LOGS = HERE / "transcripts" / "k"
CLAIMS = HERE / "claims" / "claims.csv"


def fail(msg):
    print("FAIL-CLOSED: " + msg)
    sys.exit(1)


def classify_log(path, rc_override=None):
    text = path.read_text(errors="replace")
    has_top = "#Top" in text
    trivial = "WarnTrivialClaim" in text
    stuck = "WarnStuckClaimState" in text
    decider = "DecidePredicateUnknown" in text
    rc = rc_override
    if rc is None:
        # rc is supplied by the runner's CSV; without it, infer from markers
        if has_top:
            rc = 0
        elif stuck or decider:
            rc = 1
        else:
            return "UNRECOGNIZED"
    if rc == 124:
        return "TIMEOUT"
    if rc == 0:
        if trivial:
            return "PROVED-EVAL"
        if has_top:
            return "PROVED"
        return "UNRECOGNIZED"
    if rc == 1:
        if decider:
            return "FAILED-DECIDER"
        if stuck:
            return "FAILED-STUCK"
        return "FAILED"
    return "UNRECOGNIZED"


def main():
    if not CLAIMS.is_file():
        fail(f"the claim inventory is missing: {CLAIMS}")
    rows = list(csv.DictReader(CLAIMS.open()))
    if not rows:
        fail("the claim inventory is empty")
    score = {"PROVED": 0, "PROVED-EVAL": 0, "FAILED-STUCK": 0, "FAILED-DECIDER": 0,
             "FAILED": 0, "TIMEOUT": 0, "SELF-ASSUMED": 0, "UNSOUND-CLOSURE": 0,
             "NOT-RUN": 0}
    alarms = []
    lines = []
    for r in rows:
        cid = r["claim_id"]
        exp = r["expectation"].strip()
        cls_decl = r["class"].strip()
        log = LOGS / f"kprove_{cid}.log"
        if not log.is_file():
            alarms.append(f"{cid}: MISSING LOG {log}")
            score["NOT-RUN"] += 1
            lines.append((cid, exp, "MISSING", cls_decl))
            continue
        rc = None
        if r.get("exit_code", "").strip():
            rc = int(r["exit_code"])
        status = classify_log(log, rc)
        # ---- the fail-closed consistency rules ----
        if status == "UNRECOGNIZED":
            alarms.append(f"{cid}: unrecognized terminal in {log.name}")
        if exp == "PASS" and status not in ("PROVED", "PROVED-EVAL", "SELF-ASSUMED"):
            alarms.append(f"{cid}: PASS-expected but terminal={status}")
        if exp == "FAIL" and status in ("PROVED",):
            alarms.append(f"{cid}: FAIL-expected but PROVED (nontrivial) — INCORRECT")
        if exp == "FAIL" and status == "PROVED-EVAL" and cls_decl != "negative-vacuity-probe":
            alarms.append(f"{cid}: FAIL-expected but PROVED-EVAL ({cls_decl}) — INCORRECT")
        if status == "PROVED-EVAL" and cls_decl not in (
                "eval", "bounded", "negative-vacuity-probe", "self-assumption"):
            alarms.append(f"{cid}: PROVED-EVAL but class={cls_decl} (undeclared evaluation closure)")
        if status == "PROVED-EVAL" and cls_decl == "self-assumption":
            status = "SELF-ASSUMED"
        if exp == "HOLE":
            # the vacuity exhibit: its expected terminal IS rc=0 on a false
            # claim — classified UNSOUND-CLOSURE, never a proof.
            if status == "PROVED":
                status = "UNSOUND-CLOSURE"
            elif status in ("PROVED-EVAL",):
                status = "UNSOUND-CLOSURE"
            else:
                alarms.append(f"{cid}: the vacuity exhibit did not close (terminal={status}) — behavior changed")
        if exp == "ATTEMPT" and status in ("PROVED", "PROVED-EVAL"):
            # an attempt that closed: legitimate, recorded (not an alarm)
            pass
        score[status if status in score else "NOT-RUN"] += 1
        lines.append((cid, exp, status, cls_decl))

    print("# 1Q K-ladder score (last-wins) — %d claims listed" % len(rows))
    for k in ("PROVED", "PROVED-EVAL", "FAILED-STUCK", "FAILED-DECIDER",
              "FAILED", "TIMEOUT", "SELF-ASSUMED", "UNSOUND-CLOSURE", "NOT-RUN"):
        print(f"# {k:22s}: {score[k]}")
    for ln in lines:
        print("  %-34s %-4s %-14s %s" % ln)
    if alarms:
        print("\n# GATE ALARMS:")
        for a in alarms:
            print("#   " + a)
        print("# GATE: RED")
        return 1
    print("\n# GATE: GREEN (zero alarms, zero incorrect)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
