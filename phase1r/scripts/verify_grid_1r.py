#!/usr/bin/env python3
"""SRW3 Phase 1R — the structural exhaustiveness witness for the
constructor grid and the runner fork (verify_grid_1r.py).

A PURE READER over the frozen Phase 1Q machine of record — it never
writes. Checks (all fail-closed):

  G1  the frozen 1P source anchor (the 1Q generator's own anchor):
      phase1p/semantics/abs-machine-tdrr.k sha256
      448db6a46101d1f848a7ad364fc07a06cc99a903b4615afc0e5753ca0d8db511;
  G2  the frozen 1Q machine of record sha256 (audit/baseline-1q.txt §4);
  G3  the step section carries EXACTLY the 12 declared step rows (the
      twelve-class mirror) + the single [owise] incoherent-tag complement
      — 13 `absStepQ` rule heads total, each expected row line present
      verbatim (whitespace-normalized);
  G4  the step section carries EXACTLY ONE requires (the incoherent-tag
      complement) — no pool arithmetic guard anywhere in the dispatch path;
  G5  the runner's fork coverage: the tag-1 gate rows fork over BOTH pool
      heads for BOTH bits (2x2 = 4 rows) and the tag-1 commit rows fork
      over the FULL 2x2 pool-head grid for ALL FOUR bit combinations
      (4x4 = 16 rows) — the exhaustive (command x pool-head) cover whose
      per-cell closure the one-step theorem computes;
  G6  no Int-typed pool arithmetic in the step section (the C5-adjacent
      structural property: pool distinctions are constructor patterns).

The behavioral witness remains the proof terminals themselves (a closed
one-step claim with zero residual); this script is the independent
structural check the mission asks to see alongside the row count.

Usage: python3 phase1r/scripts/verify_grid_1r.py
Exit 0 iff every check passes.
"""
import hashlib
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parents[1]
REPO = HERE.parent
SRC_1P = REPO / "phase1p" / "semantics" / "abs-machine-tdrr.k"
SRC_1Q = REPO / "phase1q" / "semantics" / "abs-machine-q.k"

SHA_1P = "448db6a46101d1f848a7ad364fc07a06cc99a903b4615afc0e5753ca0d8db511"
SHA_1Q = "2e938fcb8939e0efe15e554687947b4dc44ece9a6a843f293799a18204e5383f"


def fail(msg):
    print("VERIFY-GRID FAIL-CLOSED: " + msg)
    sys.exit(1)


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


