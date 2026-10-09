// =============================================================================
// SRW3 Phase 1I-R1 — THE REPAIRED COMMITMENT/GATE-BINDING PROOF LADDER
//                    (phase1i-r1/proofs/r1_proofs.k)
//
// Backend: HASKELL (kprove).  Claims module over srw3proto-r1.k (the repaired
// transition), which is additive over the frozen srw3proto.k — Commit_P and
// all protocol predicates are UNCHANGED inherited definitions, and the
// configuration is the frozen <srw3proto> configuration (the repair stores
// the pinned configuration and the gate-receipt pool in the reserved
// negative-key region of <plineage>; see srw3proto-r1.k).
//
// THE HEADLINE (handoff, K proof requirements):
//
//   R1-ACCEPT-IMPLIES-COMMITP
//     The operational accept guard — the EXACT requires-clause of the
//     pAcceptR1 rule, copied verbatim — implies Commit_P(B, ERC, ERP, C,
//     pbParentRootOf(B)) == true, where C is the PINNED configuration.
//     Commit_P appears ONLY in the destination, never in the requires.
//     Every premise is provided by the transition rule itself.
//
//   R1-FORGED-VERDICT-REJECT (+ branches)
//     A rejection verdict recorded by the gate (e.g. "invalid-policy"),
//     bound to the exact candidate, cannot accept: the chain state is
//     unchanged.  (In the repaired syntax the caller cannot even supply a
//     verdict Boolean — the argument does not exist; the attack surface of
//     finding F2 is REMOVED, and the receipt path is guarded.)
//
//   R1-CONFIG-* 
//     The pinned configuration is written only by pInitR1 (which refuses to
//     re-pin); no gate or accept step mutates it; a config-version
//     substitution rejects with the state unchanged.
//
//   R1-STATE-UNCHANGED-ON-REJECT
//     No pool / empty pool / wrong candidate / stale head / wrong slot /
//     wrong config version => head, counter, lineage map (committed chain
//     AND metadata region) all unchanged.
//
//   R1-VALID-ACCEPT + R1-PIPELINE-HONEST
//     Non-vacuity: the honest path (valid gate verdict + all bindings) is
//     still accept-able, from the symbolic claim and the full init -> gate
//     -> accept pipeline.
//
//   R1-RECEIPT-SINGLE-USE
//     An accepted receipt is consumed; a replayed accept with the pool now
//     empty cannot extend the chain twice.
//
// PORTED FROZEN CLAIMS (re-run against the repaired model as the handoff
// requires): PI1-COMMIT-SAFETY, PI2-DECISION-REJECT, PI2-DECISION-UNKNOWN,
// PI2-EXEC-INVALID, PIB-GATELINK-*, PI5-AUTHORITY-DESCENT, PI7-BASE are
// restated verbatim (they are claims about Commit_P and inherited
// definitions, which are unchanged).  The old PI7-STEP is REPLACED by
// R1-VALID-ACCEPT: its Commit_P requires-clause is now enforced BY THE
// TRANSITION (audit finding F3).  R1-ALL is the retried forall-closure
// (outcome recorded, whatever it is).
//
// Evidence classes: PROVED BY K (hs backend) / DEMONSTRATED (Python mirror
// with real keccak) / NOT MECHANIZED (recorded with the exact blocker).
// =============================================================================

requires "../semantics/srw3proto-r1.k"

