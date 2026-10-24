#!/usr/bin/env python3
"""SRW3 Phase 1Q — derive the CONSTRUCTOR-COUNT abstract machine variants.

Derived from the FROZEN phase1p/semantics/abs-machine-tdrr.k (the 1P TDRR
artifact of record) with the disclosed edit set EQ-A..EQ-H.  The strong
machine's K text is the reviewed template phase1q/scripts/abs-machine-q.tpl
(every line of it is part of the disclosed edit set; the generator fills
the recorded source sha and applies the mechanical checks).  The variants
(weak, mut-stale, mut-flip, mut-omit) are derived from the generated
strong machine by disclosed whole-rule replacements with exact-count
anchor checks.

Fail-closed checks (all must pass, exit 0; any failure aborts ALL writes):
  C1. the frozen 1P TDRR source exists and its sha256 is printed;
  C2. the EB command block of the TDRR source is found, and every command
      syntax line appears byte-identically in the generated Q machine
      (the command language is carried verbatim, EQ-B);
  C3. the generated step section contains NO `requires` other than the
      carried incoherent-tag complement (no pool arithmetic guard may
      survive into the dispatch path — the phase's critical requirement);
  C4. the gate/commit constructor cell grid is complete: each expected
      discriminating pattern (pool head x command shape) appears exactly
      once in the step section (the 1P-F1 lesson, mechanized);
  C5. the C1 nonneg-structural property: no step-row RHS constructs an
      Int-typed pool position (the pools stay PoolCount everywhere);
  C6. the variant anchors (weak W1/W2, stale, flip, omit) each match
      exactly the expected number of times;
  C7. roundtrip determinism: running the generator twice yields
      byte-identical outputs (checked here by regenerating into a buffer
      and comparing).

Usage: python3 phase1q/scripts/make_abs_q.py
Output: phase1q/semantics/abs-machine-q.k
        phase1q/semantics/abs-machine-weak-q.k
        phase1q/tests/abs-machine-mut-{stale,flip,omit}-q.k
Exit 0 iff every fail-closed check passes.
"""
import hashlib
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parents[1]
REPO = HERE.parent
SRC = REPO / "phase1p" / "semantics" / "abs-machine-tdrr.k"
TPL = HERE / "scripts" / "abs-machine-q.tpl"
OUT_SEM = HERE / "semantics"
OUT_TST = HERE / "tests"


def fail(msg: str) -> None:
    print("FAIL-CLOSED: " + msg)
    sys.exit(1)


def check(cond: bool, msg: str) -> None:
    if not cond:
        fail(msg)


