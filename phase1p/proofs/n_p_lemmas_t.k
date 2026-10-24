// =============================================================================
// SRW3 PHASE 1P (r2) — THE T-MACHINE LEMMA SMOKE SUBSET (5 claims — the r1 smoke set;
//                    the full families run over TDR in n_p_lemmas_tdr.k).
//                    (phase1p/proofs/n_p_lemmas_t.k)
//
// RECONSTRUCTION r2 (the r1 tree was lost before any commit; see
// phase1p/spec/branch-tag-design.md §0).  Family shapes mirror the frozen
// 1O lemma module (phase1o/proofs/n_o_lemmas.k) claim-for-claim, restated
// over absStT/ABSInvT/absStepT with the tag pinned per branch.
//
// Trust discipline (the 1O rule): K v7.1.337 has no [lemma] attribute; the
// trusted-axiom mechanism is the kprove --trusted flag.  Every trusted
// claim is INDEPENDENTLY PROVEN first (the runner's stage L runs before
// stage U), with raw logs retained under phase1p/transcripts/k/.
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-t.k"

module P-LEMMAS-T
  imports SRW3N-ABS-T

  claim // 1P-PRESV-I-COMMIT-ACCEPT (the invariant-preservation Bool form)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 1 andBool E >=Int 1 andBool SF ==K true
    [label(1P-PRESV-I-COMMIT-ACCEPT-T)]

  claim // 1P-PRESV-P-INIT-ACCEPT (THE RE-TAG: 0 -> 1, the safety bookkeeping set)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-INIT-ACCEPT-T)]

  claim // 1P-COH-P-INIT-ACCEPT (THE RE-TAG lands coherent-1)
    <k> tagCoherentT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-COH-P-INIT-ACCEPT-T)]

  claim // 1P-TAGSOUND: erasing the tag loses NOTHING but the tag (the
        // observation agreement; general over the tagged state space).
    <k> eraseT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))
        ==K absStE(C, T, G, E, N, SF, D) => true </k>
    [label(1P-TAGSOUND-T)]

  claim // 1P-ERASE-INIT-ACCEPT: the re-tag erases to the frozen 1N accept.
    <k> eraseT(absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk)))
        ==K absStE(true, true, 0, 0, 0, true, D:ADiag) => true </k>
    [label(1P-ERASE-INIT-ACCEPT-T)]

endmodule
