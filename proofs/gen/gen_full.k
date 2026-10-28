// =============================================================================
// SRW3 Phase 1B — Generalized commitment-gated semantics (k/srw3gen.k)
//
// Extends the Phase-0/1A minimal model along the two open countermodel axes
// while keeping the commitment-gate architecture UNCHANGED:
//
//   CM2 resource aliasing   : physical storage identity (StKey) != logical
//                             resource identity (ResourceId). The model input
//                             <resmap> : StKey -> ResourceId is the alias /
//                             resolution table; logicalOf (AliasClosure) maps a
//                             physical footprint to its logical resources.
//   CM3 aggregate authority : bounded delegation. <cap>/<parent> carry the
//                             granted capacity tree; <usage-c>/<usage-p> carry
//                             consumed capacity through the SAME commitment
//                             boundary as storage; the aggregate constraint is
//                             an EVALUATED obligation (IAGG), not a gate branch.
//   Generalized transitions : a transition may contain a FINITE sequence of
//                             writes/reads/consumptions; footprints are
//                             physical-key granular; Foot(E) = union of the
//                             per-effect footprints.
//
// NO-HIDDEN-AXIOM CONTRACT (inherited from Phase 0-D, unchanged):
//   * Every invariant is an EVALUATED equation (evalInvG) over state.
//   * The gate accepts by COMPUTING all applicable obligations over the
//     prospective bundle; rejection reasons are uniform (no special branches).
//   * The ONLY rule that updates <committed>/<usage-c> is the gate accept rule.
//   * Assumptions are listed in the ASSUMPTIONS block and classified in the
//     Phase-1B report (five-level evidence scheme).
//
// Gate structure (mandate Part VI-H):
//     prospective bundle -> applicable-obligation evaluation -> commit / reject
//   with applicable obligations = local + interaction + resource + authority.
//
// SRW3 PHASE 1V REMEDIATION (branch phase1v-configuration-ownership;
// Configuration Ownership and Reproducible Verification):
//   T3-v2 (Workstream A): policy, registry, authorities, the alias table
//     <resmap> and the capability configuration <cap>/<parent> are TRUSTED
//     MODEL CONFIGURATION — they enter ONLY through the initial
//     configuration ($POLICY/$REGISTRYG/$AUTHORITIES/$RESMAP/$CAP/$PARENT
//     supplied by the trusted harness invocation). setPolicy/useRegistryG/
//     useResMap/grant are REMOVED from the transition-program grammar: the
//     untrusted program cannot name them, and NO rule in the semantics
//     writes those cells. The 1U model left useResMap and grant with NO
//     guard at all (reachable mid-transition AND between transitions — the
//     1V audit findings F1a/F1b, beyond the examiner's setPolicy/useRegistry
//     lead); the 1V disposition removes the commands entirely.
//   F2/F3 (1V hardening): as (actor identity declaration) is PRE-BEGIN-ONLY
//     — mid-transition invocations are BLOCKED terminal
//     (blocked-actor-switch-open); between transitions the actor
//     re-declaration remains available and is checked by the gate at commit
//     time (membership evidence), so it is legitimate mutable protocol
//     state, not configuration.
//
// SRW3 PHASE 1W REMEDIATION (branch phase1w-boundary-audit; the 1V files
// remain in git history verbatim):
//   R9 closure (Workstream A, mirrored from the abstract model): the
//     between-transition initialization affordance is closed STRUCTURALLY —
//     `init` is REMOVED from the untrusted transition-program grammar (both
//     rules retired with their syntax: the seeding rule and the
//     blocked-init-open guard). The initial committed state enters ONLY
//     through the trusted harness invocation as the configuration variable
//     $INITSTATE (a Map StKey -> Int). NO rule in the semantics writes
//     <committed> except the gate accept rule; committed-state mutation by
//     the untrusted program is UNREPRESENTABLE at every lifecycle position.
//     The residual harness-honesty dependency is the SAME trust boundary of
//     record as every other configuration item (R10) and is recorded in A9.
// =============================================================================

module SRW3G-SYNTAX
  imports DOMAINS

  // Application / actor identifiers. appB is the authority root of the
  // bounded-delegation topology; appC/appD are its delegates.
  syntax AppId ::= "noOne" | "appA" | "appB" | "appC" | "appD"

  // Physical storage key: (application, slot) — the abstract analogue of
  // (account address, storage slot). PHYSICAL identity only.
  syntax StKey ::= "stK" "(" app:AppId "," slot:Int ")"

  // Logical resource identity (CM2). A resource MAY be manifested at several
  // physical keys; resolution is total via <resmap> with default noRes.
  syntax ResourceId ::= "noRes" | "resP" | "resQ"

  // Obligation identifiers.
  //  App-scope (local/interaction, inherited architecture):
  //   IA7 : val(stK(appA,7)) <= 10
  //   IB3 : val(stK(appB,3)) <= 10
  //   IC0 : val(stK(appC,0)) <= 10
  //   ID0 : val(stK(appD,0)) <= 10
  //  Resource-scope (CM2):
  //   IRP : val(K1) + val(K2) <= 10        (resP held at two aliased keys)
  //   IRQ : val(K3) == val(K4)             (resQ mirror consistency)
  //  Authority-scope (CM3):
  //   ICAPC: usage(appC) <= cap(appC)      (individual delegation bound)
  //   ICAPD: usage(appD) <= cap(appD)
  //   IAGG : usage(appC)+usage(appD) <= cap(appB)   (aggregate/root budget)
  syntax InvId ::= "IA7" | "IB3" | "IC0" | "ID0"
                 | "IRP" | "IRQ"
                 | "ICAPC" | "ICAPD" | "IAGG"

  // Commitments + lineage (unchanged from Phase 0-D).
  syntax Commitment ::= "rootC" | "commit" "(" Int ")"
  syntax Auth ::= "auth" "(" AppId ")" | "noAuth"
  syntax LineageRec ::= "lin" "(" parent:Commitment "," tid:Int "," auth:Auth "," polver:Int "," child:Commitment ")"

  // Security hypergraph edges. Scope kinds mirror the obligation classes:
  //   edge(J, apps)   : app-scope obligation  (interaction layer, Phase 0-D)
  //   edgeR(J, res)   : resource-scope obligation (CM2 layer)
  //   edgeA(J, actors): authority-scope obligation (CM3 layer)
  //   bareEdge(apps)  : known dependency, no contract (CM6 gap, preserved)
  syntax Edge ::= "edge" "(" inv:InvId "," apps:Set ")"
                | "edgeR" "(" inv:InvId "," res:Set ")"
                | "edgeA" "(" inv:InvId "," actors:Set ")"
                | "bareEdge" "(" apps:Set ")"

  // Effect-abstraction policy (unchanged semantics; CM7 preserved).
  syntax Policy ::= "enforce" | "trust"

  // Alias-table presets (trusted model configuration; see ASSUMPTIONS A5).
  syntax ResMapKind ::= "rmNone" | "rmPQ"

  // Total expansion of the trusted resmap selection (1V: the harness passes
  // the KIND; the model expands it — no rule writes <resmap>).
  syntax Map ::= "pickResMap" "(" kind:ResMapKind ")" [function, total]

  // Trusted registry selection (1V): the KIND is a configuration variable;
  // the production is declared HERE (visible to the initial configuration)
  // while the defining equations live in SRW3G-CLOSURE.
  syntax Set ::= "pickRegistryG" "(" kind:RegistryKindG ")" [function, total]

  // Generalized registries (see SRW3G-CLOSURE for completeness predicates).
  syntax RegistryKindG ::= "aliasNaive" | "aliasOnly" | "authNaive" | "authOnly"
                          | "fullNaive" | "full"

  // Transition command language (generalized finite effect sequences):
  // a transition = begin; (w | wH | rd | rdH | consume)*; wfCheck; gate.
  // Phase 1V: setPolicy/useRegistryG/useResMap/grant are GONE — policy,
  // registry, authorities, the alias table and the capability configuration
  // are trusted model configuration (initial configuration only; see A7).
  // Phase 1W: init is GONE from the transition-program grammar (R9 closure;
  // the initial committed state is trusted configuration $INITSTATE — see
  // the 1W remediation block above).
  syntax Srw3CmdG ::= "as" "(" actor:AppId ")"
                    | "begin"
                    | "w" "(" app:AppId "," slot:Int "," v:Int ")"     // declared write
                    | "wH" "(" app:AppId "," slot:Int "," v:Int ")"    // HIDDEN write
                    | "rd" "(" app:AppId ")"                           // declared read dependency
                    | "rdH" "(" app:AppId ")"                          // HIDDEN read
                    | "consume" "(" actor:AppId "," amount:Int ")"     // authority usage (CM3)
                    | "wfCheck"
                    | "gate"
  syntax Srw3PgmG ::= List{Srw3CmdG,","}

  syntax Ghost4 ::= "GG" "(" x1:Int "," x2:Int "," z3:Int "," z4:Int "," u1:Int "," u2:Int ")"   //GHOST:
  syntax Ghost4 ::= "GP" "(" fs:GEffs "," base:Ghost4 ")"   //GHOST:
  syntax GEffs ::= ".GEffs" | GEff GEffs   //GHOST:
  syntax GEff ::= "gEffW" "(" app:AppId "," slot:Int "," v:Int ")"   //GHOST:
  syntax GEff ::= "gEffC" "(" actor:AppId "," n:Int ")"   //GHOST:
  syntax GateRun4 ::= "chkG4" | "chkM4" | "tG" "(" Int "," Int "," Int ")" ":" GateRun4   //GHOST:
  syntax Bool ::= "ghostSafe4" "(" Ghost4 "," Map ")" [function, total]   //GHOST:
  syntax Bool ::= "ghostMatches4" "(" Ghost4 "," Map "," Map ")" [function, total]   //GHOST:
  syntax Ghost4 ::= "ghostApply4" "(" Ghost4 "," Map ")" [function, total]   //GHOST:
  syntax Ghost4 ::= "ghostUndo4" "(" Ghost4 ")" [function, total]   //GHOST:
  syntax Ghost4 ::= "gW4" "(" Ghost4 "," AppId "," Int "," Int ")" [function, total]   //GHOST:
  syntax Ghost4 ::= "gC4" "(" Ghost4 "," AppId "," Int ")" [function, total]   //GHOST:
  syntax Ghost4 ::= "foldEffs" "(" GEffs "," Ghost4 ")" [function, total]   //GHOST:
  syntax Ghost4 ::= "certW7" "(" Ghost4 "," Int ")" [function, total]   //GHOST:
  syntax Map ::= "rmPQ" "(" ")" [function, total]   //GHOST:   (run v2 fix: concrete model inputs)
  syntax Map ::= "capG" "(" ")" [function, total]   //GHOST:   (run v2 fix: concrete model inputs)
  syntax Map ::= "parentG" "(" ")" [function, total]   //GHOST:   (run v2 fix: concrete model inputs)
  syntax Ghost4 ::= "certW3" "(" Ghost4 "," Int ")" [function, total]   //GHOST:
  syntax Ghost4 ::= "certUC" "(" Ghost4 "," Int ")" [function, total]   //GHOST:
  syntax Set ::= "genUniv4" "(" ")" [function, total]   //GHOST:
  syntax Set ::= "gAUTH4" "(" ")" [function, total]   //GHOST:
  syntax Map ::= "store4" "(" Int "," Int "," Int "," Int ")" [function, total]   //GHOST:
  syntax Map ::= "usage4" "(" Int "," Int ")" [function, total]   //GHOST:
  syntax Bool ::= "safeGenMin" "(" Map "," Map "," Map ")" [function, total]   //GHOST:
