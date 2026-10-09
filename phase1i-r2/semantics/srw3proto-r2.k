// =============================================================================
// SRW3 Phase 1I-R2 — GATE VERDICT PROVENANCE BINDING (ISOLATED R2 MACHINE)
//                    (phase1i-r2/semantics/srw3proto-r2.k)
//
// Backend: HASKELL (proofs/structural core) + LLVM (concrete keccak demos via
// the Phase-1C krypto shim) + Python executable mirror (r2_model.py).
//
// REPAIR TARGET (audit/GATE-PROVENANCE-AUDIT.md, finding R2-F1):
//   The R1 gate command pGateEval(ProtoBlock, Bytes, Bytes, String) takes the
//   gate verdict V:String FROM THE CALLER and stores it in the receipt
//   verbatim.  A caller that supplies the literal "valid-g" obtains a receipt
//   claiming the frozen gate accepted — without any gate evaluation taking
//   place.  R1 closed the accept-side binding (no verdict/config argument on
//   pAcceptR1) but left the MINT-side verdict parameter open.
//
// R2 DESIGN (handoff sections 4/5):
//
//   1. ISOLATED MACHINE SURFACE.  This definition imports ONLY the frozen
//      Phase 1G gate module SRW3AUTHZ (phase1g/semantics/srw3authz.k, itself
//      unchanged all the way down to srw3lin.k + krypto.md).  It does NOT
//      import SRW3PROTO or SRW3PROTO-R1.  Consequently the legacy commands
//      pInit / pAccept (frozen 1I) and pInitR1 / pGateEval / pAcceptR1 (R1)
//      are NOT part of the R2 command language: their symbols are not
//      declared in any imported module reachable from here, and the legacy
//      transition rules are NOT PRESENT in this definition (the rule set of
//      SRW3PROTO-R2 is finite and enumerable — see the audit).  An attacker
//      controlling the admitted R2 command stream cannot invoke the old
//      unsafe transitions: they are ill-formed programs (kparse rejects),
//      not merely unharnessable paths.  (R2-LEGACY-SURFACE-EXCLUDED.)
//
//   2. THE VERDICT IS COMPUTED, NEVER SUPPLIED.  The only receipt-minting
//      rule is pGateEvalR2.  It takes the EVIDENCE OBJECTS (candidate block,
//      client execution context, lineage record, authority certificate) and
//      the client-derived execution results — and NO verdict argument of any
//      kind (no String, no Bool, no decision Int, no pre-asserted field).
//      Inside the transition the machine
//        (a) CONSTRUCTS the authority context AzCtx from the PINNED
//            configuration: the SecCtx is the protocol-authorized projection
//            ProtoAuthorizedSecCtxR2(C, pbParentRootOf(B)) and the authority
//            parameters (proof type, guest digest, proof-config digest) are
//            pinned config fields.  The gate never derives authority from the
//            certificate or context it validates (the caller cannot name any
//            of these four values — they are not command arguments);
//        (b) SUPPLIES the protocol position: T = the machine's next-slot
//            counter, HEAD = the machine's lineage anchor (both machine
//            state, not caller-chosen);
//        (c) EVALUATES the frozen gate: gr2Verdict := VerifyLineageG(RG, AC,
//            T, HEAD) — the 21-conjunct frozen accept is the ONLY producer
//            of "valid-g"; and stores the computed result in the receipt.
//      No rule, input field, or caller API writes a receipt or a verdict
//      directly.
//
//   3. CANDIDATE/CONTEXT BINDING.  The named predicate
//      GateInputMatchesBlockR2(FC, RG, CERT, B) binds every presented
//      evidence object to the EXACT candidate block (structural equalities —
//      decidable on the Haskell backend), and GateAuthorityMatchesCfgR2
//      binds the presented execution schedule/spec to the pinned values.
//      The cryptographic closures (payload digest recomputation, certificate
//      digest recomputation) are conjuncts INSIDE the frozen gate (L28
//      AzCertBindOk) — discharged by the gate evaluation itself (concrete on
//      LLVM/Python; symbolic boundary on Haskell, documented).  The mint
//      refuses unbound evidence; the accept re-checks the binding on the
//      receipt-stored inputs (defense in depth).
//
//   4. CONFIGURATION PINNED ONCE, IMMUTABLE.  pInitR2 pins the R2 protocol
//      configuration (reserved key -1), anchors the protocol head at the R2
//      protocol root, and anchors the lineage head at the 32-zero-byte
//      lineage root.  Re-initialization refuses (state unchanged); there is
//      deliberately NO upgrade transition (documented deferral, as in R1).
//      Gate/accept read the pin; no command takes a replacement config.
//
//   5. RECEIPT (handoff section 5.4).  An R2GateReceipt binds: the exact
//      candidate, the client execution results, the EXACT gate inputs (FC,
//      RG, CERT, the machine-constructed AC), the COMPUTED verdict, the
//      protocol head + lineage head + slot counter AT EVALUATION TIME, and
//      the pinned configuration object itself.  Acceptance: receipt match on
//      candidate/results/head/lineage-head/slot/config, decision derived
//      from the internally computed verdict, the verdict's decision must be
//      pdecValidR2 (only "valid-g" maps there — fail-closed), the full
//      Commit_P conjunct set checked directly, and the receipt is CONSUMED
//      exactly once.  Missing/duplicate/stale/mismatched/reject receipts
//      fail closed with state unchanged.
//
//   6. TWO CHAIN HEADS.  The protocol chain (1I semantics: head := block
//      commitment, 0x9E) and the evidence lineage chain (1D/1G semantics:
//      records anchor at their parent's F-child commitment) are distinct
//      frozen chains.  R2 tracks BOTH: <r2head> (protocol) and <r2linhead>
//      (evidence).  The gate's HEAD argument is the machine lineage anchor —
//      the applicable lineage parent for this exact candidate — and the
//      candidate's parent-commitment link is checked against <r2head>.
//      Accepting advances <r2linhead> to the accepted record's F-child
//      (R2RecChildF).  Receipt freshness is enforced on both heads.
//
// CONFIGURATION NOTE: K admits exactly one <k> cell per definition; because
// R2 does not import SRW3PROTO, it declares its own configuration
// <srw3protoR2> (cells <k> <r2lineage> <r2next> <r2head> <r2linhead>
// <r2valid>).  The reserved-negative-key discipline of R1 is retained for
// the pinned configuration (-1) and the receipt pool (-2) inside <r2lineage>.
//
// CORRESPONDENCE DISCIPLINE (handoff section 4): the R2 protocol predicates
// (ProtoCfgR2 canon/root, PolicyCommitmentR2, ProtoAuthorizedSecCtxR2,
// CtxCanonR2/CtxDigestR2, ProtoBlockR2, BlockCommitR2, SRW3RootR2, the
// decision mapping, CommitPR2) REPRODUCE the frozen Phase 1I formulas of
// srw3proto.k with IDENTICAL canonical tags and composition (0x9C/0x9D/0x9E/
// 0x9F/0xA5/0xA6).  They cannot be imported (importing SRW3PROTO would
// resurrect the legacy pAccept transition — the exact defect this repair
// removes), so the correspondence is carried by: (a) definition-level
// identity of the canonical formulas, mechanically conformance-checked
// against the transcribed frozen formulas by the R2-CORRESPONDENCE-* claims;
// (b) the byte-level K<->Python preimage cross-checks; (c) the audit's
// line-by-line frozen cross-reference.  The K one-configuration rule is the
// documented reason this indirect form is used (see audit section C).
//
// TRUST BOUNDARIES (stated, not hidden): unchanged from R1 — (a) the
// verdict is the frozen VerifyLineageG result; its soundness rests on the
// frozen gate module (mechanized in Phase 1G); (b) hash equalities are
// symbolic constraints on the Haskell backend; concrete digests are decided
// on the LLVM backend (krypto shim) and in the Python mirror (real keccak,
// collision resistance assumed); (c) the caller-presented evidence objects
// (payload bytes, trace, pre/post states, witness) are a faithful execution
// record ONLY through the frozen gate's own replay/binding layers — R2 adds
// no new trust to the evidence channel.
// =============================================================================

