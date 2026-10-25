// =============================================================================
// SRW3 PHASE 1S — THE COUNT-SEMANTICS BATTERY (mission §3, spec/count-semantics.md)
//                    (phase1s/proofs/n_s_count_semantics.k)
//
// C1.1 elimination equations (evaluation);
// C1.2 nonnegativity: the UNIVERSAL attempt (recorded with its exact
//      residual — never relabeled), the two conditional constructor-case
//      lemmas, the slack-propagation form, the STATE-RELATION and GENESIS
//      correspondence lemmas;
// the depth family lives in the generated n_s_c12_family.k.
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/rel-machine.k"

module S-COUNT-PROOFS
  imports SRW3N-REL-S

  // ===========================================================================
  // C1.1 — the elimination equations (PROVED by evaluation)
  // ===========================================================================
  claim <k> countToInt(zeroP) => 0 </k>
    [label(1S-C1.1-EQ0)]

  claim <k> countToInt(succP(P:PoolCount)) => countToInt(P) +Int 1 </k>
    [label(1S-C1.1-EQ1)]

  // ===========================================================================
  // C1.2 — nonnegativity.
  //   1S-C1.2-UNIV is the universal attempt of record. The pinned toolchain
  //   has no structural induction over function-argument constructor
  //   variables (the boundary recorded since 1O); the residual of THIS run
  //   is the residual of record — never relabeled, never a counterexample.
  // ===========================================================================
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures ?N:Int >=Int 0
    [label(1S-C1.2-UNIV)]

  // the two constructor cases (the induction step as CONDITIONAL lemmas)
  claim <k> countToInt(zeroP) => 0 </k>
    [label(1S-C1.2-CASE-ZERO)]

  claim <k> countToInt(succP(P:PoolCount)) => ?N:Int </k>
        requires countToInt(P:PoolCount) >=Int 0
        ensures ?N:Int >=Int 0
    [label(1S-C1.2-CASE-SUCC)]

  // the slack-propagation form (the mint-class discharger; NO induction)
  claim <k> countToInt(succP(succP(E0:PoolCount))) => ?N:Int </k>
        requires countToInt(succP(E0:PoolCount)) >=Int 0
        ensures ?N:Int >=Int 0
    [label(1S-C1.2-SLACK)]

  // ===========================================================================
  // §2 the state-relation lemmas (spec/state-correspondence.md)
  //   1S-STATEREL-IMAGE (general form): ATTEMPT — the residual of record is
  //   the implication checker's leaf propagation (neither a tagCoherentQ
  //   hypothesis nor its unfolded conjuncts propagate into the goal's
  //   impliesBool conjuncts; transcripts/k/kprove_1S-STATEREL-IMAGE.log).
  //   The two CONSTRUCTOR-PINNED cases close fully by evaluation and carry
  //   the lemma's content on the coherent fragment (the only fragment any
  //   reachable state inhabits — the 1Q COH record).
  // ===========================================================================
  claim <k> StateRel(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount,
                            N:Int, SF:Bool, D:ADiag),
                     qToQE(absStQ(TG, C, T, G, E, N, SF, D))) => true </k>
        requires (TG ==Int 1 impliesBool (C andBool T))
             andBool (TG ==Int 0 impliesBool (notBool C andBool notBool T))
    [label(1S-STATEREL-IMAGE)]

  claim <k> StateRel(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                            N:Int, SF:Bool, D:ADiag),
                     qToQE(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag))) => true </k>
    [label(1S-STATEREL-IMAGE-T0)]

  claim <k> StateRel(absStQ(1, true, true, G:PoolCount, E:PoolCount,
                            N:Int, SF:Bool, D:ADiag),
                     qToQE(absStQ(1, true, true, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag))) => true </k>
    [label(1S-STATEREL-IMAGE-T1)]

  // the initial-state correspondence (all three by evaluation)
  claim <k> StateRel(absGenesisQ, eraseQ(absGenesisQ)) => true </k>
    [label(1S-INIT-CORR-REL)]

  claim <k> ABSInvE(eraseQ(absGenesisQ)) => true </k>
    [label(1S-INIT-CORR-SAFEINT)]

  claim <k> ABSInvQ(absGenesisQ) => true </k>
    [label(1S-INIT-CORR-SAFECOUNT)]

  // the genesis image is exactly the integer genesis image (field-for-field)
  claim <k> eraseQ(absGenesisQ)
        => absStQE(false, false, 0, 0, 0, false, adNone) </k>
    [label(1S-INIT-CORR-IMAGE)]

  // ===========================================================================
  // C1.5 (backward, conditional) — a successor count interprets >= 1 given
  // the inner nonnegativity; the unconditional form is C1.2-dependent.
  // ===========================================================================
  claim <k> countToInt(succP(P:PoolCount)) => ?N:Int </k>
        requires countToInt(P:PoolCount) >=Int 0
        ensures ?N:Int >=Int 1
    [label(1S-C1.5-BWD-COND)]

endmodule
