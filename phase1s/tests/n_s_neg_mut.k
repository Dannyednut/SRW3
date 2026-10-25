// =============================================================================
// SRW3 PHASE 1S — THE OMIT-MUTANT CONTROL (mission §5/§7; 缺失转移行)
//                    (phase1s/tests/n_s_neg_mut.k)
//
// The coverage battery's gate-mint cell, re-run against the OMIT mutant
// (tests/abs-machine-mut-omit-gatemint-1s.k — the machine of record minus
// exactly that row). The claim MUST FAIL (the step is stuck on the
// omitted cell — the incoherent-tag complement cannot fire at tag 1): the
// omission is DETECTED by the battery. Runs against the MUTANT definition.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "abs-machine-mut-omit-gatemint-1s.k"

module S-NEG-MUT-PROOFS
  imports SRW3N-ABS-MUT-OMIT-GATEMINT

  // ===========================================================================
  // 1S-NEG-OMIT-GATEMINT (MUST FAIL against the mutant): the gate-mint
  //   cell of the coverage battery. With the row omitted the step cannot
  //   evaluate; a closure would mean the mutant still computes the
  //   documented post — it must not.
  // ===========================================================================
  claim <k> absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                            N:Int, SF:Bool, D:ADiag),
                     aGateJ(aOkT))
        => absStQ(1, true, true, succP(G:PoolCount), succP(E0:PoolCount),
                  N:Int, SF:Bool, D:ADiag) </k>
    [label(1S-NEG-OMIT-GATEMINT)]

endmodule
