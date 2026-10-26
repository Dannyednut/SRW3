// =============================================================================
// SRW3 PHASE 1U — WORKSTREAM A2: THE RULE-LIVENESS PROBE (folded rule alone).
//                    (phase1u/proofs/n_u_c15_liveness.k)
//
// QUESTION OF RECORD: on the pinned toolchain (K v7.1.337), the claim-goal
// experiment shows the frontend/simplifier UNFOLDS countToInt(succP(·)) via
// the defining equation BEFORE a succP-headed simplification rule can match
// (the 1T SHIFT1 comment documented the same ordering).  This probe isolates
// the folded corrected rule ALONE — no SHIFT1 — on the symbolic >=Int 1 goal:
//
//   if it CLOSES, the folded rule CAN fire in some rewrite phase (the rule
//   is live; the guard shapes that reach it are phase-dependent);
//   if it STICKS, the folded rule is inert at claim-goal level and the >=1
//   discharge in the 1T/1U batteries is carried entirely by SHIFT1 (the
//   folded rule's firing positions, if any, are narrower than assumed).
//
// Either outcome is recorded verbatim; both are consistent with the corrected
// rule set being sound (the folded rule is TRUE, so wherever it fires it is
// harmless).  The companion exhibit n_u_c15_mutant.k + the priority exhibit
// n_u_c15_mutant_prio.k demonstrate where the UNSOUND mutant fires.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "n_u_c15_fixture.k"

module U-C15-LIVENESS
  imports U-C15-FIXTURE

  // the folded corrected rule ALONE (no SHIFT/SHIFT1, no >=Int 0 rule)
  rule countToInt(succP(P:PoolCount)) >=Int 1 => true
    [simplification, label(1U-C1.5-PROVED-RULE)]

  claim <k> countToInt(succP(P:PoolCount)) >=Int 1 => true </k>
    [label(U-C15-LIVE-FOLDED-GE1)]

  // the unfolded shape WITHOUT SHIFT1 must stick (the unfolded guard has no
  // discharging rule here — confirms the fixture cannot close by evaluation
  // alone, i.e. a closure of the first claim is attributable to the folded
  // rule and not to builtin arithmetic on symbolic terms).
  claim <k> countToInt(P:PoolCount) +Int 1 >=Int 1 => true </k>
    [label(U-C15-LIVE-UNFOLDED-NOSHIFT-MUST-STICK)]

endmodule
