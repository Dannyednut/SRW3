// =============================================================================
// proofs/induction_ghost.k — THEOREM-CLOSURE PASS, ITEM 1 (final attempt class)
//
// Invariant-as-data / ghost-state encoding of the full lineage-length safety
// theorem, per the audit instruction:
//
//   InitialSafe(P, sigma_0) /\ SecurityClosed(P)  ->  forall n. Safe(P, sigma_n)
//   equivalently  Reach_committed(P) ⊆ Safe(P)
//
// STRUCTURE (exactly the prescribed one):
//   * The baseline semantics (k/srw3.k, modules SRW3-SYNTAX..SRW3-CLAIMS) is
//     present BYTE-IDENTICALLY (mechanical certificate:
//     scripts/audit_ghost_faithful.py); the ONLY edit class is //GHOST:-marked
//     additive lines (certificate cell, pending-write record, certificate
//     transformers at the commitment point). Real-cell behavior of every rule
//     is unchanged; the real gate decisions (allHold(applicable(R,FD), P)) are
//     kept VERBATIM as the accept/reject splitting conditions.
//   * <ghost> carries the safety certificate as DATA:
//       G(xa,xb)       certified values of the two tracked keys;
//       GW(I,S,prev,v) pending declared write, recorded by the w rule,
//                      consumed at the commitment point (apply on accept,
//                      undo on reject).
//   * GhostMatches(ghost, committed) is the EXPLICIT soundness relation
//     (lookupInt equalities on the tracked keys). It is NOT assumed:
//     GH-BASE checks the base instance by evaluation; GH-A / GH-R prove
//     preservation for the accepted / rejected transition (the 4a/4b analogues
//     at the certificate layer); GH-SOUND-I/F prove that a certified-safe
//     certificate matched to the real state implies the real-state safety
//     observer safeMin (the GhostMatches -> Safe bridge).
//   * The theorem claim GH-T is a [circularity] over chkG-terminated programs
//     (sort GateRun): the observer executes ONLY on a certified-safe
//     certificate, so a claim of universal termination proves iff no
//     admissible run ever commits an unsafe state (refutation-proof form,
//     as in attempts [B]/[C]). The induction hypothesis is re-established at
//     each unrolled tail: the certificate and the committed state are re-matched
//     through the GhostMatches-shaped shared variables (X0/Y0), and the reuse
//     requires discharge is exactly the preserved safety of the previous
//     certificate.
//
// NO UNPROVED AXIOM: no rule or claim asserts ghost == committed. The only
// link is GhostMatches, and every claim about it is a proof obligation that
// kprove checks (GH-BASE/GH-A/GH-R/GH-SOUND-I/GH-SOUND-F). The certificate
// transformer (ghostApply) is justified by GH-A, not by fiat.
//
// SCOPE (documented restriction, same scope as Claims 4a/4b and attempt [C]):
//   the minimal model universe minInvs() = {IA,IB,IAB,IC} over the two-key
//   shape {stK(appA,0), stK(appB,0)}, completeRegistry(), policy enforce,
//   actor appB, one declared write per cycle (tB). The certificate tracks the
//   two keys of that universe; writes to other keys are carried transparently
//   (GW) and provably leave GhostMatches unaffected. `init` (a direct
//   committed-state write outside the theorem's program class) is copied
//   verbatim but is outside the GH-A/GH-R preservation scope.
//
// OUTCOME: recorded verbatim in transcripts/audit/ghost_theorem.txt and
// analyzed in report section R.
// =============================================================================

