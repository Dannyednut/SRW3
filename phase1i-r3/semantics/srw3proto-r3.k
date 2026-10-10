// =============================================================================
// SRW3 Phase 1I-R3 — FULL CONFIGURATION-ROOT BINDING (ISOLATED R3 MACHINE)
//                    (phase1i-r3/semantics/srw3proto-r3.k)
//
// Backend: HASKELL (proofs/structural core) + LLVM (concrete keccak demos via
// the Phase-1C krypto shim) + Python executable mirror (r3_model.py).
//
// REPAIR TARGET (handoff: SRW3_Phase1I_R3_ConfigRoot_Binding_Handoff.md §1;
// audit/CONFIG-ROOT-BINDING-AUDIT.md, finding R3-F1):
//   In the frozen R2 machine (phase1i-r2/semantics/srw3proto-r2.k), the
//   configuration-root preimage ProtoCfgCanonR2 (tag 0x9C) commits to config
//   fields 1..8 ONLY.  Fields 9..13 (schedule, specification version, authority
//   proof type, authority guest digest, authority proof-configuration digest)
//   are consulted by GateAuthorityMatchesCfgR2 and by the machine-built
//   authority context of VerifyLineageG, yet are ABSENT from ProtoRootR2: two
//   configurations that differ only in fields 9..13 share the R2 root preimage
//   (the R2 ALIAS) while they can derive different gate authority/decisions.
//   A local R2 machine pins all 13 fields, so R2's LOCAL receipt-provenance
//   result stands; the gap is CROSS-MACHINE ROOT IDENTITY: the root a remote
//   party would use to identify "the" configuration does not determine the
//   authority parameters the gate will enforce.
//
// R3 DESIGN (handoff sections 2-5):
//
//   1. ISOLATED MACHINE SURFACE (the R2 discipline, retained).  This
//      definition imports ONLY the frozen Phase 1G gate module SRW3AUTHZ
//      (phase1g/semantics/srw3authz.k, unchanged down to srw3lin.k+krypto.md).
//      It does NOT import SRW3PROTO, SRW3PROTO-R1, or SRW3PROTO-R2.  The
//      legacy commands (pInit/pAccept of 1I; pInitR1/pGateEval/pAcceptR1 of
//      R1; pInitR2/pGateEvalR2/pAcceptR2 of R2) are NOT in the R3 command
//      language: not declared in any imported module reachable from here, and
//      no rule of this definition matches them — they are ill-formed programs
//      (kparse rejects).  (R3-LEGACY-SURFACE-EXCLUDED.)
//
//   2. COMPLETE COMMITMENT (handoff §4 question A).  The R3 canonical
//      configuration preimage ProtoCfgCanonR3 is a NEW, versioned,
//      domain-separated, length-delimited encoding committing to ALL 13
//      fields, in the handoff §3 normative order:
//
//        ProtoCfgCanonR3(C) =
//            ASCII("SRW3/ProtoCfg/R3") || 0x00
//            || U32BE(encoding_version = 1)
//            || LP32(chainId) || U32BE(policyVersion) || LP32(policyDigest)
//            || LP32(appSetDigest) || LP32(graphDigest)
//            || LP32(clientConfigDigest) || LP32(execClientDigest)
//            || LP32(fork) || LP32(schedule) || U32BE(specVersion)
//            || U32BE(authProofType) || LP32(authGuestDigest)
//            || LP32(authConfigDigest)
//        LP32(x) = U32BE(byte_length(x)) || x
//        ProtoRootR3(C) = LinH(ProtoCfgCanonR3(C))
//
//      The old 0x9C preimage is NEVER reused (R3-DOMAIN-SEPARATION).  If any
//      of the 13 fields differs, the canonical preimage differs (structurally
//      demonstrable for concrete fixtures; the general hash-root statement is
//      conditional on Keccak collision resistance and is NOT claimed as an
//      injectivity theorem).  Hashing uses the project's frozen LinH (real
//      Ethereum Keccak-256); hashlib.sha3_256 is NOT interchangeable and is
//      not used anywhere.
//
//   3. THE AUTHORIZED ROOT ANCHOR (handoff §4 question B — the DISTINCT
//      requirement this phase adds).  A locally computed root is not
//      automatically an authenticated protocol root.  The machine therefore
//      carries a DEDICATED IMMUTABLE CELL <r3anchor> holding the protocol's
//      trusted configuration-root anchor, initialized from an EXPLICIT
//      AUTHENTICATED INPUT ($SRW3R3ANCHOR, a krun configuration variable —
//      the model of the protocol's trusted genesis/config-root channel: a
//      fixed protocol genesis value or an authenticated governance root).
//      The anchor is NOT reachable through the command language: no command
//      takes or returns an anchor, and no rule writes <r3anchor> (immutability
//      by construction; R3-ANCHOR-IMMUTABLE).  Initialization must CHECK
//      ProtoRootR3(C) ==K <r3anchor> before pinning (R3-INIT-REQUIRES-
//      AUTHORIZED-ROOT); a configuration whose computed root differs from the
//      anchor is refused with state unchanged, even if the caller also
//      presents a replacement root — the model has NO root-update transition
//      at all (handoff §5: no configuration upgrade transition in scope;
//      caller-supplied expectedRoot values are not self-authenticating).
//
//      WHERE THE ANCHOR COMES FROM (handoff §4, disclosed): the model treats
//      $SRW3R3ANCHOR as an explicitly external authenticated assumption —
//      the trusted genesis/configuration-root channel is OUTSIDE the modeled
//      command stream, mirroring how a consensus client receives its genesis
//      spec.  R3 proves complete commitment RELATIVE TO THAT ANCHOR; the
//      governance question (who may change the anchor) is NOT solved here and
//      is reported as an explicit assumption, NOT as an end-to-end closure.
//
//   4. STATE (handoff §5).  The machine has:
//        - the complete 13-field pinned configuration (reserved key -1);
//        - the immutable protocol-authorized root anchor (<r3anchor> cell);
//        - a mutable protocol chain head <r3head> anchored AT INITIALIZATION
//          to ProtoRootR3(C) (== the authorized anchor, by the init check);
//        - the separate evidence-lineage head <r3linhead> (retained from R2;
//          the 1D/1G record chain anchors the next record at its parent's
//          F-child commitment);
//        - the receipt pool (reserved key -2).
//      Receipts bind: the candidate, the execution-result inputs, the exact
//      gate evidence, the COMPUTED verdict, the pinned configuration, the
//      COMPUTED configuration root ProtoRootR3(C), the root anchor, the
//      protocol head, the lineage head, and the slot/counter at evaluation
//      time.  Acceptance re-checks that the receipt's root/config match the
//      currently pinned full configuration AND that the receipt's anchor
//      matches the trusted <r3anchor> (defense in depth — the anchor and pin
//      are immutable, so a mismatch can only arise from a machine built under
//      a different anchor/config, i.e. the cross-machine replay R3 excludes).
//
//   5. THE VERDICT IS COMPUTED, NEVER SUPPLIED (the R2 discipline, retained).
//      The only receipt-minting rule is pGateEvalR3: it takes the evidence
//      objects and the client-derived execution results and NO verdict
//      argument of any sort; it CONSTRUCTS the authority context from the
//      pinned configuration, SUPPLIES the position (slot counter + lineage
//      anchor), and EVALUATES VerifyLineageG — the frozen 21-conjunct gate is
//      the only producer of "valid-g".  The gate command continues to take no
//      caller verdict; acceptance requires the DERIVED decision of the
//      COMPUTED verdict (fail-closed mapping; only "valid-g" is protocol-
//      valid).  Missing, rejected, stale, root-mismatched, config-mismatched,
//      or reused receipts fail closed with state unchanged.
//
//   6. FROZEN-FORMULA CORRESPONDENCE DISCIPLINE (handoff §2).  The R2 and
//      earlier phases are preserved byte-for-byte; R3 does not import them.
//      The frozen Phase 1I/R2 PolicyCommitment and CtxDigest formulas are
//      REPRODUCED with IDENTICAL tags and composition (0x9D/0xA5/0xA6) —
//      their semantics are NOT changed by R3, so they keep the frozen names/
//      tags (R3-CORRESPONDENCE-*).  The block commitment (0x9E) and the
//      comparison SRW3 root (0x9F) are likewise unchanged.  The ONLY formula
//      R3 replaces is the configuration-root preimage: the frozen 0x9C shape
//      is superseded by the R3 domain-separated shape; the frozen shape is
//      retained in the R3 proofs module as a clearly labeled LEGACY WITNESS
//      ORACLE (LegacyR2ProjectionR3W) used by the R2-alias regression claims
//      — never by the R3 machine itself.
//
// CONFIGURATION NOTE: K admits exactly one <k> cell per definition; R3
// declares its own configuration <srw3protoR3> (cells <k> <r3lineage>
// <r3next> <r3head> <r3linhead> <r3anchor> <r3valid>).  The reserved-
// negative-key discipline of R1/R2 is retained: pinned configuration = key
// -1, receipt pool = key -2 (negative keys can never collide with block
// slots, which are >= 0).
//
// TRUST BOUNDARIES (stated, not hidden): (a) the verdict is the frozen
// VerifyLineageG result — its soundness rests on the frozen gate module
// (mechanized in Phase 1G); (b) hash equalities are symbolic constraints on
// the Haskell backend; concrete digests are decided on the LLVM backend
// (krypto shim, real Keccak-256) and in the Python mirror (real keccak,
// collision resistance ASSUMED, not proved); (c) the authorized root anchor
// is an explicitly external authenticated input (point 3) — protocol-root
// AUTHORITY/governance remains an explicit assumption; (d) the caller-
// presented evidence objects are a faithful execution record ONLY through
// the frozen gate's own replay/binding layers; (e) Level-III model — NO
// claim of actual Ethereum consensus integration is made or implied.
// =============================================================================