endmodule

// =============================================================================
module SRW3G-STATE
  imports SRW3G-SYNTAX

  // The commitment boundary now spans storage AND consumed authority capacity.
  // <footprint-t>/<footprint-d> hold PHYSICAL footprint items: StKeys (from
  // writes) and AppIds (from reads/consumptions) — one mixed set per side.
  configuration <srw3g>
                  <k> $PGM:Srw3PgmG </k>
                  <committed> $INITSTATE:Map </committed>
                             // 1W: PROTOCOL-OWNED initial committed state —
                             // the trusted harness supplies the seed map; NO
                             // rule writes this cell except the gate accept
                             // rule (the commitment boundary). Map StKey -> Int.
                  <prospective> .Map </prospective>  // Map StKey -> Int
                  <usage-c> .Map </usage-c>          // Map AppId -> Int (committed usage)
                  <usage-p> .Map </usage-p>          // Map AppId -> Int (prospective usage)
                  <cap> $CAP:Map </cap>              // 1V: PROTOCOL-OWNED configuration
                  <parent> $PARENT:Map </parent>     // 1V: PROTOCOL-OWNED configuration
                  <resmap> pickResMap($RESMAP:ResMapKind) </resmap>
                             // 1V: PROTOCOL-OWNED configuration — the alias
                             // table KIND is selected by the trusted harness.
                  <footprint-t> .Set </footprint-t>
                  <footprint-d> .Set </footprint-d>
                  <registry> pickRegistryG($REGISTRYG:RegistryKindG) </registry>
                             // 1V: PROTOCOL-OWNED configuration.
                  <policy> $POLICY:Policy </policy>
                             // 1V: PROTOCOL-OWNED configuration (enforce|trust).
                  <gateopen> false </gateopen>       // T2: one-shot gate interval state (1U)
                  <authorities> $AUTHORITIES:Set </authorities>
                             // 1V: PROTOCOL-OWNED configuration.
                  <polver> 1 </polver>
                  <actor> noOne </actor>
                  <lineage> .Map </lineage>          // Map tid -> LineageRec
                  <lineageNext> 0 </lineageNext>
                  <head> rootC </head>
                  <result> "" </result>
                  <ghost> GG(0, 0, 0, 0, 0, 0) </ghost>   //GHOST:
                </srw3g>

  rule <k> (C:Srw3CmdG , REST:Srw3PgmG) => C ~> REST ... </k>

  // Phase 1W: BOTH 1V init rules are RETIRED with their syntax (the seeding
  // rule and the blocked-init-open guard). There is NO writer of <committed>
  // in this module anymore — the gate accept rule (SRW3G-GATE) is the only
  // committed-state writer in the entire semantics. See A9 below.

  // 1V F3: actor identity declared BEFORE the transition opens (see srw3.k).
  rule <k> as(P:AppId) => .K ... </k>
       <actor> _A:AppId => P </actor>
       <gateopen> false </gateopen>

  // 1V F3: blocked mid-transition (terminal, fail-closed).
  rule <k> as(_:AppId) ~> _REST:K => .K </k>
       <gateopen> true </gateopen>
       <result> _R:String => "blocked-actor-switch-open" </result>
       <prospective> _P:Map => .Map </prospective>
       <usage-p> _UP:Map => .Map </usage-p>

  // Prospective execution begins as a shadow copy over BOTH state components.
  // T2: a valid begin OPENS the gate interval (one-shot gate state).
  rule <k> begin => .K ... </k>
       <committed> C:Map </committed>
       <prospective> _P:Map => C </prospective>
       <usage-c> UC:Map </usage-c>
       <usage-p> _UP:Map => UC </usage-p>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> _FD:Set => .Set </footprint-d>
       <gateopen> false => true </gateopen>

  // T2: repeated/nested begin while an interval is open is BLOCKED
  // (fail-closed; cannot bypass or restart the guard mid-transition).
  rule <k> begin ~> _REST:K => .K </k>
       <gateopen> true </gateopen>
       <result> _R:String => "blocked-begin-open" </result>
       <prospective> _P:Map => .Map </prospective>
       <usage-p> _UP2:Map => .Map </usage-p>

  // Declared write: physical-key granular footprint (generalization of the
  // Phase-0 app-granular footprint). Foot(E) = union of per-effect items.
  rule <k> w(I:AppId, S:Int, V:Int) => .K ... </k>
       <prospective> P:Map => P[stK(I, S) <- V] </prospective>
       <footprint-t> FT:Set => FT |Set SetItem(stK(I, S)) </footprint-t>
       <footprint-d> FD:Set => FD |Set SetItem(stK(I, S)) </footprint-d>
       <ghost> Gh:Ghost4 => gW4(Gh, I, S, V) </ghost>   //GHOST:

  // Hidden write: real effect omitted from the declared abstraction (CM7).
  rule <k> wH(I:AppId, S:Int, V:Int) => .K ... </k>
       <prospective> P:Map => P[stK(I, S) <- V] </prospective>
       <footprint-t> FT:Set => FT |Set SetItem(stK(I, S)) </footprint-t>

  rule <k> rd(I:AppId) => .K ... </k>
       <footprint-t> FT:Set => FT |Set SetItem(I) </footprint-t>
       <footprint-d> FD:Set => FD |Set SetItem(I) </footprint-d>

  rule <k> rdH(I:AppId) => .K ... </k>
       <footprint-t> FT:Set => FT |Set SetItem(I) </footprint-t>

  syntax Map ::= "bumpUsage" "(" m:Map "," a:AppId "," n:Int ")" [function, total]
  rule bumpUsage(A:AppId |-> V:Int REST:Map, A2:AppId, N:Int)
    => (A |-> (V +Int N) REST) requires A ==K A2
  rule bumpUsage(A:AppId |-> V:Int REST:Map, A2:AppId, N:Int)
    => (A |-> V bumpUsage(REST, A2, N)) requires A =/=K A2
  rule bumpUsage(.Map, A:AppId, N:Int) => (A |-> N)

  // Authority consumption (CM3): an evaluated effect on the prospective usage
  // bundle, declared in the SAME footprint discipline as writes.
  rule <k> consume(A:AppId, N:Int) => .K ... </k>
       <usage-p> UP:Map => bumpUsage(UP, A, N) </usage-p>
       <footprint-t> FT:Set => FT |Set SetItem(A) </footprint-t>
       <footprint-d> FD:Set => FD |Set SetItem(A) </footprint-d>
       <ghost> Gh:Ghost4 => gC4(Gh, A, N) </ghost>   //GHOST:

  // Phase 1V: the setup block is REMOVED — setPolicy (both rules),
  // useResMap (both preset rules), and grant are gone. <policy>, <resmap>,
  // <cap>, <parent> have NO writer in the semantics; they are read by
  // wfCheck / the gate / evalInvG only. They are configured by the trusted
  // harness via the initial configuration (pickResMap($RESMAP), $CAP,
  // $PARENT). See A7.
