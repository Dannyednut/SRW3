// =============================================================================
// SRW3 PHASE 1U — WORKSTREAM A2: THE UNSOUND-RULE EXHIBIT (PRIORITY-BOOSTED
//                    MUTANT — deliberately buggy, never ship, never trust).
//                    (phase1u/proofs/n_u_c15_mutant_prio.k)
//
// The default-priority exhibit (n_u_c15_mutant.k) shows the pinned
// toolchain's evaluation order MASKS the mutant at claim-goal level: the
// defining equation unfolds countToInt(succP(·)) first.  THIS exhibit gives
// the 1T mutant rule [priority(1)] so it is tried BEFORE the machine
// equations — exposing the rule's falsity as a REWRITE, independent of the
// accidental evaluation order of one harness:
//
//   rule countToInt(succP(P:PoolCount)) >=Int I:Int => true
//     requires I >=Int 1  [simplification, priority(1)]     // THE UNSOUND RULE
//
// The claim U-C15-PRIO-SYMB-GE2-TRUE asserts the SYMBOLIC instance
// countToInt(succP(P)) >=Int 2 — SEMANTICALLY FALSE (witness P = zeroP:
// 1 >=Int 2 is false).  If the rule fires (I := 2 admitted by the requires),
// the false claim CLOSES (rc=0): the exhibited UNSOUND CLOSURE — a proof
// environment holding the mutant rule proves a false statement.  The same
// claim under the corrected rule set (n_u_c15_corrected.k,
// U-C15-COR-SYMB-GE2-TRUE) FAILS (rc=1): the falsity is refused.
//
// If the toolchain rejects [priority(1)] on simplification rules (rc=113),
// that rejection is recorded and the exhibit falls back to the
// default-priority finding of record (evaluation-order masking).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "n_u_c15_fixture.k"

module U-C15-MUTANT-PRIO
  imports U-C15-FIXTURE

  // the 1T unsound rule, body verbatim, priority-boosted to fire before the
  // defining equations (exposes the rewrite falsity independent of order)
  rule countToInt(succP(P:PoolCount)) >=Int I:Int => true requires I >=Int 1
    [simplification, priority(1), label(1T-C1.5-PROVED-RULE-PRIO)]

  // THE FALSE CLAIM (witness P = zeroP)
  claim <k> countToInt(succP(P:PoolCount)) >=Int 2 => true </k>
    [label(U-C15-PRIO-SYMB-GE2-TRUE)]

  // sanity: the intended >=1 shape still closes
  claim <k> countToInt(succP(P:PoolCount)) >=Int 1 => true </k>
    [label(U-C15-PRIO-SYMB-GE1-TRUE)]

endmodule
