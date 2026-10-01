// =============================================================================
// proofs/generalized_bridge.k — Round-2 theorem-boundary audit, item 2
//
// GENERALIZATION OF THE SCAFFOLD RECONCILIATION.
//
// AUDIT QUESTION (verbatim): can
//     wfCheck(state) -> gateOk_faithful(state) = implementedGate(state)
// be proved as a general property, or does the exact formulation require a
// more precise coverage predicate?
//
// ANSWER. wfCheck alone (Gamma* ⊆ GammaHat, effect completeness) is NECESSARY
// but NOT SUFFICIENT for agreement: a state can have its true effects fully
// declared while some obligation on an UNTOUCHED application is already
// violated in the inherited state (e.g. a trust-policy commit left appC=11;
// a later clean, fully-declared appB write passes wfCheck yet the faithful
// all-universe check rejects while the implemented applicable-only check
// accepts). The precise predicate under which the two decisions coincide is:
//
//     wfCoverage(H, FD, S)  :=  ∀ edge(J, Xs) ∈ H.
//                                 ( Xs ∩ FD ≠ ∅  ∨  evalInv(J, S) )
//
// i.e. every obligation the declared footprint fails to make applicable is
// already satisfied by the state. Under it, the universe-wide check (faithful
// gateOk) and the footprint-applicable check (implemented gate) coincide.
//
// THE GENERAL THEOREM (stated here; NOT YET MECHANIZED — see below):
//
//   For all hypergraphs H, declared footprints FD, states S, actor Ac and
//   root sets R/As with the name-coincidence premise (ActorName = appName(Ac),
//   R = As):
//
//       wfCoverage(H, FD, S)  ∧  rootOk(R, appName(Ac), tid)
//       ======================================================
//       ( gateOk(C, S, TR, R, H, M) ∧ rootOk(R, appName(Ac), tid) )
//         ==  gateAccept(H, FD, Ac, As, S)
//
//   Why it holds (sketch): applicable(H, FD) ⊆ universeObls(H); and
//     allHold(universeObls(H), S)
//       =  allHold(applicable(H, FD), S)
//          ∧ ∧_{edge(J,Xs) ∈ H, Xs ∩ FD = ∅} evalInv(J, S),
//   where wfCoverage makes every skipped conjunct true; the authorization
//   conjuncts coincide by evaluation of memberName/member under the
//   name-coincidence premise.
//
//   Why NOT mechanized: with H, FD, S fully symbolic, wfCoverage,
//   universeObls, applicable and allHold are recursive functions over a
//   constructor-free symbolic Set/Map and do not reduce; the identity needs
//   structural induction over symbolic aggregates, which the Haskell
//   backend's reachability+SMT fragment does not support — the SAME prover
//   boundary documented for the lineage-length induction (§F.4, attempt [B]).
//
//   What IS mechanized below: per-(registry, footprint) instances of the
//   theorem with SYMBOLIC STATE VALUES (G8-G11) — genuine universal
//   statements over all states of the covered shapes, not ground decisions —
//   plus one ground necessity witness (X3) showing the coverage premise
//   cannot be dropped.
//
// TERMINOLOGY (mandated): the reconciliation result is therefore a
// "signature-faithful realization with mechanically checked ground agreement
// over the covered states" — extended here with mechanically checked
// state-generalized agreement on the covered (registry, footprint) pairs.
// It is NOT called a refinement/simulation theorem: the fully quantified
// ∀H ∀FD ∀S statement above is not mechanized.
//
// Relationship to the safety theorem: on the ENFORCE system's reachable
// states, wfCoverage holds by the frame argument — a transition writes only
// keys of apps in FT ⊆ FD (wfCheck), so every skipped edge's keys are
// untouched and evalInv(J, σ̂) = evalInv(J, σ_n), which the induction
// hypothesis Safe(P, σ_n) makes true. This is the precise semantic link
// between the commitment-gate safety theorem and the gate-agreement theorem;
// under policy `trust` the link breaks and X1 (bridge) is the divergence.
// =============================================================================

requires "srw3.k"
requires "compat/srw3-bridge.k"

module SRW3-BRIDGE-GEN
  imports SRW3-BRIDGE

  // ---- the coverage predicate -----------------------------------------------
  syntax Bool ::= "wfCoverage" "(" edges:Set "," foot:Set "," st:Map ")" [function, total]
  rule wfCoverage(.Set, _F:Set, _S:Map) => true
  rule wfCoverage(SetItem(edge(J:InvId, Xs:Set)) Es:Set, F:Set, S:Map)
    => ( nonemptyInter(Xs, F) orBool evalInv(J, S) ) andBool wfCoverage(Es, F, S)
  rule wfCoverage(SetItem(bareEdge(_Xs:Set)) Es:Set, F:Set, S:Map)
    => wfCoverage(Es, F, S)

  // symbolic chain-state generator (shape mirrors gChain: 6 storage keys)
  syntax Map ::= "gSgen" "(" Int "," Int "," Int "," Int "," Int "," Int ")" [function, total]
  rule gSgen(PR:Int, AU:Int, LP:Int, LD:Int, LT:Int, LL:Int)
    => stK(oracle, 0)  |-> PR  stK(oracle, 1)  |-> AU
       stK(lending, 0) |-> LP  stK(lending, 1) |-> LD
       stK(liq, 0)     |-> LT  stK(liq, 1)     |-> LL
