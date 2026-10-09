// =============================================================================
// SRW3 Phase 1I — PROTOCOL-AUTHORITATIVE COMMITMENT SEMANTICS
//                          (phase1i/semantics/srw3proto.k)
//
// Backend: HASKELL.  Purely ADDITIVE over the frozen Phase 1G layer
// (srw3authz.k is REQUIRED unchanged; the 1D/1E/1F chain is untouched).
//
// The Level-III protocol model (spec sections 3/4):
//
//     protocol input -> deterministic execution -> SRW3 evaluation
//         -> protocol validity predicate -> commit / reject
//
// New canonical tags (continuing the frozen tag discipline; distinct from
// 0x00/0x01/0x02 tree, 0x03 trace, 0x11/0x12/0x13 identity, 0x1F execId,
// 0x57 witness, 0x8C/0x8D/0x8E authority, 0xA1..0xA4 identity preimages):
//
//   0x9C  protocol-configuration body        (the level-0 authority object)
//   0x9D  policy commitment
//   0x9E  block-commitment record body
//   0x9F  combined SRW3 root (option D of the section-16 comparison;
//         defined for comparison, NOT auto-selected)
//   0xA5  policy-authority preimage (level-0 derived; 1I)
//   0xA6  security-context canon (the 1H-R1 SRW3-CONTEXT-H-V1 analog)
//
// THE CENTRAL PREDICATE (spec sections 2/4/7):
//
//   CommitP(B, ERC, ERP, CFG, LH)
//       =  ExecValidP(B, ERC, ERP)                 -- Ethereum validity, bound
//       andBool pbDecisionOf(B) ==Int pdecValid    -- a VALID SRW3 decision exists
//       andBool pbPolCommitOf(B) ==K PolicyCommitmentI(CFG)
//                                                  -- protocol-authorized policy
//       andBool pbCtxDOf(B) ==K CtxDigestI(ProtoAuthorizedSecCtx(CFG, LH))
//                                                  -- first-class context binding
//
//   ExecValidP binds the block to the CLIENT-DERIVED execution results
//   (child root + payload identity).  ProtoAuthorizedSecCtx derives the
//   authorized SecurityContext FROM THE CONFIGURATION (level 0) and the
//   applicable lineage head — never from the block (context-derived
//   authorized values, the 1G discipline at the protocol layer; SC-10:
//   no construction/substitution path from block-supplied data).
//
// Authority descent (spec section 6): policy authority is DERIVED from the
// protocol config (PolicyAuthId, tag 0xA5); a policy cannot authorize itself;
// evidence cannot authorize itself (the 1G gate layers remain in force under
// the gate-derived decision mapping ProtoDecisionOfGate).
// =============================================================================
requires "srw3authz.k"

