// =============================================================================
// SRW3 PHASE 1Q — THE MUTANT BATTERY (one mutant per kompile target — the
//                    1P duplicate-syntax lesson).  This file: mut-omit-q (the gate mint row B-S deleted — the omitted constructor case).
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

// ---------------------------------------------------------------------------
// mut-omit-q
// ---------------------------------------------------------------------------
requires "../tests/abs-machine-mut-omit-q.k"

module Q-NEG-MUT-OMIT-PROOFS
  imports SRW3N-ABS-MUT-OMIT-Q

  claim // 1Q-NEG-MUT-OMIT-GATEMINT (MUST FAIL): the ground gate-mint
        // execution — on the omit machine the (aOkT, succP) shape has NO
        // step row, the machine stutters, and the pool does NOT grow.
    <srw3closureJ>
      <k> aConsJ(aGateJ(aOkT:AOk),aRunNilJ) => .K ... </k>
      <absjshadow> absStQ(1, true, true, zeroP, succP(zeroP), 0, true, adNone)
                 => absStQ(1, true, true, succP(zeroP), succP(zeroP), 0, true, adNone):AStateQ </absjshadow>
      ...
    </srw3closureJ>
    [label(1Q-NEG-MUT-OMIT-GATEMINT)]

  claim // 1Q-NEG-MUT-OMIT-C2 (MUST FAIL): the C2 correspondence at the
        // omitted class — the Q side (stuck/stutter) diverges from the
        // 1P Int-image step (which mints).
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, zeroP, succP(zeroP), 0, true, adNone), aGateJ(aOkT:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, zeroP, succP(zeroP), 0, true, adNone)), aGateJ(aOkT:AOk))) => true </k>
    [label(1Q-NEG-MUT-OMIT-C2)]

endmodule