module SRW3-SYNTAX
  imports DOMAINS

  // Application identifiers: appA/appB (minimal model);
  // oracle/lending/liq = Oracle / Lending / Liquidator chain.
  // (Single-letter tokens clash with builtin rule variables, hence names.)
  syntax AppId ::= "noOne" | "appA" | "appB" | "appC" | "oracle" | "lending" | "liq"

  // Composite storage key: (application, slot) — the abstract analogue of
  // (account address, storage slot) in the KEVM layer.
  syntax StKey ::= "stK" "(" app:AppId "," slot:Int ")"

  // Obligation identifiers.
  //   IA   : x_A <= 10                                     (local, {appA})
  //   IB   : x_B <= 10                                     (local, {appB})
  //   IAB  : x_A + x_B <= 10                               (interaction, {appA,appB})
  //   IO   : oracle price is authenticated                 (local, {oracle})
  //   IOL  : PriceUsedByLending == AuthenticatedOraclePrice     ({oracle,lending})
  //   ILD  : LiquidationTransfer <= AuthorizedDebt              ({lending,liq})
  //   IOLD : settlement uses the same authenticated price
  //          lineage used by the lending decision                ({oracle,lending,liq})
  syntax InvId ::= "IA" | "IB" | "IAB" | "IC" | "IO" | "IOL" | "ILD" | "IOLD"

  // Commitments + lineage records (handoff §14):
  // Λ = ⟨ParentCommitment, TransitionId, AuthorizationEvidence,
  //      PolicyVersion, ChildCommitment⟩
  // InputEvidence/ProofEvidence are symbolic at this layer (documented
  // abstraction); the KEVM binding realizes input evidence as concrete
  // prospective storage values.
  syntax Commitment ::= "rootC" | "commit" "(" Int ")"
  syntax Auth ::= "auth" "(" AppId ")" | "noAuth"
  syntax LineageRec ::= "lin" "(" parent:Commitment "," tid:Int "," auth:Auth "," polver:Int "," child:Commitment ")"

  // Security hypergraph H = (V, E_H) (handoff §17).
  //   edge(J, Xs)  : hyperedge carrying obligation J over app set Xs
  //   bareEdge(Xs) : known dependency with NO contract (CM6 contract gap)
  syntax Edge ::= "edge" "(" inv:InvId "," apps:Set ")" | "bareEdge" "(" apps:Set ")"

  // Effect-abstraction policy (handoff §12/§13/§19):
  //   enforce : wfCheck refuses to gate transitions whose true effects are
  //             not covered by the declared abstraction (Γ* ⊆ Γ̂)
  //   trust   : gate trusts the declared footprint alone (deliberately
  //             unsound; mechanizes the hidden-effect problem §13)
  syntax Policy ::= "enforce" | "trust"

  // Transition command language. A transition = begin; reads/writes; wfCheck; gate.
  syntax RegistryKind ::= "complete" | "negative" | "pairwiseOnly"
                        | "chainComplete" | "chainNegative"
  syntax Srw3Cmd ::= "init" "(" app:AppId "," slot:Int "," v:Int ")"
                   | "as" "(" actor:AppId ")"
                   | "begin"
                   | "w" "(" app:AppId "," slot:Int "," v:Int ")"     // declared write
                   | "wH" "(" app:AppId "," slot:Int "," v:Int ")"    // HIDDEN write (omitted from abstraction)
                   | "rd" "(" app:AppId ")"                     // declared read dependency
                   | "rdH" "(" app:AppId ")"                    // HIDDEN read (undeclared dependency)
                   | "wfCheck"
                   | "gate"
                   | "useRegistry" "(" kind:RegistryKind ")"
                   | "setPolicy" "(" policy:Policy ")"
  syntax Srw3Pgm ::= List{Srw3Cmd,","}
  // ---- invariant-as-data certificate + theorem program grammar (theorem-closure pass) ----
  // G(xa,xb)       certified values of stK(appA,0), stK(appB,0)
  // GW(I,S,prev,v) pending write of v to (I,S) over certificate prev
  // GateRun        chkG-terminated programs of one-write cycles; the ghost
  //                function EQUATIONS live in SRW3-GHOST-OBS below
  syntax Ghost ::= "G" "(" Int "," Int ")" | "GW" "(" AppId "," Int "," Ghost "," Int ")"   //GHOST:
  syntax GateRun ::= "chkG" | "chkM" | "tB" "(" Int ")" ":" GateRun   //GHOST:
  syntax Bool ::= "ghostSafe" "(" Ghost ")" [function, total]   //GHOST:
  syntax Bool ::= "ghostMatches" "(" Ghost "," st:Map ")" [function, total]   //GHOST:
  syntax Ghost ::= "ghostApply" "(" Ghost "," st:Map ")" [function, total]   //GHOST:
  syntax Ghost ::= "ghostUndo" "(" Ghost ")" [function, total]   //GHOST:
  syntax Set ::= "gAUTH" "(" ")" [function, total]   //GHOST:
  syntax Bool ::= "safeMin" "(" st:Map ")" [function, total]   //GHOST:
endmodule

// =============================================================================
module SRW3-STATE
  imports SRW3-SYNTAX

  // The commitment boundary (handoff §8): <committed> and <prospective>
  // are distinguishable semantic components. <footprint-t> is the true
  // read/write footprint of the executing transition; <footprint-d> is
  // the DECLARED footprint (the effect abstraction the gate reasons over).
  configuration <srw3>
                  <k> $PGM:Srw3Pgm </k>
                  <committed> .Map </committed>      // Map StKey -> Int
                  <prospective> .Map </prospective>  // Map StKey -> Int
                  <footprint-t> .Set </footprint-t>
                  <footprint-d> .Set </footprint-d>
                  <registry> .Set </registry>        // interaction hypergraph
                  <policy> enforce </policy>
                  <authorities> .Set </authorities>
                  <polver> 1 </polver>
                  <actor> noOne </actor>
                  <lineage> .Map </lineage>          // Map tid -> LineageRec
                  <lineageNext> 0 </lineageNext>
                  <head> rootC </head>               // chain-head commitment
                  <result> "" </result>
                  <ghost> G(0, 0) </ghost>   // invariant-as-data certificate  //GHOST:
                </srw3>

  // ---- command semantics -----------------------------------------------------
  // Decompose the program list into a sequential ~> chain so individual
  // command rules can fire on the head.
  rule <k> (C:Srw3Cmd , REST:Srw3Pgm) => C ~> REST ... </k>

  rule <k> init(I:AppId, S:Int, V:Int) => .K ... </k>
       <committed> M:Map => M[stK(I, S) <- V] </committed>

  rule <k> as(P:AppId) => .K ... </k>
       <actor> _A:AppId => P </actor>

  // Prospective execution begins as a shadow copy of the committed state:
  // sigma -> sigma_hat over committed sigma (handoff §3, §8).
  rule <k> begin => .K ... </k>
       <committed> C:Map </committed>
       <prospective> _P:Map => C </prospective>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> _FD:Set => .Set </footprint-d>

  rule <k> w(I:AppId, S:Int, V:Int) => .K ... </k>
       <prospective> P:Map => P[stK(I, S) <- V] </prospective>
       <footprint-t> FT:Set => FT |Set SetItem(I) </footprint-t>
       <footprint-d> FD:Set => FD |Set SetItem(I) </footprint-d>
       <ghost> Gh:Ghost => GW(I, S, Gh, V) </ghost>   // pending-write record  //GHOST:

  // Hidden write: real effect omitted from the declared abstraction (§13/CM7).
  rule <k> wH(I:AppId, S:Int, V:Int) => .K ... </k>
       <prospective> P:Map => P[stK(I, S) <- V] </prospective>
       <footprint-t> FT:Set => FT |Set SetItem(I) </footprint-t>

  rule <k> rd(I:AppId) => .K ... </k>
       <footprint-t> FT:Set => FT |Set SetItem(I) </footprint-t>
       <footprint-d> FD:Set => FD |Set SetItem(I) </footprint-d>

  // Hidden read: security-relevant dependency omitted from the abstraction.
  rule <k> rdH(I:AppId) => .K ... </k>
       <footprint-t> FT:Set => FT |Set SetItem(I) </footprint-t>

  rule <k> setPolicy(P:Policy) => .K ... </k>
       <policy> _Q:Policy => P </policy>
