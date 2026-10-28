// =============================================================================
// SRW3 Phase 0-D — Abstract commitment-gated composition semantics (K)
//
// Per handoff: §8 (separate EVM/transition execution from SRW3 commitment),
// §9 (minimal composition model), §11 (negative model), §12 (security
// closure), §13 (hidden-effect countermodel), §14 (lineage), §16-17
// (interaction invariants, hypergraph), §18-19 (locality, incremental
// validation), §22 (Claims 1-4), §23 (no hidden axioms).
//
// NO-HIDDEN-AXIOM CONTRACT:
//   * Every invariant is an EVALUATED equation (evalInv) over state.
//   * No predicate is assumed true; gate acceptance is decided by computing
//     all applicable obligations over the prospective state.
//   * The ONLY rule that ever updates <committed> is the accept rule of
//     `gate` (structural; verified by Claim 2 and by construction). The
//     initial CONTENT of <committed> is trusted configuration ($INITSTATE,
//     supplied by the trusted harness invocation) — Phase 1W removed the
//     `init` seeding command from the untrusted grammar, closing the 1V
//     between-transition initialization affordance (residual R9 of the 1V
//     register): committed-state mutation is now impossible outside the
//     gate accept rule at EVERY lifecycle position (before the first
//     begin, during a transition, and between transitions).
//   * Explicit abstractions are listed in the ASSUMPTIONS block above the
//     claims module and mirrored in the report.
//
// State representation: flat Map from composite keys stK(app, slot) to Int,
// mirroring EVM storage addressing (account, storage-slot) used in the
// KEVM binding layer.
//
// SRW3 PHASE 1U REMEDIATION (branch phase1u-model-hygiene; the 0D-era files
// remain in git history verbatim):
//   T1 (Workstream B): applicable() now PRESERVES the footprint across a
//     bareEdge — the 0D rule reset it to .Set, silently dropping every
//     obligation registered on edges decomposed after a bareEdge.
//   T2 (Workstream C): one-shot gate state <gateopen> — a valid begin opens
//     the gate interval; every gate path (accept/reject/reject-auth) closes
//     it; a gate with the interval closed fails closed ("gate-closed") and
//     cannot erase committed state, advance the head, or append a commit.
//     Repeated/nested begin is blocked ("blocked-begin-open").
//   T3 (Workstream E): setPolicy/useRegistry were setup-phase commands,
//     blocked only within an open gate interval (assumption A5) — the 1U
//     disposition left the pre-begin / between-transitions mutation windows
//     open (the 1V finding of record).
//
// SRW3 PHASE 1V REMEDIATION (branch phase1v-configuration-ownership;
// Configuration Ownership and Reproducible Verification):
//   T3-v2 (Workstream A): policy, registry and authorities are TRUSTED
//     MODEL CONFIGURATION — they enter the configuration ONLY through the
//     initial configuration ($POLICY/$REGISTRY/$AUTHORITIES supplied by the
//     trusted harness invocation). setPolicy/useRegistry are REMOVED from
//     the transition-program grammar: the untrusted program cannot name
//     them, and NO rule in the semantics writes those cells. The blocked-*-
//     mutable rules of 1U are retired together with the syntax they
//     guarded. The remaining transition commands cannot change policy,
//     registry, or authorities before the first transition, during one, or
//     between transitions.
//   F2/F3 (1V hardening, discovered during the configuration audit):
//     as (actor identity declaration) is PRE-BEGIN-ONLY — mid-transition
//     invocations are BLOCKED terminal (blocked-actor-switch-open); between
//     transitions the actor re-declaration remains available and is checked
//     by the gate at commit time (membership evidence), so it is legitimate
//     mutable protocol state, not configuration.
//
// SRW3 PHASE 1W REMEDIATION (branch phase1w-boundary-audit; the 1V files
// remain in git history verbatim):
//   R9 closure (Workstream A): the between-transition initialization
//     affordance is closed STRUCTURALLY, mirroring the 1V T3-v2 pattern —
//     `init` is REMOVED from the untrusted transition-program grammar
//     (both rules retired with their syntax: the seeding rule and the
//     blocked-init-open guard). The initial committed state enters ONLY
//     through the trusted harness invocation as the configuration variable
//     $INITSTATE (a Map StKey -> Int). NO rule in the semantics writes
//     <committed> except the gate accept rule; committed-state mutation by
//     the untrusted program is UNREPRESENTABLE at every lifecycle position.
//     Scenario seeding moves into the trusted harness command line
//     (-cINITSTATE="stK(appA,0) |-> 7 ..."), exactly like $POLICY/$REGISTRY/
//     $AUTHORITIES in 1V. The residual harness-honesty dependency (the
//     caller supplies an honest initial state) is the SAME trust boundary
//     of record as every other configuration item (R10) and is recorded,
//     not hidden.
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
  // Phase 1V: setPolicy/useRegistry are GONE — policy/registry/authorities
  // are trusted model configuration (initial configuration only; see A5).
  // The untrusted program cannot name them and no rule writes those cells.
  syntax RegistryKind ::= "complete" | "negative" | "pairwiseOnly"
                        | "chainComplete" | "chainNegative"
  // Phase 1W: init is GONE from the transition-program grammar (R9 closure;
  // the initial committed state is trusted configuration $INITSTATE — see
  // the 1W remediation block above). The untrusted program cannot seed or
  // mutate committed state in any lifecycle position.
  syntax Srw3Cmd ::= "as" "(" actor:AppId ")"
                   | "begin"
                   | "w" "(" app:AppId "," slot:Int "," v:Int ")"     // declared write
                   | "wH" "(" app:AppId "," slot:Int "," v:Int ")"    // HIDDEN write (omitted from abstraction)
                   | "rd" "(" app:AppId ")"                     // declared read dependency
                   | "rdH" "(" app:AppId ")"                    // HIDDEN read (undeclared dependency)
                   | "wfCheck"
                   | "gate"
  syntax Srw3Pgm ::= List{Srw3Cmd,","}

  // Trusted registry selection (1V): the KIND is a configuration variable;
  // the production is declared HERE (visible to the initial configuration)
  // while the defining equations live in SRW3-CLOSURE.
  syntax Set ::= "pickRegistry" "(" kind:RegistryKind ")" [function, total]
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
                  <committed> $INITSTATE:Map </committed>
                             // 1W: PROTOCOL-OWNED initial committed state —
                             // the trusted harness supplies the seed map; NO
                             // rule writes this cell except the gate accept
                             // rule (the commitment boundary). Map StKey -> Int.
                  <prospective> .Map </prospective>  // Map StKey -> Int
                  <footprint-t> .Set </footprint-t>
                  <footprint-d> .Set </footprint-d>
                  <registry> pickRegistry($REGISTRY:RegistryKind) </registry>
                             // 1V: PROTOCOL-OWNED configuration — the trusted
                             // harness selects the registry KIND; the model
                             // expands it. No rule writes this cell.
                  <policy> $POLICY:Policy </policy>
                             // 1V: PROTOCOL-OWNED configuration (enforce|trust).
                  <gateopen> false </gateopen>       // T2: one-shot gate interval state
                  <authorities> $AUTHORITIES:Set </authorities>
                             // 1V: PROTOCOL-OWNED configuration — the authority
                             // set is supplied by the trusted harness.
                  <polver> 1 </polver>
                  <actor> noOne </actor>
                  <lineage> .Map </lineage>          // Map tid -> LineageRec
                  <lineageNext> 0 </lineageNext>
                  <head> rootC </head>               // chain-head commitment
                  <result> "" </result>
                </srw3>

  // ---- command semantics -----------------------------------------------------
  // Decompose the program list into a sequential ~> chain so individual
  // command rules can fire on the head.
  rule <k> (C:Srw3Cmd , REST:Srw3Pgm) => C ~> REST ... </k>

  // Phase 1W: BOTH 1V init rules are RETIRED with their syntax (the seeding
  // rule and the blocked-init-open guard). There is NO writer of <committed>
  // in this module anymore — the gate accept rule (SRW3-GATE) is the only
  // committed-state writer in the entire semantics. See the 1W remediation
  // block above and A8 below.

  // 1V F3: the actor identity is declared BEFORE the transition opens.
  // A mid-transition `as` would let the program swap to an authorized
  // identity at gate time (forged authorization evidence) — with 1V's
  // configurable authority sets this would bypass reject-auth entirely.
  rule <k> as(P:AppId) => .K ... </k>
       <actor> _A:AppId => P </actor>
       <gateopen> false </gateopen>

  // 1V F3: blocked mid-transition (terminal, fail-closed).
  rule <k> as(_:AppId) ~> _REST:K => .K </k>
       <gateopen> true </gateopen>
       <result> _R:String => "blocked-actor-switch-open" </result>
       <prospective> _P:Map => .Map </prospective>

  // Prospective execution begins as a shadow copy of the committed state:
  // sigma -> sigma_hat over committed sigma (handoff §3, §8).
  // T2: a valid begin OPENS the gate interval (one-shot gate state).
  rule <k> begin => .K ... </k>
       <committed> C:Map </committed>
       <prospective> _P:Map => C </prospective>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> _FD:Set => .Set </footprint-d>
       <gateopen> false => true </gateopen>

  // T2: repeated/nested begin while an interval is open is BLOCKED
  // (fail-closed; cannot bypass or restart the guard mid-transition).
  rule <k> begin ~> _REST:K => .K </k>
       <gateopen> true </gateopen>
       <result> _R:String => "blocked-begin-open" </result>
       <prospective> _P:Map => .Map </prospective>

  rule <k> w(I:AppId, S:Int, V:Int) => .K ... </k>
       <prospective> P:Map => P[stK(I, S) <- V] </prospective>
       <footprint-t> FT:Set => FT |Set SetItem(I) </footprint-t>
       <footprint-d> FD:Set => FD |Set SetItem(I) </footprint-d>

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

  // Phase 1V: setPolicy is REMOVED (the command and both of its 1U rules —
  // the setup-phase rule and the blocked-policy-mutable rule). <policy> has
  // NO writer in the semantics; it is read by wfCheck only. See A5.
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
  // T1 (Phase 1U fix): the 0D rule reset the footprint to .Set here, which
  // silently dropped every obligation on edges decomposed AFTER a bareEdge
  // (the exploit: a violating edge placed after a bareEdge is never checked).
  // The corrected recursion PRESERVES the footprint: bareEdge means "this
  // dependency carries no contract → no obligation FROM THIS EDGE", not
  // "stop checking obligations".
  rule applicable(SetItem(bareEdge(_Xs:Set)) Es:Set, F:Set)
    => applicable(Es, F)      // dependency known, no contract → no obligation

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
  // (the pickRegistry PRODUCTION is declared in SRW3-SYNTAX — 1V: it is
  // used by the initial configuration; the equations stay here)
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

  // Phase 1V: useRegistry is REMOVED (the command and both of its 1U rules).
  // <registry> and <authorities> have NO writer in the semantics; they are
  // read by the gate rules only. The registry is configured by the trusted
  // harness via the initial configuration (pickRegistry($REGISTRY)); the
  // authority set is likewise trusted configuration ($AUTHORITIES). See A5.
  // NOTE (1V): the 1U useRegistry rule was also the ONLY writer of
  // <authorities> (it reset the set to ALL apps on every registry change);
  // authorities are now independently configured and never mutated.

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
       <gateopen> _GO:Bool => false </gateopen>
    requires notBool subset(FT, FD)
  // T2: the blocked transition terminates the interval (every path out of a
  // transition closes the gate interval — no stale-open state survives).

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
       <gateopen> true => false </gateopen>
    requires member(Ac, As) andBool allHold(applicable(R, FD), P)

  // REJECT (invariant violated): the prospective state is discarded and the
  // committed state is left untouched — the commitment boundary (handoff §4).
  rule <k> gate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <registry> R:Set </registry>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> FD:Set => .Set </footprint-d>
       <result> _R:String => "reject" </result>
       <gateopen> true => false </gateopen>
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
       <gateopen> true => false </gateopen>
    requires notBool member(Ac, As) andBool allHold(applicable(R, FD), P)

  // T2: GATE INTERVAL CLOSED — fail-closed gate.  A gate command without a
  // valid preceding begin (or a SECOND gate in the same interval) cannot
  // touch <committed>, <lineage>, <lineageNext>, or <head>, and cannot
  // append a successful commitment record.  This kills the re-entrancy
  // erasure: after any gate path the interval is closed, so a second gate
  // reaches only this rule.
  rule <k> gate => .K ... </k>
       <gateopen> false </gateopen>
       <result> _R:String => "gate-closed" </result>
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
//   A5. (Phase 1V, T3-v2) Policy, registry, and authorities are PROTOCOL-
//       OWNED trusted model configuration: they enter ONLY through the
//       initial configuration ($POLICY / $REGISTRY / $AUTHORITIES supplied
//       by the trusted harness invocation) and NO rule in the semantics
//       writes those cells (grep-audited; the 1V ownership table).  The
//       untrusted transition-program grammar cannot name them (setPolicy/
//       useRegistry are removed), so the transition cannot select or change
//       policy or registry before the first transition, during one, or
//       between transitions — a configuration-mutation attempt is
//       UNREPRESENTABLE (parse-time rejection).  The gate-step claims below
//       pin <gateopen> true </gateopen>: they describe the gate step of a
//       transition whose interval was opened by a valid begin (the 1U
//       gate-state discipline, T2).  A wrong or adversarially authored
//       policy/registry/authority configuration SUPPLIED BY THE HARNESS is
//       outside the evaluated model (the harness is the trust boundary; the
//       residual is registered, not hidden).
//   A8. (Phase 1W, R9 closure) The initial committed state $INITSTATE is
//       PROTOCOL-OWNED trusted configuration supplied by the trusted harness
//       invocation. The untrusted transition program cannot seed or mutate
//       <committed> (init is removed from the grammar; NO rule writes the
//       cell except the gate accept rule — grep-audited). A hostile harness
//       supplying a dishonest initial state (e.g. a committed state that
//       already violates an invariant) is outside the evaluated model: the
//       gate still evaluates every applicable obligation on every ACCEPTED
//       transition, but the harness-seeded BASELINE itself is trusted input
//       (the same TCB of record as $POLICY/$REGISTRY/$AUTHORITIES — R10).
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
    <gateopen> true => false </gateopen>   // the gate step closes the interval
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
    <gateopen> true => false </gateopen>   // the gate step closes the interval
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
    <gateopen> true => false </gateopen>   // the gate step closes the interval
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
    <gateopen> true => false </gateopen>   // the gate step closes the interval
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
    <gateopen> true => false </gateopen>   // the gate step closes the interval
    <authorities> As:Set </authorities>
    <actor> appB </actor>
    <result> _R:String => "reject" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
             andBool ( V >Int 10 orBool X +Int V >Int 10 )
             andBool member(appB, As)
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
endmodule
