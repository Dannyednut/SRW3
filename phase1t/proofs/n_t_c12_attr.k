// =============================================================================
// SRW3 PHASE 1T — THE C1.2 STRUCTURAL-INDUCTION MODULE (Workstream B, main
//                    route).  (phase1t/proofs/n_t_c12_induction.k)
//
// THE GOAL: prove `forall P : PoolCount, countToInt(P) >=Int 0` (C1.2)
// WITHOUT ANY ASSUMPTION — the C1.2 simplification rules of
// phase1s/proofs/n_s_migrate_c12.k are NOT present here, NOT imported, and
// NOT inherited: this module requires ONLY the rel-machine of record
// (SRW3N-REL-S), the same definition the Phase 1S conditional battery ran on.
//
// THE MECHANISM UNDER TEST: the K claim attribute [induction] — kore's
// structural-induction strategy for reachability claims (case-split on the
// constructor variables of the claim; the claim itself is the induction
// hypothesis at each subgoal).  NO phase on this toolchain attempted the
// attribute before 1T (the 1O boundary was recorded from circularity-form
// attempts only).  Whatever the raw result, it is recorded and never
// relabeled.
//
// SEPARATION OF RECORD (mission §3): this module stays SEPARATE from
// n_s_migrate_c12.k; the C12ASSUMED battery must not see anything defined
// here, and this module must not see the C1.2 assumption rules.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1s/semantics/rel-machine.k"

module T-C12-INDUCTION-PROOFS
  imports SRW3N-REL-S

  // ===========================================================================
  // 1T-C12-UNIV-IND — THE MAIN ROUTE: K-native structural induction.
  //   Base (P = zeroP):   countToInt(zeroP) = 0        >=Int 0  (evaluation)
  //   Step (P = succP(P')): countToInt(succP(P'))
  //                       = countToInt(P') +Int 1      >=Int 0  (IH + arith)
  // The [induction] attribute asks the prover to perform exactly this
  // splitting over the constructor variable P:PoolCount.
  // ===========================================================================
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures ?N:Int >=Int 0
    [induction, label(1T-C12-UNIV-IND)]

  // ===========================================================================
  // THE GENUINENESS CONTROLS for the induction mechanism (same attribute,
  // same harness, deliberately FALSE universals — each MUST FAIL; a closure
  // of either row is an UNSOUND-CLOSURE finding and the route is rejected):
  //
  //   1T-C12-NEG-GE5  — false: zeroP interprets to 0, and 0 >=Int 5 is false.
  //   1T-C12-NEG-GE1  — false at the base case only (zeroP = 0).
  //   1T-C12-NEG-ODD  — a non-arithmetic false universal (the interpretation
  //                     of zeroP is "odd") — must fail at the base case.
  // ===========================================================================
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures ?N:Int >=Int 5
    [induction, label(1T-C12-NEG-GE5)]

  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures ?N:Int >=Int 1
    [induction, label(1T-C12-NEG-GE1)]

  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures (?N:Int %Int 2) ==Int 1
    [induction, label(1T-C12-NEG-ODD)]

endmodule
