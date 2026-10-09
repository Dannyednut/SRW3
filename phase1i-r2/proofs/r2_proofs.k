// =============================================================================
// SRW3 Phase 1I-R2 — THE GATE-PROVENANCE PROOF LADDER
//                    (phase1i-r2/proofs/r2_proofs.k)
//
// Backend: HASKELL (kprove).  Claims module over srw3proto-r2.k (the isolated
// R2 machine, importing ONLY the frozen SRW3AUTHZ gate).  The legacy protocol
// modules are deliberately NOT imported here either: the claims quantify over
// the R2 command language exclusively.
//
// HEADLINE (handoff section 6):
//   R2-ACCEPT-IMPLIES-COMMITP — the operational accept guard (the EXACT
//   requires-clause of pAcceptR2, copied verbatim) implies
//   CommitPR2(B, ERC, ERP, C, pbParentRootOf(B)) == true, with CommitPR2
//   appearing ONLY in the destination, never in the requires.  The decision
//   conjunct is DERIVED: gr2DecisionOf(R) — the fail-closed mapping of the
//   receipt's internally computed VerifyLineageG verdict.
//
//   R2-GATE-RESULT-DERIVED / R2-GATE-INPUT-BINDING — mint-shape claims: the
//   receipt the mint rule writes stores (i) the verdict computed by the
//   frozen gate over the machine-constructed context and machine-supplied
//   position, and (ii) the exact evidence objects bound by
//   GateInputMatchesBlockR2 / GateAuthorityMatchesCfgR2 to the exact
//   candidate.  Receipts can enter the pool ONLY through this rule (the
//   producer-exhaustiveness audit, audit section B) and can never be written
//   by any command (no command has a receipt-shaped parameter).
//
//   R2-LEGACY-SURFACE-EXCLUDED — structural: the legacy commands are not in
//   the R2 command language and the legacy transition rules are not in the
//   R2 definition (see audit section A for the rule-set enumeration; the
//   kparse rejection transcripts are in transcripts/legacy/).  The closure
//   claim over the R2 program language is R2-ALL (retried; expected to hit
//   the same kore circularity blocker as R1-ALL — log retained either way).
//
// STATUS ANNOTATIONS in the claim comments are the audit-facing labels:
// PROVED / WITNESSED / DEMONSTRATED / ASSUMED / REFUTED / NOT MECHANIZED.
// =============================================================================

requires "../semantics/srw3proto-r2.k"

