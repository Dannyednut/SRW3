// =============================================================================
// SRW3 PHASE 1P (r2) — THE LEMMA MODULE OVER THE TDR MACHINE: the P1 tag
//                    facts, the branch-complete preservation family, the
//                    tag-coherence family, the refinement (CORR) family,
//                    and the lemma-backed universal.
//                    (phase1p/proofs/n_p_lemmas_tdr.k)
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

requires "../semantics/abs-machine-tdr.k"

module P-LEMMAS-TDR
  imports SRW3N-ABS-TDR

  // ===========================================================================
  // §P1 — THE TAG FACTS (3 claims).  The conjunctive form's benefit made
  //       precise: the RANGE conjunct is usable by z3 even while the branch
  //       implications stay stuck (symbolic comparisons inside impliesBool).
  // ===========================================================================
  claim // 1P-P1-TAG-RANGE: the tag range follows from the invariant (z3).
    <k> (TG:Int >=Int 0 andBool TG:Int <=Int 1) => true </k>
    requires ABSInvT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))
    [label(1P-P1-TAG-RANGE)]

  claim // 1P-P1-GENESIS-COH: the tagged genesis is coherent (evaluation).
    <k> tagCoherentT(absGenesisT) => true </k>
    [label(1P-P1-GENESIS-COH)]

  claim // 1P-P1-TAGST-ROUNDTRIP: tagStE rebuilds the canonical tagged state
        // on both branches (evaluation).
    <k> (tagStE(eraseT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)))
         ==K absStT(0, false, false, G, E, N, SF, D))
        andBool
        (tagStE(eraseT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)))
         ==K absStT(1, true, true, G, E, N, SF, D)) => true </k>
    [label(1P-P1-TAGST-ROUNDTRIP)]

  // ===========================================================================
  // §PRESV — THE BRANCH-COMPLETE PRESERVATION FAMILY (21 claims; the 1O
  //          family restated over the tagged machine; the tag pinned per
  //          branch in the state pattern).
  // ===========================================================================
  claim // 1P-PRESV-I-COMMIT-ACCEPT (the invariant-preservation Bool form)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 1 andBool E >=Int 1 andBool SF ==K true
    [label(1P-PRESV-I-COMMIT-ACCEPT)]

  claim // 1P-PRESV-I-COMMIT-ACCEPT-LOWE (the complement row fires; E = 0)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-COMMIT-ACCEPT-LOWE)]

  claim // 1P-PRESV-I-COMMIT-ACCEPT-LOWG (the complement row fires; G = 0)
    <k> ABSInvT(absStepT(absStT(1, true, true, 0, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, 0, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires E >=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-COMMIT-ACCEPT-LOWG)]

  claim // 1P-PRESV-I-COMMIT-REJECT-LOW (row A: the joint-guard complement)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
         andBool (G <=Int 0 orBool E <=Int 0)
    [label(1P-PRESV-I-COMMIT-REJECT-LOW)]

  claim // 1P-PRESV-I-COMMIT-REJECT-HI (row C: rejected with both pools ok)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 1 andBool E >=Int 1 andBool SF ==K true
    [label(1P-PRESV-I-COMMIT-REJECT-HI)]

  claim // 1P-PRESV-I-EXEC-MINT (the invariant-preservation Bool form)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-EXEC-MINT)]

  claim // 1P-PRESV-I-EXEC-REFUSE (the invariant-preservation Bool form)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-EXEC-REFUSE)]

  claim // 1P-PRESV-I-EXEC-SOURCE (the invariant-preservation Bool form)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-EXEC-SOURCE)]

  claim // 1P-PRESV-I-GATE-MINT (the invariant-preservation Bool form)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 1 andBool SF ==K true
    [label(1P-PRESV-I-GATE-MINT)]

  claim // 1P-PRESV-I-GATE-MINT-EMPTY (the refusal row fires; E = 0)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-GATE-MINT-EMPTY)]

  claim // 1P-PRESV-I-GATE-REFUSE-LOW (row A: the empty-pool refusal; the
        // r2 LOW/HI split — finding 1P-F1's complete partition forks the
        // refusal on the pool guard, so the family forks with it)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool E <=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-GATE-REFUSE-LOW)]

  claim // 1P-PRESV-I-GATE-REFUSE-HI (row C: refused with a nonempty pool)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 1 andBool SF ==K true
    [label(1P-PRESV-I-GATE-REFUSE-HI)]

  claim // 1P-PRESV-I-INIT-ACCEPT (re-init refused; the tag-1 identity)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-INIT-ACCEPT)]

  claim // 1P-PRESV-I-INIT-REFUSE (the tag-1 identity)
    <k> ABSInvT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-PRESV-I-INIT-REFUSE)]

  claim // 1P-PRESV-P-COMMIT-ACCEPT (the pre-init reject row; identity)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-COMMIT-ACCEPT)]

  claim // 1P-PRESV-P-COMMIT-REJECT (the pre-init reject row; identity)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-COMMIT-REJECT)]

  claim // 1P-PRESV-P-EXEC-MINT (the stall row; identity)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-EXEC-MINT)]

  claim // 1P-PRESV-P-EXEC-REFUSE (the stall row; identity)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-EXEC-REFUSE)]

  claim // 1P-PRESV-P-EXEC-SOURCE (the stall row; identity)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-EXEC-SOURCE)]

  claim // 1P-PRESV-P-GATE-MINT (the pre-init gate refusal; diag only)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-GATE-MINT)]

  claim // 1P-PRESV-P-GATE-REFUSE (the pre-init gate refusal; diag only)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aGateJ(aOkF:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-GATE-REFUSE)]

  claim // 1P-PRESV-P-INIT-ACCEPT (THE RE-TAG: 0 -> 1, the safety bookkeeping set)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-INIT-ACCEPT)]

  claim // 1P-PRESV-P-INIT-REFUSE (the tag-0 refuse row; identity)
    <k> ABSInvT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkF:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-PRESV-P-INIT-REFUSE)]

  // ===========================================================================
  // §COH — THE TAG-COHERENCE FAMILY (genesis + one claim per reachable
  //        class row; coherent in -> coherent out, including THE RE-TAG).
  // ===========================================================================
  claim // 1P-COH-GENESIS
    <k> tagCoherentT(absGenesisT) => true </k>
    [label(1P-COH-GENESIS)]

  claim // 1P-COH-P-INIT-ACCEPT (THE RE-TAG lands coherent-1)
    <k> tagCoherentT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-COH-P-INIT-ACCEPT)]

  claim // 1P-COH-P-INIT-REFUSE
    <k> tagCoherentT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkF:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-COH-P-INIT-REFUSE)]

  claim // 1P-COH-P-EXEC-STALL
    <k> tagCoherentT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-COH-P-EXEC-STALL)]

  claim // 1P-COH-P-GATE-REFUSE
    <k> tagCoherentT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-COH-P-GATE-REFUSE)]

  claim // 1P-COH-P-COMMIT-REJECT
    <k> tagCoherentT(absStepT(absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStT(0, false, false, 0, 0, 0, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires SF ==K false
    [label(1P-COH-P-COMMIT-REJECT)]

  claim // 1P-COH-I-INIT (the tag-1 identity)
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-COH-I-INIT)]

  claim // 1P-COH-I-EXEC-MINT
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-COH-I-EXEC-MINT)]

  claim // 1P-COH-I-EXEC-SOURCE
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-COH-I-EXEC-SOURCE)]

  claim // 1P-COH-I-EXEC-REFUSE
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(1P-COH-I-EXEC-REFUSE)]

  claim // 1P-COH-I-GATE-MINT (the split-form mint row)
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 1 andBool SF ==K true
    [label(1P-COH-I-GATE-MINT)]

  claim // 1P-COH-I-GATE-REFUSE-LOW (row A)
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool E <=Int 0 andBool SF ==K true
    [label(1P-COH-I-GATE-REFUSE-LOW)]

  claim // 1P-COH-I-GATE-REFUSE-HI (row C)
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 1 andBool SF ==K true
    [label(1P-COH-I-GATE-REFUSE-HI)]

  claim // 1P-COH-I-COMMIT-ACCEPT (the split-form accept row)
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 1 andBool E >=Int 1 andBool SF ==K true
    [label(1P-COH-I-COMMIT-ACCEPT)]

  claim // 1P-COH-I-COMMIT-REJECT-LOW (row A)
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
         andBool (G <=Int 0 orBool E <=Int 0)
    [label(1P-COH-I-COMMIT-REJECT-LOW)]

  claim // 1P-COH-I-COMMIT-REJECT-HI (row C)
    <k> tagCoherentT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AStateT </absjshadow>
    requires G >=Int 1 andBool E >=Int 1 andBool SF ==K true
    [label(1P-COH-I-COMMIT-REJECT-HI)]

  // ===========================================================================
  // §CORR — THE REFINEMENT FAMILY (see spec/refinement-relation.md):
  //         TAGSOUND (the observation agreement), TAGCOMPLETE-B1/B2 (the
  //         per-branch completeness), TAGCOMPLETE (the GENERAL form — the
  //         honest attempt over a disjunctive requires; the 1O evidence
  //         predicts the checker cannot dispatch it — whatever happens is
  //         recorded), and the ERASE-* per-class commutations (the erased
  //         tagged successor equals the frozen 1N rule's successor fields,
  //         in the absStE mirror space; the mirror's field correspondence
  //         is generator-verified against the 1N source).
  // ===========================================================================
  claim // 1P-TAGSOUND: erasing the tag loses NOTHING but the tag (the
        // observation agreement; general over the tagged state space).
    <k> eraseT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))
        ==K absStE(C, T, G, E, N, SF, D) => true </k>
    [label(1P-TAGSOUND)]

  claim // 1P-TAGCOMPLETE-B1: every pre-init invariant state injects coherent.
    <k> ABSInvT(tagStE(absStE(C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))) => true </k>
    requires notBool C andBool notBool T andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0
    [label(1P-TAGCOMPLETE-B1)]

  claim // 1P-TAGCOMPLETE-B2: every initialized invariant state injects coherent.
    <k> ABSInvT(tagStE(absStE(C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))) => true </k>
    requires C andBool T andBool G >=Int 0 andBool E >=Int 0 andBool SF
    [label(1P-TAGCOMPLETE-B2)]

  claim // 1P-TAGCOMPLETE: the GENERAL form (the disjunction rides in the
        // requires — the exact shape the 1O evidence indicts; ATTEMPT).
    <k> ABSInvT(tagStE(absStE(C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))) => true </k>
    requires (notBool C andBool notBool T andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0)
         orBool (C andBool T andBool G >=Int 0 andBool E >=Int 0 andBool SF)
    [label(1P-TAGCOMPLETE)]

  claim // 1P-ERASE-INIT-ACCEPT: the re-tag erases to the frozen 1N accept.
    <k> eraseT(absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk)))
        ==K absStE(true, true, 0, 0, 0, true, D:ADiag) => true </k>
    [label(1P-ERASE-INIT-ACCEPT)]

  claim // 1P-ERASE-INIT-REFUSE
    <k> eraseT(absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkF:AOk)))
        ==K absStE(false, false, G, E, N, SF, D) => true </k>
    [label(1P-ERASE-INIT-REFUSE)]

  claim // 1P-ERASE-EXEC-MINT
    <k> eraseT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc)))
        ==K absStE(true, true, G, E +Int 1, N, SF, D) => true </k>
    [label(1P-ERASE-EXEC-MINT)]

  claim // 1P-ERASE-EXEC-SOURCE
    <k> eraseT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc)))
        ==K absStE(true, true, G, E, N, SF, adSource) => true </k>
    [label(1P-ERASE-EXEC-SOURCE)]

  claim // 1P-ERASE-EXEC-REFUSE
    <k> eraseT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc)))
        ==K absStE(true, true, G, E, N, SF, adExecRefuse) => true </k>
    [label(1P-ERASE-EXEC-REFUSE)]

  claim // 1P-ERASE-GATE-MINT (the split-form mint)
    <k> eraseT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk)))
        ==K absStE(true, true, G +Int 1, E, N, SF, D) => true </k>
    requires E >=Int 1
    [label(1P-ERASE-GATE-MINT)]

  claim // 1P-ERASE-GATE-REFUSE (the split-form refusal)
    <k> eraseT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk)))
        ==K absStE(true, true, G, E, N, SF, adGate) => true </k>
    requires E <=Int 0
    [label(1P-ERASE-GATE-REFUSE)]

  claim // 1P-ERASE-COMMIT-ACCEPT (the split-form accept)
    <k> eraseT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk)))
        ==K absStE(true, true, G -Int 1, E -Int 1, N +Int 1, true, D) => true </k>
    requires G >=Int 1 andBool E >=Int 1
    [label(1P-ERASE-COMMIT-ACCEPT)]

  claim // 1P-ERASE-COMMIT-REJECT-LOW (row A)
    <k> eraseT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk)))
        ==K absStE(true, true, G, E, N, SF, D) => true </k>
    requires G <=Int 0 orBool E <=Int 0
    [label(1P-ERASE-COMMIT-REJECT-LOW)]

  claim // 1P-ERASE-COMMIT-REJECT-HI (row C)
    <k> eraseT(absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk)))
        ==K absStE(true, true, G, E, N, SF, D) => true </k>
    requires G >=Int 1 andBool E >=Int 1
    [label(1P-ERASE-COMMIT-REJECT-HI)]

  claim // 1P-ERASE-ROUNDTRIP: tagStE . eraseT is the identity on both
        // branches (the completeness of the erase map, evaluation form).
    <k> (tagStE(eraseT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)))
         ==K absStT(0, false, false, G, E, N, SF, D))
        andBool
        (tagStE(eraseT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)))
         ==K absStT(1, true, true, G, E, N, SF, D)) => true </k>
    [label(1P-ERASE-ROUNDTRIP)]

  // ===========================================================================
  // §TLR — THE LEMMA-BACKED UNIVERSAL (run with --trusted <the PRESV
  //        family>, AFTER stage L has re-proven every lemma).  The 1O
  //        discipline verbatim, over the TDR machine.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absExecutableT(RUN:APProg, AX:AStateT)
    ensures ABSInvT(?AX2:AStateT)
    [circularity, label(1P-UNIV-MACHINE-TLR)]

  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absCfgPinnedT(AX)
         andBool absExecutableT(RUN:APProg, AX:AStateT)
    ensures absInitShapedT(?AX2:AStateT)
    [circularity, label(1P-UNIV-PREFIX-TLR)]

endmodule
