// =============================================================================
// SRW3 PHASE 1Q — THE CIRCULARITY-HOLE PROBE (the unpatched PREFIX form).
//                    (phase1q/proofs/n_q_univ_prefix_unpatched.k)
//
// The FIRST draft of 1Q-UNIV-PREFIX-Q required only `absCfgPinnedQ(AX)` —
// a Bool-VALUED accessor that constrains nothing — so the claim was
// SEMANTICALLY FALSE (the tag-0 refuse-run ends uninitialized; witnessed
// by 1Q-NEG-PREFIX-CEX-Q, rc=1) and the engine nonetheless closed it in
// 18s with ZERO WarnTrivialClaim — a non-vacuous-looking proof of a false
// claim: the [circularity] self-application consumed the symbolic tail and
// the base case was never discharged.
//
// This file reproduces that closure under its own label so the hole is a
// permanent, re-runnable exhibit.  The form of record (1Q-UNIV-PREFIX-Q in
// n_q_univ_q.k) pins the start tag and closes GENUINELY (base case
// discharged by the requires; the step by the tag-preserving rows).
//
//   1Q-UNIV-PREFIX-UNPATCHED-Q  MUST be classified UNSOUND-CLOSURE (rc=0
//     here is NOT a proof of anything — the claim is false per the CEX).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-q.k"

module Q-UNIV-PREFIX-UNPATCHED-PROOFS
  imports SRW3N-ABS-Q

  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool absCfgPinnedQ(AX)
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures absInitShapedQ(?AX2:AStateQ)
    [circularity, label(1Q-UNIV-PREFIX-UNPATCHED-Q)]

endmodule
