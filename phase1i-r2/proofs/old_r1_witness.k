// =============================================================================
// SRW3 Phase 1I-R2 — THE OLD-MODEL WITNESS (before side)
//                    (phase1i-r2/proofs/old_r1_witness.k)
//
// Re-run against the UNMODIFIED R1 module (phase1i-r1/semantics/srw3proto-r1.k
// — required verbatim, nothing edited) so the before/after comparison stays
// auditable (handoff sections 2 and 6).
//
// The R1 injection (finding R2-F1): R1's pGateEval(B, ERC, ERP, V:String)
// takes the gate verdict FROM THE CALLER and stores it in the receipt
// verbatim; no rule of SRW3PROTO-R1 ever evaluates VerifyLineageG.  A caller
// that supplies "valid-g" obtains a receipt claiming the frozen gate accepted.
// If the remaining fields line up (the block carries the protocol-pinned
// policy commitment and context digest, the decision field claims valid, the
// execution results match, the parent/slot links hold), pAcceptR1 ACCEPTS.
//
// These claims make that formal over the R1 module itself:
//
//   OLD-R1-GATE-MINTS-CALLER-VERDICT — the R1 mint stores the caller's
//     verdict text verbatim (here: the literal "valid-g", supplied as a
//     command ARGUMENT — the injection channel).
//
//   OLD-R1-ACCEPTS-CALLER-VERDICT — with such a receipt in the pool and the
//     remaining fields lined up, the R1 accept FIRES and the chain extends.
//     The hash-equality conjuncts appear as HYPOTHESES: R1 has no rule that
//     could verify or refute them — the verdict's truth is exactly what the
//     caller chose.  That is the defect: the decision rests on caller text,
//     not on gate evaluation.
//
//   OLD-R1-PIPELINE-FORGED — end to end: init -> pGateEval with the caller
//     string "valid-g" -> pAcceptR1 commits the candidate whose REAL gate
//     verdict (over the evidence the caller holds) is a rejection.  R1 cannot
//     know: the verdict is whatever the caller typed.
//
// R2 comparison: the same three shapes are ILL-FORMED in the R2 command
// language (no verdict parameter exists — transcripts/legacy/) and the
// evidence-based attack (present invalid evidence) yields a COMPUTED
// rejection receipt that cannot accept (R2-FORGED-VERDICT-REJECT,
// R2-PIPELINE-FORGED, Python mirror cases).
// =============================================================================

requires "../../phase1i-r1/semantics/srw3proto-r1.k"

module OLD-R1-WITNESS
  imports SRW3PROTO-R1

  claim // OLD-R1-GATE-MINTS-CALLER-VERDICT: PROVED (witness) — the R1 mint
        // stores the caller-supplied verdict string verbatim.
    <k> pGateEval(B:ProtoBlock, ERC:Bytes, ERP:Bytes, "valid-g") => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> PS:Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(
                     gateReceipt(B:ProtoBlock, ERC:Bytes, ERP:Bytes,
                                 "valid-g", H:Bytes, N:Int) ) PS:Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    [label(OLD-R1-GATE-MINTS-CALLER-VERDICT)]

  claim // OLD-R1-ACCEPTS-CALLER-VERDICT: PROVED (witness) — the R1 accept
        // fires on a caller-supplied "valid-g" receipt with the remaining
        // fields lined up.  The security equalities are HYPOTHESES here
        // precisely because R1 never evaluates the gate: nothing in the R1
        // machine can distinguish this receipt from one a real evaluation
        // would have produced.  THE CHAIN EXTENDS.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(
                     gateReceipt(B:ProtoBlock, ERC:Bytes, ERP:Bytes,
                                 "valid-g", H:Bytes, N:Int) ) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlock) <- B:ProtoBlock] ) </plineage>
    <pnext> N:Int => N:Int +Int 1 </pnext>
    <phead> H:Bytes => BlockCommitI(B:ProtoBlock, C:ProtoCfg) </phead>
    <pvalid> V:Bool => V:Bool </pvalid>
    requires grBlockOf(gateReceipt(B:ProtoBlock, ERC:Bytes, ERP:Bytes,
                                   "valid-g", H:Bytes, N:Int)) ==K B:ProtoBlock
         andBool grDecisionOf(gateReceipt(B:ProtoBlock, ERC:Bytes, ERP:Bytes,
                                          "valid-g", H:Bytes, N:Int))
                 ==Int pdecValid
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecValid
         andBool ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlock) ==K PolicyCommitmentI(C:ProtoCfg)
         andBool pbCtxDOf(B:ProtoBlock)
                 ==K CtxDigestI(ProtoAuthorizedSecCtx(C:ProtoCfg,
                            pbParentRootOf(B:ProtoBlock)))
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
         andBool CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
    [label(OLD-R1-ACCEPTS-CALLER-VERDICT)]

  claim // OLD-R1-PIPELINE-FORGED: PROVED (witness) — the full injected
        // pipeline: init -> the caller types "valid-g" into pGateEval ->
        // pAcceptR1 commits.  The candidate's gate-relevant evidence is
        // whatever the caller holds; R1's mint never looks at it.
    <k> pInitR1(CFG)
        ~> pGateEval(B:ProtoBlock, ERC:Bytes, ERP:Bytes, "valid-g")
        ~> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, 7:Int) => .K </k>
    <plineage> .Map
            => ( -1:Int |-> CFG )
               ( -2:Int |-> .Set )
               ( 0:Int |-> B:ProtoBlock ) </plineage>
    <pnext> 0 => 1 </pnext>
    <phead> _:Bytes => BlockCommitI(B:ProtoBlock, CFG) </phead>
    <pvalid> V:Bool => V:Bool </pvalid>
    requires CFG ==K protoCfg(CH:Bytes, 7:Int, PD:Bytes, AS:Bytes, GR:Bytes,
                              CC:Bytes, EC:Bytes, FK:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int 0
         andBool pbParentCommitOf(B:ProtoBlock) ==K ProtoRoot(CFG)
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecValid
         andBool ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlock) ==K PolicyCommitmentI(CFG)
         andBool pbCtxDOf(B:ProtoBlock)
                 ==K CtxDigestI(ProtoAuthorizedSecCtx(CFG,
                            pbParentRootOf(B:ProtoBlock)))
    [label(OLD-R1-PIPELINE-FORGED)]

endmodule
