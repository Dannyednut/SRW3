// =============================================================================
// proofs/tier3_universal.k — THEOREM-CLOSURE PASS, ITEM 3
//
// TIER-3 UNIVERSAL RECONCILIATION THEOREM (the audit-mandated target):
//
//     wfCoverage(H, FD, S)  ->  gateOk_faithful(H, S) = implementedGate(H, FD, S)
//
// with UNIVERSAL QUANTIFICATION over the registry H, the declared footprint FD
// and the prospective state S, using the EXACT wfCoverage definition
// established by the Round-2 audit (proofs/generalized_bridge.k):
//
//     wfCoverage(H, FD, S) := ∀ edge(J, Xs) ∈ H. ( Xs ∩ FD ≠ ∅ ∨ evalInv(J, S) )
//
// The statement is formalized below as kprove claims and is NOT weakened:
// no coverage conjunct is dropped, no quantifier is restricted. The audit
// prediction (recorded in generalized_bridge.k) is that the Haskell backend's
// reachability+SMT fragment cannot mechanize the fully quantified statement,
// because wfCoverage, universeObls, applicable, allHold, member and memberName
// are recursive functions over constructor-free symbolic Sets and do not
// reduce; the identity needs structural induction over symbolic aggregates.
// Each attempt below therefore records its verbatim residual; the mandated
// classification is:
//
//     STATEMENT FORMALIZED; NOT YET MECHANIZED
//
// and the tier-1 (ground, G1-G7/X1/X2) and tier-2 (state-generalized over the
// covered (registry, footprint) pairs, G8-G11/X3) results are PRESERVED
// unchanged. The upstream formal statement also lives in the header comment of
// proofs/generalized_bridge.k; this artifact makes it machine-checkable
// (kprove attempts it and records the exact prover boundary).
// =============================================================================

requires "srw3.k"
requires "compat/srw3-bridge.k"
requires "generalized_bridge.k"   // the audit's wfCoverage + SRW3-BRIDGE-GEN (-I proofs)

module SRW3-TIER3-UNIV
  imports SRW3-BRIDGE-GEN
endmodule

module SRW3-TIER3-UNIV-CLAIMS
  imports SRW3-TIER3-UNIV

  claim // T3-U: THE UNIVERSAL TIER-3 THEOREM, verbatim: for ALL registries H,
        // footprints FD, states S, actors Ac (root/authority sets coinciding
        // by the name-coincidence premise, here expressed by using the same
        // symbolic set Rt for both roles — the R = As premise of the audit).
        // NowfCoverage conjunct is dropped; FD and S are fully symbolic.
    <k> ( ( rootOk(Rt:Set, appName(Ac:AppId), "t0")
            andBool gateOk(.Map, S:Map, .List, Rt:Set, H:Set, .Map) )
          ==Bool
          gateAccept(H:Set, FD:Set, Ac:AppId, Rt:Set, S:Map) )
        => true </k>
    requires wfCoverage(H:Set, FD:Set, S:Map)
    [label(T3-U)]

  claim // T3-FD: incremental step from tier 2 — the registry is FIXED to the
        // demo-complete chain registry (as in G9/G10) but the declared
        // footprint FD is now UNIVERSALLY quantified (tier 2 fixed FD per
        // instance). Isolates whether symbolic-FD alone already exceeds the
        // backend fragment.
    <k> ( ( rootOk(gAuth6(), appName(Ac:AppId), "t0")
            andBool gateOk(.Map, S:Map, .List, gAuth6(), chainCompleteRegistry(), .Map) )
          ==Bool
          gateAccept(chainCompleteRegistry(), FD:Set, Ac:AppId, gAuth6(), S:Map) )
        => true </k>
    requires wfCoverage(chainCompleteRegistry(), FD:Set, S:Map)
    [label(T3-FD)]

  claim // T3-A: the AUTHORIZATION half of the universal statement in isolation:
        // memberName(appName(Ac), As) == member(Ac, As) for a symbolic
        // authority set. Provable by structural induction over As — expected
        // to pin down the exact prover boundary (symbolic-set induction) that
        // blocks T3-U's authorization conjunct.
    <k> ( memberName(appName(Ac:AppId), As:Set)
          ==Bool member(Ac:AppId, As:Set) ) => true </k>
    [label(T3-A)]
endmodule
