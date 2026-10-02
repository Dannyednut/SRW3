// =============================================================================
// k/compat/srw3-bridge.k
//
// PRIORITY-1 AUDIT ARTIFACT — reconciliation of the original Phase 0-D
// scaffold's placeholder predicates with the evaluated-obligation semantics.
//
// ORIGINAL SCAFFOLD (srw3-work/k/srw3.k, the authoritative baseline):
//
//   syntax Bool ::= gateOk(Map, Map, List, Set, Set, Map) [function]
//   syntax Bool ::= rootOk(Set, String, String)           [function]
//
//   rule ... <gate> _ => true  </gate> requires gateOk(C, S, TR, R, H, M)
//   rule ... <gate> _ => false </gate> requires notBool gateOk(C, S, TR, R, H, M)
//
// with configuration cells <committed> <shadow> <trace> <roots> <contracts>
// <hypergraph>. Neither placeholder has ANY defining equation; rootOk is
// declared but never referenced by any rule; the tau skeleton never updates
// <committed>/<shadow>; no reject/restore path exists. See the unexecutability
// transcript (transcripts/audit/original_scaffold_probe.txt) for the mechanical
// evidence that the skeleton admits no programs and no transitions.
//
// WHAT THIS MODULE ESTABLISHES
//
//   1. A SIGNATURE-FAITHFUL instantiation of both placeholders over the
//      evaluated-obligation semantics (same names, same arities):
//
//        gateOk(C, S, TR, R, H, M)  =  allHold( universeObls(H), S )
//        rootOk(R, ActorName, Tid)  =  ActorName is in R
//
//      i.e. "every obligation carried by the hypergraph holds on the
//      prospective state" and "the actor belongs to the root set". The
//      committed state C, trace TR, roots R and contracts M receive the
//      documented readings: obligations are evaluated on the PROSPECTIVE
//      state only (S), the contracts are fused into the hypergraph edges
//      (M redundant by design), the trace is subsumed by lineage records,
//      the roots are the authority set.
//
//   2. The gate-decision extraction used by the proved semantics:
//
//        gateAccept(REG, FD, Ac, As, P) = member(Ac, As)
//                                       andBool allHold(applicable(REG, FD), P)
//
//      (the requires clause of the ACCEPT rule of SRW3-GATE, verbatim).
//
//   3. GROUND AGREEMENT CLAIMS: for every decision state exercised by the
//      demo suite (D1, D2, D6, D7b, D8, D10), the signature-faithful
//      instantiation decides EXACTLY as the implemented gate. These are
//      kprove-checked equalities between two fully evaluated Booleans: the
//      prover verifies agreement, not an assumption.
//
//   4. ONE GROUND DISAGREEMENT CLAIM (CM7/hidden-effect, demo D3): under the
//      `trust` policy with an under-approximated declared footprint, the
//      implemented gate accepts a state the faithful instantiation rejects.
//      This pins the ONLY divergence class to effect incompleteness — which
//      is exactly what wfCheck (Gamma* subset GammaHat, policy `enforce`)
//      blocks from ever reaching the gate.
//
//   TERMINOLOGY (Round-2 audit, mandated): the result of this bridge is a
//   "signature-faithful realization with mechanically checked ground
//   agreement over the covered states" — NOT a refinement/simulation
//   theorem. Finite ground agreement (G1-G7, X1, X2) and the
//   state-generalized agreement over the covered (registry, footprint) pairs
//   (G8-G11 + X3 in proofs/generalized_bridge.k, under the explicit coverage
//   predicate wfCoverage(H, FD, S)) do NOT add up to the fully quantified
//   ∀H ∀FD ∀S agreement statement, which is stated but NOT YET MECHANIZED
//   (structural induction over symbolic sets is beyond the Haskell backend's
//   reachability+SMT fragment). Do not describe this result as a general
//   refinement theorem.
//
// REFERENCE for the component mapping (report section "Reconciliation"):
//   C:Map   <committed>   sigma            (unchanged role)
//   S:Map   <prospective> sigma-hat       (original name "shadow"; renamed
//                                          because begin + evaluate + commit
//                                          gives it an active role the
//                                          skeleton never specified)
//   TR:List <lineage>+<footprint-t/d>     (Event list subsumed by Lambda
//                                          records; footprint ADDED because
//                                          Affected(tau) needs Foot(tau),
//                                          which no gateOk argument supplies)
//   R:Set   <authorities> (+ <head>)      (root-anchored authorization;
//                                          rootOk's first argument)
//   H:Set   <registry>                    (same shape: Set of hyperedges)
//   M:Map   fused into edge(InvId, AppSet) (original separated contracts from
//                                          the hypergraph with no link)
// =============================================================================

requires "srw3.k"