endmodule

// =============================================================================
module SRW3-INVAR
  imports SRW3-STATE

  // ---- obligation semantics: real evaluation, no axioms (handoff §23) ----
  // Typed storage read. The .Map default of 0 mirrors EVM SLOAD semantics
  // (a never-written storage slot reads as zero); all claimed configurations
  // initialize every referenced slot, so the default is never exercised there.
  // A typed total function is used instead of a projection cast because the
  // cast is opaque to the backend simplifier and blocks arithmetic reasoning.
  syntax Int ::= "lookupInt" "(" m:Map "," k:StKey ")" [function, total]
  rule lookupInt(stK(K:AppId, S:Int) |-> V:Int REST:Map, stK(K, S)) => V
  rule lookupInt(stK(K:AppId, S:Int) |-> V:Int REST:Map, KEY:StKey)
    => lookupInt(REST, KEY)
    requires KEY =/=K stK(K, S)
  rule lookupInt(.Map, _K:StKey) => 0

  syntax Bool ::= "evalInv" "(" inv:InvId "," st:Map ")" [function, total]

  rule evalInv(IA,   M:Map) => lookupInt(M, stK(appA, 0)) <=Int 10
  rule evalInv(IB,   M:Map) => lookupInt(M, stK(appB, 0)) <=Int 10
  rule evalInv(IAB,  M:Map) => lookupInt(M, stK(appA, 0)) +Int lookupInt(M, stK(appB, 0)) <=Int 10
  rule evalInv(IC,   M:Map) => lookupInt(M, stK(appC, 0)) <=Int 10
  rule evalInv(IO,   M:Map) => lookupInt(M, stK(oracle, 1)) ==Int 1
  rule evalInv(IOL,  M:Map) => lookupInt(M, stK(lending, 0)) ==Int lookupInt(M, stK(oracle, 0))
  rule evalInv(ILD,  M:Map) => lookupInt(M, stK(liq, 0)) <=Int lookupInt(M, stK(lending, 1))
  rule evalInv(IOLD, M:Map) => (lookupInt(M, stK(liq, 1)) ==Int lookupInt(M, stK(lending, 0))) andBool (lookupInt(M, stK(lending, 0)) ==Int lookupInt(M, stK(oracle, 0)))

  // Auditable read-set oracle Γ* (documented abstraction: derived by
  // inspection of the evalInv equations; handoff §19).
  syntax Set ::= "trueDeps" "(" inv:InvId ")" [function, total]
  rule trueDeps(IA)   => SetItem(appA)
  rule trueDeps(IB)   => SetItem(appB)
  rule trueDeps(IAB)  => SetItem(appA) |Set SetItem(appB)
  rule trueDeps(IC)   => SetItem(appC)
  rule trueDeps(IO)   => SetItem(oracle)
  rule trueDeps(IOL)  => SetItem(oracle) |Set SetItem(lending)
  rule trueDeps(ILD)  => SetItem(lending) |Set SetItem(liq)
  rule trueDeps(IOLD) => SetItem(oracle) |Set SetItem(lending) |Set SetItem(liq)

  syntax Set ::= "allInvs" "(" ")" [function, total]
  rule allInvs() => SetItem(IA) |Set SetItem(IB) |Set SetItem(IAB) |Set SetItem(IC)
                  |Set SetItem(IO) |Set SetItem(IOL) |Set SetItem(ILD) |Set SetItem(IOLD)
endmodule

