// =============================================================================
// SRW3 PHASE 1P (r2) — THE MUTATION SOUNDNESS CONTROLS (STALE-TAG MUTANT)
//                    (phase1p/proofs/n_p_neg_mut_stale.k)
//
// RECONSTRUCTION r2.  The mutant (tests/abs-machine-mut-stale.k, generated
// by scripts/make_mutants_1p.py — ONE mutant per kompile target, the r1
// duplicate-syntax lesson) forgets THE RE-TAG: the init-accept row keeps
// the tag at 0 while the fields move to the initialized shape.  Under the
// mutant, the successor of the honest init is tag-0 with C=T=true —
// incoherent and invariant-breaking.  BOTH controls MUST FAIL:
//   1P-NEG-MUT-STALE-COH   the ground coherence Bool form;
//   1P-NEG-MUT-STALE-PRESV the ground preservation Bool form.
// If either claim closed, the COH/PRESV families would be insensitive to
// the re-tag content — the families' soundness sensitivity is exactly what
// these controls establish.  Level III only.
// =============================================================================

requires "../tests/abs-machine-mut-stale.k"

module P-NEG-MUT-STALE
  imports SRW3N-ABS-TDR-MUT-STALE

  claim // 1P-NEG-MUT-STALE-COH (MUST FAIL): the mutant's init-accept
        // successor is INCOHERENT (tag 0 with the pins set).
    <k> tagCoherentT(absStepT(absGenesisT, aInitJ(aOkT))) => true </k>
    [label(1P-NEG-MUT-STALE-COH)]

  claim // 1P-NEG-MUT-STALE-PRESV (MUST FAIL): the mutant's init-accept
        // successor BREAKS ABSInvT (the tag-0 branch cannot hold C=true).
    <k> ABSInvT(absStepT(absGenesisT, aInitJ(aOkT))) => true </k>
    [label(1P-NEG-MUT-STALE-PRESV)]

endmodule
