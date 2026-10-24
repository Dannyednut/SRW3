// =============================================================================
// SRW3 PHASE 1P (r2) — THE MUTATION SOUNDNESS CONTROLS (TAG-FLIP MUTANT)
//                    (phase1p/proofs/n_p_neg_mut_flip.k)
//
// RECONSTRUCTION r2.  The mutant (tests/abs-machine-mut-flip.k, generated
// by scripts/make_mutants_1p.py — ONE mutant per kompile target) FLIPS the
// tag literal on every absStepT row RHS (0 <-> 1; the incoherent-tag
// complement row, whose RHS tag is a variable, is untouched).  Under the
// mutant the exec-mint lands on tag 0 with the pins set — incoherent — and
// the honest pipeline's destination drifts.  ALL controls MUST FAIL:
//   1P-NEG-MUT-FLIP-COH   the ground coherence Bool form (exec-mint);
//   1P-NEG-MUT-FLIP-PRESV the ground preservation Bool form (exec-mint);
//   1P-NEG-MUT-FLIP-RUN   the ground honest-pipeline destination claim.
// Level III only.
// =============================================================================

requires "../tests/abs-machine-mut-flip.k"

module P-NEG-MUT-FLIP
  imports SRW3N-ABS-TDR-MUT-FLIP

  claim // 1P-NEG-MUT-FLIP-COH (MUST FAIL): the mutant's exec-mint
        // successor is INCOHERENT (tag flipped to 0, pins still set).
    <k> tagCoherentT(absStepT(absStT(1, true, true, 0, 1, 0, true, adNone),
                              aExecJ(aOkT, aSrcAuth))) => true </k>
    [label(1P-NEG-MUT-FLIP-COH)]

  claim // 1P-NEG-MUT-FLIP-PRESV (MUST FAIL): the mutant's exec-mint
        // successor BREAKS ABSInvT.
    <k> ABSInvT(absStepT(absStT(1, true, true, 0, 1, 0, true, adNone),
                         aExecJ(aOkT, aSrcAuth))) => true </k>
    [label(1P-NEG-MUT-FLIP-PRESV)]

  claim // 1P-NEG-MUT-FLIP-RUN (MUST FAIL): the honest pipeline does NOT
        // reach the honest destination under the flip mutant.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 0, 1, true, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-NEG-MUT-FLIP-RUN)]

endmodule