// =============================================================================
module SRW3-CLOSURE
  imports SRW3-INVAR

  // ---- set helpers ----------------------------------------------------------
  // NOTE: implemented via explicit recursion over `member` rather than the
  // builtin intersectSet hook: the Haskell backend does not reliably evaluate
  // SET.intersection, which previously left wfCheck's requires symbolic and
  // introduced spurious nondeterminism (see transcripts, D4 debugging).
  syntax Bool ::= "member" "(" KItem "," Set ")" [function, total]
  rule member(_I:KItem, .Set) => false
  rule member(I:KItem, SetItem(I2:KItem) S:Set) => I ==K I2 orBool member(I, S)

  syntax Bool ::= "subset" "(" Set "," Set ")" [function, total]   // subset(X, Y) := X ⊆ Y
  rule subset(.Set, _Y:Set) => true
  rule subset(SetItem(I) Xs:Set, Y:Set)
    => member(I, Y) andBool subset(Xs, Y)

  syntax Bool ::= "nonemptyInter" "(" Set "," Set ")" [function, total]  // X ∩ Y ≠ ∅
  rule nonemptyInter(.Set, _Y:Set) => false
  rule nonemptyInter(SetItem(I) Xs:Set, Y:Set)
    => member(I, Y) orBool nonemptyInter(Xs, Y)

  // ---- Affected(τ) = { J | apps(edge(J)) ∩ Foot(τ) ≠ ∅ }  (handoff §19) ----
  // Computed over the DECLARED footprint: the gate reasons over the
  // abstraction, which is why wfCheck (Γ* ⊆ Γ̂) is load-bearing.
  syntax Set ::= "applicable" "(" edges:Set "," foot:Set ")" [function, total]
  rule applicable(.Set, _F:Set) => .Set
  rule applicable(SetItem(edge(J:InvId, Xs:Set)) Es:Set, F:Set)
    => SetItem(J) |Set applicable(Es, F)
    requires nonemptyInter(Xs, F)
  rule applicable(SetItem(edge(J:InvId, Xs:Set)) Es:Set, F:Set)
    => applicable(Es, F)
    requires notBool nonemptyInter(Xs, F)
  rule applicable(SetItem(bareEdge(_Xs:Set)) Es:Set, _F:Set)
    => applicable(Es, .Set)   // dependency known, no contract → no obligation

  // ---- obligation conjunction ----
  syntax Bool ::= "allHold" "(" obls:Set "," st:Map ")" [function, total]
  rule allHold(.Set, _M:Map) => true
  rule allHold(SetItem(J:InvId) Js:Set, M:Map) => evalInv(J, M) andBool allHold(Js, M)

  // ---- Security closure (handoff §12) --------------------------------------
  // InteractionComplete: every invariant's true dependency set is covered
  // by some hyperedge carrying that same obligation.
  syntax Bool ::= "interactionComplete" "(" edges:Set "," rest:Set ")" [function, total]
  rule interactionComplete(_R:Set, .Set) => true
  rule interactionComplete(R:Set, SetItem(J:InvId) Js:Set)
    => hasCover(R, J) andBool interactionComplete(R, Js)

  syntax Bool ::= "hasCover" "(" edges:Set "," inv:InvId ")" [function, total]
  rule hasCover(.Set, _J:InvId) => false
  rule hasCover(SetItem(edge(J:InvId, Xs:Set)) Es:Set, J2:InvId)
    => subset(trueDeps(J2), Xs) orBool hasCover(Es, J2)
    requires J ==K J2
  rule hasCover(SetItem(edge(J:InvId, _Xs:Set)) Es:Set, J2:InvId)
    => hasCover(Es, J2)
    requires J =/=K J2
  rule hasCover(SetItem(bareEdge(_Xs:Set)) Es:Set, J2:InvId)
    => hasCover(Es, J2)

  // ContractComplete: every known dependency edge carries a contract.
  syntax Bool ::= "contractComplete" "(" edges:Set ")" [function, total]
  rule contractComplete(.Set) => true
  rule contractComplete(SetItem(bareEdge(_Xs:Set)) _Es:Set) => false
  rule contractComplete(SetItem(edge(_J:InvId, _Xs:Set)) Es:Set) => contractComplete(Es)

  // SecurityClosed(P) = EffectComplete ∧ InteractionComplete ∧
  //                     ContractComplete ∧ LineageComplete ∧ GateComplete
  // At this layer:
  //   EffectComplete ≈ policy == enforce (wfCheck enforces Γ* ⊆ Γ̂)
  //   LineageComplete/GateComplete ≈ structural (single commit path that
  //   appends lineage; verified by Claims 2/3, not assumed).
  syntax Bool ::= "securityClosed" "(" edges:Set "," policy:Policy ")" [function, total]
  rule securityClosed(R:Set, P:Policy) => securityClosedUniv(R, P, allInvs())

  // Universe-parameterized closure: the obligation universe is a parameter so
  // a model covering a restricted obligation set (e.g. the two-app minimal
  // model) can be closed over ITS universe without vacuous premises.
  syntax Set ::= "minInvs" "(" ")" [function, total]
  rule minInvs() => SetItem(IA) |Set SetItem(IB) |Set SetItem(IAB) |Set SetItem(IC)

  syntax Bool ::= "securityClosedUniv" "(" edges:Set "," policy:Policy "," univ:Set ")" [function, total]
  rule securityClosedUniv(R:Set, enforce, U:Set) => interactionComplete(R, U) andBool contractComplete(R)
  rule securityClosedUniv(_R:Set, trust, _U:Set)  => false

  // ---- demo registries ----
  syntax Set ::= "pickRegistry" "(" kind:RegistryKind ")" [function, total]
  rule pickRegistry(complete)      => completeRegistry()
  rule pickRegistry(negative)      => negativeRegistry()
  rule pickRegistry(pairwiseOnly)  => pairwiseOnlyRegistry()
  rule pickRegistry(chainComplete) => chainCompleteRegistry()
  rule pickRegistry(chainNegative) => chainNegativeRegistry()

  syntax Set ::= "completeRegistry" "(" ")" [function, total]
  rule completeRegistry() => SetItem(edge(IA,  SetItem(appA)))
                          |Set SetItem(edge(IB,  SetItem(appB)))
                          |Set SetItem(edge(IAB, SetItem(appA) |Set SetItem(appB)))
                          |Set SetItem(edge(IC,  SetItem(appC)))

  // CM1: local obligations only — the interaction obligation IAB is missing.
  syntax Set ::= "negativeRegistry" "(" ")" [function, total]
  rule negativeRegistry() => SetItem(edge(IA, SetItem(appA)))
                           |Set SetItem(edge(IB, SetItem(appB)))

  // CM6: pairwise contracts present; the three-way dependency is known but
  // carries no contract (bareEdge).
  syntax Set ::= "pairwiseOnlyRegistry" "(" ")" [function, total]
  rule pairwiseOnlyRegistry() => SetItem(edge(IO,  SetItem(oracle)))
                               |Set SetItem(edge(IOL, SetItem(oracle) |Set SetItem(lending)))
                               |Set SetItem(edge(ILD, SetItem(lending) |Set SetItem(liq)))
                               |Set SetItem(bareEdge(SetItem(oracle) |Set SetItem(lending) |Set SetItem(liq)))

  syntax Set ::= "chainCompleteRegistry" "(" ")" [function, total]
  rule chainCompleteRegistry() => SetItem(edge(IO,   SetItem(oracle)))
                                |Set SetItem(edge(IOL,  SetItem(oracle) |Set SetItem(lending)))
                                |Set SetItem(edge(ILD,  SetItem(lending) |Set SetItem(liq)))
                                |Set SetItem(edge(IOLD, SetItem(oracle) |Set SetItem(lending) |Set SetItem(liq)))

  // CM6 variant: pairwise-only, the IOLD hyperedge is simply absent.
  syntax Set ::= "chainNegativeRegistry" "(" ")" [function, total]
  rule chainNegativeRegistry() => SetItem(edge(IO,  SetItem(oracle)))
                                |Set SetItem(edge(IOL,  SetItem(oracle) |Set SetItem(lending)))
                                |Set SetItem(edge(ILD,  SetItem(lending) |Set SetItem(liq)))
