// =============================================================================
// SRW3 Phase 1I-R1 — THE FROZEN MODEL'S FORGED-VERDICT WITNESS
//                    (phase1i-r1/proofs/old_witness.k)
//
// Backend: HASKELL (kprove).  Claims over the UNMODIFIED frozen Phase 1I
// module (phase1i/semantics/srw3proto.k).  These claims are the mechanical
// WITNESS of audit finding F2: the frozen operational accept extends the
// committed chain with NO validity premise of any kind.  They are proved BY
// the frozen rule itself — that is the point: the frozen transition needs
// only the structural links and SRW3OK == true.
//
// OLD-ACCEPTS-FORGED: for an ARBITRARY candidate block (no validity premise
// at all), pAccept(..., SRW3OK = true) extends the chain.
//
// OLD-ACCEPTS-INVALID-DECISION: the candidate is KNOWN-invalid — its
// decision field is pdecReject (the gate said reject).  The frozen rule
// still accepts: the decision field is never consulted by the transition.
// This is the exact "invalid block + caller-supplied accepting verdict"
// scenario of the assignment's decisive test, witnessed on the frozen
// model.  The repaired model's answer is R1-FORGED-VERDICT-REJECT /
// R1-PIPELINE-FORGED (r1_proofs.k).
//
// OLD-ACCEPTS-CALLER-CONFIG (F4): the caller presents a config C2 at accept
// time; the frozen rule commits under it — nothing pins the initialization
// configuration.  (The head is updated under the caller-chosen C2.)
// =============================================================================

requires "../../phase1i/semantics/srw3proto.k"

module OLD-WITNESS
  imports SRW3PROTO

  claim // OLD-ACCEPTS-FORGED: arbitrary block + verdict true => chain extends
    <k> pAccept(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, true)
          => .K </k>
    <plineage> L:Map => L:Map[pbSlotOf(B:ProtoBlock) <- B:ProtoBlock] </plineage>
    <pnext> N:Int => N:Int +Int 1 </pnext>
    <phead> H:Bytes => BlockCommitI(B:ProtoBlock, C:ProtoCfg) </phead>
    <pvalid> true => true </pvalid>
    requires BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
    [label(OLD-ACCEPTS-FORGED)]

  claim // OLD-ACCEPTS-INVALID-DECISION: a gate-REJECTED candidate is
        // operationally committed by the frozen rule when the caller
        // supplies the accepting Boolean.
    <k> pAccept(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, true)
          => .K </k>
    <plineage> L:Map => L:Map[pbSlotOf(B:ProtoBlock) <- B:ProtoBlock] </plineage>
    <pnext> N:Int => N:Int +Int 1 </pnext>
    <phead> H:Bytes => BlockCommitI(B:ProtoBlock, C:ProtoCfg) </phead>
    <pvalid> true => true </pvalid>
    requires BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecReject
    [label(OLD-ACCEPTS-INVALID-DECISION)]

  claim // OLD-ACCEPTS-UNKNOWN-DECISION: even a missing/unknown decision
        // (pdecUnknown) is committed by the frozen rule under SRW3OK=true.
    <k> pAccept(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, true)
          => .K </k>
    <plineage> L:Map => L:Map[pbSlotOf(B:ProtoBlock) <- B:ProtoBlock] </plineage>
    <pnext> N:Int => N:Int +Int 1 </pnext>
    <phead> H:Bytes => BlockCommitI(B:ProtoBlock, C:ProtoCfg) </phead>
    <pvalid> true => true </pvalid>
    requires BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecUnknown
    [label(OLD-ACCEPTS-UNKNOWN-DECISION)]

  // OLD-ACCEPTS-CALLER-CONFIG — the init-chained form of the F4 witness
  // (pInit(C1) then pAccept under a caller-chosen C2) was attempted and is
  // NOT MECHANIZED on the Haskell backend: chaining the accept after pInit
  // forces the block's parent-commitment field to unify against the
  // evaluated protocol root Keccak256raw(ProtoCfgCanon(C1)), which leaks
  // uninterpreted nested keccak terms into the block constructor; the
  // resulting #Ceil(Keccak256raw(...Keccak256raw(...))) definedness
  // obligations cannot be discharged without keccak evaluators (finding
  // 1C-1 discipline).  Log: transcripts/k/kprove_OLD-ACCEPTS-CALLER-CONFIG.log.
  // The F4 vulnerability is witnessed at the single-step level by
  // OLD-ACCEPTS-FORGED above (the accept command's caller-chosen C2 flows
  // into the head commitment with no comparison against any stored
  // configuration — none exists in the frozen model), by the source-level
  // analysis in audit/FORMAL-BINDING-AUDIT.md (F4), and concretely with
  // real keccak digests by the Python mirror (transcripts/attacks/,
  // R1-CM4 before/after).
  //
  // Attempt retained for the record:
  //
  // claim
  //   <k> pInit(C1:ProtoCfg)
  //       ~> pAccept(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C2:ProtoCfg, true)
  //       => .K </k>
  //   <plineage> .Map => ( 0:Int |-> B:ProtoBlock ) </plineage>
  //   <pnext> 0 => 1 </pnext>
  //   <phead> _:Bytes => H2:Bytes </phead>
  //   <pvalid> true => true </pvalid>
  //   requires pbSlotOf(B:ProtoBlock) ==Int 0
  //        andBool pbParentCommitOf(B:ProtoBlock) ==K ProtoRoot(C1:ProtoCfg)
  //        andBool H2:Bytes ==K BlockCommitI(B:ProtoBlock, C2:ProtoCfg)
  //   [label(OLD-ACCEPTS-CALLER-CONFIG)]

endmodule
