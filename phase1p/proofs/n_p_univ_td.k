// =============================================================================
// SRW3 PHASE 1P (r2) — THE UNIVERSAL ATTEMPTS OVER THE TD MACHINE (T + the
//                    REWRITE-LEVEL TAG DISCRIMINATION of the runner)
//                    (phase1p/proofs/n_p_univ_td.k)
//
// RECONSTRUCTION r2 (the r1 tree was lost before any commit; see
// phase1p/spec/branch-tag-design.md §0).
//
// The rung-TD hypothesis: with the tag DISCRIMINATED at the rewrite level
// (the runner's ground-command rules pattern the shadow's branch), the
// function call carries a tag-PINNED state and the checker can evaluate
// the class rows.  r1 expectation: the residual MOVES past the 1O leaf
// (the original disjunctive obstacle is overcome) to the Int-inequality
// requires of the guarded classes (gate-mint E>=Int 1 vs [owise];
// commit-accept G>=Int 1 andBool E>=Int 1).
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-td.k"

module P-UNIV-TD-PROOFS
  imports SRW3N-ABS-TD

  // ===========================================================================
  // 1P-UNIV-MACHINE-TD — THE UNIVERSAL THEOREM, machine form, T rung.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absExecutableT(RUN:APProg, AX:AStateT)
    ensures ABSInvT(?AX2:AStateT)
    [circularity, label(1P-UNIV-MACHINE-TD)]

  // ===========================================================================
  // 1P-UNIV-PREFIX-TD — the committed-prefix corollary, machine form.
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
    [circularity, label(1P-UNIV-PREFIX-TD)]

  // ===========================================================================
  // 1P-NEG-DEST-TD — destination-sanity control (MUST FAIL): the final state
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
    [label(1P-NEG-DEST-TD)]

  // ===========================================================================
  // 1P RUN EXECUTION CLAIMS — multi-step machine-level execution evidence
  //     (kprove executes them by real rewriting; the 1O discipline).
  // ===========================================================================
  claim // 1P-RUN-HONEST-TD: the honest pipeline executes on the T machine
        // from the tagged genesis to the exact post-commit state.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 0, 1, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-RUN-HONEST-TD)]

  claim // 1P-RUN-INIT-EXEC-TD: the honest init-then-exec run (the exec mint
        // consumes nothing and increments the exec pool).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aRunNilJ)) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 1, 0, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-RUN-INIT-EXEC-TD)]

  claim // 1P-NEG-UNSAFE-COMMIT-TD (MUST FAIL): the unsafe commit cannot
        // reach the accept successor — the T machine's own commit rows
        // refuse the (aOkT,aOkF) shape (the reject class).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkF:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 0, 1, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-NEG-UNSAFE-COMMIT-TD)]

endmodule
