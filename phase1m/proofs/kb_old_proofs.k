// =============================================================================
// SRW3 PHASE 1M — THE FRESH OLD WITNESS (kb_old_proofs.k, hs)
//
// The B1 probe shape run over the M1 machine (the L-FINDING-1 repair, NO
// hash redirect): the exact claim that KB-CEIL-SYMBOLIC proves over M2,
// which on the un-redirected machine materializes the KRYPTO hook over a
// symbolic argument — the undischargeable #Ceil (the 1L diagnosis §2 B1
// probe class).  EXPECTED FAIL with the #Ceil residual; the retained log
// pairs with kprove_KB-CEIL-SYMBOLIC.log as the OLD/NEW evidence pair.
// =============================================================================

requires "../semantics/srw3closure-j-m1.k"

module KB-OLD-PROOFS
  imports SRW3CLOSURE-J-M1

  claim // KB-OLD-CEIL-SYMBOLIC — EXPECTED FAIL (the bare probe shape: no
        // bearing rule — the mechanics-experiment OLD side).
    <jhead> H:Bytes => LinH(H:Bytes) </jhead>
    [label(KB-OLD-CEIL-SYMBOLIC)]

  claim // KB-OLD-INIT-BASE-HEAD — THE B1 OLD WITNESS (rule-bearing): the
        // M2 claim KB-INIT-BASE-HEAD run over the M1 machine (NO
        // redirect).  The destination materializes the init head advance
        // ProtoRootR3(C) = Keccak256raw(ProtoCfgCanonR3(C)) over a
        // symbolic configuration — the frozen backend has no hook
        // evaluator, so the implication check dies on the #Ceil residual
        // (the 1L frozen-machine residual of record: kprove_L-INV-INIT-
        // BASE.log, verbatim #Ceil(Keccak256raw(b"SRW3/ProtoCfg/R3" ...))).
        // EXPECTED FAIL; pairs with kprove_KB-INIT-BASE-HEAD.log (M2).
    <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K </k>
    <jhead> _:Bytes => ProtoRootR3(C:ProtoCfgR3) </jhead>
    <jlinhead> _:Bytes => JLinRoot </jlinhead>
    <jlineage> .Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> P:JCatalog ) </jlineage>
    <jnext> N:Int </jnext>
    <janchor> A:Bytes </janchor>
    <jstate> .Map </jstate>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
         andBool JCatalogWF(P:JCatalog)
         andBool BytesEq(JAppSetRootJ(P:JCatalog), qcrAppSetDOf(C:ProtoCfgR3))
         andBool BytesEq(JGraphRootJ(P:JCatalog), qcrGraphDOf(C:ProtoCfgR3))
         andBool BytesEq(JPolicyRootJ(P:JCatalog), qcrPolicyDOf(C:ProtoCfgR3))
         andBool jcPolicyVOf(P:JCatalog) ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool SafeJ(P:JCatalog, .Map) ==K true
    [label(KB-OLD-INIT-BASE-HEAD)]

  claim // KB-OLD-INIT-BASE — THE DISCRIMINATING OLD WITNESS: the 1L
        // L-INV-INIT-BASE claim VERBATIM over the M1 machine (NO
        // redirect).  The 1L frozen-machine run of this exact claim FAILED
        // with the retained residual #Ceil(Keccak256raw(b"SRW3/ProtoCfg/
        // R3" ...)) (kprove_L-INV-INIT-BASE.log — the B1 boundary of
        // record).  EXPECTED FAIL here; pairs with KB-INIT-BASE (M2).
    <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K </k>
    <jlineage> .Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> P:JCatalog ) </jlineage>
    <jnext> N:Int </jnext>
    <janchor> A:Bytes </janchor>
    <jstate> .Map </jstate>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
         andBool JCatalogWF(P:JCatalog)
         andBool BytesEq(JAppSetRootJ(P:JCatalog), qcrAppSetDOf(C:ProtoCfgR3))
         andBool BytesEq(JGraphRootJ(P:JCatalog), qcrGraphDOf(C:ProtoCfgR3))
         andBool BytesEq(JPolicyRootJ(P:JCatalog), qcrPolicyDOf(C:ProtoCfgR3))
         andBool jcPolicyVOf(P:JCatalog) ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool SafeJ(P:JCatalog, .Map) ==K true
    [label(KB-OLD-INIT-BASE)]

endmodule