endmodule

// =============================================================================
module SRW3G-INVAR
  imports SRW3G-STATE

  // ---- typed reads (total; .Map defaults mirror EVM zero semantics) --------
  syntax Int ::= "lookupInt" "(" m:Map "," k:StKey ")" [function, total]
  rule lookupInt(stK(K:AppId, S:Int) |-> V:Int REST:Map, stK(K, S)) => V
  rule lookupInt(stK(K:AppId, S:Int) |-> V:Int REST:Map, KEY:StKey)
    => lookupInt(REST, KEY)
    requires KEY =/=K stK(K, S)
  rule lookupInt(.Map, _K:StKey) => 0

  syntax Int ::= "lookupU" "(" m:Map "," a:AppId ")" [function, total]
  rule lookupU(A:AppId |-> V:Int REST:Map, A2:AppId) => V requires A ==K A2
  rule lookupU(A:AppId |-> _V:Int REST:Map, A2:AppId)
    => lookupU(REST, A2) requires A =/=K A2
  rule lookupU(.Map, _A:AppId) => 0

  syntax Int ::= "lookupCap" "(" m:Map "," a:AppId ")" [function, total]
  rule lookupCap(A:AppId |-> V:Int REST:Map, A2:AppId) => V requires A ==K A2
  rule lookupCap(A:AppId |-> _V:Int REST:Map, A2:AppId)
    => lookupCap(REST, A2) requires A =/=K A2
  rule lookupCap(.Map, _A:AppId) => 0   // unset capacity = zero budget (safe default)

  // ---- alias resolution (CM2) ----------------------------------------------
  // Resolves(K) = resmap[K], default noRes. noRes keys carry no logical
  // resource identity: they are plain physical locations.
  syntax ResourceId ::= "resolve" "(" m:Map "," k:StKey ")" [function, total]
  rule resolve(stK(A:AppId, S:Int) |-> R:ResourceId REST:Map, K2:StKey)
    => R requires stK(A, S) ==K K2
  rule resolve(stK(A:AppId, S:Int) |-> _R:ResourceId REST:Map, K2:StKey)
    => resolve(REST, K2) requires stK(A, S) =/=K K2
  rule resolve(.Map, _K:StKey) => noRes

  // ---- obligation semantics: real evaluation, no axioms --------------------
  // evalInvG(J, Store, Usage, Cap): the generalized obligation universe.
  // Bounds for the concrete delegation topology are evaluated from <cap>
  // (not hard-coded); the topology itself (children of appB) is the
  // documented concrete instance of the minimal bounded-delegation model.
  syntax Bool ::= "evalInvG" "(" inv:InvId "," st:Map "," us:Map "," cp:Map ")" [function, total]

  rule evalInvG(IA7,   M:Map, _U:Map, _C:Map) => lookupInt(M, stK(appA, 7)) <=Int 10
  rule evalInvG(IB3,   M:Map, _U:Map, _C:Map) => lookupInt(M, stK(appB, 3)) <=Int 10
  rule evalInvG(IC0,   M:Map, _U:Map, _C:Map) => lookupInt(M, stK(appC, 0)) <=Int 10
  rule evalInvG(ID0,   M:Map, _U:Map, _C:Map) => lookupInt(M, stK(appD, 0)) <=Int 10

  // CM2 resource obligations: stated over the ALIASED KEY PAIR of the resource.
  rule evalInvG(IRP,   M:Map, _U:Map, _C:Map)
    => lookupInt(M, stK(appA, 7)) +Int lookupInt(M, stK(appB, 3)) <=Int 10
  rule evalInvG(IRQ,   M:Map, _U:Map, _C:Map)
    => lookupInt(M, stK(appC, 0)) ==Int lookupInt(M, stK(appD, 0))

  // CM3 authority obligations: individual delegation bounds + aggregate budget.
  rule evalInvG(ICAPC, _M:Map, U:Map, C:Map) => lookupU(U, appC) <=Int lookupCap(C, appC)
  rule evalInvG(ICAPD, _M:Map, U:Map, C:Map) => lookupU(U, appD) <=Int lookupCap(C, appD)
  rule evalInvG(IAGG,  _M:Map, U:Map, C:Map)
    => lookupU(U, appC) +Int lookupU(U, appD) <=Int lookupCap(C, appB)

  // ---- auditable dependency oracles ----------------------------------------
  // App-scope read-set derivation (Phase-0 discipline, extended universe).
  syntax Set ::= "trueDeps" "(" inv:InvId ")" [function, total]
  rule trueDeps(IA7) => SetItem(appA)
  rule trueDeps(IB3) => SetItem(appB)
  rule trueDeps(IC0) => SetItem(appC)
  rule trueDeps(ID0) => SetItem(appD)
  // The NAIVE app-anchored derivation of the resource obligations: IRP is
  // anchored at the PRIMARY manifestation only (its alias K2 is discoverable
  // only through the alias relation — this is exactly the CM2 blind spot).
  rule trueDeps(IRP) => SetItem(appA)
  rule trueDeps(IRQ) => SetItem(appC)

  // Resource-scope dependency derivation (CM2-aware).
  syntax Set ::= "trueDepsR" "(" inv:InvId ")" [function, total]
  rule trueDepsR(IRP) => SetItem(resP)
  rule trueDepsR(IRQ) => SetItem(resQ)

  // Authority-scope dependency derivation (CM3-aware).
  syntax Set ::= "trueDepsA" "(" inv:InvId ")" [function, total]
  rule trueDepsA(ICAPC) => SetItem(appC)
  rule trueDepsA(ICAPD) => SetItem(appD)
  rule trueDepsA(IAGG)  => SetItem(appC) |Set SetItem(appD)

  // Obligation universes (universe-parameterized closure, Phase-0 discipline).
  syntax Set ::= "genAppInvs" "(" ")" [function, total]
  rule genAppInvs() => SetItem(IA7) |Set SetItem(IB3) |Set SetItem(IC0) |Set SetItem(ID0)
  syntax Set ::= "genResInvs" "(" ")" [function, total]
  rule genResInvs() => SetItem(IRP) |Set SetItem(IRQ)
  syntax Set ::= "genAuthInvs" "(" ")" [function, total]
  rule genAuthInvs() => SetItem(ICAPC) |Set SetItem(ICAPD) |Set SetItem(IAGG)
endmodule

