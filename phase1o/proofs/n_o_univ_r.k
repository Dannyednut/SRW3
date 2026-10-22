// =============================================================================
// SRW3 PHASE 1O — THE MACHINE-FORM UNIVERSAL OVER THE R-VARIANT MACHINE
//                    (phase1o/proofs/n_o_univ_r.k)
//
// The SAME three claims as n_o_univ.k, stated over the rewrite-dispatched
// machine (abs-machine-r.k; scripts/make_abs_r.py — the only difference
// is the runner's rewrite-level command dispatch; absStepJ/ABSInv/simJ/
// absExecutable are UNCHANGED).  The toy probes R2/R6 predict closure;
// R10 predicts the 1N-shape runner could never close.  Level III only.
// =============================================================================

requires "../semantics/abs-machine-r.k"

module O-UNIV-R-PROOFS
  imports SRW3N-ABS-R

  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AState => ?AX2:AState </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInv(AX) andBool absExecutable(RUN:APProg, AX:AState)
    ensures ABSInv(?AX2:AState)
    [circularity, label(1O-UNIV-MACHINE-R)]

  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AState => ?AX2:AState </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInv(AX) andBool absCfgPinnedOf(AX)
         andBool absExecutable(RUN:APProg, AX:AState)
    ensures absInitShaped(?AX2:AState)
    [circularity, label(1O-UNIV-PREFIX-R)]

  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AState => ?AX2:AState </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInv(AX) andBool absExecutable(RUN:APProg, AX:AState)
    ensures ?AX2:AState ==K absGenesis
    [label(1O-NEG-DEST-R)]

  // ===========================================================================
  // 1O RUN EXECUTION CLAIMS — multi-step machine-level execution evidence
  //     (krun's configuration injection cannot host abstract programs in
  //     K v7.1.337 — the $PGM sort is PProgJI and the --term route rejects
  //     cell syntax; recorded in the 1O report — so the multi-step runtime
  //     evidence is mechanized as GROUND execution claims instead: kprove
  //     executes them by real rewriting through the 12 ground runner rules.)
  // ===========================================================================
  claim // 1O-RUN-HONEST-R: the honest pipeline executes on the R machine
        // from the genesis to the exact post-commit state.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absSt(false, false, 0, 0, 0, false, adNone) => absSt(true, true, 0, 0, 1, true, adNone):AState </absjshadow>
      ...
    </srw3closureJ>
    [label(1O-RUN-HONEST-R)]

  claim // 1O-RUN-INIT-EXEC-R: the honest init-then-exec run (renamed from
        // the original 1O-RUN-STALL-R label, which misdescribed the content)
        // (consumed, nothing written — the disclosed R stall semantics) and
        // the run continues honestly from the unchanged state.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aRunNilJ)) => .K ... </k>
      <absjshadow> absSt(false, false, 0, 0, 0, false, adNone) => absSt(true, true, 0, 1, 0, true, adNone):AState </absjshadow>
      ...
    </srw3closureJ>
    [label(1O-RUN-INIT-EXEC-R)]

  claim // 1O-NEG-UNSAFE-COMMIT-R (MUST FAIL): the unsafe commit cannot
        // reach the accept successor — the machine's own (aOkT,aOkT)
        // literal rule refuses the (aOkT,aOkF) shape (the [owise] reject).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkF:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absSt(false, false, 0, 0, 0, false, adNone) => absSt(true, true, 0, 0, 1, true, adNone):AState </absjshadow>
      ...
    </srw3closureJ>
    [label(1O-NEG-UNSAFE-COMMIT-R)]

endmodule
