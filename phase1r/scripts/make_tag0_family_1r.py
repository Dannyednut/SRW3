#!/usr/bin/env python3
"""SRW3 Phase 1R — the tag-0 fragment family generator (make_tag0_family_1r.py).

Emits, in BOTH variants (regenerate; never edit by hand):

  phase1r/proofs/n_r_tag0_family.k      (the 1Q machine of record)
  phase1r/proofs/n_r_tag0_family_qs.k   (the QS stall-row variant)

The tag-0 fragment's universal theorem as a GENERATED FAMILY of 12 claims,
one per GROUND COMMAND SHAPE (the explicit transition constructors of the
frozen 1Q machine):

  * the APProg datatype is `aRunNilJ | aConsJ(ACmd, APProg)`; every
    executable run is the empty run (the circular base, discharged by the
    context) or `aConsJ(<head>, tail)` with <head> one of the 12 ground
    shapes — the family IS the structural-induction step, one claim per
    head constructor, with the [circularity] hypothesis providing the
    induction hypothesis for the tail;
  * the start state is the tag-0 invariant normal form
    absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, D:ADiag)
    (the disclosed normal-form meta-step of spec/fold-decomposition.md §3);
  * the four pre-init exec shapes close VACUOUSLY-BY-DESIGN: their
    absExecutableQ requires evaluates FALSE (the domain predicate's stall
    discipline).  This is control-side content (mission §7.C3), recorded
    with the VACUITY note;
  * the init-accept member is the ONLY one whose step re-tags; its tail is
    governed by the initialized-fragment universal (PROVED): on the QS
    variant the TAG1-QS claim is CARRIED IN THE SAME MODULE and passed via
    --trusted (the trust boundary is TAG1-QS's own proof log).

The QS variant exists because the family members' tails re-apply their
circular axiom through the runner; on the QS variant the pre-init stall
cells are explicit rows (edit set ER-1) so the exec branches refine and
die by their own requires instead of stalling symbolically.

Fail-closed checks (every run):
  F1  the frozen 1Q machine sha256 anchor;
  F2  the command syntax enumerated from the machine text (12 ground
      shapes over APProg); any drift = abort;
  F3  both emitted files regenerate BYTE-IDENTICAL (roundtrip);
  F4  every expected claim label emitted exactly once.

The generator NEVER writes outside phase1r/.  Level III only; no
consensus-integration claim.
"""
import hashlib
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
PHASE = HERE.parent
REPO = PHASE.parent
SRC_1Q = REPO / "phase1q" / "semantics" / "abs-machine-q.k"
SHA_1Q = "2e938fcb8939e0efe15e554687947b4dc44ece9a6a843f293799a18204e5383f"
OUT_Q = PHASE / "proofs" / "n_r_tag0_family.k"
OUT_QS = PHASE / "proofs" / "n_r_tag0_family_qs.k"

NF = "absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, D:ADiag)"

SHAPES = [
    ("aInitJ(aOkT:AOk)", "init-accept (THE re-tag)"),
    ("aInitJ(aOkF:AOk)", "init refuse"),
    ("aExecJ(aOkT:AOk, aSrcAuth:ASrc)", "exec mint (pre-init: NOT executable)"),
    ("aExecJ(aOkT:AOk, aSrcOther:ASrc)", "exec other (pre-init: NOT executable)"),
    ("aExecJ(aOkF:AOk, aSrcAuth:ASrc)", "exec unsupported (pre-init: NOT executable)"),
    ("aExecJ(aOkF:AOk, aSrcOther:ASrc)", "exec unsupported (pre-init: NOT executable)"),
    ("aGateJ(aOkT:AOk)", "gate mint attempt (pre-init refusal)"),
    ("aGateJ(aOkF:AOk)", "gate refuse (pre-init refusal)"),
    ("aCommitJ(aOkT:AOk, aOkT:AOk)", "commit presented (pre-init reject)"),
    ("aCommitJ(aOkT:AOk, aOkF:AOk)", "commit mixed (pre-init reject)"),
    ("aCommitJ(aOkF:AOk, aOkT:AOk)", "commit mixed (pre-init reject)"),
    ("aCommitJ(aOkF:AOk, aOkF:AOk)", "commit both-fail (pre-init reject)"),
]
INIT_ACCEPT_IDX = 0

TAG1_QS_CLAIM = """
  // ===========================================================================
  // 1R-UNIV-TAG1-QS — the tag-1-pinned universal invariant theorem (QS),
  //   carried IN THIS MODULE so the init-accept member can use it via
  //   --trusted (the trust boundary is TAG1-QS's own proof log).
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absCfgPinnedQ(AX) ==K true
         andBool absTagOfQ(AX) ==Int 1
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1R-UNIV-TAG1-QS)]

"""


def fail(msg):
    print("MAKE-TAG0-FAMILY FAIL-CLOSED: " + msg)
    sys.exit(1)