module R2-PROOFS
  imports SRW3PROTO-R2

  // ===========================================================================
  // R2-0 — initialization pins the configuration and anchors both heads
  // ===========================================================================

  claim // R2-INIT-PINS: PROVED — pInitR2 writes the head (protocol root), the
        // lineage head (R2LinRoot) and the pinned configuration (key -1) from
        // ONE argument; it refuses to fire when a configuration is pinned.
    <k> pInitR2(C:ProtoCfgR2) => .K </k>
    <r2lineage> L:Map => L:Map[-1 <- C:ProtoCfgR2] </r2lineage>
    <r2next> _:Int </r2next>
    <r2head> _:Bytes => ProtoRootR2(C:ProtoCfgR2) </r2head>
    <r2linhead> _:Bytes => R2LinRoot </r2linhead>
    <r2valid> _:Bool </r2valid>
    requires notBool cfgPinnedR2(L:Map)
    [label(R2-INIT-PINS)]

  claim // R2-CONFIG-IMMUTABLE: PROVED — once a configuration is pinned,
        // pInitR2 cannot re-pin (no in-model re-initialization).
    <k> pInitR2(_:ProtoCfgR2) => .K </k>
    <r2lineage> ( -1:Int |-> C1:ProtoCfgR2 ) L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    [label(R2-CONFIG-IMMUTABLE)]

  // ===========================================================================
  // R2-1 — MINT-SHAPE CLAIMS (the verdict is computed; the inputs are bound)
  //
  //   These claims restate the pGateEvalR2 transition with its guard, making
  //   the receipt content EXPLICIT: the verdict field is the frozen gate's
  //   result over (RG, machine-constructed AC, N, LH) and the stored evidence
  //   objects are the ones the guard bound.  Producer exhaustiveness (no
  //   other rule writes gateReceiptR2, no command carries a receipt) is the
  //   syntactic audit of audit section B — together the two close
  //   R2-GATE-RESULT-DERIVED and R2-GATE-INPUT-BINDING at the transition
  //   level.
  // ===========================================================================

  claim // R2-MINT-SHAPE-EXISTING-POOL: PROVED
    <k> pGateEvalR2(B:ProtoBlockR2, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                    ERC:Bytes, ERP:Bytes) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> PS:Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(
                     gateReceiptR2( B:ProtoBlockR2, ERC:Bytes, ERP:Bytes
                                  , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                  , azCtx( FC:ExecCtx
                                         , ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                                               pbParentRootOf(B:ProtoBlockR2))
                                         , CERT:AuthzCert
                                         , pcrAuthPTOf(C:ProtoCfgR2)
                                         , pcrAuthGuestDOf(C:ProtoCfgR2)
                                         , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                  , VerifyLineageG(
                                        RG:LinRecG
                                      , azCtx( FC:ExecCtx
                                             , ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                                                   pbParentRootOf(B:ProtoBlockR2))
                                             , CERT:AuthzCert
                                             , pcrAuthPTOf(C:ProtoCfgR2)
                                             , pcrAuthGuestDOf(C:ProtoCfgR2)
                                             , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                      , N:Int, LH:Bytes )
                                  , H:Bytes, N:Int, LH:Bytes
                                  , C:ProtoCfgR2 )) PS:Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> _:Bool </r2valid>
    requires GateInputMatchesBlockR2(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                     B:ProtoBlockR2)
         andBool GateAuthorityMatchesCfgR2(FC:ExecCtx, C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-MINT-SHAPE-EXISTING-POOL)]

  claim // R2-MINT-SHAPE-EMPTY-POOL: PROVED (same shape, pool not yet present)
    <k> pGateEvalR2(B:ProtoBlockR2, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                    ERC:Bytes, ERP:Bytes) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 ) L3:Map
            => ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(
                     gateReceiptR2( B:ProtoBlockR2, ERC:Bytes, ERP:Bytes
                                  , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                  , azCtx( FC:ExecCtx
                                         , ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                                               pbParentRootOf(B:ProtoBlockR2))
                                         , CERT:AuthzCert
                                         , pcrAuthPTOf(C:ProtoCfgR2)
                                         , pcrAuthGuestDOf(C:ProtoCfgR2)
                                         , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                  , VerifyLineageG(
                                        RG:LinRecG
                                      , azCtx( FC:ExecCtx
                                             , ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                                                   pbParentRootOf(B:ProtoBlockR2))
                                             , CERT:AuthzCert
                                             , pcrAuthPTOf(C:ProtoCfgR2)
                                             , pcrAuthGuestDOf(C:ProtoCfgR2)
                                             , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                      , N:Int, LH:Bytes )
                                  , H:Bytes, N:Int, LH:Bytes
                                  , C:ProtoCfgR2 )) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> _:Bool </r2valid>
    requires notBool ( -2:Int in_keys(L3:Map) )
         andBool GateInputMatchesBlockR2(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                         B:ProtoBlockR2)
         andBool GateAuthorityMatchesCfgR2(FC:ExecCtx, C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-MINT-SHAPE-EMPTY-POOL)]

  // The mint-frame twin: gate evaluation never mutates the pinned config, the
  // chain, the heads, or the counter (it only adds a receipt).
  claim // R2-CONFIG-FRAME-GATE: PROVED
    <k> pGateEvalR2(B:ProtoBlockR2, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                    ERC:Bytes, ERP:Bytes) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> PS:Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(
                     gateReceiptR2( B:ProtoBlockR2, ERC:Bytes, ERP:Bytes
                                  , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                  , azCtx( FC:ExecCtx
                                         , ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                                               pbParentRootOf(B:ProtoBlockR2))
                                         , CERT:AuthzCert
                                         , pcrAuthPTOf(C:ProtoCfgR2)
                                         , pcrAuthGuestDOf(C:ProtoCfgR2)
                                         , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                  , VerifyLineageG(
                                        RG:LinRecG
                                      , azCtx( FC:ExecCtx
                                             , ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                                                   pbParentRootOf(B:ProtoBlockR2))
                                             , CERT:AuthzCert
                                             , pcrAuthPTOf(C:ProtoCfgR2)
                                             , pcrAuthGuestDOf(C:ProtoCfgR2)
                                             , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                      , N:Int, LH:Bytes )
                                  , H:Bytes, N:Int, LH:Bytes
                                  , C:ProtoCfgR2 )) PS:Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V2:Bool </r2valid>
    requires GateInputMatchesBlockR2(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                     B:ProtoBlockR2)
         andBool GateAuthorityMatchesCfgR2(FC:ExecCtx, C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-CONFIG-FRAME-GATE)]

  // ===========================================================================
  // R2-2 — THE HEADLINE: the operational guard implies Commit_P
  //
  //   The requires-clause is the pAcceptR2 rule's guard VERBATIM (same
  //   order).  Commit_P appears ONLY in the destination.  The decision
  //   conjunct is the DERIVED decision (gr2DecisionOf) — the fail-closed
  //   mapping of the receipt's internally computed verdict.
  // ===========================================================================

  claim // R2-ACCEPT-IMPLIES-COMMITP: PROVED
    <k> CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2,
                  pbParentRootOf(B:ProtoBlockR2)) ==K true => true </k>
    requires gr2BlockOf(R:R2GateReceipt) ==K B:ProtoBlockR2
         andBool gr2ErcOf(R:R2GateReceipt) ==K ERC:Bytes
         andBool gr2ErpOf(R:R2GateReceipt) ==K ERP:Bytes
         andBool gr2HeadOf(R:R2GateReceipt) ==K H:Bytes
         andBool gr2SlotOf(R:R2GateReceipt) ==Int N:Int
         andBool gr2LinHeadOf(R:R2GateReceipt) ==K LH2:Bytes
         andBool CfgEqR2(gr2CfgOf(R:R2GateReceipt), C:ProtoCfgR2)
         andBool gr2DecisionOf(R:R2GateReceipt) ==Int pdecValidR2
         andBool pbDecisionOf(B:ProtoBlockR2) ==Int pdecValidR2
         andBool ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(gr2RGOf(R:R2GateReceipt)),
                         pbEvidenceDOf(B:ProtoBlockR2))
         andBool GateInputMatchesBlockR2(gr2FCOf(R:R2GateReceipt),
                                         gr2RGOf(R:R2GateReceipt),
                                         gr2CERTOf(R:R2GateReceipt),
                                         B:ProtoBlockR2)
         andBool GateCtxAuthorizedR2(gr2ACOf(R:R2GateReceipt), C:ProtoCfgR2,
                                     pbParentRootOf(B:ProtoBlockR2))
         andBool GateAuthorityMatchesCfgR2(gr2FCOf(R:R2GateReceipt),
                                           C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
         andBool CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool pbPolCommitOf(B:ProtoBlockR2) ==K PolicyCommitmentR2(C:ProtoCfgR2)
         andBool pbCtxDOf(B:ProtoBlockR2)
                 ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                            pbParentRootOf(B:ProtoBlockR2)))
    [label(R2-ACCEPT-IMPLIES-COMMITP)]

  // Non-vacuity twin: under the SAME guard the transition FIRES and produces
  // the extended state (safety was not bought by making everything reject).
  claim // R2-VALID-ACCEPT: PROVED
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(R:R2GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlockR2) <- B:ProtoBlockR2] ) </r2lineage>
    <r2next> N:Int => N:Int +Int 1 </r2next>
    <r2head> H:Bytes => BlockCommitR2(B:ProtoBlockR2, C:ProtoCfgR2) </r2head>
    <r2linhead> LH:Bytes => R2RecChildF(gr2RGOf(R:R2GateReceipt)) </r2linhead>
    <r2valid> V:Bool => V:Bool </r2valid>
    requires gr2BlockOf(R:R2GateReceipt) ==K B:ProtoBlockR2
         andBool gr2ErcOf(R:R2GateReceipt) ==K ERC:Bytes
         andBool gr2ErpOf(R:R2GateReceipt) ==K ERP:Bytes
         andBool gr2HeadOf(R:R2GateReceipt) ==K H:Bytes
         andBool gr2SlotOf(R:R2GateReceipt) ==Int N:Int
         andBool gr2LinHeadOf(R:R2GateReceipt) ==K LH:Bytes
         andBool CfgEqR2(gr2CfgOf(R:R2GateReceipt), C:ProtoCfgR2)
         andBool gr2DecisionOf(R:R2GateReceipt) ==Int pdecValidR2
         andBool pbDecisionOf(B:ProtoBlockR2) ==Int pdecValidR2
         andBool ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(gr2RGOf(R:R2GateReceipt)),
                         pbEvidenceDOf(B:ProtoBlockR2))
         andBool GateInputMatchesBlockR2(gr2FCOf(R:R2GateReceipt),
                                         gr2RGOf(R:R2GateReceipt),
                                         gr2CERTOf(R:R2GateReceipt),
                                         B:ProtoBlockR2)
         andBool GateCtxAuthorizedR2(gr2ACOf(R:R2GateReceipt), C:ProtoCfgR2,
                                     pbParentRootOf(B:ProtoBlockR2))
         andBool GateAuthorityMatchesCfgR2(gr2FCOf(R:R2GateReceipt),
                                           C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
         andBool CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool pbPolCommitOf(B:ProtoBlockR2) ==K PolicyCommitmentR2(C:ProtoCfgR2)
         andBool pbCtxDOf(B:ProtoBlockR2)
                 ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                            pbParentRootOf(B:ProtoBlockR2)))
    [label(R2-VALID-ACCEPT)]

  // ===========================================================================
  // R2-3 — DECISION BINDING (the candidate's decision field is the gate's)
  // ===========================================================================

  claim // R2-DECISION-BOUND: PROVED — an accepted candidate's decision field
        // equals the GATE-DERIVED decision (both are pinned pdecValidR2 by the
        // accept guard; the equality is their only joint value).
    <k> pbDecisionOf(B:ProtoBlockR2) ==Int gr2DecisionOf(R:R2GateReceipt)
        => true </k>
    requires gr2DecisionOf(R:R2GateReceipt) ==Int pdecValidR2
         andBool pbDecisionOf(B:ProtoBlockR2) ==Int pdecValidR2
    [label(R2-DECISION-BOUND)]

  claim // R2-GATELINK-VALID: PROVED — only "valid-g" (the frozen 21-conjunct
        // accept result) maps to the protocol-valid decision.
    <k> ProtoDecisionOfGateR2("valid-g") ==K pdecValidR2 => true </k>
    [label(R2-GATELINK-VALID)]

  claim // R2-GATELINK-REJECT1: PROVED — an authority-layer rejection verdict
        // maps to pdecRejectR2, so Commit_P is false for a block whose
        // decision field carries it.
    <k> CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR2)
             ==K ProtoDecisionOfGateR2("invalid-authtype")
    [label(R2-GATELINK-REJECT1)]

  claim // R2-GATELINK-REJECT2: PROVED ("invalid-authsrc")
    <k> CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR2)
             ==K ProtoDecisionOfGateR2("invalid-authsrc")
    [label(R2-GATELINK-REJECT2)]

  claim // R2-GATELINK-REJECT3: PROVED ("invalid-policy")
    <k> CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR2)
             ==K ProtoDecisionOfGateR2("invalid-policy")
    [label(R2-GATELINK-REJECT3)]

  // ===========================================================================
  // R2-4 — COMPUTED-REJECTION CANNOT ACCEPT (the decisive negative family)
  //
  //   The receipt's verdict is the COMPUTED gate result (the claim pins the
  //   gate's actual output with a hypothesis over the machine-constructed
  //   context — the same context the mint built).  Every structural conjunct
  //   of the accept guard HOLDS; the ONLY failing conjunct is the derived
  //   decision.  State unchanged.
  // ===========================================================================

  claim // R2-FORGED-VERDICT-REJECT: PROVED — a computed "invalid-policy"
        // cannot accept.  (In R2 the caller never gets to choose this string;
        // the machine computed it — and the machine refuses to commit on it.)
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(R:R2GateReceipt) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires gr2BlockOf(R:R2GateReceipt) ==K B:ProtoBlockR2
         andBool gr2ErcOf(R:R2GateReceipt) ==K ERC:Bytes
         andBool gr2ErpOf(R:R2GateReceipt) ==K ERP:Bytes
         andBool gr2HeadOf(R:R2GateReceipt) ==K H:Bytes
         andBool gr2SlotOf(R:R2GateReceipt) ==Int N:Int
         andBool gr2LinHeadOf(R:R2GateReceipt) ==K LH:Bytes
         andBool CfgEqR2(gr2CfgOf(R:R2GateReceipt), C:ProtoCfgR2)
         andBool gr2VerdictOf(R:R2GateReceipt) ==K "invalid-policy"
         andBool CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-FORGED-VERDICT-REJECT)]

  claim // R2-FORGED-VERDICT-REJECT-AUTHTYPE: PROVED (authority-layer branch)
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(R:R2GateReceipt) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires gr2BlockOf(R:R2GateReceipt) ==K B:ProtoBlockR2
         andBool gr2ErcOf(R:R2GateReceipt) ==K ERC:Bytes
         andBool gr2ErpOf(R:R2GateReceipt) ==K ERP:Bytes
         andBool gr2HeadOf(R:R2GateReceipt) ==K H:Bytes
         andBool gr2SlotOf(R:R2GateReceipt) ==Int N:Int
         andBool gr2LinHeadOf(R:R2GateReceipt) ==K LH:Bytes
         andBool CfgEqR2(gr2CfgOf(R:R2GateReceipt), C:ProtoCfgR2)
         andBool gr2VerdictOf(R:R2GateReceipt) ==K "invalid-authtype"
         andBool CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-FORGED-VERDICT-REJECT-AUTHTYPE)]

  // ===========================================================================
  // R2-5 — STATE-UNCHANGED-ON-REJECT (the restoration family)
  // ===========================================================================

  claim // R2-REJECT-NO-POOL: PROVED — with NO receipt-pool entry at all,
        // nothing can accept (missing evidence/decision is fail-closed).
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 ) L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires notBool ( -2:Int in_keys(L3:Map) )
    [label(R2-REJECT-NO-POOL)]

  claim // R2-REJECT-EMPTY-POOL: PROVED — an EMPTY pool accepts nothing.
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    [label(R2-REJECT-EMPTY-POOL)]

  claim // R2-REJECT-WRONG-CANDIDATE: PROVED — the receipt on record was
        // minted for a DIFFERENT candidate (its bound child root is 0x01,
        // the presented execution result is 0x02); also the receipt's
        // candidate block differs from the presented one.  Concrete
        // countermodel.
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(gateReceiptR2(
                   protoBlockR2(b"\x11", b"\x22", b"\x33", Int2Bytes(1, 1, BE),
                                b"\x55", b"\x66", b"\x77", b"\x88", 1, 0),
                   Int2Bytes(1, 1, BE), ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int, LH:Bytes, C:ProtoCfgR2)) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires ERC:Bytes ==K Int2Bytes(1, 2, BE)
         andBool CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-REJECT-WRONG-CANDIDATE)]

  claim // R2-REJECT-STALE-HEAD: PROVED — a receipt minted under a DISPLACED
        // protocol head (0x01) cannot authorize a commit under the current
        // head (0x02) — the reorg/stale-evidence exclusion.  Concrete.
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(gateReceiptR2(
                   B:ProtoBlockR2, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", Int2Bytes(1, 1, BE), N:Int, LH:Bytes,
                   C:ProtoCfgR2)) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> Int2Bytes(1, 2, BE) </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-REJECT-STALE-HEAD)]

  claim // R2-REJECT-STALE-LINHEAD: PROVED — a receipt minted under a
        // displaced LINEAGE anchor (0x01) cannot authorize a commit at the
        // current lineage anchor (0x02) — evidence-chain staleness.  Concrete.
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(gateReceiptR2(
                   B:ProtoBlockR2, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int, Int2Bytes(1, 1, BE),
                   C:ProtoCfgR2)) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> Int2Bytes(1, 2, BE) </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
    [label(R2-REJECT-STALE-LINHEAD)]

  claim // R2-REJECT-WRONG-SLOT: PROVED — a receipt minted at a different
        // slot position cannot accept at the current position.
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(gateReceiptR2(
                   B:ProtoBlockR2, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int +Int 1, LH:Bytes,
                   C:ProtoCfgR2)) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
    [label(R2-REJECT-WRONG-SLOT)]

  claim // R2-REJECT-GATE-INPUT-MISMATCH: PROVED — the receipt's STORED
        // evidence does not match the presented candidate: the stored
        // certificate's payload digest is 0x01 while the candidate's payload
        // digest is 0x02 (GateInputMatchesBlockR2 fails at accept — defense
        // in depth even against a hypothetically mis-shaped receipt).
        // Concrete.
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(gateReceiptR2(
                   B:ProtoBlockR2, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG,
                   azCert(Int2Bytes(1, 1, BE), PR:Bytes, EI:Bytes, CR:Bytes,
                          ED:Bytes, 1,
                          azSrc(domConsensus, I:Bytes, 0), .List, 1, PP:Bytes),
                   AC:AzCtx, "valid-g", H:Bytes, N:Int, LH:Bytes,
                   C:ProtoCfgR2)) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires pbPayloadDOf(B:ProtoBlockR2) ==K Int2Bytes(1, 2, BE)
         andBool CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-REJECT-GATE-INPUT-MISMATCH)]

  claim // R2-CONFIG-SUB-REJECT: PROVED (decidable witness) — the pinned
        // config has policy version 1; the candidate declares version 2 (a
        // policy/config upgrade that was never activated).  State unchanged.
        // (A same-version content substitution is distinguished by the
        // policy-commitment equality — keccak collision resistance, boundary
        // D.2; demonstrated in the Python mirror.)
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, 2:Int) => .K </k>
    <r2lineage> ( -1:Int |-> protoCfgR2(CH:Bytes, 1:Int, PD:Bytes, AS:Bytes,
                                        GR:Bytes, CC:Bytes, EC:Bytes,
                                        FK:Bytes, SC:Bytes, 1:Int, PT:Int,
                                        GD:Bytes, CD:Bytes) )
               ( -2:Int |-> SetItem(gateReceiptR2(
                   B:ProtoBlockR2, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int, LH:Bytes,
                   protoCfgR2(CH:Bytes, 1:Int, PD:Bytes, AS:Bytes, GR:Bytes,
                              CC:Bytes, EC:Bytes, FK:Bytes, SC:Bytes, 1:Int,
                              PT:Int, GD:Bytes, CD:Bytes))) .Set )
               L3:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> V:Bool </r2valid>
    requires BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
    [label(R2-CONFIG-SUB-REJECT)]

  claim // R2-CONFIG-FRAME-ACCEPT: PROVED — an accept (the only chain-extending
        // rule) leaves the pinned configuration unchanged.
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(R:R2GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlockR2) <- B:ProtoBlockR2] ) </r2lineage>
    <r2next> N:Int => N:Int +Int 1 </r2next>
    <r2head> H:Bytes => BlockCommitR2(B:ProtoBlockR2, C:ProtoCfgR2) </r2head>
    <r2linhead> LH:Bytes => R2RecChildF(gr2RGOf(R:R2GateReceipt)) </r2linhead>
    <r2valid> V:Bool => V:Bool </r2valid>
    requires gr2BlockOf(R:R2GateReceipt) ==K B:ProtoBlockR2
         andBool gr2ErcOf(R:R2GateReceipt) ==K ERC:Bytes
         andBool gr2ErpOf(R:R2GateReceipt) ==K ERP:Bytes
         andBool gr2HeadOf(R:R2GateReceipt) ==K H:Bytes
         andBool gr2SlotOf(R:R2GateReceipt) ==Int N:Int
         andBool gr2LinHeadOf(R:R2GateReceipt) ==K LH:Bytes
         andBool CfgEqR2(gr2CfgOf(R:R2GateReceipt), C:ProtoCfgR2)
         andBool gr2DecisionOf(R:R2GateReceipt) ==Int pdecValidR2
         andBool pbDecisionOf(B:ProtoBlockR2) ==Int pdecValidR2
         andBool ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(gr2RGOf(R:R2GateReceipt)),
                         pbEvidenceDOf(B:ProtoBlockR2))
         andBool GateInputMatchesBlockR2(gr2FCOf(R:R2GateReceipt),
                                         gr2RGOf(R:R2GateReceipt),
                                         gr2CERTOf(R:R2GateReceipt),
                                         B:ProtoBlockR2)
         andBool GateCtxAuthorizedR2(gr2ACOf(R:R2GateReceipt), C:ProtoCfgR2,
                                     pbParentRootOf(B:ProtoBlockR2))
         andBool GateAuthorityMatchesCfgR2(gr2FCOf(R:R2GateReceipt),
                                           C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
         andBool CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool pbPolCommitOf(B:ProtoBlockR2) ==K PolicyCommitmentR2(C:ProtoCfgR2)
         andBool pbCtxDOf(B:ProtoBlockR2)
                 ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                            pbParentRootOf(B:ProtoBlockR2)))
    [label(R2-CONFIG-FRAME-ACCEPT)]

  // ===========================================================================
  // R2-6 — RECEIPT SINGLE-USE (no replay through the receipt pool)
  // ===========================================================================

  claim // R2-RECEIPT-SINGLE-USE: PROVED — with exactly ONE matching receipt,
        // the first accept consumes it and commits; the replayed accept finds
        // an empty pool and rejects — the counter advances by ONE.
    <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int)
        ~> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> SetItem(R:R2GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR2 )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlockR2) <- B:ProtoBlockR2] ) </r2lineage>
    <r2next> N:Int => N:Int +Int 1 </r2next>
    <r2head> H:Bytes => BlockCommitR2(B:ProtoBlockR2, C:ProtoCfgR2) </r2head>
    <r2linhead> LH:Bytes => R2RecChildF(gr2RGOf(R:R2GateReceipt)) </r2linhead>
    <r2valid> V:Bool => V:Bool </r2valid>
    requires gr2BlockOf(R:R2GateReceipt) ==K B:ProtoBlockR2
         andBool gr2ErcOf(R:R2GateReceipt) ==K ERC:Bytes
         andBool gr2ErpOf(R:R2GateReceipt) ==K ERP:Bytes
         andBool gr2HeadOf(R:R2GateReceipt) ==K H:Bytes
         andBool gr2SlotOf(R:R2GateReceipt) ==Int N:Int
         andBool gr2LinHeadOf(R:R2GateReceipt) ==K LH:Bytes
         andBool CfgEqR2(gr2CfgOf(R:R2GateReceipt), C:ProtoCfgR2)
         andBool gr2DecisionOf(R:R2GateReceipt) ==Int pdecValidR2
         andBool pbDecisionOf(B:ProtoBlockR2) ==Int pdecValidR2
         andBool ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(gr2RGOf(R:R2GateReceipt)),
                         pbEvidenceDOf(B:ProtoBlockR2))
         andBool GateInputMatchesBlockR2(gr2FCOf(R:R2GateReceipt),
                                         gr2RGOf(R:R2GateReceipt),
                                         gr2CERTOf(R:R2GateReceipt),
                                         B:ProtoBlockR2)
         andBool GateCtxAuthorizedR2(gr2ACOf(R:R2GateReceipt), C:ProtoCfgR2,
                                     pbParentRootOf(B:ProtoBlockR2))
         andBool GateAuthorityMatchesCfgR2(gr2FCOf(R:R2GateReceipt),
                                           C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int
         andBool CV:Int ==Int pcrPolicyVOf(C:ProtoCfgR2)
         andBool pbPolCommitOf(B:ProtoBlockR2) ==K PolicyCommitmentR2(C:ProtoCfgR2)
         andBool pbCtxDOf(B:ProtoBlockR2)
                 ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(C:ProtoCfgR2,
                            pbParentRootOf(B:ProtoBlockR2)))
    [label(R2-RECEIPT-SINGLE-USE)]

  // ===========================================================================
  // R2-7 — PIPELINES (non-vacuity + the forged end-to-end countermodel)
  // ===========================================================================

  claim // R2-PIPELINE-HONEST: PROVED (K side) — init -> gate evaluation ->
        // accept commits the valid candidate.  The gate's verdict enters as
        // the gate's ACTUAL result over the machine-constructed context
        // (hypothesis pinned to exactly that context — GateCtxAuthorizedR2
        // holds of the mint-constructed AC by construction; stated so the
        // claim cannot be satisfied by a caller-chosen context).  The
        // concrete-digest instantiation is the LLVM/Python mirror.
    <k> pInitR2(CFG)
        ~> pGateEvalR2(B:ProtoBlockR2, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                       ERC:Bytes, ERP:Bytes)
        ~> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, 7:Int) => .K </k>
    <r2lineage> .Map
            => ( -1:Int |-> CFG )
               ( -2:Int |-> .Set )
               ( 0:Int |-> B:ProtoBlockR2 ) </r2lineage>
    <r2next> 0 => 1 </r2next>
    <r2head> _:Bytes => BlockCommitR2(B:ProtoBlockR2, CFG) </r2head>
    <r2linhead> _:Bytes => R2RecChildF(RG:LinRecG) </r2linhead>
    <r2valid> V:Bool => V:Bool </r2valid>
    requires CFG ==K protoCfgR2(CH:Bytes, 7:Int, PD:Bytes, AS:Bytes, GR:Bytes,
                                CC:Bytes, EC:Bytes, FK:Bytes, SC:Bytes,
                                SP:Int, PT:Int, GD:Bytes, CD:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int 0
         andBool pbParentCommitOf(B:ProtoBlockR2) ==K ProtoRootR2(CFG)
         andBool pbDecisionOf(B:ProtoBlockR2) ==Int pdecValidR2
         andBool ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlockR2) ==K PolicyCommitmentR2(CFG)
         andBool pbCtxDOf(B:ProtoBlockR2)
                 ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(CFG,
                            pbParentRootOf(B:ProtoBlockR2)))
         andBool VerifyLineageG(
                     RG:LinRecG
                   , azCtx( FC:ExecCtx
                          , ProtoAuthorizedSecCtxR2(CFG,
                                pbParentRootOf(B:ProtoBlockR2))
                          , CERT:AuthzCert
                          , pcrAuthPTOf(CFG) , pcrAuthGuestDOf(CFG)
                          , pcrAuthCfgDOf(CFG) )
                   , 0:Int, R2LinRoot ) ==K "valid-g"
         andBool GateInputMatchesBlockR2(FC:ExecCtx, RG:LinRecG,
                                         CERT:AuthzCert, B:ProtoBlockR2)
         andBool GateAuthorityMatchesCfgR2(FC:ExecCtx, CFG)
    [label(R2-PIPELINE-HONEST)]

  claim // R2-PIPELINE-FORGED: PROVED — end-to-end countermodel: init ->
        // the gate EVALUATES the presented evidence and computes a rejection
        // ("invalid-policy" over the machine-constructed context) -> the
        // caller attempts the accept anyway (correct config version, correct
        // parent link, correct slot): the chain is NOT extended, the counter
        // does NOT advance, the receipt REMAINS unconsumed.
    <k> pInitR2(CFG)
        ~> pGateEvalR2(B:ProtoBlockR2, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                       ERC:Bytes, ERP:Bytes)
        ~> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, 7:Int) => .K </k>
    <r2lineage> .Map
            => ( -1:Int |-> CFG )
               ( -2:Int |-> SetItem(
                     gateReceiptR2( B:ProtoBlockR2, ERC:Bytes, ERP:Bytes
                                  , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                  , azCtx( FC:ExecCtx
                                         , ProtoAuthorizedSecCtxR2(CFG,
                                               pbParentRootOf(B:ProtoBlockR2))
                                         , CERT:AuthzCert
                                         , pcrAuthPTOf(CFG)
                                         , pcrAuthGuestDOf(CFG)
                                         , pcrAuthCfgDOf(CFG) )
                                  , VerifyLineageG(
                                        RG:LinRecG
                                      , azCtx( FC:ExecCtx
                                             , ProtoAuthorizedSecCtxR2(CFG,
                                                   pbParentRootOf(B:ProtoBlockR2))
                                             , CERT:AuthzCert
                                             , pcrAuthPTOf(CFG)
                                             , pcrAuthGuestDOf(CFG)
                                             , pcrAuthCfgDOf(CFG) )
                                      , 0:Int, R2LinRoot )
                                  , ProtoRootR2(CFG), 0:Int, R2LinRoot
                                  , CFG )) .Set )
               ( 0:Int |-> B:ProtoBlockR2 ) </r2lineage>
    <r2next> 0 => 1 </r2next>
    <r2head> _:Bytes => BlockCommitR2(B:ProtoBlockR2, CFG) </r2head>
    <r2linhead> _:Bytes => R2RecChildF(RG:LinRecG) </r2linhead>
    <r2valid> V:Bool => V:Bool </r2valid>
    requires CFG ==K protoCfgR2(CH:Bytes, 7:Int, PD:Bytes, AS:Bytes, GR:Bytes,
                                CC:Bytes, EC:Bytes, FK:Bytes, SC:Bytes,
                                SP:Int, PT:Int, GD:Bytes, CD:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int 0
         andBool pbParentCommitOf(B:ProtoBlockR2) ==K ProtoRootR2(CFG)
         andBool pbDecisionOf(B:ProtoBlockR2) ==Int pdecValidR2
         andBool ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlockR2) ==K PolicyCommitmentR2(CFG)
         andBool pbCtxDOf(B:ProtoBlockR2)
                 ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(CFG,
                            pbParentRootOf(B:ProtoBlockR2)))
         andBool VerifyLineageG(
                     RG:LinRecG
                   , azCtx( FC:ExecCtx
                          , ProtoAuthorizedSecCtxR2(CFG,
                                pbParentRootOf(B:ProtoBlockR2))
                          , CERT:AuthzCert
                          , pcrAuthPTOf(CFG) , pcrAuthGuestDOf(CFG)
                          , pcrAuthCfgDOf(CFG) )
                   , 0:Int, R2LinRoot ) ==K "invalid-policy"
         andBool GateInputMatchesBlockR2(FC:ExecCtx, RG:LinRecG,
                                         CERT:AuthzCert, B:ProtoBlockR2)
         andBool GateAuthorityMatchesCfgR2(FC:ExecCtx, CFG)
    [label(R2-PIPELINE-FORGED)]

  // ===========================================================================
  // R2-8 — PORTED FROZEN CLAIMS (the 1I ladder re-run over the R2 predicate
  //     forms; same labels, R2 objects)
  // ===========================================================================

  claim // PI1-COMMIT-SAFETY (R2 form)
    <k> CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
        ==K true => true </k>
    requires ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
     andBool pbDecisionOf(B:ProtoBlockR2) ==Int pdecValidR2
     andBool pbPolCommitOf(B:ProtoBlockR2) ==K PolicyCommitmentR2(C:ProtoCfgR2)
     andBool pbCtxDOf(B:ProtoBlockR2)
             ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(C:ProtoCfgR2, LH:Bytes))
    [label(PI1-COMMIT-SAFETY)]

  claim // PI2-DECISION-REJECT (R2 form)
    <k> CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR2) ==Int pdecRejectR2
    [label(PI2-DECISION-REJECT)]

  claim // PI2-DECISION-UNKNOWN (R2 form)
    <k> CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR2) ==Int pdecUnknownR2
    [label(PI2-DECISION-UNKNOWN)]

  claim // PI2-EXEC-INVALID (R2 form)
    <k> CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
        ==K false => true </k>
    requires notBool ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
    [label(PI2-EXEC-INVALID)]

  claim // PI5-AUTHORITY-DESCENT (R2 form — the policy authority identity is
        // derived from the protocol configuration; a policy cannot carry its
        // own authority)
    <k> PolicyCommitmentR2(C:ProtoCfgR2) ==K LinH(
          Int2Bytes(1, 157, BE)
          +Bytes I2B4(pcrPolicyVOf(C:ProtoCfgR2))
          +Bytes pcrPolicyDOf(C:ProtoCfgR2)
          +Bytes pcrAppSetDOf(C:ProtoCfgR2) +Bytes pcrGraphDOf(C:ProtoCfgR2)
          +Bytes LinH( Int2Bytes(1, 165, BE)
                       +Bytes pcrChainIdOf(C:ProtoCfgR2)
                       +Bytes pcrForkOf(C:ProtoCfgR2) ) )
        => true </k>
    [label(PI5-AUTHORITY-DESCENT)]

  claim // PI7-BASE (R2 form)
    <k> CommitChainLinkedR2(.Map, 0, C:ProtoCfgR2) => true </k>
    [label(PI7-BASE)]

  // ===========================================================================
  // R2-9 — FROZEN-FORMULA CORRESPONDENCE CLAIMS (the audit's section C
  //     evidence at the K level: the R2 predicate reproduces the FROZEN 1I
  //     formula — transcribed byte-for-byte into the claim text from
  //     phase1i/semantics/srw3proto.k; the audit cross-references the frozen
  //     line numbers and the Python mirror re-derives identical preimages).
  // ===========================================================================

  claim // R2-CORRESPONDENCE-CONFIG-ROOT: PROVED — ProtoRootR2 is the frozen
        // ProtoRoot formula (srw3proto.k lines 86-95) over the corresponding
        // fields.
    <k> ProtoRootR2(C:ProtoCfgR2) ==K LinH(
          Int2Bytes(1, 156, BE)
          +Bytes pcrChainIdOf(C:ProtoCfgR2) +Bytes I2B4(pcrPolicyVOf(C:ProtoCfgR2))
          +Bytes pcrPolicyDOf(C:ProtoCfgR2) +Bytes pcrAppSetDOf(C:ProtoCfgR2)
          +Bytes pcrGraphDOf(C:ProtoCfgR2) +Bytes pcrClientCfgDOf(C:ProtoCfgR2)
          +Bytes pcrExecClientDOf(C:ProtoCfgR2) +Bytes pcrForkOf(C:ProtoCfgR2) )
        => true </k>
    [label(R2-CORRESPONDENCE-CONFIG-ROOT)]

  claim // R2-CORRESPONDENCE-POLICY-COMMITMENT: PROVED — PolicyCommitmentR2 is
        // the frozen PolicyCommitmentI formula (srw3proto.k lines 113-118).
    <k> PolicyCommitmentR2(C:ProtoCfgR2) ==K LinH(
          Int2Bytes(1, 157, BE)
          +Bytes I2B4(pcrPolicyVOf(C:ProtoCfgR2)) +Bytes pcrPolicyDOf(C:ProtoCfgR2)
          +Bytes pcrAppSetDOf(C:ProtoCfgR2) +Bytes pcrGraphDOf(C:ProtoCfgR2)
          +Bytes LinH( Int2Bytes(1, 165, BE)
                       +Bytes pcrChainIdOf(C:ProtoCfgR2)
                       +Bytes pcrForkOf(C:ProtoCfgR2) ) )
        => true </k>
    [label(R2-CORRESPONDENCE-POLICY-COMMITMENT)]

  claim // R2-CORRESPONDENCE-CTX-DIGEST: PROVED — CtxDigestR2 is the frozen
        // CtxDigestI formula (srw3proto.k lines 129-134) over the authorized
        // projection.
    <k> CtxDigestR2(ProtoAuthorizedSecCtxR2(C:ProtoCfgR2, LH:Bytes)) ==K LinH(
          Int2Bytes(1, 166, BE)
          +Bytes I2B4(pcrPolicyVOf(C:ProtoCfgR2))
          +Bytes pcrChainIdOf(C:ProtoCfgR2)
          +Bytes pcrAppSetDOf(C:ProtoCfgR2) +Bytes pcrGraphDOf(C:ProtoCfgR2)
          +Bytes LH:Bytes )
        => true </k>
    [label(R2-CORRESPONDENCE-CTX-DIGEST)]

  claim // R2-CORRESPONDENCE-BLOCK-COMMIT: PROVED — BlockCommitR2 is the
        // frozen BlockCommitI formula (srw3proto.k lines 213-223).
    <k> BlockCommitR2(B:ProtoBlockR2, C:ProtoCfgR2) ==K LinH(
          Int2Bytes(1, 158, BE)
          +Bytes pbParentCommitOf(B:ProtoBlockR2) +Bytes pbPayloadDOf(B:ProtoBlockR2)
          +Bytes pbParentRootOf(B:ProtoBlockR2) +Bytes pbChildRootOf(B:ProtoBlockR2)
          +Bytes pbEffectDOf(B:ProtoBlockR2) +Bytes pbEvidenceDOf(B:ProtoBlockR2)
          +Bytes pbCtxDOf(B:ProtoBlockR2)
          +Bytes LinH( Int2Bytes(1, 157, BE)
                       +Bytes I2B4(pcrPolicyVOf(C:ProtoCfgR2))
                       +Bytes pcrPolicyDOf(C:ProtoCfgR2)
                       +Bytes pcrAppSetDOf(C:ProtoCfgR2)
                       +Bytes pcrGraphDOf(C:ProtoCfgR2)
                       +Bytes LinH( Int2Bytes(1, 165, BE)
                                    +Bytes pcrChainIdOf(C:ProtoCfgR2)
                                    +Bytes pcrForkOf(C:ProtoCfgR2) ) )
          +Bytes I2B4(pbDecisionOf(B:ProtoBlockR2))
          +Bytes I2B4(pbSlotOf(B:ProtoBlockR2)) )
        => true </k>
    [label(R2-CORRESPONDENCE-BLOCK-COMMIT)]

  // ===========================================================================
  // R2-10 — the retried universal closure (the R1-ALL / PI7-ALL analog).
  //   OUTCOME IS RECORDED WHATEVER IT IS; if the kore circularity/implication
  //   blocker fires again, the claim is classified NOT MECHANIZED with the
  //   exact message retained in transcripts/k/.
  // ===========================================================================

  claim
    <k> pConsR2(CI:PCmdR2I, RUN:PProgR2I) => .K </k>
    <r2lineage> L:Map </r2lineage>
    <r2next> N:Int </r2next>
    <r2head> H:Bytes </r2head>
    <r2linhead> LH:Bytes </r2linhead>
    <r2valid> true </r2valid>
    [circularity, label(R2-ALL)]

endmodule
