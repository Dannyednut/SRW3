####SYNTAX-INSERT####
  syntax Ghost3 ::= "U2" "(" Int "," Int ")" | "GWU" "(" AppId "," Int "," Ghost3 ")"   //GHOST:
  syntax GateRun3 ::= "chkG3" | "chkM3" | "tC" "(" Int ")" ":" GateRun3   //GHOST:
  syntax GateRun3X ::= GateRun3 | "tD" "(" Int ")" ":" GateRun3X   //GHOST:
  syntax Bool ::= "ghostSafe3" "(" Ghost3 "," Map ")" [function, total]   //GHOST:
  syntax Bool ::= "ghostMatches3" "(" Ghost3 "," Map ")" [function, total]   //GHOST:
  syntax Ghost3 ::= "ghostApply3" "(" Ghost3 "," Map ")" [function, total]   //GHOST:
  syntax Ghost3 ::= "ghostUndo3" "(" Ghost3 ")" [function, total]   //GHOST:
  syntax Set ::= "minAuthUniv" "(" ")" [function, total]   //GHOST:
  syntax Set ::= "minAuthU3" "(" ")" [function, total]   //GHOST:
  syntax Set ::= "gAUTH3" "(" ")" [function, total]   //GHOST:
  syntax Map ::= "capG" "(" ")" [function, total]   //GHOST:
  syntax Map ::= "parentG" "(" ")" [function, total]   //GHOST:
  syntax Bool ::= "safeAuthMin" "(" Map "," Map ")" [function, total]   //GHOST:
####MODULES####
// =============================================================================
// GHOST EXTENSION — CM3 aggregate-authority model (Phase 1B).
// Certificate (invariant-as-data):
//   U2(U1, U2)            certified consumed capacity of delegates appC/appD.
//   GWU(A,N,Prev)         pending consumption, recorded by `consume`, consumed
//                         at the commitment point (apply on accept, undo on
//                         reject). Transparent for matches/safe observers.
// Program class: tC(N) cycles = begin ~> consume(appC,N) ~> wfCheck ~> gate
//   (the aggregate-critical delegate; tD covered one-step by GH3-A1).
// Scope: registry authOnlyRegistry(), universe {ICAPC, ICAPD, IAGG} (authority),
//   capG()/parentG() as the concrete bounded-delegation inputs, actor appC.
// The aggregate constraint is evaluated (evalInvG IAGG) — no special gate
// branch; the certificate tracks exactly the usage values it reads.
// =============================================================================

module SRW3G3-GHOST-OBS
  imports SRW3G-GATE

  // (ghost sorts are declared in SRW3G-SYNTAX via the //GHOST: syntax insert)

  // ---- certified safety over the certified usage values --------------------
  rule ghostSafe3(U2(U1:Int, U2B:Int), C:Map)
    => allHoldG(minAuthUniv(), .Map, appC |-> U1 appD |-> U2B, C)
  rule ghostSafe3(GWU(_A:AppId, _N:Int, Prev:Ghost3), C:Map) => ghostSafe3(Prev, C)

  // ---- GhostMatches: the explicit soundness relation -----------------------
  rule ghostMatches3(U2(U1:Int, U2B:Int), UM:Map)
    => lookupU(UM, appC) ==Int U1 andBool lookupU(UM, appD) ==Int U2B
  rule ghostMatches3(GWU(_A:AppId, _N:Int, Prev:Ghost3), UM:Map)
    => ghostMatches3(Prev, UM)

  // ---- certificate transformer at the commitment point ---------------------
  // tracked consumption -> certified usage updated; untracked actor -> no-op.
  rule ghostApply3(GWU(A:AppId, N:Int, U2(U1:Int, U2B:Int)), _UP:Map)
    => U2(U1 +Int N, U2B) requires A ==K appC
  rule ghostApply3(GWU(A:AppId, N:Int, U2(U1:Int, U2B:Int)), _UP2:Map)
    => U2(U1, U2B +Int N) requires A ==K appD
  rule ghostApply3(GWU(A:AppId, _N:Int, Prev:Ghost3), _UP3:Map)
    => Prev requires A =/=K appC andBool A =/=K appD
  rule ghostApply3(G:Ghost3, _UP4:Map) => G

  rule ghostUndo3(GWU(_A2:AppId, _N2:Int, Gh:Ghost3)) => Gh
  rule ghostUndo3(G:Ghost3) => G

  // ---- concrete bounded-delegation inputs for the theorem instances -------
  rule capG()    => appB |-> 10  appC |-> 6  appD |-> 6
  rule parentG() => appB |-> appB  appC |-> appB  appD |-> appB
  rule gAUTH3()  => SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(appD)
  rule minAuthUniv() => SetItem(ICAPC) |Set SetItem(ICAPD) |Set SetItem(IAGG)
  rule minAuthU3()   => SetItem(ICAPC) |Set SetItem(ICAPD) |Set SetItem(IAGG)

  // ---- one full admissible transition cycle (proof-layer command) ----------
  rule <k> tC(N:Int) : PG:GateRun3
        => begin ~> consume(appC, N) ~> wfCheck ~> gate ~> PG ... </k>
  rule <k> tD(N:Int) : PG:GateRun3
        => begin ~> consume(appD, N) ~> wfCheck ~> gate ~> PG ... </k>

  // ---- observers -----------------------------------------------------------
  rule <k> chkG3 => .K ... </k>
       <ghost> Gh:Ghost3 </ghost> <cap> C:Map </cap>
    requires ghostSafe3(Gh, C)

  rule <k> chkM3 => .K ... </k>
       <ghost> Gh:Ghost3 </ghost> <cap> C:Map </cap> <usage-c> UM:Map </usage-c>
    requires ghostMatches3(Gh, UM) andBool ghostSafe3(Gh, C)

  // ---- trusted simplification lemmas ---------------------------------------
  rule lookupInt(M:Map [KEY:StKey <- V:Int], KEY:StKey) => V [simplification]
  rule lookupInt(M:Map [KEY:StKey <- V:Int], K2:StKey) => lookupInt(M, K2)
    requires K2 =/=K KEY [simplification]

  // ---- real-state safety observer ------------------------------------------
  rule safeAuthMin(UM:Map, C:Map)
    => lookupU(UM, appC) <=Int lookupCap(C, appC)
       andBool lookupU(UM, appD) <=Int lookupCap(C, appD)
       andBool lookupU(UM, appC) +Int lookupU(UM, appD) <=Int lookupCap(C, appB)
