// Phase 1S probe B: single-import (QS only) claim mechanics — cell-wrapped
// function-evaluation claims per the 1Q convention.

requires "../../phase1r/semantics/abs-machine-qs.k"

module PROBE-B-PROOFS
  imports SRW3N-ABS-QS

  claim <k> countToInt(succP(zeroP)) => 1 </k>
    [label(PROBE-COUNT-1)]

  claim <k> countToInt(succP(P:PoolCount))
        => countToInt(P) +Int 1 </k>
    [label(PROBE-COUNT-SYMB)]

  claim <k> absStepE(absStQE(true, true, 2, 3, 7, false, adNone), aExecJ(aOkT, aSrcAuth))
        => absStQE(true, true, 2, 4, 7, false, adNone) </k>
    [label(PROBE-E-STEP)]

  // the pivotal arithmetic pattern (mint-class image-preservation shape):
  // from the WRAPPED count's nonnegativity conclude the doubly-wrapped
  // count's nonnegativity (evaluation + arithmetic slack; no induction).
  claim <k> countToInt(succP(succP(E0:PoolCount)))
        => ?N2:Int </k>
        requires countToInt(succP(E0:PoolCount)) >=Int 0
        ensures ?N2:Int >=Int 0
    [label(PROBE-SLACK)]

endmodule
