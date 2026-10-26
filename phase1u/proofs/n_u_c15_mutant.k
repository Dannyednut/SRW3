// =============================================================================
// SRW3 PHASE 1U — WORKSTREAM A2: THE UNSOUND-RULE EXHIBIT (DELIBERATELY
//                    BUGGY MUTANT — never ship, never trust).
//                    (phase1u/proofs/n_u_c15_mutant.k)
//
// This module reproduces the EXACT Phase 1T unsound rule
// (n_t_migrate_rule.k:57-58, label 1T-C1.5-PROVED-RULE) in the isolated
// fixture and exhibits its failure mode directly:
//
//   rule countToInt(succP(P:PoolCount)) >=Int I:Int => true
//     requires I >=Int 1                       // <<< THE UNSOUND RULE
//
// MATHEMATICAL FALSITY OF RECORD: for P = zeroP, I = 2 the left side is
// countToInt(succP(zeroP)) >=Int 2 == 1 >=Int 2 == false, while the
// condition 2 >=Int 1 holds — a false predicate rewritten to true.
//
// The claim U-C15-MUT-SYMB-GE2-TRUE asserts the SYMBOLIC instance
// countToInt(succP(P)) >=Int 2 (P a universally quantified PoolCount
// variable).  The claim is SEMANTICALLY FALSE — the witness P = zeroP
// falsifies it — and the mutant rule's condition admits the substitution
// I := 2, so IF the rule fires the false claim CLOSES (rc=0).  That closure
// is the exhibited unsound closure: a proof environment holding the mutant
// rule proves a false statement.  The concrete ground instance is NOT used
// as the discriminator because ground terms evaluate through the defining
// equations BEFORE any simplification rule can match (the 1T-recorded
// unfolding order); the symbolic shape is where rewrite rules are the ONLY
// evaluation path — the exact position the rule occupied in the 1T harness.
//
// Expected outcomes (recorded whatever happens):
//   U-C15-MUT-SYMB-GE2-TRUE  rc=0  => THE UNSOUND CLOSURE EXHIBITED
//   U-C15-MUT-SYMB-GE1-TRUE  rc=0  (the intended >=1 shape; sanity row)
// Level III only; no consensus-integration claim.
// =============================================================================

requires "n_u_c15_fixture.k"

module U-C15-MUTANT-EXHIBIT
  imports U-C15-FIXTURE

  // the 1T rule VERBATIM (body and requires byte-identical to
  // phase1t/proofs/n_t_migrate_rule.k:57-58; label preserved for provenance)
  rule countToInt(succP(P:PoolCount)) >=Int I:Int => true requires I >=Int 1
    [simplification, label(1T-C1.5-PROVED-RULE)]

  // THE FALSE CLAIM the mutant proves (semantically false: witness P=zeroP).
  claim <k> countToInt(succP(P:PoolCount)) >=Int 2 => true </k>
    [label(U-C15-MUT-SYMB-GE2-TRUE)]

  // sanity: the intended successor lower bound (TRUE) closes too.
  claim <k> countToInt(succP(P:PoolCount)) >=Int 1 => true </k>
    [label(U-C15-MUT-SYMB-GE1-TRUE)]

endmodule