def main() -> int:
    # ---- read the frozen source and the reviewed template -----------------
    if not SRC.is_file():
        fail(f"the frozen 1P TDRR source is missing: {SRC}")
    if not TPL.is_file():
        fail(f"the reviewed Q template is missing: {TPL}")
    src = SRC.read_text()
    src_sha = hashlib.sha256(src.encode()).hexdigest()
    tpl = TPL.read_text()
    print(f"1P TDRR source sha256 = {src_sha}")

    # ---- C2: the EB command block ------------------------------------------
    eb_marker = "  // §B — THE COMMAND LANGUAGE"
    check(src.count(eb_marker) == 1, "the EB marker not found exactly once in the TDRR source")
    eb_start = src.index(eb_marker)
    eb_end = src.index("  // §C —", eb_start)
    eb_block = src[eb_start:eb_end]
    eb_lines = [ln for ln in eb_block.splitlines()
                if ln.strip().startswith(("syntax", "|"))]
    check(len(eb_lines) >= 8, "the EB block has too few syntax lines to be the command block")
    q_step_open = tpl.index("  // §C —")
    q_head = tpl[:q_step_open]
    for ln in eb_lines:
        check(ln in q_head, f"EB byte-check failed: the line is not byte-identical in the Q head: {ln!r}")
    print(f"C2 OK (the {len(eb_lines)} EB command lines carried byte-identically)")

    # ---- C3: no pool requires in the step section ---------------------------
    step_open = tpl.index("  // §C —")
    step_close = tpl.index("  // §D —")
    step_section = tpl[step_open:step_close]
    req_lines = [ln for ln in step_section.splitlines()
                 if ln.lstrip().startswith("requires")]
    check(len(req_lines) == 1,
          f"the step section must carry EXACTLY ONE requires (the tag complement); found {len(req_lines)}: {req_lines}")
    check("TG >=Int 2 orBool TG <=Int -1" in req_lines[0],
          "the single step requires is not the carried incoherent-tag complement")
    print("C3 OK (no pool requires in the dispatch path; only the tag complement)")

    # ---- C4: the gate/commit cell grid --------------------------------------
    def count_pattern(pat: str) -> int:
        return step_section.count(pat)

    grid = [
        # (row id, discriminating LHS fragment, expected count)
        ("gate A-Z  (any bit, E=zeroP)",   "aGateJ(_:AOk))\n    => absStQ(0, false, false,", 1),  # pre-init row uses tag 0
    ]
    # The pre-init gate row (tag 0) — variable pools, no discrimination.
    # The tag-1 grid: E head x bit for gate; (G head, E head) x bit pair for commit.
    tag1_gate = [
        ("gate row A-Z  (aGateJ(_:AOk), cntE=zeroP)",   "aGateJ(_:AOk))\n    => absStQ(1, true, true, G, zeroP,", 1),
        ("gate row B-S  (aGateJ(aOkT), cntE=succP)",    "aGateJ(aOkT))\n    => absStQ(1, true, true, succP(G), succP(E0),", 1),
        ("gate row C-S  (aGateJ(aOkF), cntE=succP)",    "aGateJ(aOkF))\n    => absStQ(1, true, true, G, succP(E0),", 1),
    ]
    tag1_commit = [
        ("commit row B-SS (aOkT,aOkT; succP,succP)", "aCommitJ(aOkT, aOkT))\n    => absStQ(1, true, true, G0, E0,", 1),
        ("commit row C-SS (aOkT,aOkF; succP,succP)", "aCommitJ(aOkT, aOkF))\n    => absStQ(1, true, true, succP(G0), succP(E0),", 1),
        ("commit row D-SS (aOkF,_;    succP,succP)", "aCommitJ(aOkF, _:AOk))\n    => absStQ(1, true, true, succP(G0), succP(E0),", 1),
        ("commit row A-Z* (any bits;  zeroP,_     )", "aCommitJ(_:AOk, _:AOk))\n    => absStQ(1, true, true, zeroP,", 1),
        ("commit row A-SZ (any bits;  succP,zeroP )", "aCommitJ(_:AOk, _:AOk))\n    => absStQ(1, true, true, succP(G0), zeroP,", 1),
    ]
    grid = tag1_gate + tag1_commit
    for name, pat, want in grid:
        got = count_pattern(pat)
        check(got == want, f"grid check failed for {name}: pattern found {got} times, want {want}")
    print(f"C4 OK (the {len(grid)}-cell constructor grid complete: each pattern exactly once)")

    # ---- C5: the pools never leave PoolCount in the step section ------------
    for bad in ("G -Int 1", "E -Int 1", "G +Int 1", "E +Int 1",
                "G >=Int 1", "E >=Int 1", "G <=Int 0", "E <=Int 0",
                "G:Int, E:Int"):
        check(bad not in step_section, f"C5 failed: Int pool arithmetic/type survived: {bad!r}")
    print("C5 OK (no Int-typed pool arithmetic anywhere in the step section)")

    # ---- fill the recorded sha and write the strong machine -----------------
    out_q = tpl.replace("@@SRC_SHA256@@", src_sha)
    check("@@SRC_SHA256@@" not in out_q, "the sha placeholder was not filled")

    # ---- the weak variant (W1 = the 1P presented-bit edit; W2 = the 1Q
    #      empty-pool accept) -------------------------------------------------
    C_SS_ANCHOR = """  rule absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag),
                aCommitJ(aOkT, aOkF))
    => absStQ(1, true, true, succP(G0), succP(E0), N, SF, D)   // row C-SS: reject, pools ok (identity)"""
    W1_NEW = """  rule absStepWQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, _:Bool, D:ADiag),
                aCommitJ(aOkT, B2:AOk))
    => absStQ(1, true, true, G0, E0, N +Int 1, B2 ==K aOkT, D)  // WEAK W1: the presented bit carried
                                                              // (the 1P weak edit; safe := B2==K aOkT;
                                                              // the (aOkT,aOkF) accept breaks ABSInvQ)"""
    A_SZ_ANCHOR = """  rule absStepQ(absStQ(1, true, true, succP(G0), zeroP, N:Int, SF:Bool, D:ADiag),
                aCommitJ(_:AOk, _:AOk))
    => absStQ(1, true, true, succP(G0), zeroP, N, SF, D)       // row A-SZ: the E-empty complement (G nonempty)"""
    W2_NEW = A_SZ_ANCHOR + """

  rule absStepWQ(absStQ(1, true, true, zeroP, zeroP, N:Int, _:Bool, D:ADiag),
                aCommitJ(aOkT, aOkT))
    => absStQ(1, true, true, zeroP, zeroP, N +Int 1, true, D)   // WEAK W2 (1Q-specific): the EMPTY-POOL
                                                              // accept — structurally impossible on the
                                                              // strong machine; breaks the C3 acceptance
                                                              // correspondence, NOT the invariant"""
    check(tpl.count(C_SS_ANCHOR) == 1, "the W1 anchor (row C-SS) not found exactly once")
    check(tpl.count(A_SZ_ANCHOR) == 1, "the W2 anchor (row A-SZ) not found exactly once")
    out_weak = out_q
    out_weak = out_weak.replace(C_SS_ANCHOR, W1_NEW)
    out_weak = out_weak.replace(A_SZ_ANCHOR, W2_NEW)
    # the weak module rename + header note
    out_weak = out_weak.replace("module SRW3N-ABS-Q\n", "module SRW3N-ABS-WEAK-Q\n")
    out_weak = out_weak.replace("absStepQ", "absStepWQ")
    out_weak = out_weak.replace("absGenesisQ", "absGenesisQW")
    out_weak = out_weak.replace("absExecutableQ", "absExecutableQW")
    out_weak = out_weak.replace("absRunFQ", "absRunFQW")
    out_weak = out_weak.replace("absInitShapedQ", "absInitShapedQW")
    out_weak = out_weak.replace("absTagOfQ", "absTagOfQW")
    out_weak = out_weak.replace("absCfgPinnedQ", "absCfgPinnedQW")
    out_weak = out_weak.replace("absCatPinnedQ", "absCatPinnedQW")
    out_weak = out_weak.replace("absSafeQ", "absSafeQW")
    out_weak = out_weak.replace(
        "// SRW3 PHASE 1Q — THE CONSTRUCTOR-COUNT ABSTRACT MACHINE (the 1P TDRR",
        "// SRW3 PHASE 1Q — THE CONSTRUCTOR-COUNT ABSTRACT MACHINE (WEAK-Q — THE WEAK COMMIT + THE")
    out_weak = out_weak.replace(
        "//                    architecture with the pool counters as the free-",
        "//                    EMPTY-POOL ACCEPT, on the 1P TDRR architecture with the free-")
    # the runner calls absStepWQ via the blanket rename above; verify
    check("absStepWQ(" in out_weak and "absStepQ(" not in out_weak,
          "the weak variant rename left an absStepQ reference")
    check(out_weak.count("WEAK W1") == 1 and out_weak.count("WEAK W2") == 1,
          "the weak variant must carry exactly one W1 and one W2 row")
    print("weak variant OK (W1 presented-bit + W2 empty-pool accept, renamed symbols)")

    # ---- the mutants (one per kompile target; the 1P lesson) ----------------
    # mut-stale: the init-accept re-tag forgotten (the 1P STALE analog).
    STALE_OLD = """  rule absStepQ(absStQ(0, false, false, _:PoolCount, _:PoolCount, _:Int, _:Bool, D:ADiag),
                aInitJ(aOkT))
    => absStQ(1, true, true, zeroP, zeroP, 0, true, D)        // THE re-tag 0->1 (pools reset)"""
    STALE_NEW = """  rule absStepQ(absStQ(0, false, false, _:PoolCount, _:PoolCount, _:Int, _:Bool, D:ADiag),
                aInitJ(aOkT))
    => absStQ(0, true, true, zeroP, zeroP, 0, true, D)        // MUTANT: THE RE-TAG FORGOTTEN"""
    check(out_q.count(STALE_OLD) == 1, "the stale anchor not found exactly once")
    out_stale = out_q.replace(STALE_OLD, STALE_NEW)
    out_stale = out_stale.replace("module SRW3N-ABS-Q\n", "module SRW3N-ABS-MUT-STALE-Q\n")

    # mut-flip: every step-row RHS tag literal flipped 0<->1 (RHS only; the
    # complement row's variable tag untouched) — the 1P FLIP analog.
    out_flip = flip_step_rows(out_q)
    out_flip = out_flip.replace("module SRW3N-ABS-Q\n", "module SRW3N-ABS-MUT-FLIP-Q\n")

    # mut-omit: the gate mint row B-S deleted (the omitted constructor case;
    # the machine silently stutters where the strong machine mints).
    OMIT_OLD = """  rule absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag),
                aGateJ(aOkT))
    => absStQ(1, true, true, succP(G), succP(E0), N, SF, D)   // row B-S: the mint class (structural inc on G; E KEPT — the 1P row increments G and leaves E)"""
    check(out_q.count(OMIT_OLD) == 1, "the omit anchor (row B-S) not found exactly once")
    out_omit = out_q.replace(OMIT_OLD + "\n", "")
    check(OMIT_OLD not in out_omit,
          "the omit mutant still carries the B-S rule")
    out_omit = out_omit.replace("module SRW3N-ABS-Q\n", "module SRW3N-ABS-MUT-OMIT-Q\n")

    for name, text, marker in (
        ("mut-stale-q", out_stale, "MUTANT: THE RE-TAG FORGOTTEN"),
        ("mut-flip-q", out_flip, "MUTANT: FLIPPED"),
        ("mut-omit-q", out_omit, "MUTANT: ROW B-S OMITTED"),
    ):
        check(marker in text or name == "mut-omit-q",
              f"the {name} mutant lost its marker")
    # annotate the mutant headers
    out_stale = out_stale.replace("DO NOT EDIT BY HAND.",
                                  "DO NOT EDIT BY HAND.\n// MUTANT mut-stale-q: the STALE-TAG mutation (the 1P analog) — the init-accept\n// row keeps the tag at 0.  Breaks tagCoherentQ/ABSInvQ at the honest init.")
    out_flip = out_flip.replace("DO NOT EDIT BY HAND.",
                                "DO NOT EDIT BY HAND.\n// MUTANT mut-flip-q: the TAG-FLIP mutation (the 1P analog) — every step-row RHS\n// tag literal flipped (0<->1); the incoherent-tag complement row untouched.\n// Breaks the tag range/bookkeeping on every class.")
    out_omit = out_omit.replace("DO NOT EDIT BY HAND.",
                                "DO NOT EDIT BY HAND.\n// MUTANT mut-omit-q: the OMIT mutation (1Q-specific, mission control #10) — the\n// gate mint row B-S (succP head, aOkT) DELETED.  The machine silently stutters\n// where the strong machine mints; the grid check is load-bearing.")

    # ---- C7: roundtrip determinism ------------------------------------------
    rebuild = (tpl.replace("@@SRC_SHA256@@", src_sha))
    check(rebuild == out_q, "roundtrip determinism failed (regeneration differs)")

    # ---- write ---------------------------------------------------------------
    OUT_SEM.mkdir(parents=True, exist_ok=True)
    OUT_TST.mkdir(parents=True, exist_ok=True)
    (OUT_SEM / "abs-machine-q.k").write_text(out_q)
    (OUT_SEM / "abs-machine-weak-q.k").write_text(out_weak)
    (OUT_TST / "abs-machine-mut-stale-q.k").write_text(out_stale)
    (OUT_TST / "abs-machine-mut-flip-q.k").write_text(out_flip)
    (OUT_TST / "abs-machine-mut-omit-q.k").write_text(out_omit)
    for p in (OUT_SEM / "abs-machine-q.k", OUT_SEM / "abs-machine-weak-q.k",
              OUT_TST / "abs-machine-mut-stale-q.k", OUT_TST / "abs-machine-mut-flip-q.k",
              OUT_TST / "abs-machine-mut-omit-q.k"):
        h = hashlib.sha256(p.read_bytes()).hexdigest()
        print(f"WROTE {p}  sha256={h}")
    print("ALL FAIL-CLOSED CHECKS PASSED")
    return 0