endmodule

// =============================================================================
module SRW3-GATE
  imports SRW3-CLOSURE

  // ---- registry/authority setup (placed here: needs pickRegistry) --------
  rule <k> useRegistry(K2:RegistryKind) => .K ... </k>
       <registry> _R:Set => pickRegistry(K2) </registry>
       <authorities> _As:Set => SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(oracle) |Set SetItem(lending) |Set SetItem(liq) </authorities>

  // ---- wfCheck: effect-completeness enforcement (handoff §12, §19) ----
  // Γ*_P ⊆ Γ̂ must hold for the abstraction to be a sound basis for Affected.
  rule <k> wfCheck => .K ... </k>
       <footprint-t> FT:Set </footprint-t>
       <footprint-d> FD:Set </footprint-d>
       <policy> enforce </policy>
    requires subset(FT, FD)

  rule <k> wfCheck => .K ... </k>
       <footprint-t> _FT:Set </footprint-t>
       <footprint-d> _FD:Set </footprint-d>
       <policy> trust </policy>

  // Blocking is terminal: the remaining transition pipeline is discarded.
  rule <k> wfCheck ~> _REST:K => .K </k>
       <footprint-t> FT:Set </footprint-t>
       <footprint-d> FD:Set </footprint-d>
       <policy> enforce </policy>
       <result> _R:String => "blocked-effect-incomplete" </result>
       <prospective> _P:Map => .Map </prospective>
    requires notBool subset(FT, FD)

  // ---- the commitment gate ------------------------------------------------
  // ACCEPT: every applicable obligation holds on the prospective state and
  // the actor is authorized. This is the ONLY rule in the entire semantics
  // that updates <committed>; it appends a lineage record and advances the
  // chain head (structural GateComplete + LineageComplete).
  rule <k> gate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <committed> _C:Map => P </committed>
       <registry> R:Set </registry>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> FD:Set => .Set </footprint-d>
       <actor> Ac:AppId </actor>
       <authorities> As:Set </authorities>
       <polver> PV:Int </polver>
       <lineage> LN:Map => LN:Map [ N:Int <- lin(CH:Commitment, N:Int, auth(Ac), PV, commit(N:Int)) ] </lineage>
       <lineageNext> N:Int => N +Int 1 </lineageNext>
       <head> CH:Commitment => commit(N:Int) </head>
       <result> _R:String => "commit" </result>
       <ghost> Gh:Ghost => ghostApply(Gh, P) </ghost>   // certificate apply at commit  //GHOST:
    requires member(Ac, As) andBool allHold(applicable(R, FD), P)

  // REJECT (invariant violated): the prospective state is discarded and the
  // committed state is left untouched — the commitment boundary (handoff §4).
  rule <k> gate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <registry> R:Set </registry>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> FD:Set => .Set </footprint-d>
       <result> _R:String => "reject" </result>
       <ghost> Gh:Ghost => ghostUndo(Gh) </ghost>   // certificate undo at reject  //GHOST:
    requires notBool allHold(applicable(R, FD), P)

  // REJECT (authorization/lineage evidence invalid): obligations hold but the
  // actor is not in the authority closure.
  rule <k> gate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <registry> R:Set </registry>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> FD:Set => .Set </footprint-d>
       <actor> Ac:AppId </actor>
       <authorities> As:Set </authorities>
       <result> _R:String => "reject-auth" </result>
       <ghost> Gh:Ghost => ghostUndo(Gh) </ghost>   // certificate undo at reject-auth  //GHOST:
    requires notBool member(Ac, As) andBool allHold(applicable(R, FD), P)
