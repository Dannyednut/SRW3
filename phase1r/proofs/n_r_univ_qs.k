// =============================================================================
// SRW3 PHASE 1R — THE UNIVERSAL DECOMPOSITION OVER THE QS VARIANT
//                    (phase1r/proofs/n_r_univ_qs.k)
//
// The Experiment-C architecture of record, stated over SRW3N-ABS-QS (the
// frozen 1Q machine + the four explicit pre-init stall rows — the relation
// is UNCHANGED; see make_abs_qs.py).  The QS variant removes the ONE
// unbounded phenomenon the tag-0 fragment exposed (the pre-init stall
// chain whose branch conditions never refine the command variable); on QS
// the decomposition claims' side conditions evaluate at every branch.
//
//   1R-UNIV-TAG1-QS       the tag-1-pinned universal invariant theorem
//                         (the TAG1 architecture, re-established over QS);
//   1R-UNIV-TAG0-NF-QS    the tag-0 fragment universal over the disclosed
//                         normal form (the init-accept re-tag's tail is
//                         governed by the PROVED 1R-UNIV-TAG1-QS via
//                         --trusted);
//   1R-UNIV-COMPOSED-QS   the single-claim unpinned universal (both pinned
//                         universals trusted) — the expected DIAGNOSTIC:
//                         the tag-0 branches carry symbolic pools whose
//                         invariant conjuncts (isZeroP on a variable) are
//                         undecidable at the circular side conditions — the
//                         boundary between the two-fragment decomposition
//                         and the single-claim form on this toolchain.
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-qs.k"

module R-UNIV-QS-PROOFS
  imports SRW3N-ABS-QS

  // ===========================================================================
  // 1R-UNIV-TAG1-QS — the tag-1-pinned universal invariant theorem (QS)
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

  // ===========================================================================
  // 1R-UNIV-TAG0-NF-QS — the tag-0 fragment universal (normal form; QS).
  //   DISCLOSED NORMAL-FORM META-STEP (spec/fold-decomposition.md §3):
  //   ABSInvQ at tag 0 is a conjunction of field equalities, so every tag-0
  //   invariant state is exactly absStQ(0,false,false,zeroP,zeroP,0,SF,D)
  //   (SF, D free).  The init-accept is the only re-tag; its successor is
  //   the concrete post-init state; the tail is TAG1-QS's subject.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, D:ADiag) => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg,
                absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, D:ADiag))
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1R-UNIV-TAG0-NF-QS)]

  // ===========================================================================
  // 1R-UNIV-COMPOSED-QS — the single-claim unpinned universal (the
  //   expected diagnostic; see the file header).
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1R-UNIV-COMPOSED-QS)]

endmodule
