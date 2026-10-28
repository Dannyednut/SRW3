// =============================================================================
// SRW3 PHASE 1V — WORKSTREAM B (T1): THE ORDER-INDEPENDENCE TEST HARNESS.
//                    (phase1v/tests/t1_harness.k)
//
// Byte-identical in BEHAVIOR to the Phase 1U harness (phase1u/tests/
// t1_harness.k): the minimal mixed registry (ONE real edge + ONE bareEdge
// over the SAME dependency set) and the applicability probe. The ONLY
// difference is the harness's deployment shape under the 1V trusted-
// configuration boundary: the registry KIND `t1Mixed` is selected by the
// TRUSTED HARNESS via the initial configuration (-cREGISTRY="t1Mixed") —
// the 1U `useRegistry(t1Mixed)` program command no longer exists in the
// untrusted transition grammar (T3-v2).
//
// K `Set` values are UNORDERED: a registry containing a bareEdge and a real
// edge has NO deterministic insertion order, and the concrete engine's
// decomposition of `SetItem(H) Es` patterns is an implementation choice.
// The 0D buggy rule
//     applicable(SetItem(bareEdge(_Xs)) Es, _F) => applicable(Es, .Set)
// made the RESULT of applicable() DEPENDENT on that choice. The corrected
// rule preserves F, so EVERY decomposition yields the same answer.
//
// Under the FIXED model on this registry with an IOL-violating prospective
// (lending price != oracle price):
//   probeApplicable  -> "false"  (the IOL obligation IS applicable and
//                                 violated — every decomposition agrees)
//   gate             -> "reject"
// Under the BUGGY 0D rule the outcome is order-dependent; the recorded run
// on the pinned toolchain is retained verbatim (old-vs-fixed evidence).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../k/srw3.k"

module T1-HARNESS
  imports SRW3-GATE

  // the minimal mixed registry: one contract edge + one bare edge over the
  // SAME dependency set — the smallest shape where the 0D footprint reset
  // can drop a real obligation
  syntax RegistryKind ::= "t1Mixed"
  rule pickRegistry(t1Mixed)
    => SetItem(edge(IOL, SetItem(oracle) |Set SetItem(lending)))
       |Set SetItem(bareEdge(SetItem(oracle) |Set SetItem(lending)))

  // the applicability probe: evaluates the gate's own accept-side
  // obligation conjunction and records it in <result> (before any gate)
  syntax Srw3Cmd ::= "probeApplicable"
  rule <k> probeApplicable => .K ... </k>
       <registry> R:Set </registry>
       <footprint-d> F:Set </footprint-d>
       <prospective> P:Map </prospective>
       <result> _S:String => Bool2String(allHold(applicable(R, F), P)) </result>

endmodule
