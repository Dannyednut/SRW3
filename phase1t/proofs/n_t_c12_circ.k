// =============================================================================
// SRW3 PHASE 1T — THE C1.2 CIRCULARITY-ROUTE PROBES (Workstream B, main
//                    route, experiment set B2/B3).
//                    (phase1t/proofs/n_t_c12_circ.k)
//
// CONTEXT: K v7.1.337 REJECTS the [induction] claim attribute
// ("Unrecognized attributes: [induction]", rc=113; the exhibit module is
// phase1t/proofs/n_t_c12_attr.k, transcript kprove_1T-C12-UNIV-IND.log).
// No kprove strategy flag exists (kprove --help: only --trusted).
// The 1S universal attempt 1S-C1.2-UNIV was a PLAIN claim — a
// [circularity]-marked form was NEVER attempted in 1O/1P/1S.  These are
// those experiments, run fail-closed with falsity controls.
//
// THE VACUITY RISK is known on this toolchain (the 1Q PREFIX-UNPATCHED
// UNSOUND-CLOSURE): a circularity claim can self-apply and "close" on a
// FALSE universal.  Therefore every circularity universal here ships with
// its deliberately-false twin; if the false twin closes too, the route is
// UNSOUND-CLOSURE and rejected (never a theorem).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1s/semantics/rel-machine.k"

module T-C12-CIRC-PROOFS
  imports SRW3N-REL-S

  // ===========================================================================
  // 1T-C12-UNIV-CIRC — the universal with the [circularity] attribute: the
  //   claim becomes usable as its own induction hypothesis during its own
  //   proof.  If it closes NON-VACUOUSLY (falsity twin fails, depth probes
  //   fail): the K-native main route SUCCEEDS.
  // ===========================================================================
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures ?N:Int >=Int 0
    [circularity, label(1T-C12-UNIV-CIRC)]

  // ===========================================================================
  // 1T-C12-NEG-GE5-CIRC (MUST FAIL) — the falsity twin of the route: same
  //   mechanism, false goal (zeroP interprets to 0 and 0 >=Int 5 is false).
  // ===========================================================================
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures ?N:Int >=Int 5
    [circularity, label(1T-C12-NEG-GE5-CIRC)]

  // ===========================================================================
  // 1T-C12-STEP-NZ-CIRC — the successor-discriminated circular form: the
  //   requires excludes the base constructor, so the circular rule may only
  //   fire where a structural decrease is meaningful.
  // ===========================================================================
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        requires P =/=K zeroP
        ensures ?N:Int >=Int 0
    [circularity, label(1T-C12-STEP-NZ-CIRC)]

endmodule