module R1-PROOFS
  imports SRW3PROTO-R1

  // ===========================================================================
  // R1-0 — initialization pins the configuration and anchors the root
  // ===========================================================================

  claim // R1-INIT-PINS: pInitR1 writes BOTH the head (protocol root) and the
        // pinned configuration (reserved key -1), from ONE argument; it
        // refuses to fire when a configuration is already pinned.
    <k> pInitR1(C:ProtoCfg) => .K </k>
    <plineage> L:Map => L:Map[-1 <- C:ProtoCfg] </plineage>
    <pnext> _:Int </pnext>
    <phead> _:Bytes => ProtoRoot(C:ProtoCfg) </phead>
    <pvalid> _:Bool </pvalid>
    requires notBool cfgPinned(L:Map)
    [label(R1-INIT-PINS)]

  claim // R1-CONFIG-IMMUTABLE: once a configuration is pinned, pInitR1
        // cannot re-pin (no in-model re-initialization; a would-be
        // re-initialization leaves the state unchanged).
    <k> pInitR1(_:ProtoCfg) => .K </k>
    <plineage> ( -1:Int |-> C1:ProtoCfg ) L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    [label(R1-CONFIG-IMMUTABLE)]

  // ===========================================================================
  // R1-1 — THE HEADLINE: the operational guard implies Commit_P
  //
  // The requires-clause is the pAcceptR1 rule's guard VERBATIM.  Commit_P
  // appears only in the destination.  This is the formal answer to finding
  // F3: the theorem no longer assumes what the transition was supposed to
  // enforce — the transition now checks every conjunct, and this claim
  // certifies that the checked set entails Commit_P.
  // ===========================================================================

  claim // R1-ACCEPT-IMPLIES-COMMITP
    <k> CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg,
                pbParentRootOf(B:ProtoBlock)) ==K true => true </k>
    requires grBlockOf(R:GateReceipt) ==K B:ProtoBlock
         andBool grErcOf(R:GateReceipt) ==K ERC:Bytes
         andBool grErpOf(R:GateReceipt) ==K ERP:Bytes
         andBool grHeadOf(R:GateReceipt) ==K H:Bytes
         andBool grSlotOf(R:GateReceipt) ==Int N:Int
         andBool grDecisionOf(R:GateReceipt) ==Int pdecValid
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecValid
         andBool ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlock) ==K PolicyCommitmentI(C:ProtoCfg)
         andBool pbCtxDOf(B:ProtoBlock)
                 ==K CtxDigestI(ProtoAuthorizedSecCtx(C:ProtoCfg,
                            pbParentRootOf(B:ProtoBlock)))
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
         andBool CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
    [label(R1-ACCEPT-IMPLIES-COMMITP)]

  // The decision-binding refinement: an accepted candidate's decision field
  // is bound to the GATE-DERIVED decision (not merely to pdecValid by
  // coincidence) — the block cannot carry a decision different from the one
  // the gate evaluation produced for it.
  claim // R1-DECISION-BOUND
    <k> pbDecisionOf(B:ProtoBlock) ==Int grDecisionOf(R:GateReceipt) => true </k>
    requires grDecisionOf(R:GateReceipt) ==Int pdecValid
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecValid
    [label(R1-DECISION-BOUND)]

  // ===========================================================================
  // R1-2 — FORGED-VERDICT REJECTION (the decisive negative test)
  //
  // The gate evaluated the candidate and recorded a rejection verdict.  The
  // receipt matches the candidate exactly, the parent/slot links and the
  // config witness all HOLD (pinned in the requires) — the ONLY failing
  // conjunct is the derived decision.  The accept cannot fire; the [owise]
  // reject leaves every cell unchanged.
  // ===========================================================================

  claim // R1-FORGED-VERDICT-REJECT (CM1): a recorded "invalid-policy"
        // verdict, matched to the exact candidate, cannot accept.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(gateReceipt(B:ProtoBlock, ERC:Bytes,
                                    ERP:Bytes, "invalid-policy", H:Bytes,
                                    N:Int)) .Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    requires CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
    [label(R1-FORGED-VERDICT-REJECT)]

  claim // R1-FORGED-VERDICT-REJECT-AUTHTYPE (CM1 representative branch 2:
        // an authority-layer rejection verdict)
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(gateReceipt(B:ProtoBlock, ERC:Bytes,
                                    ERP:Bytes, "invalid-authtype", H:Bytes,
                                    N:Int)) .Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    requires CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
    [label(R1-FORGED-VERDICT-REJECT-AUTHTYPE)]

  // ===========================================================================
  // R1-3 — STATE-UNCHANGED-ON-REJECT (the general restoration property)
  // ===========================================================================

  claim // R1-REJECT-NO-POOL (CM7a): with NO receipt-pool entry at all,
        // nothing can accept — missing evidence/decision is fail-closed.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg ) L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    requires notBool ( -2:Int in_keys(L3:Map) )
    [label(R1-REJECT-NO-POOL)]

  claim // R1-REJECT-EMPTY-POOL (CM7b): an EMPTY pool accepts nothing.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> .Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    [label(R1-REJECT-EMPTY-POOL)]

  claim // R1-REJECT-WRONG-CANDIDATE (CM5-shape): the receipt on record was
        // minted for a DIFFERENT candidate — here the receipt's bound child
        // root is 0x01 while the presented execution result is 0x02.  No
        // accept; state unchanged.  Concrete-instantiated countermodel.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(gateReceipt(B:ProtoBlock,
                                    Int2Bytes(1, 1, BE), ERP:Bytes,
                                    "valid-g", H:Bytes, N:Int)) .Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    requires ERC:Bytes ==K Int2Bytes(1, 2, BE)
         andBool CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
    [label(R1-REJECT-WRONG-CANDIDATE)]

  claim // R1-REJECT-STALE-HEAD (CM8): a receipt minted under a DISPLACED
        // head (0x01) cannot authorize a commit under the current head
        // (0x02) — the reorg/stale-evidence exclusion at the receipt
        // level.  Concrete-instantiated countermodel.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(gateReceipt(B:ProtoBlock, ERC:Bytes,
                                    ERP:Bytes, "valid-g",
                                    Int2Bytes(1, 1, BE), N:Int)) .Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> Int2Bytes(1, 2, BE) </phead>
    <pvalid> V:Bool </pvalid>
    requires CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
    [label(R1-REJECT-STALE-HEAD)]

  claim // R1-REJECT-WRONG-SLOT: a receipt minted at a different slot
        // position cannot accept at the current position.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(gateReceipt(B:ProtoBlock, ERC:Bytes,
                                    ERP:Bytes, "valid-g", H:Bytes,
                                    N:Int +Int 1)) .Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    requires CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
    [label(R1-REJECT-WRONG-SLOT)]

  // ===========================================================================
  // R1-4 — CONFIG PINNING
  // ===========================================================================

  claim // R1-CONFIG-FRAME-GATE: gate evaluation never mutates the pinned
        // configuration (nor the chain).
    <k> pGateEval(B:ProtoBlock, ERC:Bytes, ERP:Bytes, V:String) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> PS:Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(gateReceipt(B:ProtoBlock, ERC:Bytes,
                                  ERP:Bytes, V:String, H:Bytes, N:Int)) PS:Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V2:Bool </pvalid>
    requires notBool ( -2:Int in_keys(L3:Map) )
         andBool notBool ( -1:Int in_keys(L3:Map) )
    [label(R1-CONFIG-FRAME-GATE)]

  claim // R1-CONFIG-FRAME-ACCEPT: an accept (the only chain-extending rule)
        // leaves the pinned configuration unchanged — no implicit config
        // mutation through commitment.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(R:GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlock) <- B:ProtoBlock] ) </plineage>
    <pnext> N:Int => N:Int +Int 1 </pnext>
    <phead> H:Bytes => BlockCommitI(B:ProtoBlock, C:ProtoCfg) </phead>
    <pvalid> V:Bool => V:Bool </pvalid>
    requires grBlockOf(R:GateReceipt) ==K B:ProtoBlock
         andBool grErcOf(R:GateReceipt) ==K ERC:Bytes
         andBool grErpOf(R:GateReceipt) ==K ERP:Bytes
         andBool grHeadOf(R:GateReceipt) ==K H:Bytes
         andBool grSlotOf(R:GateReceipt) ==Int N:Int
         andBool grDecisionOf(R:GateReceipt) ==Int pdecValid
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecValid
         andBool ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlock) ==K PolicyCommitmentI(C:ProtoCfg)
         andBool pbCtxDOf(B:ProtoBlock)
                 ==K CtxDigestI(ProtoAuthorizedSecCtx(C:ProtoCfg,
                            pbParentRootOf(B:ProtoBlock)))
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
         andBool CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
    [label(R1-CONFIG-FRAME-ACCEPT)]

  claim // R1-CONFIG-SUB-REJECT (CM4, decidable witness): the pinned config
        // has policy version 1; the candidate declares version 2 (a policy/
        // config upgrade that was never activated).  The accept guard's
        // version check fails; state unchanged.  Concrete-instantiated
        // countermodel (a same-version content substitution is
        // distinguished by the policy-commitment equality — keccak
        // collision resistance, boundary D.2; demonstrated in the Python
        // mirror).
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, 2:Int) => .K </k>
    <plineage> ( -1:Int |-> protoCfg(CH:Bytes, 1:Int, PD:Bytes, AS:Bytes,
                                     GR:Bytes, CC:Bytes, EC:Bytes, FK:Bytes) )
               ( -2:Int |-> SetItem(gateReceipt(B:ProtoBlock, ERC:Bytes,
                                    ERP:Bytes, "valid-g", H:Bytes, N:Int)) .Set )
               L3:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> V:Bool </pvalid>
    requires BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
    [label(R1-CONFIG-SUB-REJECT)]

  // ===========================================================================
  // R1-5 — NON-VACUITY: the honest path still commits
  // ===========================================================================

  claim // R1-VALID-ACCEPT: under the full operational guard (the rule's own
        // requires, verbatim) the transition FIRES and produces the extended
        // state — safety was not obtained by making all transitions
        // impossible.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(R:GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlock) <- B:ProtoBlock] ) </plineage>
    <pnext> N:Int => N:Int +Int 1 </pnext>
    <phead> H:Bytes => BlockCommitI(B:ProtoBlock, C:ProtoCfg) </phead>
    <pvalid> V:Bool => V:Bool </pvalid>
    requires grBlockOf(R:GateReceipt) ==K B:ProtoBlock
         andBool grErcOf(R:GateReceipt) ==K ERC:Bytes
         andBool grErpOf(R:GateReceipt) ==K ERP:Bytes
         andBool grHeadOf(R:GateReceipt) ==K H:Bytes
         andBool grSlotOf(R:GateReceipt) ==Int N:Int
         andBool grDecisionOf(R:GateReceipt) ==Int pdecValid
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecValid
         andBool ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlock) ==K PolicyCommitmentI(C:ProtoCfg)
         andBool pbCtxDOf(B:ProtoBlock)
                 ==K CtxDigestI(ProtoAuthorizedSecCtx(C:ProtoCfg,
                            pbParentRootOf(B:ProtoBlock)))
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
         andBool CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
    [label(R1-VALID-ACCEPT)]

  // The full honest pipeline, concrete configuration: init -> gate("valid-g")
  // -> accept.  The receipt is consumed, the chain extends once.  (The
  // policy/context digest equalities remain symbolic constraints — boundary
  // D.2; the concrete-digest run is the Python mirror, real keccak.)
  claim // R1-PIPELINE-HONEST (CM6, K side)
    <k> pInitR1(CFG) ~> pGateEval(B:ProtoBlock, ERC:Bytes, ERP:Bytes, "valid-g")
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
    [label(R1-PIPELINE-HONEST)]

  // ===========================================================================
  // R1-6 — RECEIPT SINGLE-USE (no replay through the receipt pool)
  // ===========================================================================

  claim // R1-RECEIPT-SINGLE-USE: with exactly ONE matching receipt, the
        // first accept consumes it and commits; the replayed accept finds
        // an empty pool and rejects — the counter advances by ONE.
    <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int)
        ~> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <plineage> ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> SetItem(R:GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfg )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlock) <- B:ProtoBlock] ) </plineage>
    <pnext> N:Int => N:Int +Int 1 </pnext>
    <phead> H:Bytes => BlockCommitI(B:ProtoBlock, C:ProtoCfg) </phead>
    <pvalid> V:Bool => V:Bool </pvalid>
    requires grBlockOf(R:GateReceipt) ==K B:ProtoBlock
         andBool grErcOf(R:GateReceipt) ==K ERC:Bytes
         andBool grErpOf(R:GateReceipt) ==K ERP:Bytes
         andBool grHeadOf(R:GateReceipt) ==K H:Bytes
         andBool grSlotOf(R:GateReceipt) ==Int N:Int
         andBool grDecisionOf(R:GateReceipt) ==Int pdecValid
         andBool pbDecisionOf(B:ProtoBlock) ==Int pdecValid
         andBool ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlock) ==K PolicyCommitmentI(C:ProtoCfg)
         andBool pbCtxDOf(B:ProtoBlock)
                 ==K CtxDigestI(ProtoAuthorizedSecCtx(C:ProtoCfg,
                            pbParentRootOf(B:ProtoBlock)))
         andBool BytesEq(pbParentCommitOf(B:ProtoBlock), H:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int N:Int
         andBool CV:Int ==Int pcPolicyVOf(C:ProtoCfg)
    [label(R1-RECEIPT-SINGLE-USE)]

  // ===========================================================================
  // R1-7 — the full FORGED pipeline, end to end (CM1 as a closed countermodel)
  //
  // init under a concrete config -> the gate evaluates the candidate and
  // records "invalid-policy" -> the caller attempts the accept anyway (with
  // the CORRECT config version, correct parent link, correct slot): the
  // chain is NOT extended, the counter does NOT advance, and the receipt
  // REMAINS in the pool (it was never consumed).
  // ===========================================================================

  claim // R1-PIPELINE-FORGED (CM1 end-to-end)
    <k> pInitR1(CFG)
        ~> pGateEval(B:ProtoBlock, ERC:Bytes, ERP:Bytes, "invalid-policy")
        ~> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, 7:Int) => .K </k>
    <plineage> .Map
            => ( -1:Int |-> CFG )
               ( -2:Int |-> SetItem(gateReceipt(B:ProtoBlock, ERC:Bytes,
                                    ERP:Bytes, "invalid-policy",
                                    ProtoRoot(CFG), 0:Int)) .Set ) </plineage>
    <pnext> 0 </pnext>
    <phead> ProtoRoot(CFG) </phead>
    <pvalid> V:Bool => V:Bool </pvalid>
    requires CFG ==K protoCfg(CH:Bytes, 7:Int, PD:Bytes, AS:Bytes, GR:Bytes,
                              CC:Bytes, EC:Bytes, FK:Bytes)
         andBool pbSlotOf(B:ProtoBlock) ==Int 0
         andBool pbParentCommitOf(B:ProtoBlock) ==K ProtoRoot(CFG)
    [label(R1-PIPELINE-FORGED)]

  // ===========================================================================
  // R1-8 — PORTED FROZEN CLAIMS (re-run against the repaired model; the
  // predicates they reference are unchanged definitions)
  // ===========================================================================

  claim // PI1-COMMIT-SAFETY (ported verbatim from phase1i/proofs/pi_proofs.k)
    <k> CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
        ==K true => true </k>
    requires ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
     andBool pbDecisionOf(B:ProtoBlock) ==Int pdecValid
     andBool pbPolCommitOf(B:ProtoBlock) ==K PolicyCommitmentI(C:ProtoCfg)
     andBool pbCtxDOf(B:ProtoBlock)
             ==K CtxDigestI(ProtoAuthorizedSecCtx(C:ProtoCfg, LH:Bytes))
    [label(PI1-COMMIT-SAFETY)]

  claim // PI2-DECISION-REJECT (ported verbatim)
    <k> CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlock) ==Int pdecReject
    [label(PI2-DECISION-REJECT)]

  claim // PI2-DECISION-UNKNOWN (ported verbatim)
    <k> CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlock) ==Int pdecUnknown
    [label(PI2-DECISION-UNKNOWN)]

  claim // PI2-EXEC-INVALID (ported verbatim)
    <k> CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
        ==K false => true </k>
    requires notBool ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
    [label(PI2-EXEC-INVALID)]

  claim // PIB-GATELINK-VALID (ported verbatim)
    <k> ProtoDecisionOfGate("valid-g") ==K pdecValid => true </k>
    [label(PIB-GATELINK-VALID)]

  claim // PIB-GATELINK-REJECT1 (ported verbatim)
    <k> CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlock) ==K ProtoDecisionOfGate("invalid-authtype")
    [label(PIB-GATELINK-REJECT1)]

  claim // PIB-GATELINK-REJECT2 (ported verbatim)
    <k> CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlock) ==K ProtoDecisionOfGate("invalid-authsrc")
    [label(PIB-GATELINK-REJECT2)]

  claim // PIB-GATELINK-REJECT3 (ported verbatim)
    <k> CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlock) ==K ProtoDecisionOfGate("invalid-policy")
    [label(PIB-GATELINK-REJECT3)]

  claim // PI5-AUTHORITY-DESCENT (ported verbatim)
    <k> PolicyCommitmentI(C:ProtoCfg) ==K LinH(
          Int2Bytes(1, 157, BE)
          +Bytes I2B4(pcPolicyVOf(C:ProtoCfg)) +Bytes pcPolicyDOf(C:ProtoCfg)
          +Bytes pcAppSetDOf(C:ProtoCfg) +Bytes pcGraphDOf(C:ProtoCfg)
          +Bytes LinH( Int2Bytes(1, 165, BE)
                       +Bytes pcChainIdOf(C:ProtoCfg)
                       +Bytes pcForkOf(C:ProtoCfg) ) )
        => true </k>
    [label(PI5-AUTHORITY-DESCENT)]

  claim // PI7-BASE (ported verbatim)
    <k> CommitChainLinked(.Map, 0, C:ProtoCfg) => true </k>
    [label(PI7-BASE)]

  // PI7-STEP is REPLACED by R1-VALID-ACCEPT (the Commit_P premise of the old
  // claim is now enforced by the transition; see the audit, finding F3).

  // ===========================================================================
  // R1-9 — the retried forall-closure (the PI7-ALL analog).  OUTCOME IS
  // RECORDED WHATEVER IT IS; if the kore circularity implication check
  // blocks it again, the claim is classified NOT MECHANIZED with the exact
  // message retained in transcripts/k/.
  // ===========================================================================

  claim
    <k> pCons(CI:PCmdI, RUN:PRunI) => .K </k>
    <plineage> L:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> true </pvalid>
    [circularity, label(R1-ALL)]

endmodule
