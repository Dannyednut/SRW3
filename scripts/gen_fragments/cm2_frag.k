####SYNTAX-INSERT####
  syntax Ghost2 ::= "G2" "(" Int "," Int ")" | "GW2" "(" AppId "," Int "," Ghost2 "," Int ")"   //GHOST:
  syntax GateRun2 ::= "chkG2" | "chkM2" | "tK2" "(" Int ")" ":" GateRun2   //GHOST:
  syntax GateRun1 ::= GateRun2 | "tK1" "(" Int ")" ":" GateRun1   //GHOST:
  syntax Bool ::= "ghostSafe2" "(" Ghost2 ")" [function, total]   //GHOST:
  syntax Bool ::= "ghostMatches2" "(" Ghost2 "," Map ")" [function, total]   //GHOST:
  syntax Ghost2 ::= "ghostApply2" "(" Ghost2 "," Map ")" [function, total]   //GHOST:
  syntax Ghost2 ::= "ghostUndo2" "(" Ghost2 ")" [function, total]   //GHOST:
  syntax Set ::= "minAliasUniv" "(" ")" [function, total]   //GHOST:
  syntax Set ::= "minApp2" "(" ")" [function, total]   //GHOST:
  syntax Set ::= "minRes2" "(" ")" [function, total]   //GHOST:
  syntax Set ::= "gAUTH2" "(" ")" [function, total]   //GHOST:
  syntax Map ::= "rmPQ" "(" ")" [function, total]   //GHOST:
  syntax Bool ::= "safeAliasMin" "(" Map ")" [function, total]   //GHOST:
####MODULES####

// =============================================================================
// GHOST EXTENSION — CM2 alias model (Phase 1B).
// Everything below is NEW relative to k/srw3gen.k; the copied semantics rules
// above carry only the //GHOST:-marked additive lines (certificate cell,
// pending-write record, certificate transformers at the commitment point).
//
// Certificate (invariant-as-data):
//   G2(X1, X2)            certified values of stK(appA,7) and stK(appB,3),
//                         the two aliased physical keys of resource resP.
//   GW2(I,S,Prev,V)       pending declared write, recorded by `w`, consumed
//                         at the commitment point (apply on accept, undo on
//                         reject). Transparent for matches/safe observers.
// Program class: tK2(V) cycles = begin ~> w(appB,3,V) ~> wfCheck ~> gate
//   (writes through the ALIAS key K2 — the CM2-critical direction; tK1 is the
//   symmetric primary-key direction, covered one-step by GH2-A1). The theorem
//   class always declares its write, so wfCheck never blocks inside it.
// Scope: registry aliasOnlyRegistry(), universe {IA7, IB3} (app) + {IRP}
//   (resource), resmap rmPQ(), policy enforce, actor appB for tK2 cycles.
//   The certificate tracks exactly the keys the universe's obligations read.
//
// NO UNPROVED AXIOM: ghostMatches2 is the explicit soundness relation; every
// claim about it is a kprove-checked obligation (GH2-BASE/A/R/SOUND-I/F);
// the transformer ghostApply2 is justified by GH2-A, not by fiat.
// =============================================================================

