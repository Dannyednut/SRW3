####SYNTAX-INSERT####
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
####MODULES####
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