// =============================================================================
module SRW3G-CLOSURE
  imports SRW3G-INVAR

  // ---- set helpers (explicit recursion; Phase-0 discipline) ----------------
  syntax Bool ::= "member" "(" KItem "," Set ")" [function, total]
  rule member(_I:KItem, .Set) => false
  rule member(I:KItem, SetItem(I2:KItem) S:Set) => I ==K I2 orBool member(I, S)

  syntax Bool ::= "subset" "(" Set "," Set ")" [function, total]
  rule subset(.Set, _Y:Set) => true
  rule subset(SetItem(I) Xs:Set, Y:Set) => member(I, Y) andBool subset(Xs, Y)

  syntax Bool ::= "nonemptyInter" "(" Set "," Set ")" [function, total]
  rule nonemptyInter(.Set, _Y:Set) => false
  rule nonemptyInter(SetItem(I) Xs:Set, Y:Set)
    => member(I, Y) orBool nonemptyInter(Xs, Y)

  // ---- footprint projections ----------------------------------------------
  // appsOf: the app projection of a footprint (AppId tokens + apps of StKeys).
  syntax Set ::= "appsOf" "(" Set ")" [function, total]
  rule appsOf(.Set) => .Set
  rule appsOf(SetItem(I:AppId) S:Set) => SetItem(I) |Set appsOf(S)
  rule appsOf(SetItem(stK(A:AppId, _S:Int)) S:Set) => SetItem(A) |Set appsOf(S)
  // NOTE: no [owise] catch-all — the haskell backend does not fire owise
  // fallback rules on mixed Sets (observed: authOf stuck, Phase-1B debugging).
  // The footprint universe is exactly {AppId, StKey}; these two rules are total. 

  // authOf: the authority projection — ONLY explicit AppId tokens
  // (consumptions / declared reads), not apps merely owning written keys.
  syntax Set ::= "authOf" "(" Set ")" [function, total]
  rule authOf(.Set) => .Set
  rule authOf(SetItem(I:AppId) S:Set) => SetItem(I) |Set authOf(S)
  rule authOf(SetItem(stK(_A:AppId, _S:Int)) S:Set) => authOf(S)
  // (explicit StKey rule instead of [owise]; see appsOf note above)

  // AliasClosure (mandate Part III-D):
  //   AliasClosure(E) = { r | exists k in E. Resolves(k) = r }
  // realized as logicalOf over the physical footprint; AppId tokens contribute
  // nothing; noRes keys contribute nothing (plain physical locations).
  syntax Set ::= "logicalOf" "(" Set "," Map ")" [function, total]
  rule logicalOf(.Set, _M:Map) => .Set
  rule logicalOf(SetItem(K:StKey) S:Set, M:Map)
    => SetItem(resolve(M, K)) |Set logicalOf(S, M)
    requires resolve(M, K) =/=K noRes
  rule logicalOf(SetItem(K:StKey) S:Set, M:Map)
    => logicalOf(S, M)
    requires resolve(M, K) ==K noRes
  rule logicalOf(SetItem(_I:AppId) S:Set, M:Map) => logicalOf(S, M)

  // ---- Affected(tau) generalized: per-scope applicability ------------------
  syntax Set ::= "applicableGen" "(" edges:Set "," foot:Set "," rm:Map ")" [function, total]
  rule applicableGen(.Set, _F:Set, _M:Map) => .Set

  // app-scope edge: fires on the app projection (Phase-0 rule, key-granular)
  rule applicableGen(SetItem(edge(J:InvId, Xs:Set)) Es:Set, F:Set, M:Map)
    => SetItem(J) |Set applicableGen(Es, F, M)
    requires nonemptyInter(appsOf(F), Xs)
  rule applicableGen(SetItem(edge(J:InvId, Xs:Set)) Es:Set, F:Set, M:Map)
    => applicableGen(Es, F, M)
    requires notBool nonemptyInter(appsOf(F), Xs)

  // resource-scope edge: fires on the ALIAS CLOSURE of the footprint (CM2)
  rule applicableGen(SetItem(edgeR(J:InvId, Rs:Set)) Es:Set, F:Set, M:Map)
    => SetItem(J) |Set applicableGen(Es, F, M)
    requires nonemptyInter(logicalOf(F, M), Rs)
  rule applicableGen(SetItem(edgeR(J:InvId, Rs:Set)) Es:Set, F:Set, M:Map)
    => applicableGen(Es, F, M)
    requires notBool nonemptyInter(logicalOf(F, M), Rs)

  // authority-scope edge: fires on the authority projection (CM3)
  rule applicableGen(SetItem(edgeA(J:InvId, Xs:Set)) Es:Set, F:Set, M:Map)
    => SetItem(J) |Set applicableGen(Es, F, M)
    requires nonemptyInter(authOf(F), Xs)
  rule applicableGen(SetItem(edgeA(J:InvId, Xs:Set)) Es:Set, F:Set, M:Map)
    => applicableGen(Es, F, M)
    requires notBool nonemptyInter(authOf(F), Xs)

  // dependency known, no contract -> no obligation (CM6 gap, preserved)
  rule applicableGen(SetItem(bareEdge(_Xs:Set)) Es:Set, F:Set, M:Map)
    => applicableGen(Es, F, M)

  // ---- obligation conjunction over the prospective bundle ------------------
  syntax Bool ::= "allHoldG" "(" obls:Set "," st:Map "," us:Map "," cp:Map ")" [function, total]
  rule allHoldG(.Set, _M:Map, _U:Map, _C:Map) => true
  rule allHoldG(SetItem(J:InvId) Js:Set, M:Map, U:Map, C:Map)
    => evalInvG(J, M, U, C) andBool allHoldG(Js, M, U, C)

  // ---- generalized security closure (mandate Part X-L) ---------------------
  // SecurityClosed = EffectComplete ∧ InteractionComplete ∧ ContractComplete
  //                ∧ LineageComplete ∧ GateComplete ∧ ResourceComplete
  //                ∧ AuthorityComplete
  // EffectComplete ≈ policy == enforce (wfCheck enforces the PHYSICAL
  //   completeness FT ⊆ FD; under it, AliasClosure(FT) ⊆ AliasClosure(FD)
  //   follows by monotonicity, so the resource-level applicability computed
  //   from the declared footprint coincides with the true one).
  // LineageComplete/GateComplete ≈ structural (single commit path that appends
  //   lineage; verified by the Phase-0 claims and their Phase-1B analogues).
  // ResourceComplete: every resource obligation is covered by an edgeR whose
  //   scope contains its resource dependencies (trueDepsR). The completeness
  //   OF THE ALIAS TABLE ITSELF is a model-input assumption (A5, classified
  //   ASSUMED), not an internal predicate — documented, not hidden.
  // AuthorityComplete: every authority obligation is covered by an edgeA whose
  //   scope contains its subject dependencies (trueDepsA).

  syntax Bool ::= "hasCover" "(" edges:Set "," inv:InvId ")" [function, total]
  rule hasCover(.Set, _J:InvId) => false
  rule hasCover(SetItem(edge(J:InvId, Xs:Set)) Es:Set, J2:InvId)
    => subset(trueDeps(J2), Xs) orBool hasCover(Es, J2)
    requires J ==K J2
  rule hasCover(SetItem(edge(J:InvId, _Xs:Set)) Es:Set, J2:InvId)
    => hasCover(Es, J2)
    requires J =/=K J2
  // constructor-split continuations (NO [owise]: it does not fire reliably)
  rule hasCover(SetItem(edgeR(_J:InvId, _Rs:Set)) Es:Set, J2:InvId) => hasCover(Es, J2)
  rule hasCover(SetItem(edgeA(_J3:InvId, _Xs2:Set)) Es:Set, J2:InvId) => hasCover(Es, J2)
  rule hasCover(SetItem(bareEdge(_Xs3:Set)) Es:Set, J2:InvId) => hasCover(Es, J2)

  syntax Bool ::= "hasCoverR" "(" edges:Set "," inv:InvId ")" [function, total]
  rule hasCoverR(.Set, _J:InvId) => false
  rule hasCoverR(SetItem(edgeR(J:InvId, Rs:Set)) Es:Set, J2:InvId)
    => subset(trueDepsR(J2), Rs) orBool hasCoverR(Es, J2)
    requires J ==K J2
  rule hasCoverR(SetItem(edgeR(J:InvId, _Rs:Set)) Es:Set, J2:InvId)
    => hasCoverR(Es, J2)
    requires J =/=K J2
  rule hasCoverR(SetItem(edge(_J:InvId, _Xs:Set)) Es:Set, J2:InvId) => hasCoverR(Es, J2)
  rule hasCoverR(SetItem(edgeA(_J3:InvId, _Xs2:Set)) Es:Set, J2:InvId) => hasCoverR(Es, J2)
  rule hasCoverR(SetItem(bareEdge(_Xs3:Set)) Es:Set, J2:InvId) => hasCoverR(Es, J2)

  syntax Bool ::= "hasCoverA" "(" edges:Set "," inv:InvId ")" [function, total]
  rule hasCoverA(.Set, _J:InvId) => false
  rule hasCoverA(SetItem(edgeA(J:InvId, Xs:Set)) Es:Set, J2:InvId)
    => subset(trueDepsA(J2), Xs) orBool hasCoverA(Es, J2)
    requires J ==K J2
  rule hasCoverA(SetItem(edgeA(J:InvId, _Xs:Set)) Es:Set, J2:InvId)
    => hasCoverA(Es, J2)
    requires J =/=K J2
  rule hasCoverA(SetItem(edge(_J:InvId, _Xs:Set)) Es:Set, J2:InvId) => hasCoverA(Es, J2)
  rule hasCoverA(SetItem(edgeR(_J2:InvId, _Rs:Set)) Es:Set, J2:InvId) => hasCoverA(Es, J2)
  rule hasCoverA(SetItem(bareEdge(_Xs3:Set)) Es:Set, J2:InvId) => hasCoverA(Es, J2)

  syntax Bool ::= "interactionCompleteG" "(" edges:Set "," univ:Set ")" [function, total]
  rule interactionCompleteG(_R:Set, .Set) => true
  rule interactionCompleteG(R:Set, SetItem(J:InvId) Js:Set)
    => hasCover(R, J) andBool interactionCompleteG(R, Js)

  syntax Bool ::= "resourceComplete" "(" edges:Set "," univ:Set ")" [function, total]
  rule resourceComplete(_R:Set, .Set) => true
  rule resourceComplete(R:Set, SetItem(J:InvId) Js:Set)
    => hasCoverR(R, J) andBool resourceComplete(R, Js)

  syntax Bool ::= "authorityComplete" "(" edges:Set "," univ:Set ")" [function, total]
  rule authorityComplete(_R:Set, .Set) => true
  rule authorityComplete(R:Set, SetItem(J:InvId) Js:Set)
    => hasCoverA(R, J) andBool authorityComplete(R, Js)

  syntax Bool ::= "contractComplete" "(" edges:Set ")" [function, total]
  rule contractComplete(.Set) => true
  rule contractComplete(SetItem(bareEdge(_Xs:Set)) _Es:Set) => false
  rule contractComplete(SetItem(edge(_J:InvId, _Xs:Set)) Es:Set) => contractComplete(Es)
  rule contractComplete(SetItem(edgeR(_J2:InvId, _Rs:Set)) Es:Set) => contractComplete(Es)
  rule contractComplete(SetItem(edgeA(_J3:InvId, _Xs2:Set)) Es:Set) => contractComplete(Es)

  // Universe-parameterized generalized closure (non-vacuity discipline).
  syntax Bool ::= "securityClosedGenU" "(" edges:Set "," policy:Policy ","
                    appU:Set "," resU:Set "," authU:Set ")" [function, total]
  rule securityClosedGenU(R:Set, enforce, AU:Set, RU:Set, THU:Set)
    => interactionCompleteG(R, AU)
       andBool contractComplete(R)
       andBool resourceComplete(R, RU)
       andBool authorityComplete(R, THU)
  rule securityClosedGenU(_R:Set, trust, _AU:Set, _RU:Set, _THU:Set) => false

  // ---- demo registries -----------------------------------------------------
  // CM2 hole (naive): IRP present but app-anchored at the PRIMARY holder only.
  syntax Set ::= "aliasNaiveRegistry" "(" ")" [function, total]
  rule aliasNaiveRegistry()
    => SetItem(edge(IA7, SetItem(appA)))
       |Set SetItem(edge(IB3, SetItem(appB)))
       |Set SetItem(edge(IRP, SetItem(appA)))

  // CM2 fix: resource-scope edge over the logical resource resP.
  syntax Set ::= "aliasOnlyRegistry" "(" ")" [function, total]
  rule aliasOnlyRegistry()
    => SetItem(edge(IA7, SetItem(appA)))
       |Set SetItem(edge(IB3, SetItem(appB)))
       |Set SetItem(edgeR(IRP, SetItem(resP)))

  // CM3 hole (naive): individual delegation bounds only — the aggregate
  // budget obligation is absent; membership-style checks pass individually.
  syntax Set ::= "authNaiveRegistry" "(" ")" [function, total]
  rule authNaiveRegistry()
    => SetItem(edgeA(ICAPC, SetItem(appC)))
       |Set SetItem(edgeA(ICAPD, SetItem(appD)))

  // CM3 fix: aggregate obligation as ANOTHER obligation class (no new gate).
  syntax Set ::= "authOnlyRegistry" "(" ")" [function, total]
  rule authOnlyRegistry()
    => SetItem(edgeA(ICAPC, SetItem(appC)))
       |Set SetItem(edgeA(ICAPD, SetItem(appD)))
       |Set SetItem(edgeA(IAGG, SetItem(appC) |Set SetItem(appD)))

  // Full generalized registry (all scopes, complete coverage).
  syntax Set ::= "fullRegistryGen" "(" ")" [function, total]
  rule fullRegistryGen()
    => SetItem(edge(IA7,  SetItem(appA)))
       |Set SetItem(edge(IB3, SetItem(appB)))
       |Set SetItem(edge(IC0, SetItem(appC)))
       |Set SetItem(edge(ID0, SetItem(appD)))
       |Set SetItem(edgeR(IRP, SetItem(resP)))
       |Set SetItem(edgeR(IRQ, SetItem(resQ)))
       |Set SetItem(edgeA(ICAPC, SetItem(appC)))
       |Set SetItem(edgeA(ICAPD, SetItem(appD)))
       |Set SetItem(edgeA(IAGG, SetItem(appC) |Set SetItem(appD)))

  // full minus CM2 defense (CM7-style multi-write hole demonstration)
  syntax Set ::= "fullNaiveRegistry" "(" ")" [function, total]
  rule fullNaiveRegistry()
    => SetItem(edge(IA7,  SetItem(appA)))
       |Set SetItem(edge(IB3, SetItem(appB)))
       |Set SetItem(edge(IC0, SetItem(appC)))
       |Set SetItem(edge(ID0, SetItem(appD)))
       |Set SetItem(edge(IRP, SetItem(appA)))
       |Set SetItem(edgeA(ICAPC, SetItem(appC)))
       |Set SetItem(edgeA(ICAPD, SetItem(appD)))
       |Set SetItem(edgeA(IAGG, SetItem(appC) |Set SetItem(appD)))

  // ---- demo registries -----------------------------------------------------
  // (the pickRegistryG PRODUCTION is declared in SRW3G-SYNTAX — 1V: it is
  // used by the initial configuration; the equations stay here)
  rule pickRegistryG(aliasNaive) => aliasNaiveRegistry()
  rule pickRegistryG(aliasOnly)  => aliasOnlyRegistry()
  rule pickRegistryG(authNaive)  => authNaiveRegistry()
  rule pickRegistryG(authOnly)   => authOnlyRegistry()
  rule pickRegistryG(fullNaive)  => fullNaiveRegistry()
  rule pickRegistryG(full)       => fullRegistryGen()

  // ---- trusted resmap expansion (1V) ---------------------------------------
  // The EXACT preset contents of the 1U useResMap rules, now the defining
  // equations of the configuration-variable expansion. Total: every
  // ResMapKind has an equation (a missing equation would leave pickResMap
  // stuck in the initial configuration — observed live during 1V bring-up
  // as a WarnFunctionWithoutEvaluators nondeterministic two-branch run; the
  // runner now fails closed on that warning class).
  rule pickResMap(rmPQ)
    => stK(appA, 7) |-> resP  stK(appB, 3) |-> resP
       stK(appC, 0) |-> resQ  stK(appD, 0) |-> resQ
  rule pickResMap(rmNone) => .Map
