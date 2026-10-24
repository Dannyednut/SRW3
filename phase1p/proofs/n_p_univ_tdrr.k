// =============================================================================
// SRW3 PHASE 1P (r2) — THE UNIVERSAL ATTEMPTS OVER THE TDRR MACHINE (TDR +
//                    the REQUIRES SPLIT of the Int-guarded classes)
//                    (phase1p/proofs/n_p_univ_tdr.k)
//
// RECONSTRUCTION r2 (the r1 tree was lost before any commit; see
// phase1p/spec/branch-tag-design.md §0).
//
// The rung-TDRR hypothesis: with every requires decidable and the partition
// exhaustive (the Int-guarded classes split into explicit complement
// pairs), the engine can close the universal within budget.  r1
// expectation: failed-budget on the real machine (the exploration cost
// over the rewrite branch tree + the per-branch z3 implication cost);
// NIL closes; CONS does not.
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-tdrr.k"

module P-UNIV-TDRR-PROOFS
  imports SRW3N-ABS-TDRR

  // ===========================================================================
  // 1P-UNIV-MACHINE-TDRR — THE UNIVERSAL THEOREM, machine form, T rung.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absExecutableT(RUN:APProg, AX:AStateT)
    ensures ABSInvT(?AX2:AStateT)
    [circularity, label(1P-UNIV-MACHINE-TDRR)]

  // ===========================================================================
  // 1P-UNIV-PREFIX-TDRR — the committed-prefix corollary, machine form.
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
    [circularity, label(1P-UNIV-PREFIX-TDRR)]

  // ===========================================================================
  // 1P-NEG-DEST-TDRR — destination-sanity control (MUST FAIL): the final state
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
    [label(1P-NEG-DEST-TDRR)]

  // ===========================================================================
  // 1P RUN EXECUTION CLAIMS — multi-step machine-level execution evidence
  //     (kprove executes them by real rewriting; the 1O discipline).
  // ===========================================================================
  claim // 1P-RUN-HONEST-TDRR: the honest pipeline executes on the T machine
        // from the tagged genesis to the exact post-commit state.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 0, 1, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-RUN-HONEST-TDRR)]

  claim // 1P-RUN-INIT-EXEC-TDRR: the honest init-then-exec run (the exec mint
        // consumes nothing and increments the exec pool).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aRunNilJ)) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 1, 0, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-RUN-INIT-EXEC-TDRR)]

  claim // 1P-NEG-UNSAFE-COMMIT-TDRR (MUST FAIL): the unsafe commit cannot
        // reach the accept successor — the T machine's own commit rows
        // refuse the (aOkT,aOkF) shape (the reject class).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkF:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 0, 1, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-NEG-UNSAFE-COMMIT-TDRR)]

endmodule