requires "../../phase1g/semantics/srw3authz.k"

module SRW3PROTO-R2
  imports SRW3AUTHZ

  // ===========================================================================
  // §1. R2 protocol configuration — the frozen 1I ProtoCfg fields PLUS the
  //     gate-authority parameters VerifyLineageG consumes (handoff section
  //     5.3: authority parameters not present in the 1I config are ADDED to
  //     the pinned configuration, so the gate derives authority from the pin,
  //     never from the certificate/context under validation).
  //
  //     Fields 1..8 correspond field-for-field to the frozen ProtoCfg of
  //     srw3proto.k §1 (same order, same canon tag 0x9C).  Fields 9..13 are
  //     the R2 additions: the execution schedule/spec the presented ExecCtx
  //     must match, and the 1G gate authority triple (proof type, guest
  //     digest, proof-config digest).
  // ===========================================================================

  syntax ProtoCfgR2 ::= "protoCfgR2" "(" pcrChainId:Bytes ","
                        pcrPolicyV:Int "," pcrPolicyD:Bytes ","
                        pcrAppSetD:Bytes "," pcrGraphD:Bytes ","
                        pcrClientCfgD:Bytes "," pcrExecClientD:Bytes ","
                        pcrFork:Bytes "," pcrSched:Bytes "," pcrSpec:Int ","
                        pcrAuthPT:Int "," pcrAuthGuestD:Bytes ","
                        pcrAuthCfgD:Bytes ")"

  syntax Bytes ::= pcrChainIdOf    ( ProtoCfgR2 ) [function, total]
  rule pcrChainIdOf(protoCfgR2(CH:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => CH:Bytes
  syntax Int ::= pcrPolicyVOf      ( ProtoCfgR2 ) [function, total]
  rule pcrPolicyVOf(protoCfgR2(_:Bytes, V:Int, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => V:Int
  syntax Bytes ::= pcrPolicyDOf    ( ProtoCfgR2 ) [function, total]
  rule pcrPolicyDOf(protoCfgR2(_:Bytes, _:Int, PD:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => PD:Bytes
  syntax Bytes ::= pcrAppSetDOf    ( ProtoCfgR2 ) [function, total]
  rule pcrAppSetDOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, AS:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => AS:Bytes
  syntax Bytes ::= pcrGraphDOf     ( ProtoCfgR2 ) [function, total]
  rule pcrGraphDOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, GR:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                              _:Int, _:Bytes, _:Bytes)) => GR:Bytes
  syntax Bytes ::= pcrClientCfgDOf ( ProtoCfgR2 ) [function, total]
  rule pcrClientCfgDOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                  CC:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                  _:Int, _:Bytes, _:Bytes)) => CC:Bytes
  syntax Bytes ::= pcrExecClientDOf( ProtoCfgR2 ) [function, total]
  rule pcrExecClientDOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                   _:Bytes, EC:Bytes, _:Bytes, _:Bytes, _:Int,
                                   _:Int, _:Bytes, _:Bytes)) => EC:Bytes
  syntax Bytes ::= pcrForkOf       ( ProtoCfgR2 ) [function, total]
  rule pcrForkOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, FK:Bytes, _:Bytes, _:Int,
                            _:Int, _:Bytes, _:Bytes)) => FK:Bytes
  syntax Bytes ::= pcrSchedOf      ( ProtoCfgR2 ) [function, total]
  rule pcrSchedOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, _:Bytes, _:Bytes, SC:Bytes, _:Int,
                             _:Int, _:Bytes, _:Bytes)) => SC:Bytes
  syntax Int ::= pcrSpecOf         ( ProtoCfgR2 ) [function, total]
  rule pcrSpecOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes, _:Bytes, SP:Int,
                            _:Int, _:Bytes, _:Bytes)) => SP:Int
  syntax Int ::= pcrAuthPTOf       ( ProtoCfgR2 ) [function, total]
  rule pcrAuthPTOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                              PT:Int, _:Bytes, _:Bytes)) => PT:Int
  syntax Bytes ::= pcrAuthGuestDOf ( ProtoCfgR2 ) [function, total]
  rule pcrAuthGuestDOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                  _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                  _:Int, GD:Bytes, _:Bytes)) => GD:Bytes
  syntax Bytes ::= pcrAuthCfgDOf   ( ProtoCfgR2 ) [function, total]
  rule pcrAuthCfgDOf(protoCfgR2(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                _:Int, _:Bytes, CD:Bytes)) => CD:Bytes

  // Canonical config bytes — the frozen ProtoCfgCanon formula (tag 0x9C,
  // same field order for fields 1..8) UNCHANGED; the R2 authority fields are
  // pin-internal and deliberately NOT part of the protocol-root preimage
  // (the root identity remains the 1I root of the corresponding 1I config).
  syntax Bytes ::= ProtoCfgCanonR2 ( ProtoCfgR2 ) [function, total]
  rule ProtoCfgCanonR2(C:ProtoCfgR2)
    => Int2Bytes(1, 156, BE)                      // 0x9C (frozen 1I tag)
       +Bytes pcrChainIdOf(C) +Bytes I2B4(pcrPolicyVOf(C))
       +Bytes pcrPolicyDOf(C) +Bytes pcrAppSetDOf(C) +Bytes pcrGraphDOf(C)
       +Bytes pcrClientCfgDOf(C) +Bytes pcrExecClientDOf(C) +Bytes pcrForkOf(C)

  // The level-0 protocol root — frozen ProtoRoot composition.
  syntax Bytes ::= ProtoRootR2 ( ProtoCfgR2 ) [function]
  rule ProtoRootR2(C:ProtoCfgR2) => LinH(ProtoCfgCanonR2(C))

  // Structural config equality (decidable on the Haskell backend — used by
  // the accept guard so the config-identity conjunct resolves concretely
  // there whenever both sides are the same pinned object).
  syntax Bool ::= CfgEqR2 ( ProtoCfgR2 , ProtoCfgR2 ) [function, total]
  rule CfgEqR2(C1:ProtoCfgR2, C2:ProtoCfgR2)
    => BytesEq(pcrChainIdOf(C1), pcrChainIdOf(C2))
       andBool pcrPolicyVOf(C1) ==Int pcrPolicyVOf(C2)
       andBool BytesEq(pcrPolicyDOf(C1), pcrPolicyDOf(C2))
       andBool BytesEq(pcrAppSetDOf(C1), pcrAppSetDOf(C2))
       andBool BytesEq(pcrGraphDOf(C1), pcrGraphDOf(C2))
       andBool BytesEq(pcrClientCfgDOf(C1), pcrClientCfgDOf(C2))
       andBool BytesEq(pcrExecClientDOf(C1), pcrExecClientDOf(C2))
       andBool BytesEq(pcrForkOf(C1), pcrForkOf(C2))
       andBool BytesEq(pcrSchedOf(C1), pcrSchedOf(C2))
       andBool pcrSpecOf(C1) ==Int pcrSpecOf(C2)
       andBool pcrAuthPTOf(C1) ==Int pcrAuthPTOf(C2)
       andBool BytesEq(pcrAuthGuestDOf(C1), pcrAuthGuestDOf(C2))
       andBool BytesEq(pcrAuthCfgDOf(C1), pcrAuthCfgDOf(C2))

  // ===========================================================================
  // §2. Policy commitment / authorized context — frozen 1I formulas (§2 of
  //     srw3proto.k), reproduced with identical tags and composition.
  // ===========================================================================

  // PolicyCommitment = H(0x9D || policyV || policyD || appSetD || graphD ||
  //                      PolicyAuthId),  PolicyAuthId = H(0xA5 || chainId || fork)
  syntax Bytes ::= PolicyCommitmentR2 ( ProtoCfgR2 ) [function]
  rule PolicyCommitmentR2(C:ProtoCfgR2)
    => LinH( Int2Bytes(1, 157, BE)                // 0x9D (frozen 1I tag)
             +Bytes I2B4(pcrPolicyVOf(C)) +Bytes pcrPolicyDOf(C)
             +Bytes pcrAppSetDOf(C) +Bytes pcrGraphDOf(C)
             +Bytes LinH( Int2Bytes(1, 165, BE)   // 0xA5 (frozen 1I tag)
                          +Bytes pcrChainIdOf(C) +Bytes pcrForkOf(C) ) )

  // The AUTHORIZED SecurityContext — derived from the pinned configuration
  // and the applicable lineage head; the gate consumes it; nothing
  // candidate- or caller-supplied can replace it (SC-10 discipline).
  syntax SecCtx ::= ProtoAuthorizedSecCtxR2 ( ProtoCfgR2 , Bytes ) [function]
  rule ProtoAuthorizedSecCtxR2(C:ProtoCfgR2, LH:Bytes)
    => secCtx(pcrPolicyVOf(C), pcrChainIdOf(C), pcrAppSetDOf(C),
              pcrGraphDOf(C), LH:Bytes)

  // Context canon + digest — frozen 1I formula (tag 0xA6).
  syntax Bytes ::= CtxCanonR2 ( SecCtx ) [function, total]
  rule CtxCanonR2(secCtx(V:Int, CH:Bytes, AS:Bytes, GR:Bytes, LH:Bytes))
    => Int2Bytes(1, 166, BE)                      // 0xA6 (frozen 1I tag)
       +Bytes I2B4(V) +Bytes CH +Bytes AS +Bytes GR +Bytes LH
  syntax Bytes ::= CtxDigestR2 ( SecCtx ) [function]
  rule CtxDigestR2(S:SecCtx) => LinH(CtxCanonR2(S))

  // ===========================================================================
  // §3. Protocol decisions — frozen 1I semantics (§3 of srw3proto.k): the
  //     decision is DERIVED from the gate verdict; ONLY "valid-g" is
  //     protocol-valid; every other verdict is pdecRejectR2 (fail-closed);
  //     a missing evaluation is pdecUnknownR2 (never silently valid).
  // ===========================================================================

  syntax Int ::= "pdecValidR2"   [function, total]
  syntax Int ::= "pdecRejectR2"  [function, total]
  syntax Int ::= "pdecUnknownR2" [function, total]
  rule pdecValidR2   => 1
  rule pdecRejectR2  => 0
  rule pdecUnknownR2 => 2

  syntax Int ::= ProtoDecisionOfGateR2 ( String ) [function, total]
  rule ProtoDecisionOfGateR2("valid-g") => pdecValidR2
  rule ProtoDecisionOfGateR2(S:String)  => pdecRejectR2 [owise]

  syntax Int ::= ProtoDecisionOfMissingR2 ( ) [function, total]
  rule ProtoDecisionOfMissingR2() => pdecUnknownR2

  // ===========================================================================
  // §4. The candidate block — frozen 1I ProtoBlock shape (§4 of srw3proto.k),
  //     same ten fields in the same order.
  // ===========================================================================

  syntax ProtoBlockR2 ::= "protoBlockR2" "(" pbParentCommit:Bytes ","
                          pbPayloadD:Bytes "," pbParentRoot:Bytes ","
                          pbChildRoot:Bytes "," pbEffectD:Bytes ","
                          pbEvidenceD:Bytes "," pbCtxD:Bytes ","
                          pbPolCommit:Bytes "," pbDecision:Int ","
                          pbSlot:Int ")"

  syntax Bytes ::= pbParentCommitOf ( ProtoBlockR2 ) [function, total]
  rule pbParentCommitOf(protoBlockR2(PC:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                     _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                     _:Int, _:Int)) => PC:Bytes
  syntax Bytes ::= pbPayloadDOf ( ProtoBlockR2 ) [function, total]
  rule pbPayloadDOf(protoBlockR2(_:Bytes, PL:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => PL:Bytes
  syntax Bytes ::= pbParentRootOf ( ProtoBlockR2 ) [function, total]
  rule pbParentRootOf(protoBlockR2(_:Bytes, _:Bytes, PR:Bytes, _:Bytes,
                                   _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                   _:Int, _:Int)) => PR:Bytes
  syntax Bytes ::= pbChildRootOf ( ProtoBlockR2 ) [function, total]
  rule pbChildRootOf(protoBlockR2(_:Bytes, _:Bytes, _:Bytes, CR:Bytes,
                                  _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                  _:Int, _:Int)) => CR:Bytes
  syntax Bytes ::= pbEffectDOf ( ProtoBlockR2 ) [function, total]
  rule pbEffectDOf(protoBlockR2(_:Bytes, _:Bytes, _:Bytes, _:Bytes, EF:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => EF:Bytes
  syntax Bytes ::= pbEvidenceDOf ( ProtoBlockR2 ) [function, total]
  rule pbEvidenceDOf(protoBlockR2(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                  EV:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => EV:Bytes
  syntax Bytes ::= pbCtxDOf ( ProtoBlockR2 ) [function, total]
  rule pbCtxDOf(protoBlockR2(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, CX:Bytes, _:Bytes, _:Int, _:Int))
    => CX:Bytes
  syntax Bytes ::= pbPolCommitOf ( ProtoBlockR2 ) [function, total]
  rule pbPolCommitOf(protoBlockR2(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                  _:Bytes, _:Bytes, PL:Bytes, _:Int, _:Int))
    => PL:Bytes
  syntax Int ::= pbDecisionOf ( ProtoBlockR2 ) [function, total]
  rule pbDecisionOf(protoBlockR2(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, D:Int, _:Int))
    => D:Int
  syntax Int ::= pbSlotOf ( ProtoBlockR2 ) [function, total]
  rule pbSlotOf(protoBlockR2(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, _:Bytes, _:Bytes, _:Int, SL:Int))
    => SL:Int

  // Block commitment record — frozen 1I formula (tag 0x9E).
  syntax Bytes ::= BlockCommitCanonR2 ( ProtoBlockR2 , Bytes ) [function, total]
  rule BlockCommitCanonR2(B:ProtoBlockR2, PC:Bytes)
    => Int2Bytes(1, 158, BE)                      // 0x9E (frozen 1I tag)
       +Bytes pbParentCommitOf(B) +Bytes pbPayloadDOf(B)
       +Bytes pbParentRootOf(B) +Bytes pbChildRootOf(B)
       +Bytes pbEffectDOf(B) +Bytes pbEvidenceDOf(B) +Bytes pbCtxDOf(B)
       +Bytes PC +Bytes I2B4(pbDecisionOf(B)) +Bytes I2B4(pbSlotOf(B))

  syntax Bytes ::= BlockCommitR2 ( ProtoBlockR2 , ProtoCfgR2 ) [function]
  rule BlockCommitR2(B:ProtoBlockR2, C:ProtoCfgR2)
    => LinH(BlockCommitCanonR2(B, PolicyCommitmentR2(C)))

  // Combined SRW3 root — frozen 1I candidate D (tag 0x9F; comparison object,
  // NOT auto-selected; see the 1I report).
  syntax Bytes ::= SRW3RootR2 ( ProtoBlockR2 , ProtoCfgR2 ) [function]
  rule SRW3RootR2(B:ProtoBlockR2, C:ProtoCfgR2)
    => LinH( Int2Bytes(1, 159, BE)                // 0x9F (frozen 1I tag)
             +Bytes pbParentCommitOf(B) +Bytes PolicyCommitmentR2(C)
             +Bytes pbCtxDOf(B) +Bytes pbEvidenceDOf(B)
             +Bytes I2B4(pbDecisionOf(B)) )

  // ===========================================================================
  // §5. Validity predicates and Commit_P — frozen 1I composition (§5 of
  //     srw3proto.k) over the R2 objects.
  // ===========================================================================

  syntax Bool ::= ExecValidPR2 ( ProtoBlockR2 , Bytes , Bytes ) [function, total]
  rule ExecValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes)
    => pbChildRootOf(B) ==K ERC  andBool  pbPayloadDOf(B) ==K ERP

  syntax Bool ::= SRW3ValidPR2 ( ProtoBlockR2 , ProtoCfgR2 , Bytes )
                  [function, total]
  rule SRW3ValidPR2(B:ProtoBlockR2, C:ProtoCfgR2, LH:Bytes)
    => pbDecisionOf(B) ==Int pdecValidR2
       andBool pbPolCommitOf(B) ==K PolicyCommitmentR2(C)
       andBool pbCtxDOf(B) ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(C, LH))

  syntax Bool ::= ValidPR2 ( ProtoBlockR2 , Bytes , Bytes , ProtoCfgR2 , Bytes )
                  [function, total]
  rule ValidPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
    => ExecValidPR2(B, ERC, ERP)  andBool  SRW3ValidPR2(B, C, LH)

  // THE CENTRAL PREDICATE (R2 form): Commit_P(B, ERC, ERP, C, LH).
  syntax Bool ::= CommitPR2 ( ProtoBlockR2 , Bytes , Bytes , ProtoCfgR2 ,
                              Bytes ) [function, total]
  rule CommitPR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, C:ProtoCfgR2, LH:Bytes)
    => ValidPR2(B, ERC, ERP, C, LH)

  // Committed-chain validity (the 1I CommitChainLinked discipline, R2 form).
  syntax ProtoBlockR2 ::= blockAtR2 ( Map , Int ) [function, total]
  rule blockAtR2(T:Int |-> B:ProtoBlockR2 REST:Map, T2:Int) => B
    requires T ==Int T2
  rule blockAtR2(T:Int |-> _:ProtoBlockR2 REST:Map, T2:Int)
    => blockAtR2(REST, T2)  requires T =/=Int T2

  syntax Bool ::= CommitChainLinkedR2 ( Map , Int , ProtoCfgR2 )
                  [function, total]
  rule CommitChainLinkedR2(_:Map, 0:Int, _:ProtoCfgR2) => true
  rule CommitChainLinkedR2(L:Map, N:Int, C:ProtoCfgR2)
    => pbDecisionOf(blockAtR2(L, N -Int 1)) ==Int pdecValidR2
       andBool pbPolCommitOf(blockAtR2(L, N -Int 1))
               ==K PolicyCommitmentR2(C)
       andBool pbCtxDOf(blockAtR2(L, N -Int 1))
               ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(C,
                         pbParentRootOf(blockAtR2(L, N -Int 1))))
       andBool CommitChainLinkedR2(L, N -Int 1, C)
       andBool ( N ==Int 1 orBool
                 BytesEq(pbParentCommitOf(blockAtR2(L, N -Int 1)),
                         BlockCommitR2(blockAtR2(L, N -Int 2), C)) )
    requires N >=Int 1

  // ===========================================================================
  // §6. THE GATE-INPUT BINDING (handoff section 5.2) — named, explicit,
  //     structural (decidable on the Haskell backend).  Every caller-presented
  //     evidence object is bound to the EXACT candidate block; the
  //     cryptographic closures are discharged INSIDE the frozen gate
  //     (AzCertBindOk recomputes ExecPayloadDigest(payload) == cert payload
  //     digest and AzCertId(CERT) == record certificate digest — L28), so the
  //     composed binding equals the handoff requirement without putting
  //     undecidable hash equalities into the mint guard.
  // ===========================================================================

  syntax Bool ::= GateInputMatchesBlockR2 ( ExecCtx , LinRecG , AuthzCert ,
                                            ProtoBlockR2 ) [function, total]
  rule GateInputMatchesBlockR2(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                               B:ProtoBlockR2)
    => BytesEq( azPayloadDOf(CERT), pbPayloadDOf(B) )              // payload identity
       andBool BytesEq( execCtxParentRoot(FC), pbParentRootOf(B) ) // parent state root
       andBool BytesEq( linStateRootOf(linRecFBase(linRecGBase(RG))),
                        pbChildRootOf(B) )                          // post-state root
       andBool BytesEq( linEffTraceDOf(linRecGBase(RG)),
                        pbEffectDOf(B) )                            // effect-trace digest
       andBool BytesEq( linAzCertDOf(RG), pbEvidenceDOf(B) )        // evidence identity

  // Gate authority parameters that arrive through the ExecCtx are pinned:
  // the presented schedule/spec must be the protocol-pinned values.
  syntax Bool ::= GateAuthorityMatchesCfgR2 ( ExecCtx , ProtoCfgR2 )
                  [function, total]
  rule GateAuthorityMatchesCfgR2(FC:ExecCtx, C:ProtoCfgR2)
    => BytesEq( execCtxSched(FC), pcrSchedOf(C) )
       andBool execCtxSpec(FC) ==Int pcrSpecOf(C)

  // The machine-constructed authority context is the authorized projection:
  // SecCtx = protocol-authorized projection; authority triple = pinned config
  // fields.  Holds BY CONSTRUCTION for the mint-constructed AC; stated as a
  // named predicate so the accept guard and the proof ladder can re-check it
  // explicitly (field-wise, decidable).
  syntax Bool ::= AzSecEqR2 ( SecCtx , SecCtx ) [function, total]
  rule AzSecEqR2(S1:SecCtx, S2:SecCtx)
    => secPolicyVOf(S1) ==Int secPolicyVOf(S2)
       andBool BytesEq(secChainIdOf(S1), secChainIdOf(S2))
       andBool BytesEq(secAppSetDOf(S1), secAppSetDOf(S2))
       andBool BytesEq(secGraphDOf(S1), secGraphDOf(S2))
       andBool BytesEq(secLineageHeadOf(S1), secLineageHeadOf(S2))

  syntax Bool ::= GateCtxAuthorizedR2 ( AzCtx , ProtoCfgR2 , Bytes )
                  [function, total]
  rule GateCtxAuthorizedR2(AC:AzCtx, C:ProtoCfgR2, LH:Bytes)
    => AzSecEqR2( azSecOf(AC), ProtoAuthorizedSecCtxR2(C, LH) )
       andBool azAuthPTOf(AC) ==Int pcrAuthPTOf(C)
       andBool BytesEq( azAuthGuestDOf(AC), pcrAuthGuestDOf(C) )
       andBool BytesEq( azAuthCfgDOf(AC), pcrAuthCfgDOf(C) )

  // The F-child commitment of a record — the lineage-head advance (the
  // 1D/1G record chain anchors the next record at its parent's F-child;
  // see the module header, point 6).
  syntax Bytes ::= R2RecChildF ( LinRecG ) [function]
  rule R2RecChildF(RG:LinRecG)
    => ExecChildF( linRecFBase(linRecGBase(RG))
                 , linExecIdOf(linRecGBase(RG))
                 , linEffTraceDOf(linRecGBase(RG))
                 , linExecWDOf(linRecGBase(RG))
                 , linExecCfgDOf(linRecGBase(RG)) )

  // ===========================================================================
  // §7. Receipts — the ONLY in-model carrier of a gate verdict.  Created ONLY
  //     by pGateEvalR2; consumed exactly once by pAcceptR2.  The verdict
  //     field is WRITTEN ONLY by the mint rule, as the result of evaluating
  //     the frozen gate over the machine-constructed context and the
  //     machine-supplied position.  No command has a verdict-shaped argument.
  // ===========================================================================

  syntax R2GateReceipt ::= "gateReceiptR2" "(" gr2Block:ProtoBlockR2 ","
                            gr2Erc:Bytes "," gr2Erp:Bytes ","
                            gr2FC:ExecCtx "," gr2RG:LinRecG ","
                            gr2CERT:AuthzCert "," gr2AC:AzCtx ","
                            gr2Verdict:String "," gr2Head:Bytes ","
                            gr2Slot:Int "," gr2LinHead:Bytes ","
                            gr2Cfg:ProtoCfgR2 ")"

  syntax ProtoBlockR2 ::= gr2BlockOf  ( R2GateReceipt ) [function, total]
  syntax Bytes      ::= gr2ErcOf    ( R2GateReceipt ) [function, total]
  syntax Bytes      ::= gr2ErpOf    ( R2GateReceipt ) [function, total]
  syntax ExecCtx    ::= gr2FCOf     ( R2GateReceipt ) [function, total]
  syntax LinRecG    ::= gr2RGOf     ( R2GateReceipt ) [function, total]
  syntax AuthzCert  ::= gr2CERTOf   ( R2GateReceipt ) [function, total]
  syntax AzCtx      ::= gr2ACOf     ( R2GateReceipt ) [function, total]
  syntax String     ::= gr2VerdictOf( R2GateReceipt ) [function, total]
  syntax Bytes      ::= gr2HeadOf   ( R2GateReceipt ) [function, total]
  syntax Int        ::= gr2SlotOf   ( R2GateReceipt ) [function, total]
  syntax Bytes      ::= gr2LinHeadOf( R2GateReceipt ) [function, total]
  syntax ProtoCfgR2 ::= gr2CfgOf    ( R2GateReceipt ) [function, total]

  rule gr2BlockOf(gateReceiptR2(B:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                                _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                                _:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => B:ProtoBlockR2
  rule gr2ErcOf(gateReceiptR2(_:ProtoBlockR2, E:Bytes, _:Bytes, _:ExecCtx,
                              _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                              _:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => E:Bytes
  rule gr2ErpOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, P:Bytes, _:ExecCtx,
                              _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                              _:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => P:Bytes
  rule gr2FCOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, FC:ExecCtx,
                             _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                             _:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => FC:ExecCtx
  rule gr2RGOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                             RG:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                             _:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => RG:LinRecG
  rule gr2CERTOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                               _:LinRecG, CT:AuthzCert, _:AzCtx, _:String,
                               _:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => CT:AuthzCert
  rule gr2ACOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                             _:LinRecG, _:AuthzCert, AC:AzCtx, _:String,
                             _:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => AC:AzCtx
  rule gr2VerdictOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                                  _:LinRecG, _:AuthzCert, _:AzCtx, V:String,
                                  _:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => V:String
  rule gr2HeadOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                               _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                               H:Bytes, _:Int, _:Bytes, _:ProtoCfgR2))
    => H:Bytes
  rule gr2SlotOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                               _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                               _:Bytes, S:Int, _:Bytes, _:ProtoCfgR2))
    => S:Int
  rule gr2LinHeadOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                                  _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                                  _:Bytes, _:Int, LH:Bytes, _:ProtoCfgR2))
    => LH:Bytes
  rule gr2CfgOf(gateReceiptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:ExecCtx,
                              _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                              _:Bytes, _:Int, _:Bytes, C:ProtoCfgR2))
    => C:ProtoCfgR2

  // THE DERIVED DECISION — computed from the receipt's INTERNALLY COMPUTED
  // verdict by the frozen fail-closed mapping.  gr2DecisionOf(R) ==Int
  // pdecValidR2 holds iff gr2VerdictOf(R) ==K "valid-g" (the mapping's only
  // valid-producing input).
  syntax Int ::= gr2DecisionOf ( R2GateReceipt ) [function, total]
  rule gr2DecisionOf(R:R2GateReceipt)
    => ProtoDecisionOfGateR2(gr2VerdictOf(R))

  // ===========================================================================
  // §8. Reserved metadata region accessors (lineage-map keys -1 / -2), the
  //     R1 discipline retained: literal Int keys, negative keys can never
  //     collide with block slots (block slots are >= 0).
  // ===========================================================================

  syntax ProtoCfgR2OrNone ::= ProtoCfgR2 | "noCfgR2"
  syntax ProtoCfgR2OrNone ::= storedCfgR2Of ( Map ) [function, total]
  rule storedCfgR2Of(-1 |-> C:ProtoCfgR2 REST:Map) => C:ProtoCfgR2
  rule storedCfgR2Of(REST:Map) => noCfgR2 [owise]

  syntax Set ::= receiptsR2Of ( Map ) [function, total]
  rule receiptsR2Of(-2 |-> S:Set REST:Map) => S:Set
  rule receiptsR2Of(REST:Map) => .Set [owise]

  syntax Bool ::= cfgPinnedR2 ( Map ) [function, total]
  rule cfgPinnedR2(-1 |-> _:ProtoCfgR2 REST:Map) => true
  rule cfgPinnedR2(REST:Map) => false [owise]

  // ===========================================================================
  // §9. The ISOLATED R2 machine surface — configuration and commands.
  //
  //     The command language is PProgR2I = lists of PCmdR2I.  The legacy
  //     commands (pInit/pAccept of SRW3PROTO; pInitR1/pGateEval/pAcceptR1 of
  //     SRW3PROTO-R1) are NOT in this language: their modules are not
  //     imported, their symbols are not declared here, and no rule of this
  //     definition matches them.  A program containing them is ill-formed
  //     (kparse rejects) — the old unsafe transitions are unreachable from
  //     the admitted command stream (R2-LEGACY-SURFACE-EXCLUDED).
  // ===========================================================================

  syntax PCmdR2I ::= "pInitR2" "(" ProtoCfgR2 ")"
                  // gate evaluation: candidate, client execution context,
                  // lineage record, authority certificate, client-derived
                  // child root, client-derived payload identity.
                  // NO verdict/decision argument exists (any sort).
                  | "pGateEvalR2" "(" ProtoBlockR2 "," ExecCtx "," LinRecG ","
                                    AuthzCert "," Bytes "," Bytes ")"
                  // accept: candidate + execution results + the DECLARED
                  // config-version witness.  NO verdict, NO config, NO
                  // receipt argument (the receipt is machine state).
                  | "pAcceptR2" "(" ProtoBlockR2 "," Bytes "," Bytes ","
                                  Int ")"
  syntax PProgR2I ::= "runNilR2" | pConsR2(PCmdR2I, PProgR2I)

  configuration <srw3protoR2>
                  <k> $PGM:PProgR2I </k>
                  <r2lineage> .Map </r2lineage>   // slot -> ProtoBlockR2;
                                                  // -1 -> pinned ProtoCfgR2;
                                                  // -2 -> receipt pool (Set)
                  <r2next> 0 </r2next>
                  <r2head> R2GenesisHead </r2head>        // protocol chain
                  <r2linhead> R2LinRoot </r2linhead>      // evidence chain
                  <r2valid> true </r2valid>
                </srw3protoR2>

  rule <k> pConsR2(C:PCmdR2I, RUN:PProgR2I) => C ~> RUN ... </k>
  rule <k> runNilR2 => .K ... </k>

  // genesis anchors: the protocol head (frozen 1I PGenesisHead form) and the
  // lineage root (the 1D record-chain anchor, 32 zero bytes).
  syntax Bytes ::= "R2GenesisHead" [function, total]
  rule R2GenesisHead => Int2Bytes(1, 0, BE)
  syntax Bytes ::= "R2LinRoot" [function, total]
  rule R2LinRoot => Int2Bytes(32, 0, BE)

  // ---------------------------------------------------------------------------
  // pInitR2 — pins the configuration ONCE and anchors both heads.  Refuses
  // to fire when a configuration is already pinned (no re-initialization; no
  // upgrade transition — documented deferral, as in R1).
  // ---------------------------------------------------------------------------
  rule <k> pInitR2(C:ProtoCfgR2) => .K ... </k>
       <r2head> _:Bytes => ProtoRootR2(C) </r2head>
       <r2linhead> _:Bytes => R2LinRoot </r2linhead>
       <r2lineage> L:Map => L[-1 <- C] </r2lineage>
    requires notBool cfgPinnedR2(L:Map)

  // Refused re-initialization ([owise]): consumes the command, changes
  // NOTHING (the pin is immutable).
  rule <k> pInitR2(_:ProtoCfgR2) => .K ... </k>
       <r2lineage> L:Map </r2lineage>
       <r2next> N:Int </r2next>
       <r2head> H:Bytes </r2head>
       <r2linhead> LH:Bytes </r2linhead>
       <r2valid> V:Bool </r2valid>
    [owise]

  // ---------------------------------------------------------------------------
  // pGateEvalR2 — the ONLY rule that creates a receipt.  The machine:
  //   (a) constructs the authority context AC_m FROM THE PINNED CONFIGURATION
  //       (SecCtx := authorized projection for the candidate's parent root;
  //       authority triple := pinned fields) — the caller cannot name any of
  //       these values, and the gate never derives authority from the
  //       certificate/context it validates;
  //   (b) supplies the position: T := the next-slot counter, HEAD := the
  //       lineage anchor (machine state);
  //   (c) COMPUTES the verdict: VerifyLineageG(RG, AC_m, T, HEAD) — the
  //       frozen 21-conjunct gate — and stores it in the receipt;
  //   (d) binds the evidence to the EXACT candidate (GateInputMatchesBlockR2)
  //       and the presented schedule/spec to the pin
  //       (GateAuthorityMatchesCfgR2), and requires the candidate to sit at
  //       the current chain position (parent commitment == head, slot ==
  //       counter).
  //   Mutates NO chain state (the gate evaluates; it does not commit).
  // ---------------------------------------------------------------------------
  rule <k> pGateEvalR2(B:ProtoBlockR2, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                       ERC:Bytes, ERP:Bytes) => .K ... </k>
       <r2next> N:Int </r2next>
       <r2head> H:Bytes </r2head>
       <r2linhead> LH:Bytes </r2linhead>
       <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
                  ( -2:Int |-> PS:Set )
                  L3:Map
               => ( -1:Int |-> C:ProtoCfgR2 )
                  ( -2:Int |-> SetItem(
                        gateReceiptR2( B:ProtoBlockR2, ERC:Bytes, ERP:Bytes
                                     , FC:ExecCtx, RG:LinRecG
                                     , CERT:AuthzCert
                                     , azCtx( FC:ExecCtx
                                            , ProtoAuthorizedSecCtxR2(
                                                  C:ProtoCfgR2
                                                , pbParentRootOf(B:ProtoBlockR2) )
                                            , CERT:AuthzCert
                                            , pcrAuthPTOf(C:ProtoCfgR2)
                                            , pcrAuthGuestDOf(C:ProtoCfgR2)
                                            , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                     , VerifyLineageG(
                                           RG:LinRecG
                                         , azCtx( FC:ExecCtx
                                                , ProtoAuthorizedSecCtxR2(
                                                      C:ProtoCfgR2
                                                    , pbParentRootOf(B:ProtoBlockR2) )
                                                , CERT:AuthzCert
                                                , pcrAuthPTOf(C:ProtoCfgR2)
                                                , pcrAuthGuestDOf(C:ProtoCfgR2)
                                                , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                         , N:Int, LH:Bytes )
                                     , H:Bytes, N:Int, LH:Bytes
                                     , C:ProtoCfgR2 ))
                                       PS:Set )
                  L3:Map </r2lineage>
    requires GateInputMatchesBlockR2(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                     B:ProtoBlockR2)
         andBool GateAuthorityMatchesCfgR2(FC:ExecCtx, C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int

  rule <k> pGateEvalR2(B:ProtoBlockR2, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                       ERC:Bytes, ERP:Bytes) => .K ... </k>
       <r2next> N:Int </r2next>
       <r2head> H:Bytes </r2head>
       <r2linhead> LH:Bytes </r2linhead>
       <r2lineage> ( -1:Int |-> C:ProtoCfgR2 ) L3:Map
               => ( -1:Int |-> C:ProtoCfgR2 )
                  ( -2:Int |-> SetItem(
                        gateReceiptR2( B:ProtoBlockR2, ERC:Bytes, ERP:Bytes
                                     , FC:ExecCtx, RG:LinRecG
                                     , CERT:AuthzCert
                                     , azCtx( FC:ExecCtx
                                            , ProtoAuthorizedSecCtxR2(
                                                  C:ProtoCfgR2
                                                , pbParentRootOf(B:ProtoBlockR2) )
                                            , CERT:AuthzCert
                                            , pcrAuthPTOf(C:ProtoCfgR2)
                                            , pcrAuthGuestDOf(C:ProtoCfgR2)
                                            , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                     , VerifyLineageG(
                                           RG:LinRecG
                                         , azCtx( FC:ExecCtx
                                                , ProtoAuthorizedSecCtxR2(
                                                      C:ProtoCfgR2
                                                    , pbParentRootOf(B:ProtoBlockR2) )
                                                , CERT:AuthzCert
                                                , pcrAuthPTOf(C:ProtoCfgR2)
                                                , pcrAuthGuestDOf(C:ProtoCfgR2)
                                                , pcrAuthCfgDOf(C:ProtoCfgR2) )
                                         , N:Int, LH:Bytes )
                                     , H:Bytes, N:Int, LH:Bytes
                                     , C:ProtoCfgR2 ))
                                       .Set )
                  L3:Map </r2lineage>
    requires notBool ( -2:Int in_keys(L3:Map) )
         andBool GateInputMatchesBlockR2(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                         B:ProtoBlockR2)
         andBool GateAuthorityMatchesCfgR2(FC:ExecCtx, C:ProtoCfgR2)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR2), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR2) ==Int N:Int

  // ---------------------------------------------------------------------------
  // pAcceptR2 — the ONLY rule that extends the committed chain.  The guard IS
  // the commitment discipline.  Order note: the DECIDABLE conjuncts precede
  // the hash-equality conjuncts (policy commitment, context digest) so that
  // every structural rejection resolves concretely on the Haskell backend
  // (the [owise] reject fires; a stuck hash conjunct cannot mask a decided
  // false).  On accept the matching receipt is CONSUMED exactly once and the
  // lineage head advances to the accepted record's F-child.
  // ---------------------------------------------------------------------------
  rule <k> pAcceptR2(B:ProtoBlockR2, ERC:Bytes, ERP:Bytes, CV:Int) => .K ... </k>
       <r2lineage> ( -1:Int |-> C:ProtoCfgR2 )
                  ( -2:Int |-> SetItem(R:R2GateReceipt) RS:Set )
                  L3:Map
               => ( -1:Int |-> C:ProtoCfgR2 )
                  ( -2:Int |-> RS )
                  ( L3[pbSlotOf(B:ProtoBlockR2) <- B:ProtoBlockR2] )
       </r2lineage>
       <r2next> N:Int => N +Int 1 </r2next>
       <r2head> H:Bytes => BlockCommitR2(B:ProtoBlockR2, C:ProtoCfgR2) </r2head>
       <r2linhead> LH:Bytes => R2RecChildF(gr2RGOf(R:R2GateReceipt)) </r2linhead>
       <r2valid> V:Bool => V:Bool </r2valid>
    requires gr2BlockOf(R) ==K B                                   // receipt match
         andBool gr2ErcOf(R) ==K ERC
         andBool gr2ErpOf(R) ==K ERP
         andBool gr2HeadOf(R) ==K H                                // head freshness
         andBool gr2SlotOf(R) ==Int N                              // slot freshness
         andBool gr2LinHeadOf(R) ==K LH                            // lineage freshness
         andBool CfgEqR2(gr2CfgOf(R), C)                           // config identity
         andBool gr2DecisionOf(R) ==Int pdecValidR2                // DERIVED decision
         andBool pbDecisionOf(B) ==Int pdecValidR2                 // decision binding
         andBool ExecValidPR2(B, ERC, ERP)                         // execution binding
         andBool BytesEq(linAzCertDOf(gr2RGOf(R)), pbEvidenceDOf(B)) // evidence identity
         andBool GateInputMatchesBlockR2(gr2FCOf(R), gr2RGOf(R),
                                         gr2CERTOf(R), B)          // input binding
         andBool GateCtxAuthorizedR2(gr2ACOf(R), C, pbParentRootOf(B)) // ctx authority
         andBool GateAuthorityMatchesCfgR2(gr2FCOf(R), C)          // pinned authority
         andBool BytesEq(pbParentCommitOf(B), H)                   // parent commitment
         andBool pbSlotOf(B) ==Int N                               // one block per slot
         andBool CV ==Int pcrPolicyVOf(C)                          // config witness
         andBool pbPolCommitOf(B) ==K PolicyCommitmentR2(C)        // policy binding [hash]
         andBool pbCtxDOf(B) ==K CtxDigestR2(ProtoAuthorizedSecCtxR2(
                                               C, pbParentRootOf(B))) // ctx binding [hash]

  // REJECT (restore, [owise]): ANY failure — no pinned config, no receipt,
  // a receipt for a different candidate/head/lineage-head/slot/config, a
  // rejection or unknown COMPUTED verdict, an execution mismatch, a
  // gate-input mismatch, an unauthorized context, a pinned-authority
  // mismatch, a policy/context mismatch, a config-version substitution —
  // leaves EVERY cell completely unchanged (fail-closed).
  rule <k> pAcceptR2(_:ProtoBlockR2, _:Bytes, _:Bytes, _:Int) => .K ... </k>
       <r2lineage> L:Map </r2lineage>
       <r2next> N:Int </r2next>
       <r2head> H:Bytes </r2head>
       <r2linhead> LH:Bytes </r2linhead>
       <r2valid> V:Bool </r2valid>
    [owise]

endmodule