module SRW3G2-GHOST-OBS
  imports SRW3G-GATE

  // (ghost sorts are declared in SRW3G-SYNTAX via the //GHOST: syntax insert)


  // ---- certified safety = the model's obligation universe evaluated on the
  //      certified values (the SAME evaluated obligations as the real gate) --
  rule ghostSafe2(G2(XA:Int, XB:Int))
    => allHoldG(minAliasUniv(), stK(appA, 7) |-> XA stK(appB, 3) |-> XB, .Map, .Map)
  rule ghostSafe2(GW2(_I:AppId, _S:Int, Prev:Ghost2, _V:Int)) => ghostSafe2(Prev)

  // ---- GhostMatches: the explicit soundness relation -----------------------
  rule ghostMatches2(G2(XA:Int, XB:Int), M:Map)
    => lookupInt(M, stK(appA, 7)) ==Int XA
       andBool lookupInt(M, stK(appB, 3)) ==Int XB
  rule ghostMatches2(GW2(_I:AppId, _S:Int, Prev:Ghost2, _V:Int), M:Map)
    => ghostMatches2(Prev, M)

  // ---- certificate transformer at the commitment point ---------------------
  // tracked write -> certified value updated; untracked / none -> unchanged.
  // Requires-split (no [owise]: the haskell backend does not fire owise
  // fallbacks reliably — see k/srw3gen.k appsOf note). The theorem class has
  // at most one pending record at the commitment point (declared writes only).
  rule ghostApply2(GW2(appB, 3, G2(XA:Int, _XB:Int), V:Int), _P:Map) => G2(XA, V)
  rule ghostApply2(GW2(appA, 7, G2(_XA2:Int, XB:Int), V:Int), _P2:Map) => G2(V, XB)
  rule ghostApply2(GW2(I:AppId, S:Int, G2(XA:Int, XB:Int), V:Int), _P3:Map)
    => G2(XA, XB)
    requires (I =/=K appB orBool S =/=K 3) andBool (I =/=K appA orBool S =/=K 7)
  rule ghostApply2(G:Ghost2, _P4:Map) => G

  rule ghostUndo2(GW2(_I2:AppId, _S2:Int, Gh:Ghost2, _V2:Int)) => Gh
  rule ghostUndo2(G:Ghost2) => G

  // ---- concrete model inputs for the theorem instances ---------------------
  rule rmPQ() => stK(appA, 7) |-> resP  stK(appB, 3) |-> resP
                 stK(appC, 0) |-> resQ  stK(appD, 0) |-> resQ
  rule gAUTH2() => SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(appD)
  rule minAliasUniv() => SetItem(IA7) |Set SetItem(IB3) |Set SetItem(IRP)
  rule minApp2() => SetItem(IA7) |Set SetItem(IB3)
  rule minRes2() => SetItem(IRP)

  // ---- one full admissible transition cycle (proof-layer command) ----------
  rule <k> tK2(V:Int) : PG:GateRun2
        => begin ~> w(appB, 3, V) ~> wfCheck ~> gate ~> PG ... </k>
  rule <k> tK1(V:Int) : PG:GateRun2
        => begin ~> w(appA, 7, V) ~> wfCheck ~> gate ~> PG ... </k>

  // ---- safety observer: executable ONLY on a certified-safe certificate ----
  rule <k> chkG2 => .K ... </k>
       <ghost> Gh:Ghost2 </ghost>
    requires ghostSafe2(Gh)

  // ---- matching observer: executable ONLY if the certificate BOTH matches
  //      the real committed state AND is certified-safe ----------------------
  rule <k> chkM2 => .K ... </k>
       <ghost> Gh:Ghost2 </ghost>
       <committed> M:Map </committed>
    requires ghostMatches2(Gh, M) andBool ghostSafe2(Gh)

  // ---- trusted simplification lemmas (verbatim class from Phase-1A) --------
  rule lookupInt(M:Map [KEY:StKey <- V:Int], KEY:StKey) => V [simplification]
  rule lookupInt(M:Map [KEY:StKey <- V:Int], K2:StKey) => lookupInt(M, K2)
    requires K2 =/=K KEY [simplification]

  // ---- real-state safety observer ------------------------------------------
  rule safeAliasMin(M2:Map)
    => lookupInt(M2, stK(appA, 7)) <=Int 10
       andBool lookupInt(M2, stK(appB, 3)) <=Int 10
       andBool lookupInt(M2, stK(appA, 7)) +Int lookupInt(M2, stK(appB, 3)) <=Int 10
endmodule

// =============================================================================
// Claims: the GhostMatches obligation set + the CM2 theorem.
// KORE DESTINATION NOTE (Phase-1A lesson): claims use explicit existential
// (?-prefixed) destinations over ALL changing cells; the minimal-destination
// form is documented as stuck-class in Phase 1A and is not repeated here.
// Shared variables between <committed> and <ghost> bake the GhostMatches
// shape into the induction.
// =============================================================================