module SRW3PROTO
  imports SRW3AUTHZ

  // ===========================================================================
  // §1. Level-0 protocol configuration
  // ===========================================================================

  syntax ProtoCfg ::= "protoCfg" "(" pcChainId:Bytes "," pcPolicyV:Int ","
                      pcPolicyD:Bytes "," pcAppSetD:Bytes "," pcGraphD:Bytes ","
                      pcClientCfgD:Bytes "," pcExecClientD:Bytes ","
                      pcFork:Bytes ")"

  syntax Bytes ::= pcChainIdOf    ( ProtoCfg ) [function, total]
  rule pcChainIdOf(protoCfg(CH:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes)) => CH:Bytes
  syntax Int ::= pcPolicyVOf      ( ProtoCfg ) [function, total]
  rule pcPolicyVOf(protoCfg(_:Bytes, V:Int, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes)) => V:Int
  syntax Bytes ::= pcPolicyDOf    ( ProtoCfg ) [function, total]
  rule pcPolicyDOf(protoCfg(_:Bytes, _:Int, PD:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes)) => PD:Bytes
  syntax Bytes ::= pcAppSetDOf    ( ProtoCfg ) [function, total]
  rule pcAppSetDOf(protoCfg(_:Bytes, _:Int, _:Bytes, AS:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes)) => AS:Bytes
  syntax Bytes ::= pcGraphDOf     ( ProtoCfg ) [function, total]
  rule pcGraphDOf(protoCfg(_:Bytes, _:Int, _:Bytes, _:Bytes, GR:Bytes,
                           _:Bytes, _:Bytes, _:Bytes)) => GR:Bytes
  syntax Bytes ::= pcClientCfgDOf ( ProtoCfg ) [function, total]
  rule pcClientCfgDOf(protoCfg(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                               CC:Bytes, _:Bytes, _:Bytes)) => CC:Bytes
  syntax Bytes ::= pcExecClientDOf( ProtoCfg ) [function, total]
  rule pcExecClientDOf(protoCfg(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                _:Bytes, EC:Bytes, _:Bytes)) => EC:Bytes
  syntax Bytes ::= pcForkOf       ( ProtoCfg ) [function, total]
  rule pcForkOf(protoCfg(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                         _:Bytes, _:Bytes, FK:Bytes)) => FK:Bytes

  syntax Bytes ::= ProtoCfgCanon ( ProtoCfg ) [function, total]
  rule ProtoCfgCanon(C:ProtoCfg)
    => Int2Bytes(1, 156, BE)                      // 0x9C
       +Bytes pcChainIdOf(C) +Bytes I2B4(pcPolicyVOf(C))
       +Bytes pcPolicyDOf(C) +Bytes pcAppSetDOf(C) +Bytes pcGraphDOf(C)
       +Bytes pcClientCfgDOf(C) +Bytes pcExecClientDOf(C) +Bytes pcForkOf(C)

  // The level-0 PROTOCOL ROOT (A-G2 made an explicit digest object).
  syntax Bytes ::= ProtoRoot ( ProtoCfg ) [function]
  rule ProtoRoot(C:ProtoCfg) => LinH(ProtoCfgCanon(C))

  // ===========================================================================
  // §2. Policy authority + PolicyCommitment (spec section 5)
  // ===========================================================================

  // The policy authority identity is DERIVED from the protocol configuration
  // (level 0 -> level 1 descent).  A policy cannot carry its own authority.
  syntax Bytes ::= PolicyAuthId ( ProtoCfg ) [function]
  rule PolicyAuthId(C:ProtoCfg)
    => LinH( Int2Bytes(1, 165, BE)                // 0xA5 policy-authority preimage
             +Bytes pcChainIdOf(C) +Bytes pcForkOf(C) )

  // PolicyCommitment = H(0x9D || policyV || policyDigest || appSetD ||
  //                      graphD || policyAuthorityId)
  // The SecurityContext is deliberately NOT an input (per-block mutable
  // client-derived state; it is bound at commitment-validation time via
  // CtxDigestI — see the report, section 5 justification).
  syntax Bytes ::= PolicyCommitmentI ( ProtoCfg ) [function]
  rule PolicyCommitmentI(C:ProtoCfg)
    => LinH( Int2Bytes(1, 157, BE)                // 0x9D
             +Bytes I2B4(pcPolicyVOf(C)) +Bytes pcPolicyDOf(C)
             +Bytes pcAppSetDOf(C) +Bytes pcGraphDOf(C)
             +Bytes PolicyAuthId(C) )

  // The AUTHORIZED SecurityContext: derived from the configuration and the
  // applicable lineage head.  This is the protocol-layer SC construction —
  // the gate consumes it; nothing block-supplied can replace it (SC-10).
  syntax SecCtx ::= ProtoAuthorizedSecCtx ( ProtoCfg , Bytes ) [function]
  rule ProtoAuthorizedSecCtx(C:ProtoCfg, LH:Bytes)
    => secCtx(pcPolicyVOf(C), pcChainIdOf(C), pcAppSetDOf(C),
              pcGraphDOf(C), LH:Bytes)

  // Context canon + digest (the 1H-R1 SRW3-CONTEXT-H-V1 analog; SC-9 anchor)
  syntax Bytes ::= CtxCanonI ( SecCtx ) [function, total]
  rule CtxCanonI(secCtx(V:Int, CH:Bytes, AS:Bytes, GR:Bytes, LH:Bytes))
    => Int2Bytes(1, 166, BE)                      // 0xA6
       +Bytes I2B4(V) +Bytes CH +Bytes AS +Bytes GR +Bytes LH
  syntax Bytes ::= CtxDigestI ( SecCtx ) [function]
  rule CtxDigestI(S:SecCtx) => LinH(CtxCanonI(S))

  // ===========================================================================
  // §3. Protocol decisions (gate-derived; spec sections 9/10)
  // ===========================================================================

  syntax Int ::= "pdecValid"   [function, total]
  syntax Int ::= "pdecReject"  [function, total]
  syntax Int ::= "pdecUnknown" [function, total]
  rule pdecValid   => 1
  rule pdecReject  => 0
  rule pdecUnknown => 2

  // The protocol decision is DERIVED from the frozen 1G gate verdict:
  // only "valid-g" (21 atomic conjuncts) is protocol-valid; every rejection
  // verdict maps to pdecReject; a MISSING evaluation (no verdict — the
  // evidence-availability case) maps to pdecUnknown (fail-closed: never
  // silently valid; spec section 10).
  syntax Int ::= ProtoDecisionOfGate ( String ) [function, total]
  rule ProtoDecisionOfGate("valid-g") => pdecValid
  rule ProtoDecisionOfGate(S:String)  => pdecReject [owise]

  syntax Int ::= ProtoDecisionOfMissing ( ) [function, total]
  rule ProtoDecisionOfMissing() => pdecUnknown

  // ===========================================================================
  // §4. The candidate block B (spec section 4)
  // ===========================================================================

  syntax ProtoBlock ::= "protoBlock" "(" pbParentCommit:Bytes ","
                       pbPayloadD:Bytes "," pbParentRoot:Bytes ","
                       pbChildRoot:Bytes "," pbEffectD:Bytes ","
                       pbEvidenceD:Bytes "," pbCtxD:Bytes ","
                       pbPolCommit:Bytes "," pbDecision:Int "," pbSlot:Int ")"

  syntax Bytes ::= pbParentCommitOf ( ProtoBlock ) [function, total]
  rule pbParentCommitOf(protoBlock(PC:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                   _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                   _:Int, _:Int)) => PC:Bytes
  syntax Bytes ::= pbPayloadDOf ( ProtoBlock ) [function, total]
  rule pbPayloadDOf(protoBlock(_:Bytes, PL:Bytes, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => PL:Bytes
  syntax Bytes ::= pbParentRootOf ( ProtoBlock ) [function, total]
  rule pbParentRootOf(protoBlock(_:Bytes, _:Bytes, PR:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => PR:Bytes
  syntax Bytes ::= pbChildRootOf ( ProtoBlock ) [function, total]
  rule pbChildRootOf(protoBlock(_:Bytes, _:Bytes, _:Bytes, CR:Bytes, _:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => CR:Bytes
  syntax Bytes ::= pbEffectDOf ( ProtoBlock ) [function, total]
  rule pbEffectDOf(protoBlock(_:Bytes, _:Bytes, _:Bytes, _:Bytes, EF:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => EF:Bytes
  syntax Bytes ::= pbEvidenceDOf ( ProtoBlock ) [function, total]
  rule pbEvidenceDOf(protoBlock(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                EV:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => EV:Bytes
  syntax Bytes ::= pbCtxDOf ( ProtoBlock ) [function, total]
  rule pbCtxDOf(protoBlock(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                           _:Bytes, CX:Bytes, _:Bytes, _:Int, _:Int))
    => CX:Bytes
  syntax Bytes ::= pbPolCommitOf ( ProtoBlock ) [function, total]
  rule pbPolCommitOf(protoBlock(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                _:Bytes, _:Bytes, PL:Bytes, _:Int, _:Int))
    => PL:Bytes
  syntax Int ::= pbDecisionOf ( ProtoBlock ) [function, total]
  rule pbDecisionOf(protoBlock(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, D:Int, _:Int))
    => D:Int
  syntax Int ::= pbSlotOf ( ProtoBlock ) [function, total]
  rule pbSlotOf(protoBlock(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                           _:Bytes, _:Bytes, _:Bytes, _:Int, SL:Int))
    => SL:Int

  // Block commitment record: parent commitment, payload, both state roots,
  // effect digest, evidence digest, context digest, the policy commitment
  // under which the decision was made, the decision, and the slot.
  syntax Bytes ::= BlockCommitCanon ( ProtoBlock , Bytes ) [function, total]
  rule BlockCommitCanon(B:ProtoBlock, PC:Bytes)
    => Int2Bytes(1, 158, BE)                      // 0x9E
       +Bytes pbParentCommitOf(B) +Bytes pbPayloadDOf(B)
       +Bytes pbParentRootOf(B) +Bytes pbChildRootOf(B)
       +Bytes pbEffectDOf(B) +Bytes pbEvidenceDOf(B) +Bytes pbCtxDOf(B)
       +Bytes PC +Bytes I2B4(pbDecisionOf(B)) +Bytes I2B4(pbSlotOf(B))

  syntax Bytes ::= BlockCommitI ( ProtoBlock , ProtoCfg ) [function]
  rule BlockCommitI(B:ProtoBlock, C:ProtoCfg)
    => LinH(BlockCommitCanon(B, PolicyCommitmentI(C)))

  // Combined SRW3 root — candidate D of the section-16 comparison (defined
  // for comparison; NOT auto-selected; see the report).
  syntax Bytes ::= SRW3RootI ( ProtoBlock , ProtoCfg ) [function]
  rule SRW3RootI(B:ProtoBlock, C:ProtoCfg)
    => LinH( Int2Bytes(1, 159, BE)                // 0x9F
             +Bytes pbParentCommitOf(B) +Bytes PolicyCommitmentI(C)
             +Bytes pbCtxDOf(B) +Bytes pbEvidenceDOf(B)
             +Bytes I2B4(pbDecisionOf(B)) )

  // ===========================================================================
  // §5. The validity predicates and Commit_P (spec sections 2/4/7)
  // ===========================================================================

  // Valid_Exec: the block is bound to the CLIENT-DERIVED execution results
  // (post-state root + payload identity) — the 1H L1 state-root binding.
  syntax Bool ::= ExecValidP ( ProtoBlock , Bytes , Bytes ) [function, total]
  rule ExecValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes)
    => pbChildRootOf(B) ==K ERC  andBool  pbPayloadDOf(B) ==K ERP

  // Valid_SRW3 (protocol projection): a decision EXISTS, is VALID, and the
  // context is the protocol-authorized projection for the applicable lineage
  // head (the 1G gate layers remain in force via ProtoDecisionOfGate).
  syntax Bool ::= SRW3ValidP ( ProtoBlock , ProtoCfg , Bytes ) [function, total]
  rule SRW3ValidP(B:ProtoBlock, C:ProtoCfg, LH:Bytes)
    => pbDecisionOf(B) ==Int pdecValid
       andBool pbPolCommitOf(B) ==K PolicyCommitmentI(C)
       andBool pbCtxDOf(B) ==K CtxDigestI(ProtoAuthorizedSecCtx(C, LH))

  // Valid_P = Valid_Exec AND Valid_SRW3
  syntax Bool ::= ValidP ( ProtoBlock , Bytes , Bytes , ProtoCfg , Bytes )
                  [function, total]
  rule ValidP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
    => ExecValidP(B, ERC, ERP)  andBool  SRW3ValidP(B, C, LH)

  // THE CENTRAL PREDICATE: Commit_P(B,C,E,Pi) with the applicable lineage
  // head LH supplied by the protocol state (parent-bound; the chain-level
  // ParentCommitted conjunct is carried by the transition discipline and the
  // PI7-STEP lemma).
  syntax Bool ::= CommitP ( ProtoBlock , Bytes , Bytes , ProtoCfg , Bytes )
                  [function, total]
  rule CommitP(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, LH:Bytes)
    => ValidP(B, ERC, ERP, C, LH)

  // ===========================================================================
  // §6. Committed-chain validity + the symbolic protocol run (spec section 8)
  //
  // The 1D GH-M threading architecture (srw3lin-symb.k), carried to the
  // protocol commitment layer: pAccept is the ONLY rule that extends the
  // committed chain, its requires ARE the commitment conditions (parent
  // committed, next slot, Commit_P), and <pvalid> threads the chain-validity
  // invariant through any accept sequence.  The PI-7 claims (base / step /
  // circularity) live in proofs/pi_proofs.k as a pure claims module.
  // ===========================================================================

  // block at a slot (total via guarded recursion, the linRecAt pattern)
  syntax ProtoBlock ::= blockAt ( Map , Int ) [function, total]
  rule blockAt(T:Int |-> B:ProtoBlock REST:Map, T2:Int) => B requires T ==Int T2
  rule blockAt(T:Int |-> _:ProtoBlock REST:Map, T2:Int) => blockAt(REST, T2)
    requires T =/=Int T2

  // (a) internal validity: slots 0..N-1 are Commit_P-valid blocks, each
  //     linked to its predecessor's commitment; (b) the head link is
  //     threaded by the accept rule (head := BlockCommitI) and the base root
  //     (the genesis head IS the protocol root — the level-0 anchor).
  syntax Bool ::= CommitChainLinked ( Map , Int , ProtoCfg ) [function, total]
  rule CommitChainLinked(_:Map, 0:Int, _:ProtoCfg) => true
  rule CommitChainLinked(L:Map, N:Int, C:ProtoCfg)
    => pbDecisionOf(blockAt(L, N -Int 1)) ==Int pdecValid
       andBool pbPolCommitOf(blockAt(L, N -Int 1)) ==K PolicyCommitmentI(C)
       andBool pbCtxDOf(blockAt(L, N -Int 1))
               ==K CtxDigestI(ProtoAuthorizedSecCtx(C,
                         pbParentRootOf(blockAt(L, N -Int 1))))
       andBool CommitChainLinked(L, N -Int 1, C)
       andBool ( N ==Int 1 orBool
                 BytesEq(pbParentCommitOf(blockAt(L, N -Int 1)),
                         BlockCommitI(blockAt(L, N -Int 2), C)) )
    requires N >=Int 1

  // ---- symbolic protocol run -------------------------------------------------
  // The 1D discipline (srw3lin-symb.k, finding 1C-1): the STRUCTURAL core is
  // isolated from crypto evaluation — the Haskell backend cannot evaluate
  // KRYPTO hooks, so the accept guard carries ONLY decidable structural
  // conditions (parent link, next slot) plus the SECURITY VERDICT as an
  // opaque Bool.  The verdict's SEMANTICS is pinned by the claims: SRW3OK
  // means CommitP(B,ERC,ERP,C,pbParentRootOf(B)) (PI7-STEP), and CommitP is
  // FALSE whenever the gate decision is not valid (PI2-*), the gate verdict
  // is not valid-g (PIB-GATELINK-*), or execution is invalid (PI2-EXEC).
  syntax PCmdI ::= "pAccept" "(" ProtoBlock "," Bytes "," Bytes "," ProtoCfg
                    "," Bool ")"      // Bool = the evaluated Commit_P verdict
  syntax PRunI ::= "runNil" | pCons(PCmdI, PRunI)

  configuration <srw3proto>
                  <k> $PGM:PRunI </k>
                  <plineage> .Map </plineage>      // Map slot -> ProtoBlock
                  <pnext> 0 </pnext>
                  <phead> PGenesisHead </phead>
                  <pvalid> true </pvalid>          // threaded chain validity
                </srw3proto>

  rule <k> pCons(C:PCmdI, RUN:PRunI) => C ~> RUN ... </k>
  rule <k> runNil => .K ... </k>

  // anchor the genesis head at the LEVEL-0 PROTOCOL ROOT (the commitment
  // chain starts at the protocol-authority anchor, not at an arbitrary byte
  // string — this is what makes ParentCommitted terminate at level 0)
  syntax Bytes ::= "PGenesisHead" [function, total]
  rule PGenesisHead => Int2Bytes(1, 0, BE)

  syntax PCmdI ::= "pInit" "(" ProtoCfg ")"
  rule <k> pInit(C:ProtoCfg) => .K ... </k>
       <phead> H0:Bytes => ProtoRoot(C) </phead>

  // position- and commitment-bound ACCEPT: the ONLY rule that extends the
  // committed chain.  Guard = decidable structural conditions + the opaque
  // security verdict (which the caller computed via Commit_P).
  rule <k> pAccept(B:ProtoBlock, ERC:Bytes, ERP:Bytes, C:ProtoCfg, SRW3OK:Bool)
            => .K ... </k>
       <plineage> L:Map => L[pbSlotOf(B) <- B] </plineage>
       <pnext> N:Int => N +Int 1 </pnext>
       <phead> H:Bytes => BlockCommitI(B, C) </phead>
       <pvalid> _:Bool => true </pvalid>
    requires BytesEq(pbParentCommitOf(B), H:Bytes)
         andBool pbSlotOf(B) ==Int N:Int
         andBool SRW3OK:Bool ==K true

  // REJECT (restore, [owise]): a block whose security verdict is false (or
  // that fails the structural linkage) cannot extend the chain — state
  // unchanged (PI-2 at the transition level).
  rule <k> pAccept(_:ProtoBlock, _:Bytes, _:Bytes, _:ProtoCfg, _:Bool) => .K ... </k>
       <plineage> L:Map </plineage>
       <pnext> N:Int </pnext>
       <phead> H:Bytes </phead>
       <pvalid> V:Bool </pvalid>
    [owise]

endmodule
