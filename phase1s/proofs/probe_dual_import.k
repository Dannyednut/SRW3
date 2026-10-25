// Phase 1S probe A: dual-import feasibility (QS + 1P TDRR in one def).
// Function-level only; no K-cell claims. Tests duplicate branchTag rules,
// duplicate ADiag/AOk/ASrc/ACmd/APProg productions, and cross-module
// function evaluation.

requires "../semantics/probe-requires.k"

module PROBE-A-PROOFS
  imports SRW3N-REL-PROBE-BASE

  // probe claim 1: countToInt evaluation (QS side)
  claim countToInt(succP(zeroP)) ==Int 1
    [label(PROBE-COUNT-1)]

  // probe claim 2: cross-module evaluation — the 1P step on a concrete
  // Int state equals the verbatim mirror step on the same fields
  claim absStepT(absStT(1, true, true, 2, 3, 7, false, adNone), aExecJ(aOkT, aSrcAuth))
        ==K absStT(1, true, true, 2, 4, 7, false, adNone)
    [label(PROBE-T-STEP)]

  // probe claim 3: the mirror (absStepE) on the mirrored fields
  claim absStepE(absStQE(true, true, 2, 3, 7, false, adNone), aExecJ(aOkT, aSrcAuth))
        ==K absStQE(true, true, 2, 4, 7, false, adNone)
    [label(PROBE-E-STEP)]

endmodule