endmodule

// =============================================================================
module SRW3G-GATE
  imports SRW3G-CLOSURE

  // Phase 1V: the setup-command block is REMOVED — useResMap (both preset
  // rules) and useRegistryG (both rules) are gone. <resmap> and <registry>
  // have NO writer in the semantics; they are read by applicableGen / the
  // gate only. Configuration is via the trusted harness (initial
  // configuration). See A7.
  // NOTE (1V): the 1U useResMap/useRegistryG rules were the ONLY writers of
  // <resmap>/<registry>/<authorities>; with useRegistryG gone, authorities
  // are independently configured and never mutated.

  // ---- wfCheck: PHYSICAL effect completeness (Γ* ⊆ Γ̂ at StKey granularity) -
  // Under enforce, the declared physical footprint must cover the true one.
  // CM2 note: physical completeness is NECESSARY but not sufficient — the CM2
  // hole (alias-blind obligation applicability) is closed at the gate by the
  // resource-scope applicability over AliasClosure(FD); see the demos.
  rule <k> wfCheck => .K ... </k>
       <footprint-t> FT:Set </footprint-t>
       <footprint-d> FD:Set </footprint-d>
       <policy> enforce </policy>
    requires subset(FT, FD)

  rule <k> wfCheck => .K ... </k>
       <footprint-t> _FT:Set </footprint-t>
       <footprint-d> _FD:Set </footprint-d>
       <policy> trust </policy>

  rule <k> wfCheck ~> _REST:K => .K </k>
       <footprint-t> FT:Set </footprint-t>
       <footprint-d> FD:Set </footprint-d>
       <policy> enforce </policy>
       <result> _R:String => "blocked-effect-incomplete" </result>
       <prospective> _P:Map => .Map </prospective>
       <usage-p> _UP:Map => .Map </usage-p>
       <gateopen> _GO:Bool => false </gateopen>
    requires notBool subset(FT, FD)
  // T2: the blocked transition terminates the interval (every path out of a
  // transition closes the gate interval — no stale-open state survives).

  // ---- the commitment gate (STRUCTURE UNCHANGED) ---------------------------
  // ACCEPT: the ONLY rule that updates <committed>/<usage-c>; appends lineage,
  // advances the head. Applicable obligations = local + interaction +
  // resource (alias-closed) + authority — ONE evaluated conjunction.
  rule <k> gate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <committed> _C:Map => P </committed>
       <usage-p> UP:Map => .Map </usage-p>
       <usage-c> _UC:Map => UP </usage-c>
       <registry> R:Set </registry>
       <resmap> RM:Map </resmap>
       <cap> CP:Map </cap>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> FD:Set => .Set </footprint-d>
       <actor> Ac:AppId </actor>
       <authorities> As:Set </authorities>
       <polver> PV:Int </polver>
       <lineage> LN:Map => LN:Map [ N:Int <- lin(CH:Commitment, N:Int, auth(Ac), PV, commit(N:Int)) ] </lineage>
       <lineageNext> N:Int => N +Int 1 </lineageNext>
       <head> CH:Commitment => commit(N:Int) </head>
       <result> _R:String => "commit" </result>
       <ghost> Gh:Ghost4 => ghostApply4(Gh, P) </ghost>   //GHOST:
       <gateopen> true => false </gateopen>
    requires member(Ac, As)
             andBool allHoldG(applicableGen(R, FD, RM), P, UP, CP)

  // REJECT (some applicable obligation violated): prospective bundle discarded.
  rule <k> gate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <usage-p> UP:Map => .Map </usage-p>
       <registry> R:Set </registry>
       <resmap> RM:Map </resmap>
       <cap> CP:Map </cap>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> FD:Set => .Set </footprint-d>
       <result> _R:String => "reject" </result>
       <ghost> Gh:Ghost4 => ghostUndo4(Gh) </ghost>   //GHOST:
       <gateopen> true => false </gateopen>
    requires notBool allHoldG(applicableGen(R, FD, RM), P, UP, CP)

  // REJECT (authorization evidence invalid): obligations hold, actor not in
  // the authority closure (unchanged membership discipline).
  rule <k> gate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <usage-p> UP:Map => .Map </usage-p>
       <registry> R:Set </registry>
       <resmap> RM:Map </resmap>
       <cap> CP:Map </cap>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> FD:Set => .Set </footprint-d>
       <actor> Ac:AppId </actor>
       <authorities> As:Set </authorities>
       <result> _R:String => "reject-auth" </result>
       <ghost> Gh:Ghost4 => ghostUndo4(Gh) </ghost>   //GHOST:
       <gateopen> true => false </gateopen>
    requires notBool member(Ac, As)
             andBool allHoldG(applicableGen(R, FD, RM), P, UP, CP)

  // T2: GATE INTERVAL CLOSED — fail-closed gate (the generalized analogue of
  // the srw3.k fix): a gate command without a valid preceding begin (or a
  // second gate) cannot touch <committed>/<usage-c>, lineage, or head.
  rule <k> gate => .K ... </k>
       <gateopen> false </gateopen>
       <result> _R:String => "gate-closed" </result>
