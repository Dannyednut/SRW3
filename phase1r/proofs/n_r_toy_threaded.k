// =============================================================================
// SRW3 PHASE 1R — EXPERIMENT D: THE MINIMAL MISSING-CAPABILITY EXAMPLE
//                    (the state-threading domain predicate)
//                    (phase1r/proofs/n_r_toy_threaded.k)
//
// The isolated experiment of record.  The 1Q forked toy's universal Q1F
// CLOSES (4s, non-vacuous) while the 1Q machine's universal
// 1Q-UNIV-MACHINE-Q does not terminate.  Between them, exactly TWO
// structural differences remain after the 1R diagnosis:
//   (i)  the domain predicate THREADS THE STATE (absExecutableQ recurses
//        through absStepQ), where the toy's okQ recurses over the program
//        alone, and
//   (ii) the machine's branch/stall structure.
// This file removes (ii): the toy of record gains ONLY a state-threading
// domain predicate okS (every command allowed; the state threaded through
// tstepQ — the minimal mirror of absExecutableQ) and re-states the SAME
// universal claim with okS in place of okQ.  Everything else is the 1Q
// forked toy byte-for-byte (state, invariant, step, fold, runner).
//
//   QT-UNIV-THREADED  the universal with the THREADING predicate
//                     (the missing-capability example if it does not
//                     terminate while Q1F does);
//   QT-BOUND-1        the same architecture at bounded depth (the spine of
//                     one symbolic command, nil-terminated) — the control
//                     that the threading predicate alone does not break
//                     the FINITE ladder;
//   QT-OKQ-EVAL       the threading predicate's base discipline (evaluation).
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1q/proofs/repro/univ-repro-qf.k"

module TOY-THREADED
  imports TOY-QF

  // ---- the STATE-THREADING domain predicates (the only new definitions) --
  // okS: the UNRESTRICTED threading mirror (every command allowed) — the
  //      SOUNDNESS control: it admits breakC, so the unrestricted threaded
  //      universal MUST FAIL (the falsity witness of record);
  // okX: the RESTRICTED threading predicate (breakC excluded — the exact
  //      okQ discipline, state-threaded) — the missing-capability subject.
  syntax Bool ::= okS ( TPrg , TStQ ) [function, total]
  rule okS(nilT, _:TStQ) => true
  rule okS(consT(C:TCmd, R:TPrg), S:TStQ) => okS(R, tstepQ(S, C))

  syntax Bool ::= okX ( TPrg , TStQ ) [function, total]
  rule okX(nilT, _:TStQ) => true
  rule okX(consT(breakC, _:TPrg), _:TStQ) => false
  rule okX(consT(C:TCmd, R:TPrg), S:TStQ) => okX(R, tstepQ(S, C)) [owise]

endmodule

module TOY-THREADED-PROOFS
  imports TOY-THREADED

  claim // QT-UNIV-UNRESTRICTED (MUST FAIL — the soundness control): the
        // unrestricted threading predicate admits breakC, whose forgery
        // breaks invQ; the recorded residual is the falsity witness.
    <k> P:TPrg => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okS(P:TPrg, S:TStQ)
    ensures invQ(?S2:TStQ)
    [circularity, label(QT-UNIV-UNRESTRICTED)]

  claim // QT-UNIV-THREADED: the universal with the RESTRICTED threading
        // predicate (the minimal missing-capability example of record:
        // if THIS does not terminate/close while Q1F does, the isolated
        // trigger is the state-threading recursion in the domain
        // predicate — the exact absExecutableQ shape).
    <k> P:TPrg => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okX(P:TPrg, S:TStQ)
    ensures invQ(?S2:TStQ)
    [circularity, label(QT-UNIV-THREADED)]

  claim // QT-BOUND-1: the RESTRICTED threading predicate at bounded depth
        // (the finite-ladder control).
    <k> consT(C1:TCmd, nilT) => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okX(consT(C1:TCmd, nilT), S:TStQ)
    ensures invQ(?S2:TStQ)
    [label(QT-BOUND-1)]

  claim // QT-BOUND-1-UNRESTRICTED (MUST FAIL): the unrestricted predicate
        // at bounded depth — breakC is admitted, the invariant breaks.
    <k> consT(C1:TCmd, nilT) => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okS(consT(C1:TCmd, nilT), S:TStQ)
    ensures invQ(?S2:TStQ)
    [label(QT-BOUND-1-UNRESTRICTED)]

  claim // QT-OKQ-EVAL: the threading predicate's base case (evaluation).
    <k> okS(nilT, stQ(0, zeroP)) => true </k>
    [label(QT-OKQ-EVAL)]

endmodule
