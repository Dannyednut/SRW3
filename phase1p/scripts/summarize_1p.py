#!/usr/bin/env python3
"""SRW3 Phase 1P (r2) — the fail-closed score summarizer.

Recomputes the phase score from the FULL runner CSV (transcripts/k/claims-
status-p.csv).  Rules (the 1O summarize discipline):
  * LAST-WINS per claim label (the CSV is append-only; re-runs supersede —
    e.g. the TDR/TDRR re-runs after finding 1P-F1's partition fix);
  * every expected-PASS/PASS-EVAL claim must be PROVED (WarnTrivialClaim
    allowed ONLY in the PASS-EVAL class — the 1M misclassification guard);
  * every expected-FAIL claim must NOT be proved;
  * ATTEMPT claims are recorded with their raw result (never relabeled);
  * PASS-SELF claims are recorded as self-assumed-not-a-proof;
  * the universal theorem is MECHANIZED iff 1P-UNIV-MACHINE-TDRR (or -TLR)
    is PROVED non-trivially — anything else is NOT MECHANIZED.
Exit 0 iff no ALARM and no INCORRECT in the last-wins view.
"""
import csv
import sys
from collections import OrderedDict
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
CSVF = HERE / "transcripts" / "k" / "claims-status-p.csv"
OUTF = HERE / "transcripts" / "k" / "score-p.txt"

def main() -> int:
    rows = list(csv.DictReader(CSVF.open()))
    last: "OrderedDict[str, dict]" = OrderedDict()
    for r in rows:
        last[r["claim"]] = r  # last-wins

    alarms, incorrect, passed, failed, attempts, selfs = [], [], 0, 0, [], 0
    for label, r in last.items():
        exp, raw, triv, corr = r["expected"], r["raw_result"], r["trivial"], r["correct"]
        if exp in ("PASS", "PASS-EVAL"):
            if raw == "PROVED" and (triv == "no" or exp == "PASS-EVAL"):
                passed += 1
            else:
                incorrect.append(label)
        elif exp == "PASS-SELF":
            selfs += 1
        elif exp == "FAIL":
            if raw != "PROVED":
                failed += 1
            else:
                alarms.append(label)
        elif exp == "ATTEMPT":
            attempts.append(f"{label}={raw}")
        if corr == "ALARM" and label not in alarms:
            alarms.append(label)
        if corr == "INCORRECT" and label not in incorrect:
            incorrect.append(label)

    univ = [last[l]["raw_result"] + ("/TRIV" if last[l]["trivial"] == "YES" else "")
            for l in ("1P-UNIV-MACHINE-TDRR", "1P-UNIV-MACHINE-TLR",
                      "1P-UNIV-MACHINE-TDR", "1P-UNIV-MACHINE-TD", "1P-UNIV-MACHINE-T")
            if l in last]
    mechanized = (last.get("1P-UNIV-MACHINE-TDRR", {}).get("raw_result") == "PROVED"
                  and last.get("1P-UNIV-MACHINE-TDRR", {}).get("trivial") == "no") or \
                 (last.get("1P-UNIV-MACHINE-TLR", {}).get("raw_result") == "PROVED"
                  and last.get("1P-UNIV-MACHINE-TLR", {}).get("trivial") == "no")

    lines = [
        f"# 1P K-ladder score (last-wins) — {len(last)} distinct claims",
        f"# PASS-expected proved      : {passed}",
        f"# FAIL-expected not-proved  : {failed}",
        f"# ATTEMPT claims (recorded) : {len(attempts)}",
        f"# SELF-assumed (the hole)   : {selfs}",
        f"# GATE ALARMS               : {len(alarms)} {alarms if alarms else ''}",
        f"# INCORRECT                 : {len(incorrect)} {incorrect if incorrect else ''}",
        f"# GATE                      : {'GREEN' if not alarms and not incorrect else 'RED'}",
        "#",
        "# THE UNIVERSAL ATTEMPTS (last-wins raw results):",
        *[f"#   {a}" for a in attempts if a.startswith("1P-UNIV") or a.startswith("T1-") or a.startswith("T2-")],
        "#",
        "# THE UNIVERSAL THEOREM IS MECHANIZED IFF 1P-UNIV-MACHINE-TDRR (or",
        "# 1P-UNIV-MACHINE-TLR with the trusted PRESV family) IS PROVED",
        "# NON-TRIVIALLY.",
        f"# VERDICT: {'THE UNIVERSAL THEOREM IS MECHANIZED' if mechanized else 'THE UNIVERSAL THEOREM IS NOT MECHANIZED'}",
        "# Whatever this file says, the phase disposition follows the raw",
        "# results and the logs.",
    ]
    OUTF.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0 if not alarms and not incorrect else 1

if __name__ == "__main__":
    sys.exit(main())