endmodule

// =============================================================================
// Explicit, separable assumptions (handoff §23).
//
// ASSUMPTIONS (abstracted, documented):
//   A1. trueDeps(·) is a manual read-set derivation from the evalInv
//       equations (auditable; in the KEVM layer the analogue is derived
//       from actual storage accesses).
//   A2. Commitments are opaque terms (commit(Int)); no hash function is
//       modeled at this layer.
//   A3. InputEvidence/ProofEvidence of Λ are carried symbolically; the
//       authorization evidence checked is authority membership.
//   A4. Claim-level closure premises are evaluated against the concrete
//       registry term in each claim (non-vacuous; see report §E).
// =============================================================================

module SRW3-CLAIMS
  imports SRW3-GATE

  // ---------------------------------------------------------------------------
  // Claim 1 — Local preservation (handoff §22.1).
  // Single-app universe (registry = {IA}); a locally valid transition that the
  // gate accepts produces a committed state satisfying the declared local
  // invariant, and appends lineage.
  // ---------------------------------------------------------------------------
  claim
    <k> w(appA, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int => stK(appA, 0) |-> V:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appA) => .Set </footprint-d>
    <registry> SetItem(edge(IA, SetItem(appA))) </registry>
    <policy> _Pol:Policy </policy>
    <authorities> As:Set </authorities>
    <polver> 1 </polver>
    <actor> appA </actor>
    <lineage> LN:Map => LN:Map [ N:Int <- lin(CH:Commitment, N:Int, auth(appA), 1, commit(N:Int)) ] </lineage>
    <lineageNext> N:Int => N +Int 1 </lineageNext>
    <head> CH:Commitment => commit(N:Int) </head>
    <result> _R:String => "commit" </result>
    requires X <=Int 10 andBool V <=Int 10 andBool member(appA, As)

  // ---------------------------------------------------------------------------
  // Claim 2 — Gate coverage (handoff §22.2).
  // Under the COMPLETE registry, a transition whose prospective state violates
  // an applicable invariant cannot produce a committed state: the committed
  // cell is unchanged and the prospective state is discarded.
  // ---------------------------------------------------------------------------
  claim
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> _Pol:Policy </policy>
    <authorities> As:Set </authorities>
    <actor> appB </actor>
    <result> _R:String => "reject" </result>
    requires X +Int V >Int 10 andBool member(appB, As)

  // ---------------------------------------------------------------------------
  // Claim 3 — Lineage append (handoff §22.3).
  // A valid, accepted transition produces a child commitment whose lineage
  // record references the current chain head as parent and the new commitment
  // as child, with the actor's authorization evidence.
  // ---------------------------------------------------------------------------
  claim
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> _Pol:Policy </policy>
    <authorities> As:Set </authorities>
    <polver> 1 </polver>
    <actor> appB </actor>
    <lineage> LN:Map => LN:Map [ N:Int <- lin(CH:Commitment, N:Int, auth(appB), 1, commit(N:Int)) ] </lineage>
    <lineageNext> N:Int => N +Int 1 </lineageNext>
    <head> CH:Commitment => commit(N:Int) </head>
    <result> _R:String => "commit" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool V <=Int 10
             andBool X +Int V <=Int 10 andBool member(appB, As)

  // ---------------------------------------------------------------------------
  // Claim 4 — Closed composition, one-step safety preservation (handoff §22.4,
  // §20, §21). The induction step of the Phase-0 theorem over the minimal
  // model, split into the two gate outcomes (4a accept / 4b reject); their
  // conjunction is the theorem. Premises are computed predicates, not axioms:
  // InitialSafe (X,Y,X+Y) and SecurityClosed are evaluated, not assumed.
  // ---------------------------------------------------------------------------
  // 4a: admissible prospective → commits to a safe committed state.
  claim
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <authorities> As:Set </authorities>
    <polver> 1 </polver>
    <actor> appB </actor>
    <lineage> LN:Map => LN:Map [ N:Int <- lin(CH:Commitment, N:Int, auth(appB), 1, commit(N:Int)) ] </lineage>
    <lineageNext> N:Int => N +Int 1 </lineageNext>
    <head> CH:Commitment => commit(N:Int) </head>
    <result> _R:String => "commit" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
             andBool V <=Int 10 andBool X +Int V <=Int 10
             andBool member(appB, As)
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())

  // 4b: inadmissible prospective → rejection; the committed state is the
  // initial safe state, unchanged.
  claim
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <authorities> As:Set </authorities>
    <actor> appB </actor>
    <result> _R:String => "reject" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
             andBool ( V >Int 10 orBool X +Int V >Int 10 )
             andBool member(appB, As)
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
endmodule