requires "../../phase1g/semantics/srw3authz.k"

module SRW3PROTO-R3
  imports SRW3AUTHZ

  // ===========================================================================
  // §1. The complete R3 protocol configuration — the same 13 fields as the
  //     frozen R2 ProtoCfgR2 (fields 1..8 = the frozen 1I ProtoCfg fields;
  //     fields 9..13 = the R2 authority additions), now ALL committed by the
  //     root (handoff §1/§3).
  // ===========================================================================

  syntax ProtoCfgR3 ::= "protoCfgR3" "(" qcrChainId:Bytes ","
                        qcrPolicyV:Int "," qcrPolicyD:Bytes ","
                        qcrAppSetD:Bytes "," qcrGraphD:Bytes ","
                        qcrClientCfgD:Bytes "," qcrExecClientD:Bytes ","
                        qcrFork:Bytes "," qcrSched:Bytes "," qcrSpec:Int ","
                        qcrAuthPT:Int "," qcrAuthGuestD:Bytes ","
                        qcrAuthCfgD:Bytes ")"

  syntax Bytes ::= qcrChainIdOf    ( ProtoCfgR3 ) [function, total]
  rule qcrChainIdOf(protoCfgR3(CH:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => CH:Bytes
  syntax Int ::= qcrPolicyVOf      ( ProtoCfgR3 ) [function, total]
  rule qcrPolicyVOf(protoCfgR3(_:Bytes, V:Int, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => V:Int
  syntax Bytes ::= qcrPolicyDOf    ( ProtoCfgR3 ) [function, total]
  rule qcrPolicyDOf(protoCfgR3(_:Bytes, _:Int, PD:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => PD:Bytes
  syntax Bytes ::= qcrAppSetDOf    ( ProtoCfgR3 ) [function, total]
  rule qcrAppSetDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, AS:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => AS:Bytes
  syntax Bytes ::= qcrGraphDOf     ( ProtoCfgR3 ) [function, total]
  rule qcrGraphDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, GR:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                              _:Int, _:Bytes, _:Bytes)) => GR:Bytes
  syntax Bytes ::= qcrClientCfgDOf ( ProtoCfgR3 ) [function, total]
  rule qcrClientCfgDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                  CC:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                  _:Int, _:Bytes, _:Bytes)) => CC:Bytes
  syntax Bytes ::= qcrExecClientDOf( ProtoCfgR3 ) [function, total]
  rule qcrExecClientDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                   _:Bytes, EC:Bytes, _:Bytes, _:Bytes, _:Int,
                                   _:Int, _:Bytes, _:Bytes)) => EC:Bytes
  syntax Bytes ::= qcrForkOf       ( ProtoCfgR3 ) [function, total]
  rule qcrForkOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, FK:Bytes, _:Bytes, _:Int,
                            _:Int, _:Bytes, _:Bytes)) => FK:Bytes
  syntax Bytes ::= qcrSchedOf      ( ProtoCfgR3 ) [function, total]
  rule qcrSchedOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, _:Bytes, _:Bytes, SC:Bytes, _:Int,
                             _:Int, _:Bytes, _:Bytes)) => SC:Bytes
  syntax Int ::= qcrSpecOf         ( ProtoCfgR3 ) [function, total]
  rule qcrSpecOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes, _:Bytes, SP:Int,
                            _:Int, _:Bytes, _:Bytes)) => SP:Int
  syntax Int ::= qcrAuthPTOf       ( ProtoCfgR3 ) [function, total]
  rule qcrAuthPTOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                              PT:Int, _:Bytes, _:Bytes)) => PT:Int
  syntax Bytes ::= qcrAuthGuestDOf ( ProtoCfgR3 ) [function, total]
  rule qcrAuthGuestDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                  _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                  _:Int, GD:Bytes, _:Bytes)) => GD:Bytes
  syntax Bytes ::= qcrAuthCfgDOf   ( ProtoCfgR3 ) [function, total]
  rule qcrAuthCfgDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                _:Int, _:Bytes, CD:Bytes)) => CD:Bytes

  // --------------------------------------------------------------------------
  // §1.3 THE NORMATIVE R3 CANONICAL ENCODING (handoff §3) — explicit versioned
  //      domain separator + length-delimited byte strings.  The frozen R2/1I
  //      0x9C preimage is NOT reused.  U32BE is unsigned 4-byte big-endian
  //      (the intended 32-bit discipline of the frozen I2B4); LP32 length-
  //      prefixes each byte field so adjacent fields are unambiguous.
  //      NOTE on input validation: the PYTHON encoder rejects negative /
  //      >2^32-1 integers and non-bytes fields BEFORE encoding (TypeError/
  //      ValueError; test suite).  In K, Int is unbounded; a garbage integer
  //      makes I2B4/Int2Bytes UNDEFINED (stuck), so a garbage configuration
  //      simply has no canonical preimage, no root, and cannot pass the init
  //      equality — the machine fails closed.  (K declares I2B4 total per the
  //      frozen srw3lin.k; the partiality of Int2Bytes on out-of-range ints is
  //      a K-builtin fact, disclosed here rather than papered over.)
  // --------------------------------------------------------------------------

  syntax Bytes ::= "R3DomainSep" [function, total]
  rule R3DomainSep
    => LinHex("535257332f50726f746f4366672f523300")   // "SRW3/ProtoCfg/R3" || 0x00 (17 bytes)

  syntax Int ::= "R3EncodingVersion" [function, total]
  rule R3EncodingVersion => 1

  syntax Bytes ::= LP32R3 ( Bytes ) [function, total]
  rule LP32R3(B:Bytes) => I2B4(lengthBytes(B)) +Bytes B

  syntax Bytes ::= ProtoCfgCanonR3 ( ProtoCfgR3 ) [function, total]
  rule ProtoCfgCanonR3(C:ProtoCfgR3)
    => R3DomainSep                                    // domain (17 B)
       +Bytes I2B4(R3EncodingVersion)                 // U32BE(1)
       +Bytes LP32R3(qcrChainIdOf(C))                 // field 1
       +Bytes I2B4(qcrPolicyVOf(C))                   // field 2
       +Bytes LP32R3(qcrPolicyDOf(C))                 // field 3
       +Bytes LP32R3(qcrAppSetDOf(C))                 // field 4
       +Bytes LP32R3(qcrGraphDOf(C))                  // field 5
       +Bytes LP32R3(qcrClientCfgDOf(C))              // field 6
       +Bytes LP32R3(qcrExecClientDOf(C))             // field 7
       +Bytes LP32R3(qcrForkOf(C))                    // field 8
       +Bytes LP32R3(qcrSchedOf(C))                   // field 9
       +Bytes I2B4(qcrSpecOf(C))                      // field 10
       +Bytes I2B4(qcrAuthPTOf(C))                    // field 11
       +Bytes LP32R3(qcrAuthGuestDOf(C))              // field 12
       +Bytes LP32R3(qcrAuthCfgDOf(C))                // field 13

  // The level-0 protocol root — the R3 composition (handoff §3).
  syntax Bytes ::= ProtoRootR3 ( ProtoCfgR3 ) [function]
  rule ProtoRootR3(C:ProtoCfgR3) => LinH(ProtoCfgCanonR3(C))

  // Structural config equality (decidable on the Haskell backend — used by
  // the accept guard so the config-identity conjunct resolves concretely
  // there whenever both sides are the same pinned object).
  syntax Bool ::= CfgEqR3 ( ProtoCfgR3 , ProtoCfgR3 ) [function, total]
  rule CfgEqR3(C1:ProtoCfgR3, C2:ProtoCfgR3)
    => BytesEq(qcrChainIdOf(C1), qcrChainIdOf(C2))
       andBool qcrPolicyVOf(C1) ==Int qcrPolicyVOf(C2)
       andBool BytesEq(qcrPolicyDOf(C1), qcrPolicyDOf(C2))
       andBool BytesEq(qcrAppSetDOf(C1), qcrAppSetDOf(C2))
       andBool BytesEq(qcrGraphDOf(C1), qcrGraphDOf(C2))
       andBool BytesEq(qcrClientCfgDOf(C1), qcrClientCfgDOf(C2))
       andBool BytesEq(qcrExecClientDOf(C1), qcrExecClientDOf(C2))
       andBool BytesEq(qcrForkOf(C1), qcrForkOf(C2))
       andBool BytesEq(qcrSchedOf(C1), qcrSchedOf(C2))
       andBool qcrSpecOf(C1) ==Int qcrSpecOf(C2)
       andBool qcrAuthPTOf(C1) ==Int qcrAuthPTOf(C2)
       andBool BytesEq(qcrAuthGuestDOf(C1), qcrAuthGuestDOf(C2))
       andBool BytesEq(qcrAuthCfgDOf(C1), qcrAuthCfgDOf(C2))

  // ===========================================================================
  // §2. Policy commitment / authorized context — FROZEN 1I formulas (§2 of
  //     srw3proto.k; byte-identical to the R2 reproduction), reproduced with
  //     identical tags and composition.  R3 does NOT change their semantics
  //     (handoff §2: name and version any changed formula; these are NOT
  //     changed) — they remain the historical correspondence points.  The
  //     policy commitment continues to cover policy fields 2..5 and the
  //     chain/fork identity; fields 9..13 are AUTHORITY parameters bound by
  //     the R3 ROOT (new) and enforced via the gate context construction, not
  //     by the policy commitment (unchanged division of labor, now with a
  //     root that actually determines all of it).
  // ===========================================================================

  // PolicyCommitment = H(0x9D || policyV || policyD || appSetD || graphD ||
  //                      PolicyAuthId),  PolicyAuthId = H(0xA5 || chainId || fork)
  syntax Bytes ::= PolicyCommitmentR3 ( ProtoCfgR3 ) [function]
  rule PolicyCommitmentR3(C:ProtoCfgR3)
    => LinH( Int2Bytes(1, 157, BE)                // 0x9D (frozen 1I tag)
             +Bytes I2B4(qcrPolicyVOf(C)) +Bytes qcrPolicyDOf(C)
             +Bytes qcrAppSetDOf(C) +Bytes qcrGraphDOf(C)
             +Bytes LinH( Int2Bytes(1, 165, BE)   // 0xA5 (frozen 1I tag)
                          +Bytes qcrChainIdOf(C) +Bytes qcrForkOf(C) ) )

  // The AUTHORIZED SecurityContext — derived from the pinned configuration
  // and the applicable lineage head; the gate consumes it; nothing
  // candidate- or caller-supplied can replace it (SC-10 discipline).
  syntax SecCtx ::= ProtoAuthorizedSecCtxR3 ( ProtoCfgR3 , Bytes ) [function]
  rule ProtoAuthorizedSecCtxR3(C:ProtoCfgR3, LH:Bytes)
    => secCtx(qcrPolicyVOf(C), qcrChainIdOf(C), qcrAppSetDOf(C),
              qcrGraphDOf(C), LH:Bytes)

  // Context canon + digest — frozen 1I formula (tag 0xA6).
  syntax Bytes ::= CtxCanonR3 ( SecCtx ) [function, total]
  rule CtxCanonR3(secCtx(V:Int, CH:Bytes, AS:Bytes, GR:Bytes, LH:Bytes))
    => Int2Bytes(1, 166, BE)                      // 0xA6 (frozen 1I tag)
       +Bytes I2B4(V) +Bytes CH +Bytes AS +Bytes GR +Bytes LH
  syntax Bytes ::= CtxDigestR3 ( SecCtx ) [function]
  rule CtxDigestR3(S:SecCtx) => LinH(CtxCanonR3(S))

  // ===========================================================================
  // §3. Protocol decisions — frozen 1I semantics (§3 of srw3proto.k): the
  //     decision is DERIVED from the gate verdict; ONLY "valid-g" is
  //     protocol-valid; every other verdict is pdecRejectR3 (fail-closed);
  //     a missing evaluation is pdecUnknownR3 (never silently valid).
  // ===========================================================================

  syntax Int ::= "pdecValidR3"   [function, total]
  syntax Int ::= "pdecRejectR3"  [function, total]
  syntax Int ::= "pdecUnknownR3" [function, total]
  rule pdecValidR3   => 1
  rule pdecRejectR3  => 0
  rule pdecUnknownR3 => 2

  syntax Int ::= ProtoDecisionOfGateR3 ( String ) [function, total]
  rule ProtoDecisionOfGateR3("valid-g") => pdecValidR3
  rule ProtoDecisionOfGateR3(S:String)  => pdecRejectR3 [owise]

  syntax Int ::= ProtoDecisionOfMissingR3 ( ) [function, total]
  rule ProtoDecisionOfMissingR3() => pdecUnknownR3

  // ===========================================================================
  // §4. The candidate block — frozen 1I ProtoBlock shape (§4 of srw3proto.k),
  //     same ten fields in the same order (R3 changes the CONFIGURATION ROOT,
  //     not the block shape).
  // ===========================================================================

  syntax ProtoBlockR3 ::= "protoBlockR3" "(" pbParentCommit:Bytes ","
                          pbPayloadD:Bytes "," pbParentRoot:Bytes ","
                          pbChildRoot:Bytes "," pbEffectD:Bytes ","
                          pbEvidenceD:Bytes "," pbCtxD:Bytes ","
                          pbPolCommit:Bytes "," pbDecision:Int ","
                          pbSlot:Int ")"

  syntax Bytes ::= pbParentCommitOf ( ProtoBlockR3 ) [function, total]
  rule pbParentCommitOf(protoBlockR3(PC:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                     _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                     _:Int, _:Int)) => PC:Bytes
  syntax Bytes ::= pbPayloadDOf ( ProtoBlockR3 ) [function, total]
  rule pbPayloadDOf(protoBlockR3(_:Bytes, PL:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => PL:Bytes
  syntax Bytes ::= pbParentRootOf ( ProtoBlockR3 ) [function, total]
  rule pbParentRootOf(protoBlockR3(_:Bytes, _:Bytes, PR:Bytes, _:Bytes,
                                   _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                   _:Int, _:Int)) => PR:Bytes
  syntax Bytes ::= pbChildRootOf ( ProtoBlockR3 ) [function, total]
  rule pbChildRootOf(protoBlockR3(_:Bytes, _:Bytes, _:Bytes, CR:Bytes,
                                  _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                  _:Int, _:Int)) => CR:Bytes
  syntax Bytes ::= pbEffectDOf ( ProtoBlockR3 ) [function, total]
  rule pbEffectDOf(protoBlockR3(_:Bytes, _:Bytes, _:Bytes, _:Bytes, EF:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => EF:Bytes
  syntax Bytes ::= pbEvidenceDOf ( ProtoBlockR3 ) [function, total]
  rule pbEvidenceDOf(protoBlockR3(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                  EV:Bytes, _:Bytes, _:Bytes, _:Int, _:Int))
    => EV:Bytes
  syntax Bytes ::= pbCtxDOf ( ProtoBlockR3 ) [function, total]
  rule pbCtxDOf(protoBlockR3(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, CX:Bytes, _:Bytes, _:Int, _:Int))
    => CX:Bytes
  syntax Bytes ::= pbPolCommitOf ( ProtoBlockR3 ) [function, total]
  rule pbPolCommitOf(protoBlockR3(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                  _:Bytes, _:Bytes, PL:Bytes, _:Int, _:Int))
    => PL:Bytes
  syntax Int ::= pbDecisionOf ( ProtoBlockR3 ) [function, total]
  rule pbDecisionOf(protoBlockR3(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, D:Int, _:Int))
    => D:Int
  syntax Int ::= pbSlotOf ( ProtoBlockR3 ) [function, total]
  rule pbSlotOf(protoBlockR3(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, _:Bytes, _:Bytes, _:Int, SL:Int))
    => SL:Int

  // Block commitment record — frozen 1I formula (tag 0x9E).
  syntax Bytes ::= BlockCommitCanonR3 ( ProtoBlockR3 , Bytes ) [function, total]
  rule BlockCommitCanonR3(B:ProtoBlockR3, PC:Bytes)
    => Int2Bytes(1, 158, BE)                      // 0x9E (frozen 1I tag)
       +Bytes pbParentCommitOf(B) +Bytes pbPayloadDOf(B)
       +Bytes pbParentRootOf(B) +Bytes pbChildRootOf(B)
       +Bytes pbEffectDOf(B) +Bytes pbEvidenceDOf(B) +Bytes pbCtxDOf(B)
       +Bytes PC +Bytes I2B4(pbDecisionOf(B)) +Bytes I2B4(pbSlotOf(B))

  syntax Bytes ::= BlockCommitR3 ( ProtoBlockR3 , ProtoCfgR3 ) [function]
  rule BlockCommitR3(B:ProtoBlockR3, C:ProtoCfgR3)
    => LinH(BlockCommitCanonR3(B, PolicyCommitmentR3(C)))

  // Combined SRW3 root — frozen 1I candidate D (tag 0x9F; comparison object,
  // NOT auto-selected; see the 1I report).
  syntax Bytes ::= SRW3RootR3 ( ProtoBlockR3 , ProtoCfgR3 ) [function]
  rule SRW3RootR3(B:ProtoBlockR3, C:ProtoCfgR3)
    => LinH( Int2Bytes(1, 159, BE)                // 0x9F (frozen 1I tag)
             +Bytes pbParentCommitOf(B) +Bytes PolicyCommitmentR3(C)
             +Bytes pbCtxDOf(B) +Bytes pbEvidenceDOf(B)
             +Bytes I2B4(pbDecisionOf(B)) )

  // ===========================================================================
  // §5. Validity predicates and Commit_P — frozen 1I composition (§5 of
  //     srw3proto.k) over the R3 objects.  CommitPR3 is the R3 commitment
  //     predicate: the ROOT it is relative to is ProtoRootR3 (complete 13-
  //     field commitment), and the configuration identity is anchored by the
  //     init-time check against <r3anchor> (§9) — the predicate itself is the
  //     frozen composition, unchanged.
  // ===========================================================================

  syntax Bool ::= ExecValidPR3 ( ProtoBlockR3 , Bytes , Bytes ) [function, total]
  rule ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
    => pbChildRootOf(B) ==K ERC  andBool  pbPayloadDOf(B) ==K ERP

  syntax Bool ::= SRW3ValidPR3 ( ProtoBlockR3 , ProtoCfgR3 , Bytes )
                  [function, total]
  rule SRW3ValidPR3(B:ProtoBlockR3, C:ProtoCfgR3, LH:Bytes)
    => pbDecisionOf(B) ==Int pdecValidR3
       andBool pbPolCommitOf(B) ==K PolicyCommitmentR3(C)
       andBool pbCtxDOf(B) ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(C, LH))

  syntax Bool ::= ValidPR3 ( ProtoBlockR3 , Bytes , Bytes , ProtoCfgR3 , Bytes )
                  [function, total]
  rule ValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
    => ExecValidPR3(B, ERC, ERP)  andBool  SRW3ValidPR3(B, C, LH)

  // THE CENTRAL PREDICATE (R3 form): Commit_P(B, ERC, ERP, C, LH).
  syntax Bool ::= CommitPR3 ( ProtoBlockR3 , Bytes , Bytes , ProtoCfgR3 ,
                              Bytes ) [function, total]
  rule CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
    => ValidPR3(B, ERC, ERP, C, LH)

  // Committed-chain validity (the 1I CommitChainLinked discipline, R3 form).
  syntax ProtoBlockR3 ::= blockAtR3 ( Map , Int ) [function, total]
  rule blockAtR3(T:Int |-> B:ProtoBlockR3 REST:Map, T2:Int) => B
    requires T ==Int T2
  rule blockAtR3(T:Int |-> _:ProtoBlockR3 REST:Map, T2:Int)
    => blockAtR3(REST, T2)  requires T =/=Int T2

  syntax Bool ::= CommitChainLinkedR3 ( Map , Int , ProtoCfgR3 )
                  [function, total]
  rule CommitChainLinkedR3(_:Map, 0:Int, _:ProtoCfgR3) => true
  rule CommitChainLinkedR3(L:Map, N:Int, C:ProtoCfgR3)
    => pbDecisionOf(blockAtR3(L, N -Int 1)) ==Int pdecValidR3
       andBool pbPolCommitOf(blockAtR3(L, N -Int 1))
               ==K PolicyCommitmentR3(C)
       andBool pbCtxDOf(blockAtR3(L, N -Int 1))
               ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(C,
                         pbParentRootOf(blockAtR3(L, N -Int 1))))
       andBool CommitChainLinkedR3(L, N -Int 1, C)
       andBool ( N ==Int 1 orBool
                 BytesEq(pbParentCommitOf(blockAtR3(L, N -Int 1)),
                         BlockCommitR3(blockAtR3(L, N -Int 2), C)) )
    requires N >=Int 1

  // ===========================================================================
  // §6. THE GATE-INPUT BINDING (handoff §5; the R2 predicates, R3 form) —
  //     named, explicit, structural (decidable on the Haskell backend).
  //     Every caller-presented evidence object is bound to the EXACT
  //     candidate block; the cryptographic closures (payload digest
  //     recomputation, certificate digest recomputation) are conjuncts INSIDE
  //     the frozen gate (L28 AzCertBindOk) — discharged by the gate evaluation
  //     itself (concrete on LLVM/Python; symbolic boundary on Haskell,
  //     documented).  The mint refuses unbound evidence; the accept re-checks
  //     the binding on the receipt-stored inputs (defense in depth).
  // ===========================================================================

  syntax Bool ::= GateInputMatchesBlockR3 ( ExecCtx , LinRecG , AuthzCert ,
                                            ProtoBlockR3 ) [function, total]
  rule GateInputMatchesBlockR3(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                               B:ProtoBlockR3)
    => BytesEq( azPayloadDOf(CERT), pbPayloadDOf(B) )              // payload identity
       andBool BytesEq( execCtxParentRoot(FC), pbParentRootOf(B) ) // parent state root
       andBool BytesEq( linStateRootOf(linRecFBase(linRecGBase(RG))),
                        pbChildRootOf(B) )                          // post-state root
       andBool BytesEq( linEffTraceDOf(linRecGBase(RG)),
                        pbEffectDOf(B) )                            // effect-trace digest
       andBool BytesEq( linAzCertDOf(RG), pbEvidenceDOf(B) )        // evidence identity

  // Gate authority parameters that arrive through the ExecCtx are pinned:
  // the presented schedule/spec must be the protocol-pinned values (fields
  // 9/10 — the very fields the R2 root omitted; here they are root-bound AND
  // still pinned, so the mint refuses a schedule/spec substitution outright).
  syntax Bool ::= GateAuthorityMatchesCfgR3 ( ExecCtx , ProtoCfgR3 )
                  [function, total]
  rule GateAuthorityMatchesCfgR3(FC:ExecCtx, C:ProtoCfgR3)
    => BytesEq( execCtxSched(FC), qcrSchedOf(C) )
       andBool execCtxSpec(FC) ==Int qcrSpecOf(C)

  // The machine-constructed authority context is the authorized projection:
  // SecCtx = protocol-authorized projection; authority triple = pinned config
  // fields 11..13.  Holds BY CONSTRUCTION for the mint-constructed AC; stated
  // as a named predicate so the accept guard and the proof ladder can
  // re-check it explicitly (field-wise, decidable).
  syntax Bool ::= AzSecEqR3 ( SecCtx , SecCtx ) [function, total]
  rule AzSecEqR3(S1:SecCtx, S2:SecCtx)
    => secPolicyVOf(S1) ==Int secPolicyVOf(S2)
       andBool BytesEq(secChainIdOf(S1), secChainIdOf(S2))
       andBool BytesEq(secAppSetDOf(S1), secAppSetDOf(S2))
       andBool BytesEq(secGraphDOf(S1), secGraphDOf(S2))
       andBool BytesEq(secLineageHeadOf(S1), secLineageHeadOf(S2))

  syntax Bool ::= GateCtxAuthorizedR3 ( AzCtx , ProtoCfgR3 , Bytes )
                  [function, total]
  rule GateCtxAuthorizedR3(AC:AzCtx, C:ProtoCfgR3, LH:Bytes)
    => AzSecEqR3( azSecOf(AC), ProtoAuthorizedSecCtxR3(C, LH) )
       andBool azAuthPTOf(AC) ==Int qcrAuthPTOf(C)
       andBool BytesEq( azAuthGuestDOf(AC), qcrAuthGuestDOf(C) )
       andBool BytesEq( azAuthCfgDOf(AC), qcrAuthCfgDOf(C) )

  // The F-child commitment of a record — the lineage-head advance (the
  // 1D/1G record chain anchors the next record at its parent's F-child).
  syntax Bytes ::= R3RecChildF ( LinRecG ) [function]
  rule R3RecChildF(RG:LinRecG)
    => ExecChildF( linRecFBase(linRecGBase(RG))
                 , linExecIdOf(linRecGBase(RG))
                 , linEffTraceDOf(linRecGBase(RG))
                 , linExecWDOf(linRecGBase(RG))
                 , linExecCfgDOf(linRecGBase(RG)) )

  // ===========================================================================
  // §7. Receipts — the ONLY in-model carrier of a gate verdict.  Created ONLY
  //     by pGateEvalR3; consumed exactly once by pAcceptR3.  The verdict
  //     field is WRITTEN ONLY by the mint rule, as the result of evaluating
  //     the frozen gate over the machine-constructed context and the
  //     machine-supplied position.  No command has a verdict-shaped argument.
  //
  //     R3 ADDITIONS (handoff §5): the receipt also binds
  //       gr3Root    — the COMPUTED complete-configuration root
  //                    ProtoRootR3(cfg) of the pinned configuration at mint
  //                    time (the full 13-field commitment), and
  //       gr3Anchor  — the trusted protocol root anchor (<r3anchor>) under
  //                    which the verdict was derived.
  //     Acceptance re-checks BOTH against the live machine state (the pinned
  //     configuration and the immutable anchor cell) — a receipt cannot be
  //     replayed across configurations, roots, or anchors (R3-CROSS-ROOT-
  //     REPLAY-REJECTS).
  // ===========================================================================

  syntax R3GateReceipt ::= "gateReceiptR3" "(" gr3Block:ProtoBlockR3 ","
                            gr3Erc:Bytes "," gr3Erp:Bytes ","
                            gr3FC:ExecCtx "," gr3RG:LinRecG ","
                            gr3CERT:AuthzCert "," gr3AC:AzCtx ","
                            gr3Verdict:String "," gr3Head:Bytes ","
                            gr3Slot:Int "," gr3LinHead:Bytes ","
                            gr3Cfg:ProtoCfgR3 "," gr3Root:Bytes ","
                            gr3Anchor:Bytes ")"

  syntax ProtoBlockR3 ::= gr3BlockOf   ( R3GateReceipt ) [function, total]
  syntax Bytes      ::= gr3ErcOf     ( R3GateReceipt ) [function, total]
  syntax Bytes      ::= gr3ErpOf     ( R3GateReceipt ) [function, total]
  syntax ExecCtx    ::= gr3FCOf      ( R3GateReceipt ) [function, total]
  syntax LinRecG    ::= gr3RGOf      ( R3GateReceipt ) [function, total]
  syntax AuthzCert  ::= gr3CERTOf    ( R3GateReceipt ) [function, total]
  syntax AzCtx      ::= gr3ACOf      ( R3GateReceipt ) [function, total]
  syntax String     ::= gr3VerdictOf ( R3GateReceipt ) [function, total]
  syntax Bytes      ::= gr3HeadOf    ( R3GateReceipt ) [function, total]
  syntax Int        ::= gr3SlotOf    ( R3GateReceipt ) [function, total]
  syntax Bytes      ::= gr3LinHeadOf ( R3GateReceipt ) [function, total]
  syntax ProtoCfgR3 ::= gr3CfgOf      ( R3GateReceipt ) [function, total]
  syntax Bytes      ::= gr3RootOf    ( R3GateReceipt ) [function, total]
  syntax Bytes      ::= gr3AnchorOf  ( R3GateReceipt ) [function, total]

  rule gr3BlockOf(gateReceiptR3(B:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                                _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                                _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                                _:Bytes, _:Bytes))
    => B:ProtoBlockR3
  rule gr3ErcOf(gateReceiptR3(_:ProtoBlockR3, E:Bytes, _:Bytes, _:ExecCtx,
                              _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                              _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                              _:Bytes, _:Bytes))
    => E:Bytes
  rule gr3ErpOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, P:Bytes, _:ExecCtx,
                              _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                              _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                              _:Bytes, _:Bytes))
    => P:Bytes
  rule gr3FCOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, FC:ExecCtx,
                             _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                             _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                             _:Bytes, _:Bytes))
    => FC:ExecCtx
  rule gr3RGOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                             RG:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                             _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                             _:Bytes, _:Bytes))
    => RG:LinRecG
  rule gr3CERTOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                               _:LinRecG, CT:AuthzCert, _:AzCtx, _:String,
                               _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                               _:Bytes, _:Bytes))
    => CT:AuthzCert
  rule gr3ACOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                             _:LinRecG, _:AuthzCert, AC:AzCtx, _:String,
                             _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                             _:Bytes, _:Bytes))
    => AC:AzCtx
  rule gr3VerdictOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                                  _:LinRecG, _:AuthzCert, _:AzCtx, V:String,
                                  _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                                  _:Bytes, _:Bytes))
    => V:String
  rule gr3HeadOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                               _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                               H:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                               _:Bytes, _:Bytes))
    => H:Bytes
  rule gr3SlotOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                               _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                               _:Bytes, S:Int, _:Bytes, _:ProtoCfgR3,
                               _:Bytes, _:Bytes))
    => S:Int
  rule gr3LinHeadOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                                  _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                                  _:Bytes, _:Int, LH:Bytes, _:ProtoCfgR3,
                                  _:Bytes, _:Bytes))
    => LH:Bytes
  rule gr3CfgOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                              _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                              _:Bytes, _:Int, _:Bytes, C:ProtoCfgR3,
                              _:Bytes, _:Bytes))
    => C:ProtoCfgR3
  rule gr3RootOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                               _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                               _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                               RT:Bytes, _:Bytes))
    => RT:Bytes
  rule gr3AnchorOf(gateReceiptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:ExecCtx,
                                 _:LinRecG, _:AuthzCert, _:AzCtx, _:String,
                                 _:Bytes, _:Int, _:Bytes, _:ProtoCfgR3,
                                 _:Bytes, AN:Bytes))
    => AN:Bytes

  // THE DERIVED DECISION — computed from the receipt's INTERNALLY COMPUTED
  // verdict by the frozen fail-closed mapping.  gr3DecisionOf(R) ==Int
  // pdecValidR3 holds iff gr3VerdictOf(R) ==K "valid-g" (the mapping's only
  // valid-producing input).
  syntax Int ::= gr3DecisionOf ( R3GateReceipt ) [function, total]
  rule gr3DecisionOf(R:R3GateReceipt)
    => ProtoDecisionOfGateR3(gr3VerdictOf(R))

  // ===========================================================================
  // §8. Reserved metadata region accessors (lineage-map keys -1 / -2), the
  //     R1/R2 discipline retained: literal Int keys, negative keys can never
  //     collide with block slots (block slots are >= 0).
  // ===========================================================================

  syntax ProtoCfgR3OrNone ::= ProtoCfgR3 | "noCfgR3"
  syntax ProtoCfgR3OrNone ::= storedCfgR3Of ( Map ) [function, total]
  rule storedCfgR3Of(-1 |-> C:ProtoCfgR3 REST:Map) => C:ProtoCfgR3
  rule storedCfgR3Of(REST:Map) => noCfgR3 [owise]

  syntax Set ::= receiptsR3Of ( Map ) [function, total]
  rule receiptsR3Of(-2 |-> S:Set REST:Map) => S:Set
  rule receiptsR3Of(REST:Map) => .Set [owise]

  syntax Bool ::= cfgPinnedR3 ( Map ) [function, total]
  rule cfgPinnedR3(-1 |-> _:ProtoCfgR3 REST:Map) => true
  rule cfgPinnedR3(REST:Map) => false [owise]

  // ===========================================================================
  // §9. The ISOLATED R3 machine surface — configuration and commands.
  //
  //     The command language is PProgR3I = lists of PCmdR3I.  The legacy
  //     commands (pInit/pAccept of SRW3PROTO; pInitR1/pGateEval/pAcceptR1 of
  //     R1; pInitR2/pGateEvalR2/pAcceptR2 of R2) are NOT in this language:
  //     their modules are not imported, their symbols are not declared here,
  //     and no rule of this definition matches them.  A program containing
  //     them is ill-formed (kparse rejects) — the old unsafe transitions are
  //     unreachable from the admitted command stream
  //     (R3-LEGACY-SURFACE-EXCLUDED).
  //
  //     THE ANCHOR IS NOT A COMMAND INPUT (handoff §4): <r3anchor> is filled
  //     by the AUTHENTICATED EXTERNAL INPUT $SRW3R3ANCHOR at machine
  //     instantiation.  No command takes an anchor, no command takes a root,
  //     and no rule writes the cell — the anchor is immutable by
  //     construction.  A caller-supplied "expectedRoot" in the command
  //     stream is therefore not expressible, let alone self-authenticating.
  // ===========================================================================

  syntax PCmdR3I ::= "pInitR3" "(" ProtoCfgR3 ")"
                  // gate evaluation: candidate, client execution context,
                  // lineage record, authority certificate, client-derived
                  // child root, client-derived payload identity.
                  // NO verdict/decision argument exists (any sort).
                  // NO configuration argument (the pin is immutable).
                  // NO root/anchor argument (the anchor is protocol input).
                  | "pGateEvalR3" "(" ProtoBlockR3 "," ExecCtx "," LinRecG ","
                                    AuthzCert "," Bytes "," Bytes ")"
                  // accept: candidate + execution results + the DECLARED
                  // config-version witness.  NO verdict, NO config, NO root,
                  // NO receipt argument (the receipt is machine state).
                  | "pAcceptR3" "(" ProtoBlockR3 "," Bytes "," Bytes ","
                                  Int ")"
  syntax PProgR3I ::= "runNilR3" | pConsR3(PCmdR3I, PProgR3I)

  configuration <srw3protoR3>
                  <k> $PGM:PProgR3I </k>
                  <r3lineage> .Map </r3lineage>   // slot -> ProtoBlockR3;
                                                  // -1 -> pinned ProtoCfgR3;
                                                  // -2 -> receipt pool (Set)
                  <r3next> 0 </r3next>
                  <r3head> R3GenesisHead </r3head>        // protocol chain
                  <r3linhead> R3LinRoot </r3linhead>      // evidence chain
                  // THE PROTOCOL-AUTHORIZED CONFIGURATION-ROOT ANCHOR —
                  // explicit authenticated external input (handoff §4 B);
                  // immutable: NO rule writes this cell.
                  <r3anchor> $SRW3R3ANCHOR:Bytes </r3anchor>
                  <r3valid> true </r3valid>
                </srw3protoR3>

  rule <k> pConsR3(C:PCmdR3I, RUN:PProgR3I) => C ~> RUN ... </k>
  rule <k> runNilR3 => .K ... </k>

  // genesis anchors: the protocol head (frozen 1I PGenesisHead form) and the
  // lineage root (the 1D record-chain anchor, 32 zero bytes).  The protocol
  // head is OVERWRITTEN at initialization to ProtoRootR3(C) (== the anchor,
  // by the init check) — the genesis value only exists before init.
  syntax Bytes ::= "R3GenesisHead" [function, total]
  rule R3GenesisHead => Int2Bytes(1, 0, BE)
  syntax Bytes ::= "R3LinRoot" [function, total]
  rule R3LinRoot => Int2Bytes(32, 0, BE)

  // ---------------------------------------------------------------------------
  // pInitR3 — pins the configuration ONCE, ONLY under the authorized root,
  // and anchors both heads.  Refuses to fire when a configuration is already
  // pinned (no re-initialization) or when ProtoRootR3(C) differs from the
  // trusted anchor (R3-INIT-REQUIRES-AUTHORIZED-ROOT — the decisive R3 init
  // check).  There is deliberately NO upgrade/root-update transition
  // (documented deferral, as in R1/R2).
  // ---------------------------------------------------------------------------
  rule <k> pInitR3(C:ProtoCfgR3) => .K ... </k>
       <r3head> _:Bytes => ProtoRootR3(C) </r3head>
       <r3linhead> _:Bytes => R3LinRoot </r3linhead>
       <r3lineage> L:Map => L[-1 <- C] </r3lineage>
       <r3anchor> A:Bytes </r3anchor>
    requires notBool cfgPinnedR3(L:Map)
         andBool BytesEq(ProtoRootR3(C), A:Bytes)

  // Refused initialization ([owise]): a config already pinned, or the
  // computed root does not match the trusted anchor (including ANY mutation
  // of fields 1..13 re-presented under the old authorized root, and any
  // caller attempt to re-pin under a different root).  Consumes the command,
  // changes NOTHING (fail-closed; R3-INIT-ROOT-MISMATCH-REJECTS,
  // R3-CONFIG-IMMUTABLE).
  rule <k> pInitR3(_:ProtoCfgR3) => .K ... </k>
       <r3lineage> L:Map </r3lineage>
       <r3next> N:Int </r3next>
       <r3head> H:Bytes </r3head>
       <r3linhead> LH:Bytes </r3linhead>
       <r3anchor> A:Bytes </r3anchor>
       <r3valid> V:Bool </r3valid>
    [owise]

  // ---------------------------------------------------------------------------
  // pGateEvalR3 — the ONLY rule that creates a receipt.  The machine:
  //   (a) constructs the authority context AC_m FROM THE PINNED CONFIGURATION
  //       (SecCtx := authorized projection for the candidate's parent root;
  //       authority triple := pinned fields 11..13) — the caller cannot name
  //       any of these values, and the gate never derives authority from the
  //       certificate/context it validates;
  //   (b) supplies the position: T := the next-slot counter, HEAD := the
  //       lineage anchor (machine state);
  //   (c) COMPUTES the verdict: VerifyLineageG(RG, AC_m, T, HEAD) — the
  //       frozen 21-conjunct gate — and stores it in the receipt;
  //   (d) binds the COMPLETE CONFIGURATION ROOT: gr3Root := ProtoRootR3(C)
  //       (the 13-field R3 root) and gr3Anchor := the trusted anchor;
  //   (e) binds the evidence to the EXACT candidate (GateInputMatchesBlockR3)
  //       and the presented schedule/spec to the pin
  //       (GateAuthorityMatchesCfgR3), and requires the candidate to sit at
  //       the current chain position (parent commitment == head, slot ==
  //       counter).
  //   Mutates NO chain state (the gate evaluates; it does not commit).
  // ---------------------------------------------------------------------------
  rule <k> pGateEvalR3(B:ProtoBlockR3, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                       ERC:Bytes, ERP:Bytes) => .K ... </k>
       <r3next> N:Int </r3next>
       <r3head> H:Bytes </r3head>
       <r3linhead> LH:Bytes </r3linhead>
       <r3anchor> A:Bytes </r3anchor>
       <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
                  ( -2:Int |-> PS:Set )
                  L3:Map
               => ( -1:Int |-> C:ProtoCfgR3 )
                  ( -2:Int |-> SetItem(
                        gateReceiptR3( B:ProtoBlockR3, ERC:Bytes, ERP:Bytes
                                     , FC:ExecCtx, RG:LinRecG
                                     , CERT:AuthzCert
                                     , azCtx( FC:ExecCtx
                                            , ProtoAuthorizedSecCtxR3(
                                                  C:ProtoCfgR3
                                                , pbParentRootOf(B:ProtoBlockR3) )
                                            , CERT:AuthzCert
                                            , qcrAuthPTOf(C:ProtoCfgR3)
                                            , qcrAuthGuestDOf(C:ProtoCfgR3)
                                            , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                     , VerifyLineageG(
                                           RG:LinRecG
                                         , azCtx( FC:ExecCtx
                                                , ProtoAuthorizedSecCtxR3(
                                                      C:ProtoCfgR3
                                                    , pbParentRootOf(B:ProtoBlockR3) )
                                                , CERT:AuthzCert
                                                , qcrAuthPTOf(C:ProtoCfgR3)
                                                , qcrAuthGuestDOf(C:ProtoCfgR3)
                                                , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                         , N:Int, LH:Bytes )
                                     , H:Bytes, N:Int, LH:Bytes
                                     , C:ProtoCfgR3
                                     , ProtoRootR3(C:ProtoCfgR3)
                                     , A:Bytes ))
                                       PS:Set )
                  L3:Map </r3lineage>
    requires GateInputMatchesBlockR3(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                     B:ProtoBlockR3)
         andBool GateAuthorityMatchesCfgR3(FC:ExecCtx, C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int

  rule <k> pGateEvalR3(B:ProtoBlockR3, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                       ERC:Bytes, ERP:Bytes) => .K ... </k>
       <r3next> N:Int </r3next>
       <r3head> H:Bytes </r3head>
       <r3linhead> LH:Bytes </r3linhead>
       <r3anchor> A:Bytes </r3anchor>
       <r3lineage> ( -1:Int |-> C:ProtoCfgR3 ) L3:Map
               => ( -1:Int |-> C:ProtoCfgR3 )
                  ( -2:Int |-> SetItem(
                        gateReceiptR3( B:ProtoBlockR3, ERC:Bytes, ERP:Bytes
                                     , FC:ExecCtx, RG:LinRecG
                                     , CERT:AuthzCert
                                     , azCtx( FC:ExecCtx
                                            , ProtoAuthorizedSecCtxR3(
                                                  C:ProtoCfgR3
                                                , pbParentRootOf(B:ProtoBlockR3) )
                                            , CERT:AuthzCert
                                            , qcrAuthPTOf(C:ProtoCfgR3)
                                            , qcrAuthGuestDOf(C:ProtoCfgR3)
                                            , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                     , VerifyLineageG(
                                           RG:LinRecG
                                         , azCtx( FC:ExecCtx
                                                , ProtoAuthorizedSecCtxR3(
                                                      C:ProtoCfgR3
                                                    , pbParentRootOf(B:ProtoBlockR3) )
                                                , CERT:AuthzCert
                                                , qcrAuthPTOf(C:ProtoCfgR3)
                                                , qcrAuthGuestDOf(C:ProtoCfgR3)
                                                , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                         , N:Int, LH:Bytes )
                                     , H:Bytes, N:Int, LH:Bytes
                                     , C:ProtoCfgR3
                                     , ProtoRootR3(C:ProtoCfgR3)
                                     , A:Bytes ))
                                       .Set )
                  L3:Map </r3lineage>
    requires notBool ( -2:Int in_keys(L3:Map) )
         andBool GateInputMatchesBlockR3(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                         B:ProtoBlockR3)
         andBool GateAuthorityMatchesCfgR3(FC:ExecCtx, C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int

  // ---------------------------------------------------------------------------
  // pAcceptR3 — the ONLY rule that extends the committed chain.  The guard IS
  // the commitment discipline.  Order note (the R2 discipline): the DECIDABLE
  // conjuncts precede the hash-equality conjuncts so that every structural
  // rejection resolves concretely on the Haskell backend (the [owise] reject
  // fires; a stuck hash conjunct cannot mask a decided false).  The R3
  // root/anchor re-checks are placed FIRST among the hash-class conjuncts:
  // the anchor conjunct is decidable whenever the anchor cell is concrete
  // (it always is in any machine instance), so a cross-root/cross-anchor
  // replay resolves concretely even on the Haskell backend.  On accept the
  // matching receipt is CONSUMED exactly once and the lineage head advances
  // to the accepted record's F-child.
  // ---------------------------------------------------------------------------
  rule <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K ... </k>
       <r3anchor> A:Bytes </r3anchor>
       <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
                  ( -2:Int |-> SetItem(R:R3GateReceipt) RS:Set )
                  L3:Map
               => ( -1:Int |-> C:ProtoCfgR3 )
                  ( -2:Int |-> RS )
                  ( L3[pbSlotOf(B:ProtoBlockR3) <- B:ProtoBlockR3] )
       </r3lineage>
       <r3next> N:Int => N +Int 1 </r3next>
       <r3head> H:Bytes => BlockCommitR3(B:ProtoBlockR3, C:ProtoCfgR3) </r3head>
       <r3linhead> LH:Bytes => R3RecChildF(gr3RGOf(R:R3GateReceipt)) </r3linhead>
       <r3valid> V:Bool => V:Bool </r3valid>
    requires gr3BlockOf(R) ==K B                                   // receipt match
         andBool gr3ErcOf(R) ==K ERC
         andBool gr3ErpOf(R) ==K ERP
         andBool gr3HeadOf(R) ==K H                                // head freshness
         andBool gr3SlotOf(R) ==Int N                              // slot freshness
         andBool gr3LinHeadOf(R) ==K LH                            // lineage freshness
         andBool CfgEqR3(gr3CfgOf(R), C)                           // config identity
         andBool BytesEq(gr3AnchorOf(R), A:Bytes)                  // ANCHOR re-check
         andBool gr3DecisionOf(R) ==Int pdecValidR3                // DERIVED decision
         andBool pbDecisionOf(B) ==Int pdecValidR3                 // decision binding
         andBool ExecValidPR3(B, ERC, ERP)                         // execution binding
         andBool BytesEq(linAzCertDOf(gr3RGOf(R)), pbEvidenceDOf(B)) // evidence identity
         andBool GateInputMatchesBlockR3(gr3FCOf(R), gr3RGOf(R),
                                         gr3CERTOf(R), B)          // input binding
         andBool GateCtxAuthorizedR3(gr3ACOf(R), C, pbParentRootOf(B)) // ctx authority
         andBool GateAuthorityMatchesCfgR3(gr3FCOf(R), C)          // pinned authority
         andBool BytesEq(pbParentCommitOf(B), H)                   // parent commitment
         andBool pbSlotOf(B) ==Int N                               // one block per slot
         andBool CV ==Int qcrPolicyVOf(C)                          // config witness
         andBool BytesEq(gr3RootOf(R), ProtoRootR3(C))             // ROOT re-check [hash]
         andBool pbPolCommitOf(B) ==K PolicyCommitmentR3(C)        // policy binding [hash]
         andBool pbCtxDOf(B) ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(
                                               C, pbParentRootOf(B))) // ctx binding [hash]

  // REJECT (restore, [owise]): ANY failure — no pinned config, no receipt,
  // a receipt for a different candidate/head/lineage-head/slot/config, a
  // receipt minted under a DIFFERENT root or a DIFFERENT anchor (the
  // cross-root replay exclusion), a rejection or unknown COMPUTED verdict,
  // an execution mismatch, a gate-input mismatch, an unauthorized context, a
  // pinned-authority mismatch, a policy/context mismatch, a config-version
  // substitution — leaves EVERY cell completely unchanged (fail-closed).
  rule <k> pAcceptR3(_:ProtoBlockR3, _:Bytes, _:Bytes, _:Int) => .K ... </k>
       <r3lineage> L:Map </r3lineage>
       <r3next> N:Int </r3next>
       <r3head> H:Bytes </r3head>
       <r3linhead> LH:Bytes </r3linhead>
       <r3anchor> A:Bytes </r3anchor>
       <r3valid> V:Bool </r3valid>
    [owise]

endmodule