module SRW3G2-GHOST-CLAIMS
  imports SRW3G2-GHOST-OBS

  claim // GH2-BASE: the soundness relation HOLDS BY EVALUATION at the
        // theorem's initial shape (base case; no axiom)
    <k> ghostMatches2(G2(X0:Int, Y0:Int),
                      stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int) => true </k>
    [label(GH2-BASE)]

  claim // GH2-A: ACCEPT preservation (4a-analogue at the certificate layer):
        // after an accepted alias-key transition the certificate matches the
        // committed state AND is safe (checked dynamically by chkM2)
    <k> ( tK2(V:Int) : chkM2 ) => .K </k>
    <committed> stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> .Map => .Map </usage-c>
    <usage-p> .Map => .Map </usage-p>
    <cap> .Map </cap>
    <parent> .Map </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> aliasOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH2() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> G2(X0:Int, Y0:Int) => ?Gh2:Ghost2 </ghost>
    requires X0:Int <=Int 10 andBool Y0:Int <=Int 10 andBool X0:Int +Int Y0:Int <=Int 10
             andBool V:Int <=Int 10 andBool X0:Int +Int V:Int <=Int 10
    [label(GH2-A)]

  claim // GH2-R: REJECT preservation (4b-analogue): the PREVIOUS matching
        // relation is preserved (committed state and certificate unchanged)
    <k> ( tK2(V:Int) : chkM2 ) => .K </k>
    <committed> stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> .Map => .Map </usage-c>
    <usage-p> .Map => .Map </usage-p>
    <cap> .Map </cap>
    <parent> .Map </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> aliasOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH2() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> G2(X0:Int, Y0:Int) => ?Gh2:Ghost2 </ghost>
    requires X0:Int <=Int 10 andBool Y0:Int <=Int 10 andBool X0:Int +Int Y0:Int <=Int 10
             andBool notBool ( V:Int <=Int 10 andBool X0:Int +Int V:Int <=Int 10 )
    [label(GH2-R)]

  claim // GH2-A1: one-step preservation for the PRIMARY-key direction (tK1,
        // actor appA) — non-circular; complements the tK2 theorem class
    <k> ( tK1(V:Int) : chkM2 ) => .K </k>
    <committed> stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> .Map => .Map </usage-c>
    <usage-p> .Map => .Map </usage-p>
    <cap> .Map </cap>
    <parent> .Map </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> aliasOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appA </actor>
    <authorities> gAUTH2() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> G2(X0:Int, Y0:Int) => ?Gh2:Ghost2 </ghost>
    requires X0:Int <=Int 10 andBool Y0:Int <=Int 10 andBool X0:Int +Int Y0:Int <=Int 10
             andBool V:Int <=Int 10 andBool V:Int +Int Y0:Int <=Int 10
    [label(GH2-A1)]

  claim // GH2-SOUND-I: a certified-safe certificate, matched to the real
        // state, implies the REAL-state safety observer (residual-sharing form)
    <k> ( lookupInt(M:Map, stK(appA, 7)) <=Int 10
          andBool lookupInt(M, stK(appB, 3)) <=Int 10
          andBool lookupInt(M, stK(appA, 7)) +Int lookupInt(M, stK(appB, 3)) <=Int 10 )
        => true </k>
    requires lookupInt(M, stK(appA, 7)) ==Int XA:Int
             andBool lookupInt(M, stK(appB, 3)) ==Int XB:Int
             andBool ghostSafe2(G2(XA, XB))
    [label(GH2-SOUND-I)]

  claim // GH2-SOUND-F: the same bridge via the NAMED relation (definitional form)
    <k> safeAliasMin(M:Map) => true </k>
    requires ghostMatches2(G2(XA:Int, XB:Int), M) andBool ghostSafe2(G2(XA, XB))
    [label(GH2-SOUND-F)]

  claim // GATE2-AGREE: the certificate-predicted accept condition == the REAL
        // gate's evaluated applicable-obligation conjunction on the
        // prospective state, under the ALIAS-AWARE applicability (edgeR over
        // AliasClosure(FD) = {resP}) — the claim that makes CM2 impossible
    <k> allHoldG(applicableGen(aliasOnlyRegistry(), SetItem(stK(appB, 3)), rmPQ()),
                 stK(appA, 7) |-> XA:Int stK(appB, 3) |-> V:Int, .Map, .Map)
        ==Bool ( V:Int <=Int 10 andBool XA:Int +Int V:Int <=Int 10 ) => true </k>
    [label(GATE2-AGREE)]

  claim // GH2-ISO: one full cycle + observer, NON-circular (diagnostic; covers
        // BOTH gate branches and the observer firing)
    <k> ( tK2(V:Int) : chkG2 ) => .K </k>
    <committed> stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> .Map => .Map </usage-c>
    <usage-p> .Map => .Map </usage-p>
    <cap> .Map </cap>
    <parent> .Map </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> aliasOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH2() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> G2(X0:Int, Y0:Int) => ?Gh2:Ghost2 </ghost>
    requires X0:Int <=Int 10 andBool Y0:Int <=Int 10 andBool X0:Int +Int Y0:Int <=Int 10
    [label(GH2-ISO)]

  claim // GH2-T1: TWO cycles + observer, NON-circular (bounded-depth probe)
    <k> ( tK2(V1:Int) : (tK2(V2:Int) : chkG2) ) => .K </k>
    <committed> stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> .Map => .Map </usage-c>
    <usage-p> .Map => .Map </usage-p>
    <cap> .Map </cap>
    <parent> .Map </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> aliasOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH2() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> G2(X0:Int, Y0:Int) => ?Gh2:Ghost2 </ghost>
    requires X0:Int <=Int 10 andBool Y0:Int <=Int 10 andBool X0:Int +Int Y0:Int <=Int 10
    [label(GH2-T1)]

  claim // GH2-T2: THE CM2 ALIAS-AWARE LINEAGE-LENGTH SAFETY THEOREM
        //   InitialSafe_alias(s0) /\ SecurityClosed_alias -> forall n. Safe_alias(s_n)
        // over the generalized (alias-aware) GateRun semantics; the induction
        // covers arbitrary sequences of alias-key transition cycles.
    <k> ( tK2(V1:Int) : PG:GateRun2 ) => .K </k>
    <committed> stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> .Map => .Map </usage-c>
    <usage-p> .Map => .Map </usage-p>
    <cap> .Map </cap>
    <parent> .Map </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> aliasOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH2() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> G2(X0:Int, Y0:Int) => ?Gh2:Ghost2 </ghost>
    requires X0:Int <=Int 10 andBool Y0:Int <=Int 10 andBool X0:Int +Int Y0:Int <=Int 10
             andBool securityClosedGenU(aliasOnlyRegistry(), enforce, minApp2(), minRes2(), .Set)
    [circularity, label(GH2-T2)]

  claim // GH2-M: the STRONGER form — GhostMatches re-checked at every
        // termination (chkM2 observer): for all n the committed states remain
        // certified-safe AND matched to their certificates
    <k> ( tK2(V1:Int) : PG:GateRun2 ) => .K </k>
    <committed> stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> .Map => .Map </usage-c>
    <usage-p> .Map => .Map </usage-p>
    <cap> .Map </cap>
    <parent> .Map </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> aliasOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH2() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> G2(X0:Int, Y0:Int) => ?Gh2:Ghost2 </ghost>
    requires X0:Int <=Int 10 andBool Y0:Int <=Int 10 andBool X0:Int +Int Y0:Int <=Int 10
             andBool securityClosedGenU(aliasOnlyRegistry(), enforce, minApp2(), minRes2(), .Set)
    [circularity, label(GH2-M)]

  claim // GH2-NEG (non-vacuity control): GH2-T2 with the InitialSafe premise
        // dropped MUST FAIL (kprove must reject the under-premised theorem)
    <k> ( tK2(V1:Int) : PG:GateRun2 ) => .K </k>
    <committed> stK(appA, 7) |-> X0:Int stK(appB, 3) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <usage-c> .Map => .Map </usage-c>
    <usage-p> .Map => .Map </usage-p>
    <cap> .Map </cap>
    <parent> .Map </parent>
    <resmap> rmPQ() </resmap>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <registry> aliasOnlyRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH2() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    <ghost> G2(X0:Int, Y0:Int) => ?Gh2:Ghost2 </ghost>
    requires securityClosedGenU(aliasOnlyRegistry(), enforce, minApp2(), minRes2(), .Set)
    [circularity, label(GH2-NEG)]
endmodule