endmodule

// =============================================================================
// ASSUMPTIONS (explicit, documented; classified in the Phase-1B report):
//   A1. trueDeps/trueDepsR/trueDepsA are manual read-set derivations from the
//       evalInvG equations (auditable; Phase-0 discipline A1 carried over).
//   A2. Commitments are opaque terms (commit(Int)); no hash at this layer.
//   A3. Authorization evidence = authority membership + evaluated aggregate
//       obligations; no cryptographic signatures at this layer.
//   A4. Claim-level closure premises are evaluated against the concrete
//       registry term in each claim (non-vacuous).
//   A5. <resmap> (the alias relation) is an EXTERNAL MODEL INPUT: the model
//       does not derive which storage keys alias which logical resources; it
//       consumes that relation as data and enforces obligations uniformly over
//       its closure. Classified ASSUMED; a wrong or incomplete resmap is a
//       modeling error outside the calculus (see report limitations).
//       (Phase 1V: the resmap VALUE is supplied once by the trusted harness
//       via the initial configuration — pickResMap($RESMAP) — and NO rule
//       writes the cell; the 1U useResMap command, which any transition
//       could invoke at ANY time (no guard at all), is removed.)
//   A6. <cap>/<parent> (granted capacity and delegation tree) are external
//       model inputs for the minimal bounded-delegation topology; the
//       aggregate obligation is evaluated from them, not asserted.
//       (Phase 1V: they are supplied once by the trusted harness via the
//       initial configuration ($CAP/$PARENT) and NO rule writes the cells;
//       the 1U grant command — reachable mid-transition with NO guard,
//       letting a transition raise its own delegation bounds — is removed.)
//   A7. (Phase 1V, T3-v2) Policy, registry, authorities, the alias table,
//       and the capability configuration are PROTOCOL-OWNED trusted model
//       configuration: they enter ONLY through the initial configuration
//       ($POLICY/$REGISTRYG/$AUTHORITIES/$RESMAP/$CAP/$PARENT supplied by
//       the trusted harness) and NO rule in the semantics writes those
//       cells. The untrusted transition-program grammar cannot name them
//       (setPolicy/useRegistryG/useResMap/grant are removed), so the
//       transition cannot select or change any of them before the first
//       transition, during one, or between transitions — a configuration-
//       mutation attempt is UNREPRESENTABLE (parse-time rejection). The
//       one-shot gate state <gateopen> (T2) opens on a valid begin and
//       closes on every gate path; a closed-interval gate fails closed.
//       A wrong or adversarially authored configuration SUPPLIED BY THE
//       HARNESS is outside the evaluated model (the harness is the trust
//       boundary; the residual is registered, not hidden).
//   A9. (Phase 1W, R9 closure) The initial committed state $INITSTATE is
//       PROTOCOL-OWNED trusted configuration supplied by the trusted harness
//       invocation. The untrusted transition program cannot seed or mutate
//       <committed> (init is removed from the grammar; NO rule writes the
//       cell except the gate accept rule — grep-audited). A hostile harness
//       supplying a dishonest initial state is outside the evaluated model
//       (the same TCB of record as every other configuration item — R10).
// =============================================================================

// =============================================================================
// GHOST EXTENSION — GENERALIZED finite-effect model (Phase 1B, strongest form).
// Combines CM2 aliasing + CM3 aggregate authority + multi-write transitions in
// ONE commitment-gated theorem over the FULL generalized registry.
//
// Certificate (invariant-as-data):
//   GG(X1,X2,Z3,Z4,U1,U2)  certified values of the four storage keys
//                          stK(appA,7)=X1, stK(appB,3)=X2 (the aliased resP
//                          pair), stK(appC,0)=Z3, stK(appD,0)=Z4 (the resQ
//                          mirror pair, constant in this class), and the
//                          consumed capacities U1 (appC), U2 (appD).
//   GP(FS, B)              pending FINITE effect sequence FS over base cert B;
//                          `w`/`consume` cons effects, the gate folds them
//                          (apply on accept) or drops them (undo on reject).
//                          Effects update DISJOINT certificate fields, so the
//                          fold is order-insensitive; untracked targets are
//                          transparent (requires-split, no [owise]).
// Program class: tG(V1,V2,N) cycles =
//   begin ~> w(appA,7,V1) ~> w(appB,3,V2) ~> consume(appC,N) ~> wfCheck ~> gate
//   — a generalized finite multi-write + authority transition per cycle; every
//   effect is declared, so wfCheck never blocks inside the class.
// Scope: registry fullRegistryGen() (ALL nine obligations covered), resmap
//   rmPQ(), capG()/parentG(), policy enforce, actor appB.
//
// NO UNPROVED AXIOM: ghostMatches4 explicit; GH4-BASE/A/R/SOUND-I/F checked by
// kprove; GATE4-AGREE equates the certificate-predicted accept condition with
// the real gate's evaluated conjunction (alias-aware + authority-aware).
// =============================================================================

