// =============================================================================
// SRW3 PHASE 1U — WORKSTREAM A2: THE ISOLATED C1.5 COUNTEREXAMPLE FIXTURE
//                    (definition).  (phase1u/proofs/n_u_c15_fixture.k)
//
// A MINIMAL, ISOLATED definition carrying EXACTLY the ingredients the audited
// rules talk about — nothing else:
//
//   * the free algebra PoolCount ::= zeroP | succP(_)  — the constructor
//     declarations VERBATIM from the machine of record
//     (phase1q/semantics/abs-machine-q.k:31-32);
//   * the two defining equations of countToInt VERBATIM from the machine of
//     record (abs-machine-q.k:400-402; no requires, no owise);
//   * a one-cell configuration.
//
// The fixture is the base definition for the two exhibit spec modules:
//   phase1u/proofs/n_u_c15_mutant.k     (the DELIBERATELY BUGGY 1T rule set)
//   phase1u/proofs/n_u_c15_corrected.k  (the corrected 1U rule set)
// Isolation guarantees the experiment can only exercise the rule sets under
// test — no migration machinery, no other simplifications.
// Level III only; no consensus-integration claim.
// =============================================================================

module U-C15-FIXTURE
  imports DOMAINS

  // (C-a) the free algebra — constructors verbatim from abs-machine-q.k:31-32
  syntax PoolCount ::= "zeroP" [constructor]          // exactly zero receipts
  syntax PoolCount ::= succP(PoolCount) [constructor] // exactly one more receipt than _

  // (C-b) the two defining equations of record — verbatim from
  // abs-machine-q.k:400-402
  syntax Int ::= countToInt ( PoolCount ) [function, total]
  rule countToInt(zeroP) => 0
  rule countToInt(succP(N:PoolCount)) => countToInt(N) +Int 1

  configuration <uc15> <k> $PGM:K </k> </uc15>
endmodule