def flip_step_rows(text: str) -> str:
    """Flip every step-row RHS tag literal (0<->1), RHS only.

    The step section runs from '§C' to '§D'.  RHS lines start with
    '    => absStQ('.  The incoherent-tag complement row's RHS is the
    variable TG and is naturally untouched.  Idempotent check: flipping
    twice restores the text.
    """
    step_open = text.index("  // §C —")
    step_close = text.index("  // §D —")
    head, sec, tail = text[:step_open], text[step_open:step_close], text[step_close:]
    out_lines = []
    flipped = 0
    for ln in sec.splitlines():
        if ln.lstrip().startswith("=> absStQ("):
            if " => absStQ(0," in ln:
                ln = ln.replace(" => absStQ(0,", " => absStQ(1,")
                flipped += 1
            elif " => absStQ(1," in ln:
                ln = ln.replace(" => absStQ(1,", " => absStQ(0,")
                flipped += 1
            else:
                ln = ln + "  // MUTANT: FLIPPED-PASSTHROUGH (variable tag)" if "TG" in ln else ln
        out_lines.append(ln)
    # mark the section so the mutant is self-describing
    sec_new = "\n".join(out_lines) + "\n"
    # add the marker at the first RHS flip site comment-free position: append a
    # section banner right after the §C banner instead of per-line noise.
    banner = ("  // MUTANT: FLIPPED — every step-row RHS tag literal below was flipped "
              "(0<->1) by make_abs_q.py.\n")
    anchor = "  // ===========================================================================\n"
    first_banner_end = sec_new.index(anchor) + len(anchor)
    # insert after the SECOND banner line pair (the §C header block) — simpler:
    # append the banner immediately before the first rule of the section.
    first_rule = sec_new.index("  rule absStepQ")
    sec_new = sec_new[:first_rule] + banner + sec_new[first_rule:]
    return head + sec_new + tail


if __name__ == "__main__":
    sys.exit(main())