module SRW3-BRIDGE
  imports SRW3-GATE

  // ---- signature-faithful instantiations (same names/arities as baseline) ---

  syntax Set ::= "universeObls" "(" edges:Set ")" [function, total]
  rule universeObls(.Set) => .Set
  rule universeObls(SetItem(edge(J:InvId, _Xs:Set)) Es:Set) => SetItem(J) |Set universeObls(Es)
  rule universeObls(SetItem(bareEdge(_Xs:Set)) Es:Set) => universeObls(Es)

  syntax Bool ::= "gateOk" "(" Map "," Map "," List "," Set "," Set "," Map ")" [function, total]
  rule gateOk(_C:Map, S:Map, _TR:List, _R:Set, H:Set, _M:Map)
    => allHold(universeObls(H), S)

  syntax String ::= "appName" "(" a:AppId ")" [function, total]
  rule appName(appA)     => "appA"
  rule appName(appB)     => "appB"
  rule appName(appC)     => "appC"
  rule appName(oracle)   => "oracle"
  rule appName(lending)  => "lending"
  rule appName(liq)      => "liq"
  rule appName(noOne)    => "noOne"

  syntax Bool ::= "memberName" "(" n:String "," as:Set ")" [function, total]
  rule memberName(_N:String, .Set) => false
  rule memberName(N:String, SetItem(A:AppId) R2:Set)
    => N ==String appName(A) orBool memberName(N, R2)

  syntax Bool ::= "rootOk" "(" Set "," String "," String ")" [function, total]
  rule rootOk(R:Set, ActorName:String, _Tid:String) => memberName(ActorName, R)

  // ---- the implemented gate's accept condition, extracted -------------------

  syntax Bool ::= "gateAccept" "(" reg:Set "," fd:Set "," ac:AppId "," as:Set "," p:Map ")" [function, total]
  rule gateAccept(REG:Set, FD:Set, Ac:AppId, As:Set, P:Map)
    => member(Ac, As) andBool allHold(applicable(REG, FD), P)

  // ---- ground states (verbatim from the demo suite) -------------------------

  syntax Map ::= "gC_D1"  "(" ")" [function, total]   // committed  (7,3)
  rule gC_D1()  => stK(appA, 0) |-> 7 stK(appB, 0) |-> 3
  syntax Map ::= "gP_D1"  "(" ")" [function, total]   // prospective (7,7)  [D1]
  rule gP_D1()  => stK(appA, 0) |-> 7 stK(appB, 0) |-> 7
  syntax Map ::= "gP_honest" "(" ")" [function, total] // prospective (7,2)  [D2b-style honest]
  rule gP_honest() => stK(appA, 0) |-> 7 stK(appB, 0) |-> 2

  syntax Map ::= "gChain" "(" ")" [function, total]   // committed chain state after oracle/lending setup
  rule gChain() => stK(oracle, 0) |-> 100 stK(oracle, 1) |-> 1
                stK(lending, 0) |-> 100 stK(lending, 1) |-> 5
                stK(liq, 0) |-> 0     stK(liq, 1) |-> 100
  syntax Map ::= "gP_stale" "(" ")" [function, total] // lending wrote 90   [D7b]
  rule gP_stale() => stK(oracle, 0) |-> 100 stK(oracle, 1) |-> 1
                  stK(lending, 0) |-> 90  stK(lending, 1) |-> 5
                  stK(liq, 0) |-> 0     stK(liq, 1) |-> 100
  syntax Map ::= "gP_settle90" "(" ")" [function, total] // settlement at 90 [D8]
  rule gP_settle90() => stK(oracle, 0) |-> 100 stK(oracle, 1) |-> 1
                     stK(lending, 0) |-> 100 stK(lending, 1) |-> 5
                     stK(liq, 0) |-> 4     stK(liq, 1) |-> 90
  syntax Map ::= "gP_settle99" "(" ")" [function, total] // settlement at 99 [D10]
  rule gP_settle99() => stK(oracle, 0) |-> 100 stK(oracle, 1) |-> 1
                     stK(lending, 0) |-> 100 stK(lending, 1) |-> 5
                     stK(liq, 0) |-> 4     stK(liq, 1) |-> 99
  syntax Map ::= "gP_hidden" "(" ")" [function, total] // hidden write appC:=11 [D3]
  rule gP_hidden() => stK(appA, 0) |-> 7 stK(appB, 0) |-> 2 stK(appC, 0) |-> 11

  syntax Set ::= "gAuth6" "(" ")" [function, total]
  rule gAuth6() => SetItem(appA) |Set SetItem(appB) |Set SetItem(appC)
                |Set SetItem(oracle) |Set SetItem(lending) |Set SetItem(liq)
endmodule