// =============================================================================
// GHOST EXTENSION MODULES — everything below is NEW (theorem-closure pass).
// The ghost FUNCTION SYNTAX is declared in SRW3-SYNTAX above (visible to the
// copied gate rules); this module holds their defining EQUATIONS.
// =============================================================================

module SRW3-GHOST-OBS
  imports SRW3-GATE

  // ---- certified safety = the model's obligation universe evaluated on the
  //      certified values (the SAME evaluated obligations as the real gate;
  //      IC vacuous on the two-key shape — SF0 of the safe-form audit) --------
  rule ghostSafe(G(XA:Int, XB:Int))
    => allHold(minInvs(), stK(appA, 0) |-> XA stK(appB, 0) |-> XB)
  rule ghostSafe(GW(_I:AppId, _S:Int, Prev:Ghost, _V:Int)) => ghostSafe(Prev)

  // ---- GhostMatches: the explicit soundness relation ------------------------
  rule ghostMatches(G(XA:Int, XB:Int), M:Map)
    => lookupInt(M, stK(appA, 0)) ==Int XA
       andBool lookupInt(M, stK(appB, 0)) ==Int XB
  rule ghostMatches(GW(_I:AppId, _S:Int, Prev:Ghost, _V:Int), M:Map)
    => ghostMatches(Prev, M)

  // ---- certificate transformer at the commitment point ----------------------
  // tracked write  -> certified value updated;  untracked / none -> unchanged.
  rule ghostApply(GW(appB, 0, G(XA:Int, _XB:Int), V:Int), _P:Map) => G(XA, V)
  rule ghostApply(GW(appA, 0, G(_XA2:Int, XB:Int), V:Int), _P2:Map) => G(V, XB)
  rule ghostApply(Gh:Ghost, _P3:Map) => Gh [owise]

  rule ghostUndo(GW(_I2:AppId, _S2:Int, Gh:Ghost, _V2:Int)) => Gh
  rule ghostUndo(Gh2:Ghost) => Gh2 [owise]

  // ---- concrete authority set for the theorem instances ---------------------
  rule gAUTH() => SetItem(appA) |Set SetItem(appB) |Set SetItem(appC)

  // ---- one full admissible transition cycle (proof-layer command) -----------
  rule <k> tB(V:Int) : PG:GateRun
        => begin ~> w(appB, 0, V) ~> wfCheck ~> gate ~> PG ... </k>

  // ---- safety observer: executable ONLY on a certified-safe certificate -----
  rule <k> chkG => .K ... </k>
       <ghost> Gh:Ghost </ghost>
    requires ghostSafe(Gh)

  // ---- matching observer: executable ONLY if the certificate BOTH matches
  //      the real committed state (GhostMatches) AND is certified-safe. This
  //      is the refutation-proof observer for the preservation claims (GH-A /
  //      GH-R: a defective certificate transformer would desynchronize the
  //      certificate, chkM would stick, and the claim would FAIL) and for the
  //      strongest theorem form (GH-M: the soundness relation is re-checked at
  //      every program termination).
  rule <k> chkM => .K ... </k>
       <ghost> Gh:Ghost </ghost>
       <committed> M:Map </committed>
    requires ghostMatches(Gh, M) andBool ghostSafe(Gh)

  // ---- trusted simplification lemmas (verbatim from proofs/induction_full.k)
  rule lookupInt(M:Map [KEY:StKey <- V:Int], KEY:StKey) => V [simplification]
  rule lookupInt(M:Map [KEY:StKey <- V:Int], K2:StKey) => lookupInt(M, K2)
    requires K2 =/=K KEY [simplification]

  // ---- real-state safety observer (verbatim from proofs/induction_full.k) ---
  rule safeMin(M2:Map)
    => lookupInt(M2, stK(appA, 0)) <=Int 10
       andBool lookupInt(M2, stK(appB, 0)) <=Int 10
       andBool lookupInt(M2, stK(appA, 0)) +Int lookupInt(M2, stK(appB, 0)) <=Int 10
endmodule

// =============================================================================
// Claims: the GhostMatches obligation set + the full theorem.
//
// KORE DESTINATION NOTE (discovered in this pass, consistent with the [C]
// residuals of the record attempt): a claim whose destination mentions ONLY
// <k> .K fails the implication check with a stuck residual, while the SAME
// claim with explicit existential (?-prefixed) destination cells over ALL
// cells closes. GH-T (minimal destination) is retained as the documented
// probe; the theorem forms use the explicit-existential destinations.
// =============================================================================

