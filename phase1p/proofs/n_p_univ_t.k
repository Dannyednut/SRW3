// =============================================================================
// SRW3 PHASE 1P (r2) — THE UNIVERSAL ATTEMPTS OVER THE T MACHINE (the tag
//                    encoding ALONE; the R-form runner with a SYMBOLIC shadow)
//                    (phase1p/proofs/n_p_univ_t.k)
//
// RECONSTRUCTION r2 (the r1 tree was lost before any commit; see
// phase1p/spec/branch-tag-design.md §0).
//
// The rung-T hypothesis: the CONJUNCTIVE tagged invariant ABSInvT alone
// unblocks the 1O implication checker (the disjunction is gone; the branch
// is an Int in the state).  The runner is the 1O R-form (12 ground-command
// rules, the shadow update THROUGH the function with a SYMBOLIC shadow
// variable) — so rung T isolates the invariant form, with the dispatch
// held at the 1O-R state.  r1 expectation: the residual keeps the 1O
// signature (the shadow is a symbolic constructor variable in
// function-argument position — the checker cannot case-split it).
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-t.k"

module P-UNIV-T-PROOFS
  imports SRW3N-ABS-T

  // ===========================================================================
  // 1P-UNIV-MACHINE-T — THE UNIVERSAL THEOREM, machine form, T rung.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absExecutableT(RUN:APProg, AX:AStateT)
    ensures ABSInvT(?AX2:AStateT)
    [circularity, label(1P-UNIV-MACHINE-T)]

  // ===========================================================================
  // 1P-UNIV-PREFIX-T — the committed-prefix corollary, machine form.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absCfgPinnedT(AX)
         andBool absExecutableT(RUN:APProg, AX:AStateT)
    ensures absInitShapedT(?AX2:AStateT)
    [circularity, label(1P-UNIV-PREFIX-T)]

  // ===========================================================================
  // 1P-NEG-DEST-T — destination-sanity control (MUST FAIL): the final state
  //     is not always the tagged genesis.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absExecutableT(RUN:APProg, AX:AStateT)
    ensures ?AX2:AStateT ==K absGenesisT
    [label(1P-NEG-DEST-T)]

  // ===========================================================================
  // 1P RUN EXECUTION CLAIMS — multi-step machine-level execution evidence
  //     (kprove executes them by real rewriting; the 1O discipline).
  // ===========================================================================
  claim // 1P-RUN-HONEST-T: the honest pipeline executes on the T machine
        // from the tagged genesis to the exact post-commit state.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 0, 1, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-RUN-HONEST-T)]

  claim // 1P-RUN-INIT-EXEC-T: the honest init-then-exec run (the exec mint
        // consumes nothing and increments the exec pool).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aRunNilJ)) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 1, 0, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-RUN-INIT-EXEC-T)]

  claim // 1P-NEG-UNSAFE-COMMIT-T (MUST FAIL): the unsafe commit cannot
        // reach the accept successor — the T machine's own commit rows
        // refuse the (aOkT,aOkF) shape (the reject class).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkF:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 0, 1, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-NEG-UNSAFE-COMMIT-T)]

endmodule