// =============================================================================
// Ground claims. Every term is fully concrete; kprove checks the evaluated
// agreement (a disagreement would make the claim false and kprove would fail).
// =============================================================================

module SRW3-BRIDGE-CLAIMS
  imports SRW3-BRIDGE

  // ---- agreement claims (expected PROVED: two fully evaluated Booleans agree;
  //      a disagreement would leave the equality false and kprove would FAIL —
  //      no vacuity hole: the checked equality sits in <k>, not in requires) ----

  claim // G1 [D1]: violating write, complete registry -> both REJECT
    <k> ( rootOk(gAuth6(), "appB", "t0")
          andBool gateOk(gC_D1(), gP_D1(), .List, gAuth6(), completeRegistry(), .Map) )
        ==Bool
        gateAccept(completeRegistry(), SetItem(appB), appB, gAuth6(), gP_D1())
        => true
    </k>

  claim // G2 [D6 step 1]: honest lending commit -> both ACCEPT
    <k> ( rootOk(gAuth6(), "lending", "t0")
          andBool gateOk(gChain(), gChain(), .List, gAuth6(), chainCompleteRegistry(), .Map) )
        ==Bool
        gateAccept(chainCompleteRegistry(), SetItem(lending), lending, gAuth6(), gChain())
        => true
    </k>

  claim // G3 [D7b]: stale price 90 -> both REJECT
    <k> ( rootOk(gAuth6(), "lending", "t0")
          andBool gateOk(gChain(), gP_stale(), .List, gAuth6(), chainCompleteRegistry(), .Map) )
        ==Bool
        gateAccept(chainCompleteRegistry(), SetItem(lending), lending, gAuth6(), gP_stale())
        => true
    </k>

  claim // G4 [D8]: settlement at 90 (IOLD) -> both REJECT
    <k> ( rootOk(gAuth6(), "liq", "t0")
          andBool gateOk(gChain(), gP_settle90(), .List, gAuth6(), chainCompleteRegistry(), .Map) )
        ==Bool
        gateAccept(chainCompleteRegistry(), SetItem(liq), liq, gAuth6(), gP_settle90())
        => true
    </k>

  claim // G5 [D2 / CM1]: negative registry -> both ACCEPT the violation
    <k> ( rootOk(gAuth6(), "appB", "t0")
          andBool gateOk(gC_D1(), gP_D1(), .List, gAuth6(), negativeRegistry(), .Map) )
        ==Bool
        gateAccept(negativeRegistry(), SetItem(appB), appB, gAuth6(), gP_D1())
        => true
    </k>

  claim // G6 [D10 / CM6]: pairwise-only registry -> both ACCEPT the three-way violation
    <k> ( rootOk(gAuth6(), "liq", "t0")
          andBool gateOk(gChain(), gP_settle99(), .List, gAuth6(), pairwiseOnlyRegistry(), .Map) )
        ==Bool
        gateAccept(pairwiseOnlyRegistry(), SetItem(liq), liq, gAuth6(), gP_settle99())
        => true
    </k>

  claim // G7 [honest (7,2)]: in-bounds write -> both ACCEPT
    <k> ( rootOk(gAuth6(), "appB", "t0")
          andBool gateOk(gC_D1(), gP_honest(), .List, gAuth6(), completeRegistry(), .Map) )
        ==Bool
        gateAccept(completeRegistry(), SetItem(appB), appB, gAuth6(), gP_honest())
        => true
    </k>

  // ---- disagreement claims (CM7 / D3): the ONLY divergence class -------------

  claim // X1 [D3, trust policy]: implemented gate ACCEPTS what the faithful
        // instantiation REJECTS (hidden write appC:=11 outside declared foot).
        // Asserts the DISAGREEMENT => PROVED pins the divergence to effect
        // incompleteness exactly.
    <k> notBool (
          ( rootOk(gAuth6(), "appB", "t0")
            andBool gateOk(gC_D1(), gP_hidden(), .List, gAuth6(), completeRegistry(), .Map) )
          ==Bool
          gateAccept(completeRegistry(), SetItem(appB), appB, gAuth6(), gP_hidden())
        ) => true
    </k>

  claim // X2 [D4, enforce policy, same state]: with the true effects covered
        // (appC declared in the footprint too) the implemented gate REJECTS
        // the hidden-write state -> agreement RESTORED (both reject).
    <k> ( rootOk(gAuth6(), "appB", "t0")
          andBool gateOk(gC_D1(), gP_hidden(), .List, gAuth6(), completeRegistry(), .Map) )
        ==Bool
        gateAccept(completeRegistry(),
                   SetItem(appB) |Set SetItem(appC),
                   appB, gAuth6(), gP_hidden())
        => true
    </k>
endmodule
