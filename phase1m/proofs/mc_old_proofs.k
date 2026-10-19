// =============================================================================
// SRW3 PHASE 1M — THE WORKSTREAM-C OLD WITNESS (mc_old_proofs.k, hs)
//
// The domain-coverage claim run over the M2 machine (the hash-redirect
// machine WITHOUT the explicit gate-failure transition): the guard-false
// branch of the gate command matches NO rule — the configuration is STUCK
// (the 1L blocker census B4: "a pGateEvalJ whose mint preconditions are
// unmet matches NO rule ... the circular re-application cannot re-fire and
// the branch dies").  EXPECTED FAIL with the stuck-configuration residual;
// pairs with kprove_MC-GATE-COVERAGE.log (M3, PROVED) as the B4 OLD/NEW
// pair.
// =============================================================================

requires "../semantics/srw3closure-j-m2.k"

module MC-OLD-PROOFS
  imports SRW3CLOSURE-J-M2

  claim // MC-OLD-GATE-COVERAGE — EXPECTED FAIL (the B4 stuck-path witness).
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
               L2:Map </jlineage>
    <jrefuse> RF:JRefuse </jrefuse>
    [label(MC-OLD-GATE-COVERAGE)]

  claim // MC-OLD-GATE-COVERAGE-WRONGSLOT — THE CONCRETE B4 WITNESS over M2:
        // the mint guard is DECIDABLY FALSE (slot 7 vs counter 5) and the
        // machine has NO refusal rule — NO rule matches and the
        // configuration is STUCK: the command is never consumed.  EXPECTED
        // FAIL with the stuck-configuration residual; pairs with
        // MC-GATE-REFUSE-WRONGSLOT (M3, PROVED).
    <k> pGateEvalJ(jBlockJ( b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , 1 , 7 )
                 , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> 5 </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
               L2:Map </jlineage>
    [label(MC-OLD-GATE-COVERAGE-WRONGSLOT)]

endmodule