module SRW3G4-GHOST-OBS
  imports SRW3G-GATE

  // (ghost sorts are declared in SRW3G-SYNTAX via the //GHOST: syntax insert)

  // ---- certified safety over the FULL generalized universe -----------------
  rule ghostSafe4(GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int), C:Map)
    => allHoldG(genUniv4(), store4(X1, X2, Z3, Z4), usage4(U1, U2), C)
  rule ghostSafe4(GP(_FS:GEffs, B:Ghost4), C:Map) => ghostSafe4(B, C)

  // ---- GhostMatches: explicit soundness relation over BOTH state bundles ---
  rule ghostMatches4(GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int), M:Map, UM:Map)
    => lookupInt(M, stK(appA, 7)) ==Int X1
       andBool lookupInt(M, stK(appB, 3)) ==Int X2
       andBool lookupInt(M, stK(appC, 0)) ==Int Z3
       andBool lookupInt(M, stK(appD, 0)) ==Int Z4
       andBool lookupU(UM, appC) ==Int U1
       andBool lookupU(UM, appD) ==Int U2
  rule ghostMatches4(GP(_FS:GEffs, B:Ghost4), M:Map, UM:Map) => ghostMatches4(B, M, UM)

  // ---- effect application on the certificate (disjoint fields) -------------
  rule certW7(GG(_X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int), V:Int)
    => GG(V, X2, Z3, Z4, U1, U2)
  rule certW3(GG(X1:Int, _X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int), V:Int)
    => GG(X1, V, Z3, Z4, U1, U2)
  rule certUC(GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int), N:Int)
    => GG(X1, X2, Z3, Z4, U1 +Int N, U2)

  rule foldEffs(.GEffs, B:Ghost4) => B
  rule foldEffs(gEffW(I:AppId, S:Int, V:Int) FS:GEffs, B:Ghost4)
    => foldEffs(FS, certW7(B, V)) requires I ==K appA andBool S ==K 7
  rule foldEffs(gEffW(I:AppId, S:Int, V:Int) FS:GEffs, B:Ghost4)
    => foldEffs(FS, certW3(B, V)) requires I ==K appB andBool S ==K 3
  rule foldEffs(gEffW(I:AppId, S:Int, _V:Int) FS:GEffs, B:Ghost4)
    => foldEffs(FS, B)
    requires (I =/=K appA orBool S =/=K 7) andBool (I =/=K appB orBool S =/=K 3)
  rule foldEffs(gEffC(A:AppId, N:Int) FS:GEffs, B:Ghost4)
    => foldEffs(FS, certUC(B, N)) requires A ==K appC
  rule foldEffs(gEffC(A:AppId, _N:Int) FS:GEffs, B:Ghost4)
    => foldEffs(FS, B) requires A =/=K appC

  // pending-record construction (constructor-split, total)
  rule gW4(GP(FS:GEffs, B:Ghost4), I:AppId, S:Int, V:Int) => GP(gEffW(I, S, V) FS, B)
  rule gW4(G:Ghost4, I:AppId, S:Int, V:Int) => GP(gEffW(I, S, V) .GEffs, G)
  rule gC4(GP(FS:GEffs, B:Ghost4), A:AppId, N:Int) => GP(gEffC(A, N) FS, B)
  rule gC4(G:Ghost4, A:AppId, N:Int) => GP(gEffC(A, N) .GEffs, G)

  // ---- certificate transformer at the commitment point ---------------------
  rule ghostApply4(GP(FS:GEffs, B:Ghost4), _P:Map) => foldEffs(FS, B)
  rule ghostApply4(G:Ghost4, _P2:Map) => G
  rule ghostUndo4(GP(_FS:GEffs, B:Ghost4)) => B
  rule ghostUndo4(G:Ghost4) => G

  // ---- concrete model inputs ----------------------------------------------
  rule gAUTH4() => SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(appD)
  rule genUniv4() => SetItem(IA7) |Set SetItem(IB3) |Set SetItem(IC0) |Set SetItem(ID0)
                     |Set SetItem(IRP) |Set SetItem(IRQ)
                     |Set SetItem(ICAPC) |Set SetItem(ICAPD) |Set SetItem(IAGG)
  rule store4(X1:Int, X2:Int, Z3:Int, Z4:Int)
    => stK(appA, 7) |-> X1  stK(appB, 3) |-> X2  stK(appC, 0) |-> Z3  stK(appD, 0) |-> Z4
  rule usage4(U1:Int, U2:Int) => appC |-> U1  appD |-> U2
  // ---- concrete model inputs for the theorem instances ---------------------
  // (fix 2026-09-29, run v2: these three were used by the GH4 claims but had
  // no defining rules in SRW3G4-GHOST-OBS — every transition-touching GH4
  // claim stuck at exit=113, including the pure-evaluation GATE4-AGREE.
  // Values identical to the cm2/cm3 concrete inputs and to the K demo runner.)
  rule rmPQ() => stK(appA, 7) |-> resP  stK(appB, 3) |-> resP
                 stK(appC, 0) |-> resQ  stK(appD, 0) |-> resQ
  rule capG()    => appB |-> 10  appC |-> 6  appD |-> 6
  rule parentG() => appB |-> appB  appC |-> appB  appD |-> appB

  // ---- one generalized finite-effect transition cycle ----------------------
  rule <k> tG(V1:Int, V2:Int, N:Int) : PG:GateRun4
        => begin ~> w(appA, 7, V1) ~> w(appB, 3, V2) ~> consume(appC, N)
                 ~> wfCheck ~> gate ~> PG ... </k>

  // ---- observers -----------------------------------------------------------
  rule <k> chkG4 => .K ... </k>
       <ghost> Gh:Ghost4 </ghost> <cap> C:Map </cap>
    requires ghostSafe4(Gh, C)

  rule <k> chkM4 => .K ... </k>
       <ghost> Gh:Ghost4 </ghost> <cap> C:Map </cap>
       <committed> M:Map </committed> <usage-c> UM:Map </usage-c>
    requires ghostMatches4(Gh, M, UM) andBool ghostSafe4(Gh, C)

  // ---- trusted simplification lemmas ---------------------------------------
  rule lookupInt(M:Map [KEY:StKey <- V:Int], KEY:StKey) => V [simplification]
  rule lookupInt(M:Map [KEY:StKey <- V:Int], K2:StKey) => lookupInt(M, K2)
    requires K2 =/=K KEY [simplification]

  // ---- real-state safety observer ------------------------------------------
  rule safeGenMin(M2:Map, UM2:Map, C2:Map)
    => lookupInt(M2, stK(appA, 7)) <=Int 10
       andBool lookupInt(M2, stK(appB, 3)) <=Int 10
       andBool lookupInt(M2, stK(appA, 7)) +Int lookupInt(M2, stK(appB, 3)) <=Int 10
       andBool lookupInt(M2, stK(appC, 0)) <=Int 10
       andBool lookupInt(M2, stK(appD, 0)) <=Int 10
       andBool lookupInt(M2, stK(appC, 0)) ==Int lookupInt(M2, stK(appD, 0))
       andBool lookupU(UM2, appC) <=Int lookupCap(C2, appC)
       andBool lookupU(UM2, appD) <=Int lookupCap(C2, appD)
       andBool lookupU(UM2, appC) +Int lookupU(UM2, appD) <=Int lookupCap(C2, appB)
endmodule