module SRW3-GHOST-CLAIMS
  imports SRW3-GHOST-OBS

  claim // GH-BASE: the soundness relation HOLDS BY EVALUATION at the theorem's
        // initial shape (the certificate base case; no axiom)
    <k> ghostMatches(G(X0:Int, Y0:Int),
                     stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int) => true </k>
    [label(GH-BASE)]

  claim // GH-A: ACCEPT preservation (the 4a-analogue at the certificate layer):
        // after an accepted transition the certificate matches the committed
        // state AND is safe — checked dynamically by the chkM observer (a
        // defective certificate transformer would make chkM stick)
    <k> ( tB(V:Int) : chkM ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool V <=Int 10 andBool X0 +Int V <=Int 10
    [label(GH-A)]

  claim // GH-R: REJECT preservation (the 4b-analogue): the PREVIOUS matching
        // relation is preserved (committed state and certificate unchanged)
    <k> ( tB(V:Int) : chkM ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool notBool ( V <=Int 10 andBool X0 +Int V <=Int 10 )
    [label(GH-R)]

  claim // GH-SOUND-I: a certified-safe certificate, matched to the real state,
        // implies the REAL-state safety observer safeMin (residual-sharing
        // form: the stuck lookupInt terms are shared between goal and premise)
    <k> ( lookupInt(M:Map, stK(appA, 0)) <=Int 10
          andBool lookupInt(M, stK(appB, 0)) <=Int 10
          andBool lookupInt(M, stK(appA, 0)) +Int lookupInt(M, stK(appB, 0)) <=Int 10 )
        => true </k>
    requires lookupInt(M, stK(appA, 0)) ==Int XA:Int
             andBool lookupInt(M, stK(appB, 0)) ==Int XB:Int
             andBool ghostSafe(G(XA, XB))
    [label(GH-SOUND-I)]

  claim // GH-SOUND-F: the same bridge stated via the NAMED relation (the
        // definitional form of GH-SOUND-I; ghostMatches/ghostSafe unfold to
        // exactly the GH-SOUND-I premise)
    <k> safeMin(M:Map) => true </k>
    requires ghostMatches(G(XA:Int, XB:Int), M) andBool ghostSafe(G(XA, XB))
    [label(GH-SOUND-F)]

  claim // GATE-AGREE: the certificate-predicted accept condition == the REAL
        // gate's evaluated applicable-obligation conjunction on the
        // prospective state (SF2-shape of the safe-form audit, prospective form)
    <k> allHold(applicable(completeRegistry(), SetItem(appB)),
                stK(appA, 0) |-> XA:Int stK(appB, 0) |-> XB:Int [stK(appB, 0) <- V:Int])
        ==Bool ( V <=Int 10 andBool XA +Int V <=Int 10 ) => true </k>
    [label(GATE-AGREE)]

  claim // GH-ISO: one full cycle + observer, NON-circular (diagnostic; the
        // C-ISO isolate of the record attempt, at the ghost layer). Covers BOTH
        // gate branches (accept and reject) and the observer firing.
    <k> ( tB(V:Int) : chkG ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
    [label(GH-ISO)]

  claim // GH-T1: TWO cycles + observer, NON-circular (bounded-depth probe:
        // separates per-step machinery + tail carrying from the reuse mechanism)
    <k> ( tB(V1:Int) : (tB(V2:Int) : chkG) ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
    [label(GH-T1)]

  claim // GH-T (minimal-destination probe): the SAME theorem as GH-T2 but with
        // a destination mentioning only <k> .K. EXPECTED STUCK per the kore
        // destination behavior documented above (same residual class as the
        // [C] record attempt). Retained as the diagnostic; do not weaken.
    <k> ( tB(V1:Int) : PG:GateRun ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int </committed>
    <ghost> G(X0:Int, Y0:Int) </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
    [circularity, label(GH-T)]

  claim // GH-T2: THE FULL LINEAGE-LENGTH SAFETY THEOREM (circularity).
        //   InitialSafe(P, sigma_0) /\ SecurityClosed(P) -> forall n. Safe(P, sigma_n)
        // InitialSafe(P, sigma_0) is the evaluated requires; SecurityClosed(P)
        // is the evaluated securityClosedUniv premise. The observer chkG
        // executes only on a certified-safe certificate, so universal
        // termination of admissible chkG-terminated programs proves iff no
        // admissible run ever commits an unsafe state (refutation-proof form).
        // The shared variables X0/Y0 between <committed> and <ghost> bake the
        // GhostMatches shape into the induction; its preservation is GH-A/GH-R;
        // the certificate-to-real-state bridge is GH-SOUND-I/F. Existential
        // destinations over all cells (see the kore destination note).
    <k> ( tB(V1:Int) : PG:GateRun ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
    [circularity, label(GH-T2)]

  claim // GH-M: the STRONGEST form — the same forall-n theorem with the
        // GhostMatches soundness relation RE-CHECKED at every termination
        // (chkM observer): every admissible chkM-terminated run terminates,
        // i.e. the committed lineage states remain certified-safe AND matched
        // to their certificates for all n.
    <k> ( tB(V1:Int) : PG:GateRun ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
    [circularity, label(GH-M)]

  claim // GH-T2-NEG (non-vacuity control): GH-T2 with the InitialSafe premise
        // dropped MUST FAIL (an initially-unsafe certified value sticks at the
        // observer; kprove must reject the under-premised theorem).
    <k> ( tB(V1:Int) : PG:GateRun ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires securityClosedUniv(completeRegistry(), enforce, minInvs())
    [circularity, label(GH-T2-NEG)]
endmodule