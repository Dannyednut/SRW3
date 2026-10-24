// =============================================================================
// SRW3 PHASE 1Q — THE MUTANT BATTERY (one mutant per kompile target — the
//                    1P duplicate-syntax lesson).  This file: mut-flip-q (every step-row RHS tag literal flipped).
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

// ---------------------------------------------------------------------------
// mut-flip-q
// ---------------------------------------------------------------------------
requires "../tests/abs-machine-mut-flip-q.k"

module Q-NEG-MUT-FLIP-PROOFS
  imports SRW3N-ABS-MUT-FLIP-Q

  claim // 1Q-NEG-MUT-FLIP-INIT (MUST FAIL): the flipped honest init lands
        // at tag 0 with initialized bits.
    <k> ABSInvQ(absStepQ(absGenesisQ, aInitJ(aOkT:AOk))) => true </k>
    [label(1Q-NEG-MUT-FLIP-INIT)]

  claim // 1Q-NEG-MUT-FLIP-RUN (MUST FAIL): the honest pipeline does NOT
        // land on the exact post-commit state on the flipped machine.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisQ => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone):AStateQ </absjshadow>
      ...
    </srw3closureJ>
    [label(1Q-NEG-MUT-FLIP-RUN)]

endmodule