// =============================================================================
module SRW3G4-GHOST-CLAIMS
  imports SRW3G4-GHOST-OBS

  claim // GH4-BASE: the soundness relation holds by evaluation at the base shape
    <k> ghostMatches4(GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int),
                      stK(appA, 7) |-> X1:Int stK(appB, 3) |-> X2:Int
                      stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int,
                      appC |-> U1:Int appD |-> U2:Int) => true </k>
    [label(GH4-BASE)]

  claim // GH4-A: ACCEPT preservation for a generalized finite-effect
        // transition (two aliased writes + one authority consumption):
        // certificate matches the committed bundle AND is safe afterwards
    <k> ( tG(V1:Int, V2:Int, NA:Int) : chkM4 ) => .K </k>
    <committed> stK(appA, 7) |-> X1:Int stK(appB, 3) |-> X2:Int
                stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U1:Int appD |-> U2:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> fullRegistryGen() </registry>
    <policy> enforce </policy>
    <gateopen> false </gateopen>   //GHOST: (1U T2: pre-begin initial state)
    <actor> appB </actor>
    <authorities> gAUTH4() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int) => ?Gh2:Ghost4 </ghost>
    requires X1:Int <=Int 10 andBool X2:Int <=Int 10 andBool X1:Int +Int X2:Int <=Int 10
             andBool Z3:Int <=Int 10 andBool Z4:Int <=Int 10 andBool Z3:Int ==Int Z4:Int
             andBool U1:Int <=Int 6 andBool U2:Int <=Int 6
             andBool U1:Int +Int U2:Int <=Int 10
             andBool V1:Int <=Int 10 andBool V2:Int <=Int 10
             andBool V1:Int +Int V2:Int <=Int 10
             andBool U1:Int +Int NA:Int <=Int 6
             andBool U1:Int +Int NA:Int +Int U2:Int <=Int 10
    [label(GH4-A)]

  claim // GH4-R: REJECT preservation for the generalized transition
    <k> ( tG(V1:Int, V2:Int, NA:Int) : chkM4 ) => .K </k>
    <committed> stK(appA, 7) |-> X1:Int stK(appB, 3) |-> X2:Int
                stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U1:Int appD |-> U2:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> fullRegistryGen() </registry>
    <policy> enforce </policy>
    <gateopen> false </gateopen>   //GHOST: (1U T2: pre-begin initial state)
    <actor> appB </actor>
    <authorities> gAUTH4() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int) => ?Gh2:Ghost4 </ghost>
    requires X1:Int <=Int 10 andBool X2:Int <=Int 10 andBool X1:Int +Int X2:Int <=Int 10
             andBool Z3:Int <=Int 10 andBool Z4:Int <=Int 10 andBool Z3:Int ==Int Z4:Int
             andBool U1:Int <=Int 6 andBool U2:Int <=Int 6
             andBool U1:Int +Int U2:Int <=Int 10
             andBool notBool ( V1:Int <=Int 10 andBool V2:Int <=Int 10
                               andBool V1:Int +Int V2:Int <=Int 10
                               andBool U1:Int +Int NA:Int <=Int 6
                               andBool U1:Int +Int NA:Int +Int U2:Int <=Int 10 )
    [label(GH4-R)]

  claim // GH4-SOUND-I: certified-safe certificate, matched to the real bundle,
        // implies the real-state generalized safety observer (residual-sharing)
    <k> ( safeGenMin(M:Map, UM:Map, CP:Map) ) => true </k>
    requires lookupInt(M, stK(appA, 7)) ==Int X1:Int
             andBool lookupInt(M, stK(appB, 3)) ==Int X2:Int
             andBool lookupInt(M, stK(appC, 0)) ==Int Z3:Int
             andBool lookupInt(M, stK(appD, 0)) ==Int Z4:Int
             andBool lookupU(UM, appC) ==Int U1:Int
             andBool lookupU(UM, appD) ==Int U2:Int
             andBool ghostSafe4(GG(X1, X2, Z3, Z4, U1, U2), CP)
    [label(GH4-SOUND-I)]

  claim // GH4-SOUND-F: the same bridge stated through the named relations
    <k> safeGenMin(M:Map, UM:Map, CP:Map) => true </k>
    requires ghostMatches4(GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int), M, UM)
             andBool ghostSafe4(GG(X1, X2, Z3, Z4, U1, U2), CP)
    [label(GH4-SOUND-F)]

  claim // GATE4-AGREE: the certificate-predicted accept condition == the REAL
        // gate's evaluated conjunction over the FULL generalized registry —
        // alias-aware (edgeR over AliasClosure) AND authority-aware (edgeA)
    <k> allHoldG(applicableGen(fullRegistryGen(),
                               SetItem(stK(appA, 7)) |Set SetItem(stK(appB, 3))
                                       |Set SetItem(appC), rmPQ()),
                 stK(appA, 7) |-> V1:Int stK(appB, 3) |-> V2:Int
                 stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int,
                 appC |-> ( U1:Int +Int NA:Int ) appD |-> U2:Int, capG())
        ==Bool ( V1:Int <=Int 10 andBool V2:Int <=Int 10
                 andBool V1:Int +Int V2:Int <=Int 10
                 andBool Z3:Int <=Int 10
                 andBool U1:Int +Int NA:Int <=Int 6
                 andBool U1:Int +Int NA:Int +Int U2:Int <=Int 10 ) => true </k>
    [label(GATE4-AGREE)]

  claim // GH4-ISO: one generalized cycle + observer, NON-circular (diagnostic)
    <k> ( tG(V1:Int, V2:Int, NA:Int) : chkG4 ) => .K </k>
    <committed> stK(appA, 7) |-> X1:Int stK(appB, 3) |-> X2:Int
                stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U1:Int appD |-> U2:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> fullRegistryGen() </registry>
    <policy> enforce </policy>
    <gateopen> false </gateopen>   //GHOST: (1U T2: pre-begin initial state)
    <actor> appB </actor>
    <authorities> gAUTH4() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int) => ?Gh2:Ghost4 </ghost>
    requires X1:Int <=Int 10 andBool X2:Int <=Int 10 andBool X1:Int +Int X2:Int <=Int 10
             andBool Z3:Int <=Int 10 andBool Z4:Int <=Int 10 andBool Z3:Int ==Int Z4:Int
             andBool U1:Int <=Int 6 andBool U2:Int <=Int 6
             andBool U1:Int +Int U2:Int <=Int 10
    [label(GH4-ISO)]

  claim // GH4-T1: TWO generalized cycles + observer, NON-circular
    <k> ( tG(V1:Int, V2:Int, NA1:Int) : (tG(W1:Int, W2:Int, NA2:Int) : chkG4) ) => .K </k>
    <committed> stK(appA, 7) |-> X1:Int stK(appB, 3) |-> X2:Int
                stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U1:Int appD |-> U2:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> fullRegistryGen() </registry>
    <policy> enforce </policy>
    <gateopen> false </gateopen>   //GHOST: (1U T2: pre-begin initial state)
    <actor> appB </actor>
    <authorities> gAUTH4() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int) => ?Gh2:Ghost4 </ghost>
    requires X1:Int <=Int 10 andBool X2:Int <=Int 10 andBool X1:Int +Int X2:Int <=Int 10
             andBool Z3:Int <=Int 10 andBool Z4:Int <=Int 10 andBool Z3:Int ==Int Z4:Int
             andBool U1:Int <=Int 6 andBool U2:Int <=Int 6
             andBool U1:Int +Int U2:Int <=Int 10
    [label(GH4-T1)]

  claim // GH4-T2: THE GENERALIZED LINEAGE-LENGTH SAFETY THEOREM (strongest
        // Phase-1B target):
        //   InitialSafe_gen(s0) /\ SecurityClosed_gen -> forall n. Safe_gen(s_n)
        // over arbitrary sequences of generalized finite-effect transitions
        // (multi-write + aliased resources + aggregate authority) in ONE
        // commitment-gated calculus.
    <k> ( tG(V1:Int, V2:Int, NA1:Int) : PG:GateRun4 ) => .K </k>
    <committed> stK(appA, 7) |-> X1:Int stK(appB, 3) |-> X2:Int
                stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U1:Int appD |-> U2:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> fullRegistryGen() </registry>
    <policy> enforce </policy>
    <gateopen> false </gateopen>   //GHOST: (1U T2: pre-begin initial state)
    <actor> appB </actor>
    <authorities> gAUTH4() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int) => ?Gh2:Ghost4 </ghost>
    requires X1:Int <=Int 10 andBool X2:Int <=Int 10 andBool X1:Int +Int X2:Int <=Int 10
             andBool Z3:Int <=Int 10 andBool Z4:Int <=Int 10 andBool Z3:Int ==Int Z4:Int
             andBool U1:Int <=Int 6 andBool U2:Int <=Int 6
             andBool U1:Int +Int U2:Int <=Int 10
             andBool securityClosedGenU(fullRegistryGen(), enforce,
                                        genAppInvs(), genResInvs(), genAuthInvs())
    [circularity, label(GH4-T2)]

  claim // GH4-M: the STRONGEST form — GhostMatches re-checked at every
        // termination over both state bundles
    <k> ( tG(V1:Int, V2:Int, NA1:Int) : PG:GateRun4 ) => .K </k>
    <committed> stK(appA, 7) |-> X1:Int stK(appB, 3) |-> X2:Int
                stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U1:Int appD |-> U2:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> fullRegistryGen() </registry>
    <policy> enforce </policy>
    <gateopen> false </gateopen>   //GHOST: (1U T2: pre-begin initial state)
    <actor> appB </actor>
    <authorities> gAUTH4() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int) => ?Gh2:Ghost4 </ghost>
    requires X1:Int <=Int 10 andBool X2:Int <=Int 10 andBool X1:Int +Int X2:Int <=Int 10
             andBool Z3:Int <=Int 10 andBool Z4:Int <=Int 10 andBool Z3:Int ==Int Z4:Int
             andBool U1:Int <=Int 6 andBool U2:Int <=Int 6
             andBool U1:Int +Int U2:Int <=Int 10
             andBool securityClosedGenU(fullRegistryGen(), enforce,
                                        genAppInvs(), genResInvs(), genAuthInvs())
    [circularity, label(GH4-M)]

  claim // GH4-NEG (non-vacuity control): GH4-T2 without InitialSafe MUST FAIL
    <k> ( tG(V1:Int, V2:Int, NA1:Int) : PG:GateRun4 ) => .K </k>
    <committed> stK(appA, 7) |-> X1:Int stK(appB, 3) |-> X2:Int
                stK(appC, 0) |-> Z3:Int stK(appD, 0) |-> Z4:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U1:Int appD |-> U2:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> fullRegistryGen() </registry>
    <policy> enforce </policy>
    <gateopen> false </gateopen>   //GHOST: (1U T2: pre-begin initial state)
    <actor> appB </actor>
    <authorities> gAUTH4() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> GG(X1:Int, X2:Int, Z3:Int, Z4:Int, U1:Int, U2:Int) => ?Gh2:Ghost4 </ghost>
    requires securityClosedGenU(fullRegistryGen(), enforce,
                                genAppInvs(), genResInvs(), genAuthInvs())
    [circularity, label(GH4-NEG)]
endmodule
