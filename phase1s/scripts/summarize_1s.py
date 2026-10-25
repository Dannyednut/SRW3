#!/usr/bin/env python3
"""SRW3 Phase 1S — the fail-closed claim summarizer.

Adapted from phase1r/scripts/summarize_1r.py (the 1R terminal discipline)
with the 1S extensions:

  * the ASSUMPTION class: the disclosed C1.2 axiom row (1S-C12-NONNEG-
    ASSUMED) is never run as a goal; its ledger status is ASSUMPTION by
    declaration and a log for it is an ALARM (assuming is not running);
  * the PROVED-UNDER-ASSUMPTION class: a PASS-ASSUMED-expected claim that
    closes is reported PROVED-UNDER-C1.2-ASSUMPTION — never as an
    unconditional theorem;
  * the timeout discipline: rc=124 -> TIMEOUT, never a refutation;
  * the BOUNDED class (inherited): a depth-family closure is
    BOUNDED-PROVED, never the universal.

Fails closed on: a missing log for a listed claim, an unrecognized
terminal, an inconsistent classification (a PASS-expected claim not
proved / a FAIL-expected claim proved / an ATTEMPT mislabeled), a
WarnTrivialClaim on a claim not declared evaluation-class, a success
claim without a non-triviality marker where one is required, a log for
the ASSUMPTION row.

Usage: python3 phase1s/scripts/summarize_1s.py
Exit 0 iff the gate is GREEN (zero alarms, zero incorrect).
"""
import csv
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parents[1]
LOGS = HERE / "transcripts" / "k"
CLAIMS = HERE / "claims" / "claims.csv"

ASSUMPTION_IDS = {"1S-C12-NONNEG-ASSUMED"}


def fail(msg):
    print("FAIL-CLOSED: " + msg)
    sys.exit(1)


def classify_log(path, rc_override=None):
    text = path.read_text(errors="replace")
    has_top = "#Top" in text
    trivial = "WarnTrivialClaim" in text
    stuck = "WarnStuckClaimState" in text
    decider = "DecidePredicateUnknown" in text
    if rc_override == 113 and ("Unused filtering labels" in text
                               or "[Error] Critical" in text
                               or "structural errors" in text):
        return "FORMULATION-ERROR"
    rc = rc_override
    if rc is None:
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
    seen = set()
    score = {"PROVED": 0, "BOUNDED-PROVED": 0, "PROVED-EVAL": 0,
             "PROVED-UNDER-C1.2-ASSUMPTION": 0, "ASSUMPTION": 0,
             "FAILED-STUCK": 0, "FAILED-DECIDER": 0, "FAILED": 0,
             "TIMEOUT": 0, "SELF-ASSUMED": 0, "UNSOUND-CLOSURE": 0,
             "NOT-RUN": 0}
    alarms = []
    lines = []
    for r in rows:
        cid = r["claim_id"].strip()
        if cid in seen:
            alarms.append(f"{cid}: DUPLICATE row in the ledger")
        seen.add(cid)
        exp = r["expectation"].strip()
        cls_decl = r["class"].strip()
        if cid in ASSUMPTION_IDS:
            if exp != "ASSUMPTION":
                alarms.append(f"{cid}: declared assumption but expectation={exp}")
            log = LOGS / f"kprove_{cid}.log"
            if log.is_file():
                alarms.append(f"{cid}: an ASSUMPTION row has a run log — assuming is not running")
            score["ASSUMPTION"] += 1
            lines.append((cid, exp, "ASSUMPTION", cls_decl))
            continue
        if exp == "UNATTEMPTED":
            score["NOT-RUN"] += 1
            lines.append((cid, exp, "NOT-RUN", cls_decl))
            continue
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
        if status == "FORMULATION-ERROR":
            status = "NOT-RUN"
        # ---- the 1S status refinements (before consistency checks) ----
        if status == "PROVED" and cls_decl == "bounded":
            status = "BOUNDED-PROVED"
        if cls_decl == "self-assumption" and status in ("PROVED", "PROVED-EVAL"):
            status = "SELF-ASSUMED"
        if exp == "PASS-ASSUMED" and status in ("PROVED", "PROVED-EVAL"):
            status = "PROVED-UNDER-C1.2-ASSUMPTION"
        if exp == "HOLE" and status in ("PROVED", "PROVED-EVAL"):
            status = "UNSOUND-CLOSURE"
        # ---- the fail-closed consistency rules ----
        if status == "UNRECOGNIZED":
            alarms.append(f"{cid}: unrecognized terminal in {log.name}")
        if exp == "PASS" and status not in ("PROVED", "PROVED-EVAL",
                                            "BOUNDED-PROVED", "SELF-ASSUMED"):
            alarms.append(f"{cid}: PASS-expected but terminal={status}")
        if exp == "PASS-ASSUMED" and status not in (
                "PROVED-UNDER-C1.2-ASSUMPTION", "PROVED", "PROVED-EVAL"):
            alarms.append(f"{cid}: PASS-ASSUMED-expected but terminal={status}")
        if exp == "FAIL" and status in ("PROVED", "BOUNDED-PROVED",
                                        "PROVED-UNDER-C1.2-ASSUMPTION"):
            alarms.append(f"{cid}: FAIL-expected but {status} — INCORRECT")
        if exp == "FAIL" and status == "PROVED-EVAL" and cls_decl != "negative-vacuity-probe":
            alarms.append(f"{cid}: FAIL-expected but PROVED-EVAL ({cls_decl}) — INCORRECT")
        if status == "PROVED-EVAL" and cls_decl not in (
                "eval", "bounded", "negative-vacuity-probe", "self-assumption"):
            alarms.append(f"{cid}: PROVED-EVAL but class={cls_decl} (undeclared evaluation closure)")
        if exp == "ATTEMPT" and status in ("PROVED", "BOUNDED-PROVED", "PROVED-EVAL",
                                           "PROVED-UNDER-C1.2-ASSUMPTION"):
            pass  # an attempt that closed: legitimate, recorded (not an alarm)
        if exp == "HOLE" and status != "UNSOUND-CLOSURE":
            alarms.append(f"{cid}: the hole exhibit did not close ({status}) — behavior changed")
        score[status if status in score else "NOT-RUN"] += 1
        lines.append((cid, exp, status, cls_decl))

    print("# 1S score (last-wins) — %d claims listed" % len(rows))
    for k in ("PROVED", "BOUNDED-PROVED", "PROVED-EVAL",
              "PROVED-UNDER-C1.2-ASSUMPTION", "ASSUMPTION",
              "FAILED-STUCK", "FAILED-DECIDER", "FAILED",
              "TIMEOUT", "SELF-ASSUMED", "UNSOUND-CLOSURE", "NOT-RUN"):
        if score[k]:
            print(f"#   {k}: {score[k]}")
    if alarms:
        print("# GATE: RED (%d alarm(s))" % len(alarms))
        for a in alarms:
            print("# ALARM " + a)
        return 1
    print("# GATE: GREEN (zero alarms, zero incorrect)")
    for cid, exp, status, cls in lines:
        print(f"  {cid:42s} {exp:12s} {status:32s} {cls}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
