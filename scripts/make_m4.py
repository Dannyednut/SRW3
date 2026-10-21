#!/usr/bin/env python3
"""SRW3 Phase 1N — generate the M4 machine: M3 + exactly ONE disclosed edit.

THE DISCLOSED EDIT (the only difference between phase1m/semantics/
srw3closure-j-m3.k and phase1n/semantics/srw3closure-j-m4.k):

  The configuration declaration gains ONE cell:

      <absjshadow> $ABS:K </absjshadow>

  — the abstract-transition-simulation shadow state (Phase 1N).  No rule of
  the M3 machine mentions the shadow cell, so every frozen M3 transition is
  UNCHANGED (K rules match the cells they name; an extra cell is inert).
  The cell carries the AState of the abstract machine defined additively in
  phase1n/semantics/abs-machine.k (module SRW3N-ABS), which also defines the
  runner/steps over <absjshadow> and the simulation projections.

  The machine module is renamed SRW3CLOSURE-J-M3 -> SRW3CLOSURE-J-M4 so both
  machines can coexist in one proof environment (the 1M KB/MC OLD/NEW
  discipline).

Roundtrip discipline (the make_m2.py/make_m3.py standard): the generator is
the single source of truth; the diff of record is checked (exactly the
disclosed edit) and the sha256 of both files is printed.
"""
import hashlib
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
SRC = REPO / "phase1m" / "semantics" / "srw3closure-j-m3.k"
DST = REPO / "phase1n" / "semantics" / "srw3closure-j-m4.k"

OLD = """  configuration <srw3closureJ>
                  <k> $PGM:PProgJI </k>"""

NEW = """  configuration <srw3closureJ>
                  // PHASE 1N DISCLOSED EDIT (the ONLY M3 -> M4 difference):
                  // the abstract-transition-simulation shadow state.  NO M3
                  // rule mentions this cell; it is read/written ONLY by the
                  // additive Phase 1N module (SRW3N-ABS, abs-machine.k) and
                  // by the 1N claims.  Everything else is the frozen M3
                  // machine byte-for-byte.
                  <absjshadow> $ABS:K </absjshadow>
                  <k> $PGM:PProgJI </k>"""


def main() -> int:
    text = SRC.read_text()
    if text.count(OLD) != 1:
        print(f"FATAL: anchor found {text.count(OLD)} times (expected 1)", file=sys.stderr)
        return 1
    out = text.replace(OLD, NEW)
    # the machine's module is renamed so both machines can coexist in proofs
    out = out.replace("module SRW3CLOSURE-J-M3", "module SRW3CLOSURE-J-M4", 1)
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text(out)

    # ---- roundtrip verification: the ONLY diffs are the disclosed edit ----
    import difflib

    diff = list(
        difflib.unified_diff(
            text.splitlines(keepends=True),
            out.splitlines(keepends=True),
            fromfile="m3",
            tofile="m4",
        )
    )
    changed = [l for l in diff if (l.startswith("+") or l.startswith("-")) and not l.startswith(("+++", "---"))]
    added = [l for l in changed if l.startswith("+")]
    removed = [l for l in changed if l.startswith("-")]
    ok = (
        len(removed) == 1  # the module-name line (renamed)
        and len(added) == 8  # 6 inserted disclosure lines + shadow cell + renamed module line
        and any("<absjshadow> $ABS:K </absjshadow>" in l for l in added)
        and any("module SRW3CLOSURE-J-M4" in l for l in added)
        and not any("pInitJ" in l or "pExecJ" in l or "pGateEvalJ" in l or "pCommitJ" in l for l in changed)
    )
    print("roundtrip diff: +%d/-%d lines; disclosed-edit-only=%s" % (len(added), len(removed), ok))
    print("sha256 m3:", hashlib.sha256(text.encode()).hexdigest())
    print("sha256 m4:", hashlib.sha256(out.encode()).hexdigest())
    return 0 if ok else 2


if __name__ == "__main__":
    sys.exit(main())
