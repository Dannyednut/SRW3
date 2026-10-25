// =============================================================================
// SRW3 PHASE 1S — THE MIGRATION BATTERY UNDER THE DISCLOSED C1.2 ASSUMPTION
//                    (phase1s/proofs/n_s_migrate_c12.k)
//
// The C12ASSUMED variants of the migration theorem. The assumption is the
// DISCLOSED simplification rule below (label 1S-C12-SIMPL-ASSUMED): the
// C1.2 nonnegativity of countToInt, introduced as a REWRITE-TIME
// simplification so that the implication checker's conditions can use it.
// (The cell-claim form of the axiom cannot discharge pure conditions — the
// first C12ASSUMED run's identical residual is retained:
// transcripts/k/kprove_1S-MIGRATE-UNIV-C12ASSUMED.log.)
//
// EVERY result in this module is PROVED-UNDER-C1.2-ASSUMPTION — never an
// unconditional theorem. The unconditional attempts live in
// n_s_migrate.k (whose residual of record is exactly the C1.2 condition
// pair countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0 at the
// commit-accept strip state).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/rel-machine.k"

module S-MIGRATE-C12-PROOFS
  imports SRW3N-REL-S

  // ===========================================================================
  // THE DISCLOSED C1.2 ASSUMPTION (never proved; the ledger row
  // 1S-C12-NONNEG-ASSUMED is its declaration of record):
  //   countToInt(P) >=Int 0  for all P : PoolCount,
  // plus its ARITHMETIC CLOSURES (each implied by C1.2 + integer
  // arithmetic — the simplifier unfolds countToInt(succP-headed) into
  // +Int forms, so the shifted shapes are what the implication checker's
  // conditions actually contain):
  //   countToInt(P) +Int I >=Int 0  for I >= 0.
  // As simplifications they discharge the implication checker's conditions
  // — which the trusted-cell-claim form could not.
  // ===========================================================================
  rule countToInt(P:PoolCount) >=Int 0 => true
    [simplification, label(1S-C12-SIMPL-ASSUMED)]

  rule countToInt(P:PoolCount) +Int I:Int >=Int 0 => true requires I >=Int 0
    [simplification, label(1S-C12-SIMPL-ASSUMED-SHIFT)]

  // ===========================================================================
  // 1S-MIGRATE-UNIV-C12ASSUMED — the strengthened universal with the
  //   C1.2 assumption. If it closes: PROVED-UNDER-C1.2-ASSUMPTION.
  // ===========================================================================
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
    [circularity, label(1S-MIGRATE-UNIV-C12ASSUMED)]

  // ===========================================================================
  // 1S-MIGRATE-GENESIS-C12ASSUMED — the initial-state-grounded run form
  //   (the "InitialSafeInt(s0) ∧ ReachableInt(s0,s) → SafeInt(s)" shape of
  //   the mission, in the equivalent arbitrary-finite-run form): from the
  //   GENESIS (integer safety by evaluation — 1S-INIT-CORR-*), every
  //   executable run ends integer-safe.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg, absGenesisQ)
    ensures ABSInvQ(?AX2:AStateQ)
         andBool ABSInvE(eraseQ(?AX2:AStateQ))
    [circularity, label(1S-MIGRATE-GENESIS-C12ASSUMED)]

endmodule
