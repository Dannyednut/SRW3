// =============================================================================
// SRW3 PHASE 1S — THE NEGATIVE-CONTROL BATTERY (mission §7)
//                    (phase1s/tests/n_s_neg.k)
//
// Every control states a claim that MUST FAIL (or, where labeled, must
// close trivially and be classified SELF-ASSUMED). A closure of a MUST-FAIL
// row is an alarm; the summarizer fails closed on any inconsistency.
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "n_s_neg_defs.k"

module S-NEG-PROOFS
  imports SRW3N-NEG-DEFS-S

  // ===========================================================================
  // 1S-NEG-NEGCOUNT-UNSAFE (MUST FAIL): a negative-count integer state is
  //   UNSAFE under the integer model's own predicate (ABSInvE's tag-1
  //   nonnegativity conjuncts) — negative counts have NO legal natural-
  //   number representation, and the safety predicate refuses them.
  // ===========================================================================
  claim <k> ABSInvE(absStQE(true, true, -1, -1, 0, true, adNone)) => true </k>
    [label(1S-NEG-NEGCOUNT-UNSAFE)]

  // ===========================================================================
  // 1S-NEG-NEGCOUNT-NOT-REPRESENTABLE (MUST FAIL): no Q state's image is a
  //   negative count — the genesis's image is (0,0), never (-1,-1): the
  //   evaluation closes against the fabricated negative target.
  // ===========================================================================
  claim <k> eraseQ(absGenesisQ) => absStQE(true, true, -1, -1, 0, true, adNone) </k>
    [label(1S-NEG-NEGCOUNT-NOT-REPRESENTABLE)]

  // ===========================================================================
  // THE STALE MAP (mission §7: 过期/错误计数映射; the definitions live in
  //   n_s_neg_defs.k): the stale map cannot reproduce the exact increment.
  // ===========================================================================

  claim <k> eraseQStale(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag),
                                 aExecJ(aOkT, aSrcAuth)))
        => absStepE(eraseQStale(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                       N:Int, SF:Bool, D:ADiag)),
                    aExecJ(aOkT, aSrcAuth)) </k>
    [label(1S-NEG-STALE-MAP)]

  // ===========================================================================
  // 1S-NEG-DEC-FROM-ZERO (MUST FAIL): zeroP has NO decrement anywhere —
  //   the fabricated accept-from-G-empty post (E stripped, N+1) is
  //   unreachable (the real step is the row A-Z* identity).
  // ===========================================================================
  claim <k> absStepQ(absStQ(1, true, true, zeroP, succP(zeroP), 0, true, adNone),
                     aCommitJ(aOkT, aOkT))
        => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone) </k>
    [label(1S-NEG-DEC-FROM-ZERO)]

  // ===========================================================================
  // 1S-NEG-DEC-FROM-ONE-INT (MUST FAIL): the integer side cannot decrement
  //   below the guard — at G'=0 the row-A complement fires (identity); the
  //   fabricated (-1, 0, N+1) post is unreachable.
  // ===========================================================================
  claim <k> absStepE(absStQE(true, true, 0, 1, 0, true, adNone), aCommitJ(aOkT, aOkT))
        => absStQE(true, true, -1, 0, 1, true, adNone) </k>
    [label(1S-NEG-DEC-FROM-ONE-INT)]

  // ===========================================================================
  // 1S-NEG-EMPTY-COMMIT (MUST FAIL): the strong empty-reject of record —
  //   a commit-accept from BOTH pools empty does NOT mint (N stays 0).
  // ===========================================================================
  claim <k> absStepQ(absStQ(1, true, true, zeroP, zeroP, 0, true, adNone),
                     aCommitJ(aOkT, aOkT))
        => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone) </k>
    [label(1S-NEG-EMPTY-COMMIT)]

  // ===========================================================================
  // 1S-NEG-BAD-AUTH-COMMIT (MUST FAIL): 双池非空但授权位无效 — the
  //   (aOkF, _) commit does NOT mint (row D-SS identity).
  // ===========================================================================
  claim <k> absStepQ(absStQ(1, true, true, succP(zeroP), succP(zeroP), 0, true, adNone),
                     aCommitJ(aOkF, aOkT))
        => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone) </k>
    [label(1S-NEG-BAD-AUTH-COMMIT)]

  // ===========================================================================
  // THE BRANCH-TAG BREAK (mission §7: 破坏分支 tag 的转移; the broken step
  //   lives in n_s_neg_defs.k): the mutant re-tag to 0 breaks (i) the
  //   invariant and (ii) the correspondence to the integer mirror — both
  //   MUST FAIL.
  // ===========================================================================

  claim <k> ABSInvQ(absStepQBroken(absGenesisQ, aInitJ(aOkT))) => true </k>
    [label(1S-NEG-TAGBREAK-INV)]

  claim <k> eraseQ(absStepQBroken(absGenesisQ, aInitJ(aOkT)))
        => absStepE(eraseQ(absGenesisQ), aInitJ(aOkT)) </k>
    [label(1S-NEG-TAGBREAK-CORR-IMAGE)]

  // THE STATE-REL-LEVEL TAG-BREAK CONTROL (MUST FAIL): the broken post-state
  //   is NOT StateRel-related to the honest post-state's image — the tag-bits
  //   consistency conjuncts refuse it. This is the control that actually
  //   carries the tag discipline (the first draft above CLOSED — the eraseQ
  //   image is BLIND to the tag by design: the mirror has no tag field — the
  //   finding is retained as the -IMAGE row, expectation PASS).
  claim <k> StateRel(absStepQBroken(absGenesisQ, aInitJ(aOkT)),
                     eraseQ(absStepQ(absGenesisQ, aInitJ(aOkT)))) => true </k>
    [label(1S-NEG-TAGBREAK-CORR)]

  // ===========================================================================
  // 1S-NEG-FAKE-CORR (MUST FAIL): the fake universal correspondence — the
  //   per-class conditions REMOVED (symbolic state AND symbolic command).
  //   Both sides are stuck; semantically the claim is false on incoherent
  //   states (Q stutters, the mirror is stuck on mixed bits). Its failure
  //   records WHY the correspondence must be per-class and coherent-fragment
  //   restricted (and why it is never called a bisimulation).
  // ===========================================================================
  claim <k> eraseQ(absStepQ(AX:AStateQ, C:ACmd))
        => absStepE(eraseQ(AX:AStateQ), C:ACmd) </k>
    [label(1S-NEG-FAKE-CORR)]

  // ===========================================================================
  // 1S-NEG-SELF-ASSUMED (closes TRIVIALLY — classified SELF-ASSUMED-NOT-
  //   A-PROOF): the conclusion IS the hypothesis. NEVER cited as C1.2
  //   evidence (the 1Q self-assumption discipline).
  // ===========================================================================
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        requires countToInt(P:PoolCount) >=Int 0
        ensures ?N:Int >=Int 0
    [label(1S-NEG-SELF-ASSUMED)]

  // ===========================================================================
  // 1S-NEG-MIXED-BITS (MUST FAIL): the mixed-bit mirror state is STUCK
  //   (no absStepE row matches both bits true/false) — the fabricated
  //   total post is unreachable. The stuckness of the two models on the
  //   incoherent fragment DIFFERS by design (Q stutters; the mirror is
  //   stuck): the correspondence is coherent-fragment only.
  // ===========================================================================
  claim <k> absStepE(absStQE(true, false, 0, 0, 0, false, adNone), aInitJ(aOkT))
        => absStQE(true, true, 0, 0, 0, true, adNone) </k>
    [label(1S-NEG-MIXED-BITS)]

  // ===========================================================================
  // 1S-NEG-CONV-NEG-INT (MUST FAIL): the CONVERSE direction has no witness
  //   for a negative-count mirror state — no Q state is StateRel-related to
  //   (true,true,-1,-1,…): the relation refuses it by CountRel (the exact
  //   interpretation of ANY constructor count is 0 or positive — at the
  //   evaluated level the relation evaluates false for the fabricated pair).
  // ===========================================================================
  claim <k> StateRel(absGenesisQ, absStQE(false, false, -1, -1, 0, false, adNone)) => true </k>
    [label(1S-NEG-CONV-NEG-INT)]

endmodule
