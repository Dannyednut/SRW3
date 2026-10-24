// =============================================================================
// SRW3 PHASE 1Q — THE LEMMA MODULE OVER THE CONSTRUCTOR-COUNT MACHINE: the
//                    P1 tag facts, the branch-complete preservation family,
//                    the tag-coherence family, and the CORR/C families
//                    (the C1-C5 obligations of spec/refinement-relation.md).
//                    (phase1q/proofs/n_q_lemmas_q.k)
//
// Family shapes mirror the 1P lemma module (phase1p/proofs/n_p_lemmas_tdr.k)
// claim-for-claim, restated over absStQ/ABSInvQ/absStepQ with the pool head
// pinned per branch (the constructor fork's claim-level mirror).
//
// Trust discipline (the 1O/1P rule): nothing here is trusted; every claim
// is attempted live with its raw log retained.  C1-DEP claims carry
// `countToInt(_) >=Int 0` as an EXPLICIT disclosed hypothesis (obligation
// C1 is open); a C1-DEP PROVED claim is NOT a C1-free proof and both
// statuses are recorded separately in claims/claims.csv.
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-q.k"

module Q-LEMMAS-PROOFS
  imports SRW3N-ABS-Q

  // ===========================================================================
  // §P1 — THE TAG FACTS (3 claims)
  // ===========================================================================
  claim // 1Q-P1-TAG-RANGE: the tag range follows from the invariant (z3).
    <k> (TG:Int >=Int 0 andBool TG:Int <=Int 1) => true </k>
    requires ABSInvQ(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag))
    [label(1Q-P1-TAG-RANGE)]

  claim // 1Q-P1-GENESIS-COH: the constructor genesis is coherent (evaluation).
    <k> tagCoherentQ(absGenesisQ) => true </k>
    [label(1Q-P1-GENESIS-COH)]

  claim // 1Q-P1-ERASE-GENESIS: the genesis erases to the exact Int-image
        // genesis (evaluation — the 1P TAGST-ROUNDTRIP's Q form; the
        // Int->PoolCount rebuild direction is not defined, EQ-G).
    <k> ( eraseQ(absGenesisQ) ==K absStQE(false, false, 0, 0, 0, false, adNone)) => true </k>
    [label(1Q-P1-ERASE-GENESIS)]

  // ===========================================================================
  // §C1 — THE REPRESENTATION NONNEGATIVITY OBLIGATION
  // ===========================================================================
  claim // 1Q-C1-NONNEG (the general obligation; expected: sticks — needs
        // structural induction over the free constructor sort; the residual
        // IS the record; concrete witnesses below are the mechanized
        // fragment, classified BOUNDED).
    <k> countToInt(N:PoolCount) >=Int 0 => true </k>
    [label(1Q-C1-NONNEG)]

  claim // 1Q-C1-CONCRETE (BOUNDED: depths 0..5 by evaluation — disclosed as
        // a bounded test, NOT the general C1).
    <k> (countToInt(zeroP) >=Int 0
         andBool countToInt(succP(zeroP)) >=Int 0
         andBool countToInt(succP(succP(zeroP))) >=Int 0
         andBool countToInt(succP(succP(succP(zeroP)))) >=Int 0
         andBool countToInt(succP(succP(succP(succP(zeroP))))) >=Int 0
         andBool countToInt(succP(succP(succP(succP(succP(zeroP)))))) >=Int 0)
        => true </k>
    [label(1Q-C1-CONCRETE)]

  // ===========================================================================
  // §PRESV — THE BRANCH-COMPLETE PRESERVATION FAMILY (14 claims; the 1P
  //          family restated over the constructor machine; the pool HEAD
  //          pinned per branch — the claim-level mirror of the fork; NO
  //          pool requires anywhere).
  // ===========================================================================
  claim // 1Q-PRESV-I-COMMIT-ACCEPT (row B-SS: structural dec x2)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-COMMIT-ACCEPT)]

  claim // 1Q-PRESV-I-COMMIT-REJECT-ZG (row A-Z*: the G-empty complement)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, zeroP, E:PoolCount, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absStQ(1, true, true, zeroP, E:PoolCount, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-COMMIT-REJECT-ZG)]

  claim // 1Q-PRESV-I-COMMIT-REJECT-ZGS (row A-SZ: the E-empty complement)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, succP(G0), zeroP, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStQ(1, true, true, succP(G0), zeroP, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-COMMIT-REJECT-ZGS)]

  claim // 1Q-PRESV-I-COMMIT-REJECT-HI (row C-SS: rejected with pools ok)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-COMMIT-REJECT-HI)]

  claim // 1Q-PRESV-I-COMMIT-REJECT-BITF (row D-SS: the accept bit false)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag), aCommitJ(aOkF:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-COMMIT-REJECT-BITF)]

  claim // 1Q-PRESV-I-EXEC-MINT (the structural inc; variable pools)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-EXEC-MINT)]

  claim // 1Q-PRESV-I-EXEC-REFUSE
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-EXEC-REFUSE)]

  claim // 1Q-PRESV-I-EXEC-SOURCE
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc))) => true </k>
    <absjshadow> absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-EXEC-SOURCE)]

  claim // 1Q-PRESV-I-GATE-MINT (row B-S: structural inc on G)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-GATE-MINT)]

  claim // 1Q-PRESV-I-GATE-MINT-EMPTY (row A-Z: the empty-pool refusal)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, G:PoolCount, zeroP, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absStQ(1, true, true, G:PoolCount, zeroP, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-GATE-MINT-EMPTY)]

  claim // 1Q-PRESV-I-GATE-REFUSE-S (row C-S: refused, nonempty)
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk))) => true </k>
    <absjshadow> absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires SF ==K true
    [label(1Q-PRESV-I-GATE-REFUSE-S)]

  claim // 1Q-PRESV-I-INIT-ACCEPT (the ONLY legal re-tag; pools reset)
    <k> ABSInvQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires N ==Int 0
    [label(1Q-PRESV-I-INIT-ACCEPT)]

  claim // 1Q-PRESV-I-INIT-REFUSE
    <k> ABSInvQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aInitJ(aOkF:AOk))) => true </k>
    <absjshadow> absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires N ==Int 0
    [label(1Q-PRESV-I-INIT-REFUSE)]

  claim // 1Q-PRESV-I-EXEC-STALL (the tag-0 stall discipline)
    <k> ABSInvQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag):AStateQ </absjshadow>
    requires N ==Int 0
    [label(1Q-PRESV-I-EXEC-STALL)]

  // ===========================================================================
  // §COH — THE TAG-COHERENCE FAMILY (6 claims: coherent in, coherent out)
  // ===========================================================================
  claim // 1Q-COH-P-INIT-ACCEPT
    <k> tagCoherentQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    requires N ==Int 0
    [label(1Q-COH-P-INIT-ACCEPT)]

  claim // 1Q-COH-P-INIT-REFUSE
    <k> tagCoherentQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aInitJ(aOkF:AOk))) => true </k>
    requires N ==Int 0
    [label(1Q-COH-P-INIT-REFUSE)]

  claim // 1Q-COH-P-EXEC-STALL
    <k> tagCoherentQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    requires N ==Int 0
    [label(1Q-COH-P-EXEC-STALL)]

  claim // 1Q-COH-I-GATE-MINT (the structural inc keeps coherence)
    <k> tagCoherentQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    [label(1Q-COH-I-GATE-MINT)]

  claim // 1Q-COH-I-COMMIT-ACCEPT (the structural dec keeps coherence — the
        // dec of a successor is a PoolCount by construction)
    <k> tagCoherentQ(absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    [label(1Q-COH-I-COMMIT-ACCEPT)]

  claim // 1Q-COH-I-COMMIT-REJECT-ZG (the empty-pool complement keeps coherence)
    <k> tagCoherentQ(absStepQ(absStQ(1, true, true, zeroP, E:PoolCount, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    [label(1Q-COH-I-COMMIT-REJECT-ZG)]

  // ===========================================================================
  // §C2 — THE STEP-CORRESPONDENCE FAMILY (eraseQ o absStepQ == absStepE o
  //       eraseQ, per class).  The erased 1P rows need the erased pools to
  //       satisfy the 1P guards; the C1-DEP claims carry
  //       `countToInt(_) >=Int 0` as an EXPLICIT DISCLOSED hypothesis.
  // ===========================================================================
  claim // 1Q-C2-ERASE-INIT-ACCEPT (the re-tag; pools reset on both sides)
    <k> ( eraseQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk)))
        ==K absStepE(eraseQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag)), aInitJ(aOkT:AOk))) => true </k>
    [label(1Q-C2-ERASE-INIT-ACCEPT)]

  claim // 1Q-C2-ERASE-INIT-REFUSE
    <k> ( eraseQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aInitJ(aOkF:AOk)))
        ==K absStepE(eraseQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag)), aInitJ(aOkF:AOk))) => true </k>
    [label(1Q-C2-ERASE-INIT-REFUSE)]

  claim // 1Q-C2-ERASE-EXEC-MINT (succP(E) erases to ctI(E)+1 — the equation
        // unfolds on the CONSTRUCTOR-headed term; no split needed)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc)))
        ==K absStepE(eraseQ(absStQ(1, true, true, G, E, N, SF, D)), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    [label(1Q-C2-ERASE-EXEC-MINT)]

  claim // 1Q-C2-ERASE-EXEC-REFUSE
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc)))
        ==K absStepE(eraseQ(absStQ(1, true, true, G, E, N, SF, D)), aExecJ(aOkF:AOk, aSrcAuth:ASrc))) => true </k>
    [label(1Q-C2-ERASE-EXEC-REFUSE)]

  claim // 1Q-C2-ERASE-EXEC-SOURCE
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc)))
        ==K absStepE(eraseQ(absStQ(1, true, true, G, E, N, SF, D)), aExecJ(aOkT:AOk, aSrcOther:ASrc))) => true </k>
    [label(1Q-C2-ERASE-EXEC-SOURCE)]

  claim // 1Q-C2-ERASE-EXEC-STALL
    <k> ( eraseQ(absStepQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc)))
        ==K absStepE(eraseQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag)), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    [label(1Q-C2-ERASE-EXEC-STALL)]

  claim // 1Q-C2-ERASE-GATE-MINT (row B-S; C1-DEP: the 1P row's own
        // `ctI(succP(E0)) >=Int 1` guard needs ctI(E0) >=Int 0 — z3-false
        // for an uninterpreted ctI without the hypothesis)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, G, succP(E0), N:Int, SF:Bool, D:ADiag)), aGateJ(aOkT:AOk))) => true </k>
    requires countToInt(E0) >=Int 0
    [label(1Q-C2-ERASE-GATE-MINT)]

  claim // 1Q-C2-ERASE-GATE-MINT-NODEP (the SAME claim WITHOUT the C1
        // hypothesis — attempted to measure the C1 dependence; expected:
        // sticks at the 1P row guard)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, G, succP(E0), N:Int, SF:Bool, D:ADiag)), aGateJ(aOkT:AOk))) => true </k>
    [label(1Q-C2-ERASE-GATE-MINT-NODEP)]

  claim // 1Q-C2-ERASE-GATE-REFUSE-Z (row A-Z: concrete zeroP needs no C1)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, zeroP, N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, G, zeroP, N:Int, SF:Bool, D:ADiag)), aGateJ(aOkF:AOk))) => true </k>
    [label(1Q-C2-ERASE-GATE-REFUSE-Z)]

  claim // 1Q-C2-ERASE-GATE-REFUSE-S (row C-S; C1-DEP on the row-C guard)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0), N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, G, succP(E0), N:Int, SF:Bool, D:ADiag)), aGateJ(aOkF:AOk))) => true </k>
    requires countToInt(E0) >=Int 0
    [label(1Q-C2-ERASE-GATE-REFUSE-S)]

  claim // 1Q-C2-ERASE-COMMIT-ACCEPT (row B-SS; C1-DEP: the 1P accept
        // guard `ctI(succP(G0)) >=Int 1 andBool ctI(succP(E0)) >=Int 1`)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag)), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    requires countToInt(G0) >=Int 0 andBool countToInt(E0) >=Int 0
    [label(1Q-C2-ERASE-COMMIT-ACCEPT)]

  claim // 1Q-C2-ERASE-COMMIT-REJECT-ZG (row A-Z*: the G side is CONCRETE
        // zeroP — the 1P complement fires on 0 <=Int 0; NO C1 needed)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, zeroP, E:PoolCount, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, zeroP, E, N:Int, SF:Bool, D:ADiag)), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    [label(1Q-C2-ERASE-COMMIT-REJECT-ZG)]

  claim // 1Q-C2-ERASE-COMMIT-REJECT-ZGS (row A-SZ: the E side is CONCRETE
        // zeroP — the 1P complement fires on 0 <=Int 0; NO C1 needed)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, succP(G0), zeroP, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, succP(G0), zeroP, N:Int, SF:Bool, D:ADiag)), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    [label(1Q-C2-ERASE-COMMIT-REJECT-ZGS)]

  claim // 1Q-C2-ERASE-COMMIT-REJECT-HI (row C-SS; C1-DEP)
    <k> ( eraseQ(absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk)))
        ==K absStepE(eraseQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, SF:Bool, D:ADiag)), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    requires countToInt(G0) >=Int 0 andBool countToInt(E0) >=Int 0
    [label(1Q-C2-ERASE-COMMIT-REJECT-HI)]

  // ===========================================================================
  // §C3 — THE ACCEPTANCE-CORRESPONDENCE OBLIGATION
  // ===========================================================================
  claim // 1Q-C3-SUCC-IMPLIES-NONZERO (the => direction; C1-DEP)
    <k> countToInt(succP(G0)) >=Int 1 => true </k>
    requires countToInt(G0) >=Int 0
    [label(1Q-C3-SUCC-IMPLIES-NONZERO)]

  claim // 1Q-C3-ZERO-NOT-NONZERO (the zeroP witness: ctI(zeroP)=0 < 1)
    <k> (countToInt(zeroP) >=Int 1) => false </k>
    [label(1Q-C3-ZERO-NOT-NONZERO)]

  claim // 1Q-C3-GENERAL-FORM (the equivalence over a symbolic pool — the
        // constructor case split the checker lacks; expected: sticks)
    <k> isSuccP(N:PoolCount) ==K (countToInt(N:PoolCount) >=Int 1) => true </k>
    requires countToInt(N:PoolCount) >=Int 0
    [label(1Q-C3-GENERAL-FORM)]

  // ===========================================================================
  // §C4 — THE INVARIANT-MEANING CORRESPONDENCE (TAGSOUND-Q; the rebuild
  //       (TAGCOMPLETE) direction needs the Int->PoolCount map, which is
  //       deliberately not defined — EQ-G; the per-class C2 commutations
  //       carry the rest of the C4 content)
  // ===========================================================================
  claim // 1Q-C4-TAGSOUND-B0: the erased Q genesis-branch state satisfies
        // the 1P invariant meaning (evaluation).
    <k> ABSInvE(eraseQ(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag))) => true </k>
    requires N ==Int 0
    [label(1Q-C4-TAGSOUND-B0)]

  claim // 1Q-C4-TAGSOUND-B1-SUCC: the erased initialized state with
        // successor pools satisfies the 1P meaning (C1-DEP: the 1P
        // invariant's own `ctI >=Int 0` conjuncts).
    <k> ABSInvE(eraseQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, true, D:ADiag))) => true </k>
    requires countToInt(G0) >=Int 0 andBool countToInt(E0) >=Int 0
    [label(1Q-C4-TAGSOUND-B1-SUCC)]

  claim // 1Q-C4-TAGSOUND-B1-ZERO: the erased initialized state with zeroP
        // pools (evaluation).
    <k> ABSInvE(eraseQ(absStQ(1, true, true, zeroP, zeroP, N:Int, true, D:ADiag))) => true </k>
    [label(1Q-C4-TAGSOUND-B1-ZERO)]

  // ===========================================================================
  // §C5 — THE TRANSITION-COMPLETENESS OBLIGATION
  // ===========================================================================
  claim // 1Q-C5-EXHAUSTIVENESS-ATTEMPT (the free-constructor exhaustiveness
        // over a symbolic pool — the function-argument constructor split
        // the checker lacks; expected: sticks.  The MECHANICAL C5 evidence
        // is the generator's cell-grid check, recorded in audit/.)
    <k> (isZeroP(N:PoolCount) orBool isSuccP(N:PoolCount)) => true </k>
    [label(1Q-C5-EXHAUSTIVENESS-ATTEMPT)]

  // ===========================================================================
  // §NEG-SELF — THE SELF-ASSUMPTION PROBE (the 1P PASS-EVAL hole, reproduced
  //             deliberately; MUST be recorded SELF-ASSUMED-NOT-A-PROOF)
  // ===========================================================================
  claim // 1Q-NEG-SELF-ASSUME: assumes its own conclusion inside the
        // hypothesis — closes with WarnTrivialClaim; NOT a proof of
        // anything.
    <k> ABSInvQ(absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, true, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    requires ABSInvQ(absStepQ(absStQ(1, true, true, succP(G0), succP(E0), N:Int, true, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk)))
    [label(1Q-NEG-SELF-ASSUME)]

endmodule
