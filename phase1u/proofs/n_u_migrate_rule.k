// =============================================================================
// SRW3 PHASE 1U — WORKSTREAM A: THE CORRECTED DERIVED-LEMMA RULE MODULE.
//                    (phase1u/proofs/n_u_migrate_rule.k)
//
// SOUNDNESS REMEDIATION OF RECORD.  The Phase 1T module
// phase1t/proofs/n_t_migrate_rule.k (left BYTE-FROZEN as historical evidence
// of what 1T executed) carried ONE unsound derived rule:
//
//   rule countToInt(succP(P:PoolCount)) >=Int I:Int => true
//     requires I >=Int 1
//     [simplification, label(1T-C1.5-PROVED-RULE)]
//
// COUNTEREXAMPLE OF RECORD: P = zeroP, I = 2.  The left side becomes
// countToInt(succP(zeroP)) >=Int 2  ==  1 >=Int 2  ==  false, while the
// requires 2 >=Int 1 HOLDS — the rule rewrites a FALSE predicate to TRUE.
// The 1T justification (the K-proved conditional 1S-C1.5-BWD-COND composed
// with the Lean-checked C1.2) yields EXACTLY the literal threshold
// "countToInt(succP(P)) >=Int 1" and NOTHING STRONGER; the 1T rule
// generalized the justified literal 1 into a universally-quantified I under
// a too-weak requires.  The machine of record contains NO legitimate
// >=Int 2 guard shape over countToInt (verified by inspection:
// phase1q/semantics/abs-machine-q.k rows B/C/D carry G >=Int 1 / E >=Int 1
// on the integer side and CONSTRUCTOR splits on the PoolCount side; the
// invariant conjuncts are >=Int 0) — so the overgeneralization was never
// load-bearing for any true goal.
//
// THE CORRECTION (exact-threshold candidate, the only body the justifying
// theorems support):
//
//   rule countToInt(succP(P:PoolCount)) >=Int 1 => true
//     [simplification, label(1U-C1.5-PROVED-RULE)]
//
// Justification chain (each link retained):
//   (i)   countToInt(succP(P)) = countToInt(P) +Int 1   — the machine
//         equation of record (abs-machine-q.k:402; no requires, no owise);
//   (ii)  countToInt(P) >=Int 0 for ALL P               — the Lean-checked
//         C1.2 (phase1t/audit/lean/c12_induction.lean, theorem c12_nonneg,
//         Lean 4.16.0 kernel-checked, axiom report [propext, Quot.sound]);
//   (iii) x >= 0 -> x + 1 >= 1                          — unbounded-integer
//         monotonicity, discharged inside the Lean helper lemma c15_succ_ge1
//         (phase1u/audit/lean/c12_helpers.lean) and by Z3 within K.
//
// The OTHER THREE derived rules are AUDITED and carried UNCHANGED (their
// bodies are exactly the statements the justifying theorems support):
//   1U-C12-LEAN-RULE       — the literal C1.2 statement;
//   1U-C12-LEAN-RULE-SHIFT — C1.2 + monotonicity (I >= 0);
//   1U-C12-LEAN-RULE-SHIFT1 — C1.2 + monotonicity (I >= 1).
// See phase1u/report/phase1u-final-report.md §A1 for the full rule audit.
//
// The claim battery below is the 1T mechanism-B battery VERBATIM (same
// shapes, same requires/ensures, same [circularity]) with labels prefixed
// 1U- so the ledger rows are fresh and append-only; every 1T row remains
// the record of what 1T actually executed.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1s/semantics/rel-machine.k"

module U-MIGRATE-RULE-PROOFS
  imports SRW3N-REL-S

  // ---------------------------------------------------------------------------
  // THE DERIVED C1.2 LEMMA RULES (projections of the Lean certificate;
  // bodies verbatim from n_t_migrate_rule.k lines 43-47 — audited sound)
  // ---------------------------------------------------------------------------
  rule countToInt(P:PoolCount) >=Int 0 => true
    [simplification, label(1U-C12-LEAN-RULE)]

  rule countToInt(P:PoolCount) +Int I:Int >=Int 0 => true requires I >=Int 0
    [simplification, label(1U-C12-LEAN-RULE-SHIFT)]

  // ---------------------------------------------------------------------------
  // THE CORRECTED C1.5 RULE: the literal threshold the justification chain
  // (i)+(ii)+(iii) supports.  NO requires — the threshold IS 1, not "any
  // I >= 1".  (1T's requires I >=Int 1 was the unsound generalization.)
  // ---------------------------------------------------------------------------
  rule countToInt(succP(P:PoolCount)) >=Int 1 => true
    [simplification, label(1U-C1.5-PROVED-RULE)]

  // ---------------------------------------------------------------------------
  // THE SHIFT-1 PROJECTION (audited sound: C1.2 + monotonicity I >= 1)
  // ---------------------------------------------------------------------------
  rule countToInt(P:PoolCount) +Int I:Int >=Int 1 => true requires I >=Int 1
    [simplification, label(1U-C12-LEAN-RULE-SHIFT1)]

  // ---------------------------------------------------------------------------
  // the unconditional strengthened universal (verbatim shape from
  // n_t_migrate_rule.k / n_s_migrate.k)
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
    [circularity, label(1U-MIGRATE-UNIV-LEANC12-RULE)]

  // ---------------------------------------------------------------------------
  // the genesis form (1S/1T record: TIMEOUT expected; recorded whatever
  // happens, never relabeled)
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
    [circularity, label(1U-MIGRATE-GENESIS-LEANC12-RULE)]

  // ---------------------------------------------------------------------------
  // the five correspondence cells, conditions dropped (verbatim shapes from
  // n_t_migrate_rule.k lines 107-145)
  // ---------------------------------------------------------------------------
  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkT)) </k>
    [label(1U-CORR-GATE-MINT-RULE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkF)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkF)) </k>
    [label(1U-CORR-GATE-REFUSE-RULE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkT)) </k>
    [label(1U-CORR-COMMIT-ACCEPT-RULE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkF)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkF)) </k>
    [label(1U-CORR-COMMIT-C-RULE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkF, A2:AOk)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkF, A2:AOk)) </k>
    [label(1U-CORR-COMMIT-D-RULE)]

  // ---------------------------------------------------------------------------
  // the NODEP strip-state probe under the corrected rule set
  // ---------------------------------------------------------------------------
  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkT)) </k>
    [label(1U-CORR-NODEP-RULE)]

  // ---------------------------------------------------------------------------
  // the three preservation cells under the corrected rules
  // ---------------------------------------------------------------------------
  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aExecJ(aOkT, aSrcAuth)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1U-PRESV-INT-EXE-MINT-RULE)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aGateJ(aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1U-PRESV-INT-GATE-MINT-RULE)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aCommitJ(aOkT, aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1U-PRESV-INT-COMMIT-ACCEPT-RULE)]

  // ===========================================================================
  // 1U-WSA-CTRL-DEST-FALSE-RULE (MUST NOT CLOSE — expected TIMEOUT, same as
  //   the 1T record; the COMPUTATIONALLY DECISIVE false-goal control for the
  //   dangerous generalization is the separate counterexample fixture
  //   phase1u/proofs/n_u_c15_counterexample.k, which closes in seconds).
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg, absGenesisQ)
    ensures ?AX2:AStateQ ==K absGenesisQ
    [label(1U-WSA-CTRL-DEST-FALSE-RULE)]

endmodule
