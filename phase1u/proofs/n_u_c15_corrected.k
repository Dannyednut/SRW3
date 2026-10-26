// =============================================================================
// SRW3 PHASE 1U — WORKSTREAM A2: THE CORRECTED-RULE EXHIBIT.
//                    (phase1u/proofs/n_u_c15_corrected.k)
//
// The corrected rule set of record (the four audited rules with the C1.5
// generalization replaced by the exact-threshold form) in the SAME isolated
// fixture, run under the SAME claim shapes as the mutant exhibit:
//
//   rule countToInt(succP(P:PoolCount)) >=Int 1 => true   // the corrected C1.5
//   rule countToInt(P:PoolCount) >=Int 0 => true          // the Lean C1.2
//   rule countToInt(P) +Int I >=Int 0 => true req I >=Int 0  // SHIFT
//   rule countToInt(P) +Int I >=Int 1 => true req I >=Int 1  // SHIFT1
//
// Expected outcomes (each one VERIFIES AN ACTUAL RESULT, not the absence of
// a rewrite rule):
//   U-C15-COR-SYMB-GE2-TRUE      rc=1  THE DECISIVE NEGATIVE CONTROL: the
//                                same false claim the mutant closed is now
//                                REFUSED — no sound rule covers >=Int 2, the
//                                symbolic goal cannot evaluate, the prover
//                                cannot close.  Closes in seconds (computationally
//                                decisive — not a timeout).
//   U-C15-COR-CONCRETE-GE2-FALSE rc=0  the concrete witness case evaluates:
//                                countToInt(succP(zeroP)) >=Int 2 normalizes
//                                to false and the claim asserts exactly that.
//   U-C15-COR-CONCRETE-GE1-TRUE  rc=0  countToInt(succP(zeroP)) = 1 >=Int 1
//                                (the threshold case, ground).
//   U-C15-COR-SYMB-GE1-TRUE      rc=0  the intended successor lower bound
//                                countToInt(succP(P)) >=Int 1 — closes under
//                                the corrected rule (the rule is load-bearing
//                                here: without any C1.5-family rule the
//                                symbolic goal cannot close).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "n_u_c15_fixture.k"

module U-C15-CORRECTED-EXHIBIT
  imports U-C15-FIXTURE

  // ---- the corrected rule set of record (bodies = the audited 1U set) ----
  rule countToInt(P:PoolCount) >=Int 0 => true
    [simplification, label(1U-C12-LEAN-RULE)]

  rule countToInt(P:PoolCount) +Int I:Int >=Int 0 => true requires I >=Int 0
    [simplification, label(1U-C12-LEAN-RULE-SHIFT)]

  rule countToInt(succP(P:PoolCount)) >=Int 1 => true
    [simplification, label(1U-C1.5-PROVED-RULE)]

  rule countToInt(P:PoolCount) +Int I:Int >=Int 1 => true requires I >=Int 1
    [simplification, label(1U-C12-LEAN-RULE-SHIFT1)]

  // ---- the four controls -------------------------------------------------
  claim <k> countToInt(succP(P:PoolCount)) >=Int 2 => true </k>
    [label(U-C15-COR-SYMB-GE2-TRUE)]

  claim <k> countToInt(succP(zeroP)) >=Int 2 => false </k>
    [label(U-C15-COR-CONCRETE-GE2-FALSE)]

  claim <k> countToInt(succP(zeroP)) >=Int 1 => true </k>
    [label(U-C15-COR-CONCRETE-GE1-TRUE)]

  claim <k> countToInt(succP(P:PoolCount)) >=Int 1 => true </k>
    [label(U-C15-COR-SYMB-GE1-TRUE)]

endmodule