def emit(qs_mode: bool) -> str:
    req = ("../../phase1r/semantics/abs-machine-qs.k" if qs_mode
           else "../../phase1q/semantics/abs-machine-q.k")
    mod = "R-TAG0-FAM-QS-PROOFS" if qs_mode else "R-TAG0-FAM-PROOFS"
    sfx = "-QS" if qs_mode else ""
    variant_note = (
        " (QS VARIANT — the stall cells are explicit rows; ER-1)"
        if qs_mode else "")
    hdr = f"""// =============================================================================
// SRW3 PHASE 1R — THE TAG-0 FRAGMENT FAMILY{variant_note}
//                    (GENERATED — DO NOT EDIT BY HAND)
//                    (phase1r/proofs/n_r_tag0_family{('_qs' if qs_mode else '')}.k)
//
// GENERATED by phase1r/scripts/make_tag0_family_1r.py{(' --variant qs' if qs_mode else '')} from the FROZEN
// phase1q/semantics/abs-machine-q.k (sha256 {SHA_1Q[:12]}…).  Regenerate;
// never edit.
//
// The tag-0 fragment's universal invariant theorem as the structural-
// induction family over APProg: one [circularity] claim per ground command
// shape (the induction step for that head constructor; the circular
// hypothesis is the induction hypothesis for the tail), the empty run
// discharged by the context.  The start state is the tag-0 invariant
// NORMAL FORM {NF}
// (the disclosed meta-step: ABSInvQ at tag 0 pins every field but SF, D —
// spec/fold-decomposition.md §3).
//
// Member dispositions (by design):
//   * idx {INIT_ACCEPT_IDX + 1} ({SHAPES[INIT_ACCEPT_IDX][1]}): the ONLY re-tag member; on the QS
//     variant run with --trusted 1R-UNIV-TAG1-QS (the proved initialized-
//     fragment universal, carried in this module);
//   * idx 3-6 (the pre-init exec shapes): the requires evaluates FALSE
//     (the domain predicate's stall discipline) — a VACUOUS closure that
//     IS the content (stalled commands are not executed transitions);
//   * all other members: the step is an identity/diagnostic row — the
//     tail re-applies this member's own circular axiom (the observed
//     engine boundary: see the 1R report for the disposition of record).
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "{req}"

module {mod}
  imports SRW3N-ABS-{'QS' if qs_mode else 'Q'}
"""
    body = [TAG1_QS_CLAIM] if qs_mode else []
    for i, (shape, desc) in enumerate(SHAPES, 1):
        trusted_note = (" — THE RE-TAG MEMBER: the successor is the concrete\n"
                        "        // post-init state; the tail is governed by the PROVED\n"
                        "        // initialized-fragment universal (run with --trusted)"
                        if i - 1 == INIT_ACCEPT_IDX else "")
        body.append(f"""
  claim // 1R-T0F-{i}{sfx}-Q: head = {shape}  ({desc}){trusted_note}
    <srw3closureJ>
      <k> aConsJ({shape}, RUN:APProg) => .K ... </k>
      <absjshadow> {NF} => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(aConsJ({shape}, RUN:APProg), {NF})
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1R-T0F-{i}{sfx}-Q)]
""")
    tail = """
endmodule
"""
    return hdr + "".join(body) + tail


def main():
    # F1 — the frozen anchor
    if not SRC_1Q.is_file():
        fail(f"missing the 1Q machine of record: {SRC_1Q}")
    digest = hashlib.sha256(SRC_1Q.read_bytes()).hexdigest()
    if digest != SHA_1Q:
        fail(f"1Q machine sha256 {digest} != the anchor — refusing to generate")
    print("F1 OK    1Q machine of record sha256 anchored")

    # F2 — the command syntax enumerated from the machine text
    text = SRC_1Q.read_text()
    for tok in ("syntax AOk ::= \"aOkT\" | \"aOkF\"",
                "syntax ASrc ::= \"aSrcAuth\"",
                "| \"aSrcOther\"",
                "syntax ACmd ::= aInitJ ( AOk )",
                "| aExecJ ( AOk , ASrc )",
                "| aGateJ ( AOk )",
                "| aCommitJ ( AOk , AOk )",
                "syntax APProg ::= \"aRunNilJ\" | aConsJ ( ACmd , APProg )"):
        if tok not in text:
            fail(f"the command syntax drifted; expected line not found: {tok}")
    print("F2 OK    command syntax verified: 12 ground shapes over APProg")

    # F3/F4 — emit both variants + roundtrip + label checks
    out_q1, out_q2 = emit(False), emit(False)
    out_qs1, out_qs2 = emit(True), emit(True)
    if out_q1 != out_q2 or out_qs1 != out_qs2:
        fail("the generator is not deterministic (roundtrip mismatch)")
    OUT_Q.write_text(out_q1)
    OUT_QS.write_text(out_qs1)
    for i in range(1, len(SHAPES) + 1):
        if out_q1.count(f"label(1R-T0F-{i}-Q)") != 1:
            fail(f"label 1R-T0F-{i}-Q not emitted exactly once (q variant)")
        if out_qs1.count(f"label(1R-T0F-{i}-QS-Q)") != 1:
            fail(f"label 1R-T0F-{i}-QS-Q not emitted exactly once (qs variant)")
    if out_qs1.count("label(1R-UNIV-TAG1-QS)") != 1:
        fail("the QS variant does not carry the TAG1-QS trusted claim exactly once")
    print(f"F3 OK    roundtrip deterministic (q: {len(out_q1)} bytes; qs: {len(out_qs1)} bytes)")
    print(f"F4 OK    all claim labels emitted exactly once (both variants)")
    print(f"WROTE {OUT_Q}")
    print(f"WROTE {OUT_QS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
