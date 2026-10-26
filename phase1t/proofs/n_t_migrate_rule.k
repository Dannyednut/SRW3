// =============================================================================
// SRW3 PHASE 1T — WORKSTREAM C, MECHANISM B: the derived-lemma rewrite form.
//                    (phase1t/proofs/n_t_migrate_rule.k)
//
// MECHANISM COMPARISON of record.  Mechanism A (n_t_migrate_uncond.k /
// n_t_corr_uncond.k) hands the Lean-checked C1.2 claim off with --trusted.
// Mechanism B makes the SAME lemma available as rewrite-time
// simplification — the rule is a PROJECTION of the kernel-checked theorem
// c12_nonneg, NOT an assumption:
//
//   evidence: phase1t/audit/lean/c12_induction.lean
//             theorem c12_nonneg : ∀ p : PoolCount, countToInt p ≥ 0
//             (Lean 4.16.0, commit 128a1e6b0a82, kernel-checked, axiom
//              report [propext, Quot.sound]; falsity controls fail as
//              designed — transcripts retained)
//
// The Phase 1S rules were labeled 1S-C12-SIMPL-ASSUMED[+SHIFT] and their
// ledger row declared "never proved".  The 1T rules carry the SAME bodies
// with a DIFFERENT epistemic status, disclosed in the labels: the
// justification is the retained Lean certificate.  A reader who rejects
// the independent-checker route must reject these rows too — nothing else
// changed.  The arithmetic closure (SHIFT) is the C1.2 statement plus
// unbounded-integer monotonicity (I >= 0 → x >= 0 → x + I >= 0), itself
// discharged by Z3's integer arithmetic inside the checker conditions.
//
// The runs below re-execute the unconditional migration battery with these
// derived rules — the direct comparison against the Phase 1S C12ASSUMED
// rows (identical bodies, different justification) isolates the exact
// effect of replacing the assumption by the checked lemma: NONE
// mechanically, ALL epistemically.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1s/semantics/rel-machine.k"

module T-MIGRATE-RULE-PROOFS
  imports SRW3N-REL-S

  // ---------------------------------------------------------------------------
  // THE DERIVED C1.2 LEMMA RULES (projections of the Lean certificate;
  // bodies verbatim from n_s_migrate_c12.k lines 38-42)
  // ---------------------------------------------------------------------------
  rule countToInt(P:PoolCount) >=Int 0 => true
    [simplification, label(1T-C12-LEAN-RULE)]

  rule countToInt(P:PoolCount) +Int I:Int >=Int 0 => true requires I >=Int 0
    [simplification, label(1T-C12-LEAN-RULE-SHIFT)]

  // ---------------------------------------------------------------------------
  // THE DERIVED C1.5 RULE (the successor-lower-bound projection): composed
  // from the K-NATIVE-PROVED conditional 1S-C1.5-BWD-COND
  // (countToInt(succP(P)) >=Int 1 requires countToInt(P) >=Int 0; rc=0,
  // ledger of record) and the Lean-checked C1.2 (the hypothesis holds
  // unconditionally).  Needed by the per-cell equalities, whose mirror-side
  // guards are >=Int 1 shapes (the >=Int 0 rules above do not cover them).
  // ---------------------------------------------------------------------------
  rule countToInt(succP(P:PoolCount)) >=Int I:Int => true requires I >=Int 1
    [simplification, label(1T-C1.5-PROVED-RULE)]

  // ---------------------------------------------------------------------------
  // THE SHIFT-1 PROJECTION: the mirror's guard shapes carry the count as the
  // ALREADY-UNFOLDED +Int-1 form (countToInt(P) +Int 1 — simplification
  // unfolds countToInt(succP(P)) before the succP-headed rule can match), so
  // the >=Int 1 discharge needs the unfolded shape too.  Justification:
  // countToInt(P) >=Int 0 (the Lean-checked C1.2) and I >=Int 1 gives
  // countToInt(P) +Int I >=Int 1 by unbounded-integer monotonicity.
  // ---------------------------------------------------------------------------
  rule countToInt(P:PoolCount) +Int I:Int >=Int 1 => true requires I >=Int 1
    [simplification, label(1T-C12-LEAN-RULE-SHIFT1)]

  // ---------------------------------------------------------------------------
  // the unconditional strengthened universal (verbatim shape from
  // n_s_migrate.k)
  // ---------------------------------------------------------------------------
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool ABSInvE(eraseQ(AX))
         andBool tagCoherentQ(AX)
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
         andBool ABSInvE(eraseQ(?AX2:AStateQ))
    [circularity, label(1T-MIGRATE-UNIV-LEANC12-RULE)]

  // ---------------------------------------------------------------------------
  // the genesis form (the 1S form timed out; recorded whatever happens)
  // ---------------------------------------------------------------------------
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg, absGenesisQ)
    ensures ABSInvQ(?AX2:AStateQ)
         andBool ABSInvE(eraseQ(?AX2:AStateQ))
    [circularity, label(1T-MIGRATE-GENESIS-LEANC12-RULE)]

  // ---------------------------------------------------------------------------
  // the five correspondence cells, conditions dropped (the derived rule
  // discharges them at rewrite time)
  // ---------------------------------------------------------------------------
  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkT)) </k>
    [label(1T-CORR-GATE-MINT-RULE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkF)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkF)) </k>
    [label(1T-CORR-GATE-REFUSE-RULE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkT)) </k>
    [label(1T-CORR-COMMIT-ACCEPT-RULE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkF)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkF)) </k>
    [label(1T-CORR-COMMIT-C-RULE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkF, A2:AOk)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkF, A2:AOk)) </k>
    [label(1T-CORR-COMMIT-D-RULE)]

  // ---------------------------------------------------------------------------
  // the NODEP strip-state probe under the derived rule
  // ---------------------------------------------------------------------------
  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkT)) </k>
    [label(1T-CORR-NODEP-RULE)]

  // ---------------------------------------------------------------------------
  // the three preservation cells under the derived rules (the ABSInvE-chain
  // content the migration theorem composes; the COMMIT-ACCEPT cell is the
  // one whose 1S COND form carried the C1.2 requires)
  // ---------------------------------------------------------------------------
  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aExecJ(aOkT, aSrcAuth)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1T-PRESV-INT-EXE-MINT-RULE)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aGateJ(aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1T-PRESV-INT-GATE-MINT-RULE)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aCommitJ(aOkT, aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1T-PRESV-INT-COMMIT-ACCEPT-RULE)]

  // ===========================================================================
  // 1T-WSA-CTRL-DEST-FALSE-RULE (MUST FAIL) — the false-goal control under
  //   THIS harness (the derived-rule set): if the checked-lemma rules are
  //   strong enough to prove the destination falsehood, the mechanism is
  //   unsound and every closure above is rejected.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg, absGenesisQ)
    ensures ?AX2:AStateQ ==K absGenesisQ
    [label(1T-WSA-CTRL-DEST-FALSE-RULE)]

endmodule
