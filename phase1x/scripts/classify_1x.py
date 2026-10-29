#!/usr/bin/env python3
"""SRW3 Phase 1X — the result classifier (classify_1x.py).

ONE classification function, used by BOTH the Phase 1X ghost runner
(run_1x_ghost.sh calls this script per claim) and the Phase 1X regression
fixtures — so the runner's verdict logic and the tested logic cannot drift.

Status vocabulary (closed; see phase1x/claims/expected-ghost-inventory.json
_status_vocabulary and the report §B):

  PROVED        rc=0 AND >=1 '#Top' marker AND no prover '[Error]' line
                AND no 'WarnStuckClaimState' warning.
  FAILED-STUCK  rc=1 AND the stuck signature present in the log:
                'WarnStuckClaimState' AND 'backend terminated'
                (the prover could not make progress: configuration unifies
                with the destination but the implication check failed).
  FAILED        rc=1 WITHOUT the full stuck signature (a prover failure that
                is not evidenced as stuck — recorded limitation: a generic
                rc=1 alone cannot distinguish a genuine refutation from
                other prover failures; only the stuck signature is
                machine-checkable on the pinned toolchain, so this class is
                deliberately narrow and anything unrecognized fails the run).
  TIMEOUT       rc=124 (the configured budget was exhausted — never
                relabeled as proof or disproof).
  NOT-RUN       no execution result available (missing log with rc=None).
  INVALID-SUCCESS rc=0 but closure evidence absent/mixed (missing #Top,
                prover error, or stuck warning) — a success-shaped exit that
                is NOT classifiable as PROVED. The runner treats any
                INVALID-SUCCESS as a hard failure.
  UNKNOWN       any other nonzero exit code — unrecognized; hard failure.

Output (single line, machine-parsable):
  status=<STATUS> top=<n> stuck=<n> backenderr=<n> err=<n>
Exit code: 0 when a classification was determined (even a failing one —
the CALLER decides expected-vs-observed); 2 on usage errors.
"""
import argparse
import os
import sys

STUCK_TOKEN = "WarnStuckClaimState"
BACKENDERR_TOKEN = "backend terminated"
TOP_TOKEN = "#Top"
ERR_TOKEN = "[Error]"


def classify(rc, log):
    """rc: int or None; log: path or None. Returns (status, evidence-dict)."""
    counts = {"top": 0, "stuck": 0, "backenderr": 0, "err": 0}
    text = ""
    if log is not None and os.path.exists(log):
        with open(log, errors="replace") as f:
            text = f.read()
        counts["top"] = text.count(TOP_TOKEN)
        counts["stuck"] = text.count(STUCK_TOKEN)
        counts["backenderr"] = text.count(BACKENDERR_TOKEN)
        counts["err"] = text.count(ERR_TOKEN)
    log_present = log is not None and os.path.exists(log)

    if rc == 124:
        return "TIMEOUT", counts
    if not log_present:
        return "NOT-RUN", counts
    if rc == 0:
        if counts["top"] >= 1 and counts["err"] == 0 and counts["stuck"] == 0:
            return "PROVED", counts
        return "INVALID-SUCCESS", counts
    if rc == 1:
        if counts["stuck"] >= 1 and counts["backenderr"] >= 1:
            return "FAILED-STUCK", counts
        return "FAILED", counts
    return "UNKNOWN", counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rc", type=int, default=None)
    ap.add_argument("--log", default=None)
    a = ap.parse_args()
    status, counts = classify(a.rc, a.log)
    print(f"status={status} top={counts['top']} stuck={counts['stuck']} "
          f"backenderr={counts['backenderr']} err={counts['err']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
