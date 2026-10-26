// =============================================================================
// SRW3 PHASE 1T — WORKSTREAM C: THE CORRESPONDENCE CELLS, C1.2-DEPENDENCE
//                    REMOVED (mechanism A: --trusted hand-off).
//                    (phase1t/proofs/n_t_corr_uncond.k)
//
// The five C12-COND correspondence cells of 1S (GATE-MINT / GATE-REFUSE /
// COMMIT-ACCEPT / COMMIT-C / COMMIT-D) were CONDITIONAL: their requires
// (countToInt(succP(.)) >=Int 1) is exactly the C1.2 spot.  With C1.2
// CHECKED (Lean 4.16.0, phase1t/audit/lean/c12_induction.lean), the
// conditions are DERIVABLE — the 1T cells below drop the requires and must
// close with the trusted C1.2 lemma available (the prover unfolds
// countToInt(succP(E0)) to countToInt(E0) +Int 1 and needs
// countToInt(E0) >=Int 0 — the trusted lemma's exact content).
//
// Also carried: the three preservation cells (EXE-MINT, GATE-MINT,
// COMMIT-ACCEPT) and the NODEP probes in their unconditional forms — the
// COMMIT-ACCEPT-NODEP cell of 1S retained the exact C1.2 residual
// countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0; its 1T unconditional
// form is THE direct test of whether the residual is discharged by the
// checked lemma.
//
// NO SIMPLIFICATION RULES — same discipline as n_t_migrate_uncond.k.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1s/semantics/rel-machine.k"

module T-CORR-UNCOND-PROOFS
  imports SRW3N-REL-S

  // the C1.2 lemma of record (Lean-checked; --trusted for the rows below)
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures ?N:Int >=Int 0
    [label(1T-C12-UNIV-LEAN)]

  // ===========================================================================
  // the five correspondence cells, conditions dropped (were C12-COND)
  // ===========================================================================
  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkT)) </k>
    [label(1T-CORR-GATE-MINT-UNCOND)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkF)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkF)) </k>
    [label(1T-CORR-GATE-REFUSE-UNCOND)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkT)) </k>
    [label(1T-CORR-COMMIT-ACCEPT-UNCOND)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkF)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkF)) </k>
    [label(1T-CORR-COMMIT-C-UNCOND)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkF, A2:AOk)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkF, A2:AOk)) </k>
    [label(1T-CORR-COMMIT-D-UNCOND)]

  // ===========================================================================
  // the three preservation cells (were PROVED conditional in 1S; the 1T
  // forms carry the SAME hypothesis structure — ABSInvE + tagCoherentQ —
  // with the C1.2 spot now discharged from the checked lemma)
  // ===========================================================================
  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aExecJ(aOkT, aSrcAuth)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1T-PRESV-INT-EXE-MINT-LEANC12)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aGateJ(aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1T-PRESV-INT-GATE-MINT-LEANC12)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aCommitJ(aOkT, aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1T-PRESV-INT-COMMIT-ACCEPT-LEANC12)]

  // ===========================================================================
  // 1T-CORR-COMMIT-ACCEPT-NODEP-UNCOND — the NODEP cell (the residual
  //   carrier of record) in its requires-free form: THE strip-state probe.
  //   1S residual: #Not(countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0).
  // ===========================================================================
  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkT)) </k>
    [label(1T-CORR-COMMIT-ACCEPT-NODEP-UNCOND)]

endmodule