endmodule

// =============================================================================
module SRW3G3-GHOST-CLAIMS
  imports SRW3G3-GHOST-OBS

  claim // GH3-BASE: the soundness relation holds by evaluation at the base shape
    <k> ghostMatches3(U2(X0:Int, Y0:Int), appC |-> X0:Int appD |-> Y0:Int) => true </k>
    [label(GH3-BASE)]

  claim // GH3-A: ACCEPT preservation for an aggregate-authority transition:
        // after acceptance the usage certificate matches the committed usage
        // AND is safe (the aggregate obligation was EVALUATED by the gate)
    <k> ( tC(NA:Int) : chkM3 ) => .K </k>
    <committed> .Map => .Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U0:Int appD |-> V0:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> .Map </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> authOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appC </actor>
    <authorities> gAUTH3() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> U2(U0:Int, V0:Int) => ?Gh2:Ghost3 </ghost>
    requires U0:Int <=Int 6 andBool V0:Int <=Int 6 andBool U0:Int +Int V0:Int <=Int 10
             andBool U0:Int +Int NA:Int <=Int 6
             andBool U0:Int +Int NA:Int +Int V0:Int <=Int 10
    [label(GH3-A)]

  claim // GH3-R: REJECT preservation (aggregate overflow blocked; nothing moves)
    <k> ( tC(NA:Int) : chkM3 ) => .K </k>
    <committed> .Map => .Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U0:Int appD |-> V0:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> .Map </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> authOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appC </actor>
    <authorities> gAUTH3() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> U2(U0:Int, V0:Int) => ?Gh2:Ghost3 </ghost>
    requires U0:Int <=Int 6 andBool V0:Int <=Int 6 andBool U0:Int +Int V0:Int <=Int 10
             andBool notBool ( U0:Int +Int NA:Int <=Int 6
                               andBool U0:Int +Int NA:Int +Int V0:Int <=Int 10 )
    [label(GH3-R)]

  claim // GH3-A1: one-step preservation for the SECOND delegate (tD, actor
        // appD) — non-circular; complements the tC theorem class
    <k> ( tD(NA:Int) : chkM3 ) => .K </k>
    <committed> .Map => .Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U0:Int appD |-> V0:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> .Map </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> authOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appD </actor>
    <authorities> gAUTH3() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> U2(U0:Int, V0:Int) => ?Gh2:Ghost3 </ghost>
    requires U0:Int <=Int 6 andBool V0:Int <=Int 6 andBool U0:Int +Int V0:Int <=Int 10
             andBool V0:Int +Int NA:Int <=Int 6
             andBool U0:Int +Int V0:Int +Int NA:Int <=Int 10
    [label(GH3-A1)]

  claim // GH3-SOUND-I: certified-safe usage certificate, matched to the real
        // usage state, implies the real-state authority safety observer
    <k> ( lookupU(UM:Map, appC) <=Int lookupCap(CP:Map, appC)
          andBool lookupU(UM, appD) <=Int lookupCap(CP, appD)
          andBool lookupU(UM, appC) +Int lookupU(UM, appD) <=Int lookupCap(CP, appB) )
        => true </k>
    requires lookupU(UM, appC) ==Int XA:Int
             andBool lookupU(UM, appD) ==Int XB:Int
             andBool ghostSafe3(U2(XA, XB), CP)
    [label(GH3-SOUND-I)]

  claim // GH3-SOUND-F: the same bridge via the NAMED relation
    <k> safeAuthMin(UM:Map, CP:Map) => true </k>
    requires ghostMatches3(U2(XA:Int, XB:Int), UM)
             andBool ghostSafe3(U2(XA, XB), CP)
    [label(GH3-SOUND-F)]

  claim // GATE3-AGREE: the certificate-predicted accept condition == the REAL
        // gate's evaluated applicable-obligation conjunction, including the
        // AGGREGATE obligation IAGG evaluated from cap (no special branch)
    <k> allHoldG(applicableGen(authOnlyRegistry(), SetItem(appC), .Map),
                 .Map, appC |-> ( U0:Int +Int NA:Int ) appD |-> V0:Int, capG())
        ==Bool ( U0:Int +Int NA:Int <=Int 6
                 andBool U0:Int +Int NA:Int +Int V0:Int <=Int 10 ) => true </k>
    [label(GATE3-AGREE)]

  claim // GH3-ISO: one full cycle + observer, NON-circular (diagnostic)
    <k> ( tC(NA:Int) : chkG3 ) => .K </k>
    <committed> .Map => .Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U0:Int appD |-> V0:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> .Map </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> authOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appC </actor>
    <authorities> gAUTH3() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> U2(U0:Int, V0:Int) => ?Gh2:Ghost3 </ghost>
    requires U0:Int <=Int 6 andBool V0:Int <=Int 6 andBool U0:Int +Int V0:Int <=Int 10
    [label(GH3-ISO)]

  claim // GH3-T1: TWO cycles + observer, NON-circular (bounded-depth probe)
    <k> ( tC(NA1:Int) : (tC(NA2:Int) : chkG3) ) => .K </k>
    <committed> .Map => .Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U0:Int appD |-> V0:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> .Map </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> authOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appC </actor>
    <authorities> gAUTH3() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> U2(U0:Int, V0:Int) => ?Gh2:Ghost3 </ghost>
    requires U0:Int <=Int 6 andBool V0:Int <=Int 6 andBool U0:Int +Int V0:Int <=Int 10
    [label(GH3-T1)]

  claim // GH3-T2: THE CM3 AGGREGATE-AUTHORITY LINEAGE-LENGTH SAFETY THEOREM
        //   InitialSafe_auth(s0) /\ SecurityClosed_auth -> forall n. Safe_auth(s_n)
    <k> ( tC(NA1:Int) : PG:GateRun3 ) => .K </k>
    <committed> .Map => .Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U0:Int appD |-> V0:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> .Map </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> authOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appC </actor>
    <authorities> gAUTH3() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> U2(U0:Int, V0:Int) => ?Gh2:Ghost3 </ghost>
    requires U0:Int <=Int 6 andBool V0:Int <=Int 6 andBool U0:Int +Int V0:Int <=Int 10
             andBool securityClosedGenU(authOnlyRegistry(), enforce, .Set, .Set, minAuthU3())
    [circularity, label(GH3-T2)]

  claim // GH3-M: the STRONGER form — GhostMatches re-checked at every termination
    <k> ( tC(NA1:Int) : PG:GateRun3 ) => .K </k>
    <committed> .Map => .Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U0:Int appD |-> V0:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> .Map </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> authOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appC </actor>
    <authorities> gAUTH3() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> U2(U0:Int, V0:Int) => ?Gh2:Ghost3 </ghost>
    requires U0:Int <=Int 6 andBool V0:Int <=Int 6 andBool U0:Int +Int V0:Int <=Int 10
             andBool securityClosedGenU(authOnlyRegistry(), enforce, .Set, .Set, minAuthU3())
    [circularity, label(GH3-M)]

  claim // GH3-NEG (non-vacuity control): GH3-T2 without InitialSafe MUST FAIL
    <k> ( tC(NA1:Int) : PG:GateRun3 ) => .K </k>
    <committed> .Map => .Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> appC |-> U0:Int appD |-> V0:Int => ?UC2:Map </usage-c>
    <usage-p> UP2:Map => ?UP3:Map </usage-p>
    <cap> capG() </cap>
    <parent> parentG() </parent>
    <resmap> .Map </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> authOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appC </actor>
    <authorities> gAUTH3() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> U2(U0:Int, V0:Int) => ?Gh2:Ghost3 </ghost>
    requires securityClosedGenU(authOnlyRegistry(), enforce, .Set, .Set, minAuthU3())
    [circularity, label(GH3-NEG)]
endmodule
