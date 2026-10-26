// =============================================================================
// SRW3 PHASE 1U — WORKSTREAM B (T1): THE ORDER-INDEPENDENCE TEST HARNESS.
//                    (phase1u/tests/t1_harness.k)
//
// K `Set` values are UNORDERED: a registry containing a bareEdge and a real
// edge has NO deterministic insertion order, and the concrete engine's
// decomposition of `SetItem(H) Es` patterns is an implementation choice.
// The 0D buggy rule
//     applicable(SetItem(bareEdge(_Xs)) Es, _F) => applicable(Es, .Set)
// made the RESULT of applicable() DEPENDENT on that choice (bareEdge-first:
// every later edge is checked against .Set and dropped — the obligation
// disappears).  The corrected rule preserves F, so EVERY decomposition
// yields the same answer and the function is order-independent again.
//
// This harness provides the MINIMAL discriminating registry: exactly ONE
// real edge (IOL over {oracle, lending}) and ONE bareEdge over the same app
// set, plus a PROBE command that records the evaluated
// allHold(applicable(<registry>, <footprint-d>), <prospective>) verdict into
// <result> BEFORE any gate runs — so the probe shows the engine's actual
// applicability decision, not just the gate's end-to-end outcome.
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