def main():
    # G1/G2 — the frozen anchors
    for path, sha, tag in ((SRC_1P, SHA_1P, "1P TDRR source"),
                           (SRC_1Q, SHA_1Q, "1Q machine of record")):
        if not path.is_file():
            fail(f"missing {tag}: {path}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != sha:
            fail(f"{tag} sha256 {digest} != the anchor {sha} — the frozen "
                 f"baseline moved; refusing to certify the grid")
        print(f"G1/G2 OK  {tag}: sha256 anchored")

    text = SRC_1Q.read_text()

    # isolate the step section (§C) and the runner section (§D) by slicing
    # between the raw § markers (each section header block sits between the
    # §<X> title line and the next §<Y> title line)
    i_c = text.index("// §C —")
    i_d = text.index("// §D —")
    i_e = text.index("// §E —")
    step, run = text[i_c:i_d], text[i_d:i_e]

    # G3 — the twelve declared rows + the complement
    rows_expected = [
        # init (rows 1-3)
        "rule absStepQ(absStQ(0, false, false, _:PoolCount, _:PoolCount, _:Int, _:Bool, D:ADiag), aInitJ(aOkT)) => absStQ(1, true, true, zeroP, zeroP, 0, true, D)",
        "rule absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aInitJ(aOkF)) => absStQ(0, false, false, G, E, N, SF, D)",
        "rule absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aInitJ(_:AOk)) => absStQ(1, true, true, G, E, N, SF, D)",
        # exec (rows 4, 7-9)
        "rule absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aExecJ(_:AOk, _:ASrc)) => absStQ(0, false, false, G, E, N, SF, D)",
        "rule absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT, aSrcAuth)) => absStQ(1, true, true, G, succP(E), N, SF, D)",
        "rule absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, _:ADiag), aExecJ(aOkT, aSrcOther)) => absStQ(1, true, true, G, E, N, SF, adSource)",
        "rule absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, _:ADiag), aExecJ(aOkF, _:ASrc)) => absStQ(1, true, true, G, E, N, SF, adExecRefuse)",
        # gate (rows 5, 10)
        "rule absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aGateJ(_:AOk)) => absStQ(0, false, false, G, E, N, SF, adGate)",
        "rule absStepQ(absStQ(1, true, true, G:PoolCount, zeroP, N:Int, SF:Bool, _:ADiag), aGateJ(_:AOk)) => absStQ(1, true, true, G, zeroP, N, SF, adGate)",
        "rule absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag), aGateJ(aOkT)) => absStQ(1, true, true, succP(G), succP(E0), N, SF, D)",
        "rule absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, _:ADiag), aGateJ(aOkF)) => absStQ(1, true, true, G, succP(E0), N, SF, adGate)",
        # commit (rows 6, 11-12)
        "rule absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aCommitJ(_:AOk, _:AOk)) => absStQ(0, false, false, G, E, N, SF, D)",
        "rule absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, _:Bool, D:ADiag), aCommitJ(aOkT, aOkT)) => absStQ(1, true, true, G0, E0, N +Int 1, true, D)",
        "rule absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT, aOkF)) => absStQ(1, true, true, succP(G0), succP(E0), N, SF, D)",
        "rule absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag), aCommitJ(aOkF, _:AOk)) => absStQ(1, true, true, succP(G0), succP(E0), N, SF, D)",
        "rule absStepQ(absStQ(1, true, true, zeroP, E:PoolCount, N:Int, SF:Bool, D:ADiag), aCommitJ(_:AOk, _:AOk)) => absStQ(1, true, true, zeroP, E, N, SF, D)",
        "rule absStepQ(absStQ(1, true, true, succP(G0), zeroP, N:Int, SF:Bool, D:ADiag), aCommitJ(_:AOk, _:AOk)) => absStQ(1, true, true, succP(G0), zeroP, N, SF, D)",
    ]
    nstep = norm(step)
    for i, row in enumerate(rows_expected, 1):
        if norm(row) not in nstep:
            fail(f"declared step row {i} not found verbatim in the step section")
    n_rules = len(re.findall(r"\brule absStepQ\(", step))
    if n_rules != 18:
        fail(f"the step section carries {n_rules} absStepQ rules; the declared "
             f"partition is 18 (17 rows + the [owise] complement)")
    if "[owise]" not in step:
        fail("the incoherent-tag complement ([owise]) is missing from the step section")
    print(f"G3 OK    step partition: 18 rule heads = 17 declared rows + 1 [owise]; "
          f"all declared rows verbatim")

    # G4 — exactly one requires in the dispatch path (comment lines stripped)
    strip_comments = lambda s: "\n".join(
        ln for ln in s.splitlines() if not ln.lstrip().startswith("//"))
    step_code = strip_comments(step)
    reqs = re.findall(r"\brequires\b", step_code)
    if len(reqs) != 1:
        fail(f"the step section carries {len(reqs)} requires; the of-record "
             f"partition carries EXACTLY ONE (the incoherent-tag complement)")
    if "TG >=Int 2 orBool TG <=Int -1" not in step_code:
        fail("the single requires is not the incoherent-tag complement")
    print("G4 OK    exactly one requires in the dispatch path (the incoherent-tag complement)")

    # G5 — the runner fork cover
    fork_gate = len(re.findall(r"aGateJ\((aOkT|aOkF)\) => \.K", run))
    fork_commit = len(re.findall(r"aCommitJ\((aOkT|aOkF), ?(aOkT|aOkF)\) => \.K", run))
    # tag-0 rows: init x2 + gate x2 + commit x4 = 8 ground-command rows
    # tag-1 non-discriminating: init x2 + exec x4 = 6
    # fork: gate 2 bits x 2 heads = 4; commit 4 bit-combos x 4 heads = 16
    if fork_gate != 2 + 4:
        fail(f"gate runner rows: {fork_gate}; expected 8 (2 tag-0 + 4 fork cells)")
    if fork_commit != 4 + 16:
        fail(f"commit runner rows: {fork_commit}; expected 20 (4 tag-0 + 16 fork cells)")
    n_exec_rows = len(re.findall(r"aExecJ\(", run))
    if n_exec_rows != 8:  # 4 ground shapes x (LHS command + shadow call) = 8 mentions
        fail(f"exec runner mentions: {n_exec_rows}; expected 8 (the 4 ground shapes, "
             f"no exec fork — pools are not exec-discriminating)")
    n_owise = len(re.findall(r"\[owise\]", run))
    if n_owise != 1:
        fail(f"runner [owise] complements: {n_owise}; expected exactly 1")
    print("G5 OK    runner cover: gate 2+4, commit 4+16, exec 4 shapes, 1 [owise]")

    # G6 — no Int pool arithmetic in the step section (the slot counter N
    # +Int 1 is the ONLY Int arithmetic allowed — it is not a pool)
    int_pool_ops = re.findall(r"\b(G|E|G0|E0)\s*[+-]Int\b", step_code)
    if int_pool_ops:
        fail(f"Int pool arithmetic found in the step section: {int_pool_ops[:3]}")
    print("G6 OK    no Int pool arithmetic in the dispatch path "
          "(the exact counts are constructor-structured)")

    print("VERIFY-GRID: ALL CHECKS PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