endmodule

// =============================================================================
// State-generalized agreement claims. S carries SYMBOLIC values; the requires
// is the coverage predicate VERBATIM (evaluated per instance). kprove checks
// the equality by evaluation over all values of the symbolic variables
// (WarnTrivialClaim = checked-by-evaluation; the quantification is what makes
// these more than the ground G-claims of the original bridge).
// =============================================================================

module SRW3-BRIDGE-GEN-CLAIMS
  imports SRW3-BRIDGE-GEN

  claim // G8: completeRegistry, FD = {appB}; skipped edges {IA, IC}; coverage
        // premise reduces to X <= 10. Agreement holds for ALL symbolic X, V.
    <k> ( rootOk(gAuth6(), "appB", "t0")
          andBool gateOk(.Map, stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int,
                         .List, gAuth6(), completeRegistry(), .Map) )
        ==Bool
        gateAccept(completeRegistry(), SetItem(appB), appB, gAuth6(),
                   stK(appA, 0) |-> X stK(appB, 0) |-> V)
        => true
    </k>
    requires wfCoverage(completeRegistry(), SetItem(appB),
                        stK(appA, 0) |-> X stK(appB, 0) |-> V)

  claim // G9: chainCompleteRegistry, FD = {lending}; skipped edge {IO}; the
        // coverage premise is exactly oracle authentication (AU == 1).
    <k> ( rootOk(gAuth6(), "lending", "t0")
          andBool gateOk(.Map, gSgen(PR:Int, AU:Int, LP:Int, LD:Int, LT:Int, LL:Int),
                         .List, gAuth6(), chainCompleteRegistry(), .Map) )
        ==Bool
        gateAccept(chainCompleteRegistry(), SetItem(lending), lending, gAuth6(),
                   gSgen(PR, AU, LP, LD, LT, LL))
        => true
    </k>
    requires wfCoverage(chainCompleteRegistry(), SetItem(lending),
                        gSgen(PR, AU, LP, LD, LT, LL))

  claim // G10: chainCompleteRegistry, FD = {liq}; skipped edges {IO, IOL};
        // coverage premise: oracle authenticated AND lending price consistent.
    <k> ( rootOk(gAuth6(), "liq", "t0")
          andBool gateOk(.Map, gSgen(PR:Int, AU:Int, LP:Int, LD:Int, LT:Int, LL:Int),
                         .List, gAuth6(), chainCompleteRegistry(), .Map) )
        ==Bool
        gateAccept(chainCompleteRegistry(), SetItem(liq), liq, gAuth6(),
                   gSgen(PR, AU, LP, LD, LT, LL))
        => true
    </k>
    requires wfCoverage(chainCompleteRegistry(), SetItem(liq),
                        gSgen(PR, AU, LP, LD, LT, LL))

  claim // G11: negativeRegistry (CM1 registry!), FD = {appB}; skipped {IA};
        // agreement STILL holds state-generally under coverage — the CM1
        // defect is closure-level (InteractionComplete false), not gate-level.
    <k> ( rootOk(gAuth6(), "appB", "t0")
          andBool gateOk(.Map, stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int,
                         .List, gAuth6(), negativeRegistry(), .Map) )
        ==Bool
        gateAccept(negativeRegistry(), SetItem(appB), appB, gAuth6(),
                   stK(appA, 0) |-> X stK(appB, 0) |-> V)
        => true
    </k>
    requires wfCoverage(negativeRegistry(), SetItem(appB),
                        stK(appA, 0) |-> X stK(appB, 0) |-> V)

  // ---- necessity witness: the coverage premise cannot be dropped -----------
  claim // X3 (ground): oracle UNAUTHENTICATED (AU = 0) but every applicable
        // obligation consistent — the implemented gate (footprint {lending})
        // ACCEPTS while the faithful all-universe instantiation REJECTS.
        // Pure effect-completeness (wfCheck) does not produce this state:
        // it arises from an inherited violation on an untouched app.
    <k> notBool (
          ( rootOk(gAuth6(), "lending", "t0")
            andBool gateOk(.Map, gSgen(100, 0, 100, 5, 4, 100),
                           .List, gAuth6(), chainCompleteRegistry(), .Map) )
          ==Bool
          gateAccept(chainCompleteRegistry(), SetItem(lending), lending,
                     gAuth6(), gSgen(100, 0, 100, 5, 4, 100))
        ) => true
    </k>
endmodule
