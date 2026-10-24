// =============================================================================
// SRW3 PHASE 1Q — THE MUTANT BATTERY (one mutant per kompile target — the
//                    1P duplicate-syntax lesson).  This file: mut-stale-q (the re-tag forgotten at honest init).
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../tests/abs-machine-mut-stale-q.k"

module Q-NEG-MUT-STALE-PROOFS
  imports SRW3N-ABS-MUT-STALE-Q

  claim // 1Q-NEG-MUT-STALE-COH (MUST FAIL): the stale machine's honest
        // init keeps tag 0 with initialized bits — incoherent.
    <k> tagCoherentQ(absStepQ(absGenesisQ, aInitJ(aOkT:AOk))) => true </k>
    [label(1Q-NEG-MUT-STALE-COH)]

  claim // 1Q-NEG-MUT-STALE-INV (MUST FAIL)
    <k> ABSInvQ(absStepQ(absGenesisQ, aInitJ(aOkT:AOk))) => true </k>
    [label(1Q-NEG-MUT-STALE-INV)]

endmodule
