// =============================================================================
// SRW3 Phase 1G — Authority-rooted state and execution evidence
//                          (phase1g/semantics/srw3authz.k — ADDITIVE)
//
// Normative model spec: phase1g/semantics/MODEL.md (FROZEN).
//
// The frozen Phase 1D-R1 / 1E / 1F modules (srw3lin*.k, srw3auth.k,
// srw3exec.k) are NOT modified. This module is purely additive (the
// linCtxP / linRecE / execCtx precedents continue as azCtx / linRecG):
//
//   * authority domains + levels (MODEL.md §3): domConsensus/domPolicy at
//     level 0 (protocol authorization roots), domExecution/domProof at
//     level 1 (evidence producers); the certified object sits at level 2.
//
//   * the AuthorityCertificate (MODEL.md §3/§6): rel ∈ {1,2,3} with the
//     rel→domain mapping, the source, the authority chain (strict level
//     decrease terminating at a level-0 protocol root), policyV, proofPub.
//
//   * NoCircularAuthority (MODEL.md §4): the certificate never cites itself
//     (neither in its chain nor as its own source) and its chain strictly
//     decreases to a level-0 protocol root (or is empty for a level-0
//     source).
//
//   * authorized identities (MODEL.md §5): ALWAYS derived from the
//     verification context (chainId, fork config, policy version, pinned
//     proof descriptor) — never from the certificate being validated.
//
//   * SecurityContext (MODEL.md §7): policyV/chainId/appSetD/graphD/
//     lineageHead — the policy binding is part of the accept condition.
//
//   * LinRecG = (LinRecF, azCertD, azPolicyV) with CanonCoreG = CanonCoreF
//     || azCertD || policyV_4 (CanonCoreF a STRICT PREFIX; childG binds the
//     certificate and the policy version).
//
//   * VerifyLineageG: first-fail; the full 1F chain fires first (all its
//     verdicts unchanged), then the SEVEN new authority layers
//     (invalid-authtype / authrel / authlevel / authsrc / authcircle /
//     authbind / policy) and valid-g. Full accept = 21 atomic conjuncts
//     (MODEL.md §9).
//
//   * the access-list (BAL) analysis object (MODEL.md §12): footprint /
//     post-value checks — an ANALYSIS object, NOT a gate conjunct.
//
// Domain tags (new; collision-free against the frozen set): 0x8C cert body,
// 0x8D proof public inputs, 0x8E BAL object, 0xA1..0xA4 authorized-identity
// preimages.
// =============================================================================

requires "srw3exec.k"

module SRW3AUTHZ
  imports SRW3EXEC

  // ===========================================================================
  // §0. Authority domains and levels (MODEL.md §3)
  // ===========================================================================

  syntax AuthzDomain ::= "domConsensus" | "domExecution" | "domProof" | "domPolicy"

  syntax Int ::= AuthzDomByte ( AuthzDomain ) [function, total]
  rule AuthzDomByte(domConsensus) => 1
  rule AuthzDomByte(domExecution) => 2
  rule AuthzDomByte(domProof)     => 3
  rule AuthzDomByte(domPolicy)    => 4

  syntax Int ::= AuthzDomLevel ( AuthzDomain ) [function, total]
  rule AuthzDomLevel(domConsensus) => 0
  rule AuthzDomLevel(domPolicy)    => 0
  rule AuthzDomLevel(domExecution) => 1
  rule AuthzDomLevel(domProof)     => 1

  // domain equality (total; avoids ==K on a user sort inside the gate)
  syntax Bool ::= AzDomEq ( AuthzDomain , AuthzDomain ) [function, total]
  rule AzDomEq(D:AuthzDomain, D:AuthzDomain) => true
  rule AzDomEq(D1:AuthzDomain, D2:AuthzDomain) => false [owise]

  // ===========================================================================
  // §1. Authority sources and chain steps
  // ===========================================================================

  syntax AuthzSrc ::= "azSrc" "(" azSDom:AuthzDomain "," azSId:Bytes ","
                        azSLevel:Int ")"
  syntax AzStep   ::= "azStep" "(" azTDom:AuthzDomain "," azTId:Bytes ","
                        azTLevel:Int ")"

  syntax AuthzDomain ::= azSrcDomOf ( AuthzSrc ) [function, total]
  rule azSrcDomOf(azSrc(D:AuthzDomain, _:Bytes, _:Int)) => D
  syntax Bytes ::= azSrcIdOf ( AuthzSrc ) [function, total]
  rule azSrcIdOf(azSrc(_:AuthzDomain, I:Bytes, _:Int)) => I
  syntax Int ::= azSrcLevelOf ( AuthzSrc ) [function, total]
  rule azSrcLevelOf(azSrc(_:AuthzDomain, _:Bytes, L:Int)) => L

  syntax AuthzDomain ::= azStepDomOf ( AzStep ) [function, total]
  rule azStepDomOf(azStep(D:AuthzDomain, _:Bytes, _:Int)) => D
  syntax Bytes ::= azStepIdOf ( AzStep ) [function, total]
  rule azStepIdOf(azStep(_:AuthzDomain, I:Bytes, _:Int)) => I
  syntax Int ::= azStepLevelOf ( AzStep ) [function, total]
  rule azStepLevelOf(azStep(_:AuthzDomain, _:Bytes, L:Int)) => L

  // ===========================================================================
  // §2. Authorized identities — CONTEXT-derived, never certificate-derived
  //     (MODEL.md §5)
  // ===========================================================================

  syntax Bytes ::= AuthzConsensusId ( Bytes ) [function]
  rule AuthzConsensusId(CH:Bytes)
    => LinH(Int2Bytes(1, 161, BE) +Bytes CH)

  syntax Bytes ::= AuthzExecClientId ( Bytes , Bytes ) [function]
  rule AuthzExecClientId(CH:Bytes, CFG:Bytes)
    => LinH(Int2Bytes(1, 162, BE) +Bytes CH +Bytes CFG)

  syntax Bytes ::= AuthzProofSysId ( Int , Bytes , Bytes ) [function]
  rule AuthzProofSysId(PT:Int, G:Bytes, C:Bytes)
    => LinH(Int2Bytes(1, 163, BE) +Bytes I2B4(PT) +Bytes G +Bytes C)

  syntax Bytes ::= AuthzPolicyAuthId ( Int ) [function]
  rule AuthzPolicyAuthId(PV:Int)
    => LinH(Int2Bytes(1, 164, BE) +Bytes I2B4(PV))

  // ===========================================================================
  // §3. SecurityContext (MODEL.md §7)
  // ===========================================================================

  syntax SecCtx ::= "secCtx" "(" secPolicyV:Int "," secChainId:Bytes ","
                       secAppSetD:Bytes "," secGraphD:Bytes ","
                       secLineageHead:Bytes ")"

  syntax Int ::= secPolicyVOf ( SecCtx ) [function, total]
  rule secPolicyVOf(secCtx(V:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => V
  syntax Bytes ::= secChainIdOf ( SecCtx ) [function, total]
  rule secChainIdOf(secCtx(_:Int, CH:Bytes, _:Bytes, _:Bytes, _:Bytes)) => CH
  syntax Bytes ::= secAppSetDOf ( SecCtx ) [function, total]
  rule secAppSetDOf(secCtx(_:Int, _:Bytes, A:Bytes, _:Bytes, _:Bytes)) => A
  syntax Bytes ::= secGraphDOf ( SecCtx ) [function, total]
  rule secGraphDOf(secCtx(_:Int, _:Bytes, _:Bytes, G:Bytes, _:Bytes)) => G
  syntax Bytes ::= secLineageHeadOf ( SecCtx ) [function, total]
  rule secLineageHeadOf(secCtx(_:Int, _:Bytes, _:Bytes, _:Bytes, LH:Bytes)) => LH

  // ===========================================================================
  // §4. The AuthorityCertificate (MODEL.md §3/§6)
  // ===========================================================================

  syntax AuthzCert ::= "azCert" "(" azCPayloadD:Bytes "," azCParentRoot:Bytes ","
                         azCExecId:Bytes "," azCChildRoot:Bytes ","
                         azCEffectD:Bytes "," azCRel:Int ","
                         azCSrc:AuthzSrc "," azCChain:List ","
                         azCPolicyV:Int "," azCProofPub:Bytes ")"

  syntax Bytes ::= azPayloadDOf  ( AuthzCert ) [function, total]
  rule azPayloadDOf(azCert(P:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                           _:AuthzSrc, _:List, _:Int, _:Bytes)) => P
  syntax Bytes ::= azParentRootOf ( AuthzCert ) [function, total]
  rule azParentRootOf(azCert(_:Bytes, PR:Bytes, _:Bytes, _:Bytes, _:Bytes,
                             _:Int, _:AuthzSrc, _:List, _:Int, _:Bytes)) => PR
  syntax Bytes ::= azExecIdOf ( AuthzCert ) [function, total]
  rule azExecIdOf(azCert(_:Bytes, _:Bytes, E:Bytes, _:Bytes, _:Bytes, _:Int,
                         _:AuthzSrc, _:List, _:Int, _:Bytes)) => E
  syntax Bytes ::= azChildRootOf ( AuthzCert ) [function, total]
  rule azChildRootOf(azCert(_:Bytes, _:Bytes, _:Bytes, CR:Bytes, _:Bytes,
                            _:Int, _:AuthzSrc, _:List, _:Int, _:Bytes)) => CR
  syntax Bytes ::= azEffectDOf ( AuthzCert ) [function, total]
  rule azEffectDOf(azCert(_:Bytes, _:Bytes, _:Bytes, _:Bytes, ED:Bytes,
                          _:Int, _:AuthzSrc, _:List, _:Int, _:Bytes)) => ED
  syntax Int ::= azRelOf ( AuthzCert ) [function, total]
  rule azRelOf(azCert(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, R:Int,
                      _:AuthzSrc, _:List, _:Int, _:Bytes)) => R
  syntax AuthzSrc ::= azSrcOf ( AuthzCert ) [function, total]
  rule azSrcOf(azCert(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                      S:AuthzSrc, _:List, _:Int, _:Bytes)) => S
  syntax List ::= azChainOf ( AuthzCert ) [function, total]
  rule azChainOf(azCert(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                        _:AuthzSrc, CH:List, _:Int, _:Bytes)) => CH
  syntax Int ::= azPolicyVOf ( AuthzCert ) [function, total]
  rule azPolicyVOf(azCert(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                          _:AuthzSrc, _:List, V:Int, _:Bytes)) => V
  syntax Bytes ::= azProofPubOf ( AuthzCert ) [function, total]
  rule azProofPubOf(azCert(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                           _:AuthzSrc, _:List, _:Int, PP:Bytes)) => PP

  // canonical encodings (MODEL.md §6)
  syntax Bytes ::= AzStepCanon ( AzStep ) [function, total]
  rule AzStepCanon(azStep(D:AuthzDomain, I:Bytes, L:Int))
    => Int2Bytes(1, AuthzDomByte(D), BE) +Bytes I +Bytes I2B4(L)

  syntax Bytes ::= AzChainBytes ( List ) [function, total]
  rule AzChainBytes(.List) => .Bytes
  rule AzChainBytes(ListItem(S:AzStep) REST:List)
    => AzStepCanon(S) +Bytes AzChainBytes(REST)

  syntax Bytes ::= AzCertBody ( AuthzCert ) [function, total]
  rule AzCertBody(C:AuthzCert)
    => Int2Bytes(1, 140, BE)                       // 0x8C
       +Bytes azPayloadDOf(C) +Bytes azParentRootOf(C) +Bytes azExecIdOf(C)
       +Bytes azChildRootOf(C) +Bytes azEffectDOf(C)
       +Bytes Int2Bytes(1, azRelOf(C), BE)
       +Bytes ( Int2Bytes(1, AuthzDomByte(azSrcDomOf(azSrcOf(C))), BE)
                +Bytes azSrcIdOf(azSrcOf(C))
                +Bytes I2B4(azSrcLevelOf(azSrcOf(C))) )
       +Bytes AzChainBytes(azChainOf(C))
       +Bytes I2B4(azPolicyVOf(C))
       +Bytes azProofPubOf(C)

  syntax Bytes ::= AzCertId ( AuthzCert ) [function]
  rule AzCertId(C:AuthzCert) => LinH(AzCertBody(C))

  syntax Bool ::= AzCertPubEmpty ( AuthzCert ) [function, total]
  rule AzCertPubEmpty(C:AuthzCert) => azProofPubOf(C) ==K .Bytes

  // proof public inputs (rel=3; MODEL.md §6)
  syntax Bytes ::= AzProofPub ( Bytes , Bytes , Bytes , Bytes , Int , Bytes ,
                                Int , Bytes , Bytes , Bytes ) [function]
  rule AzProofPub(PLD:Bytes, PR:Bytes, CH:Bytes, SCH:Bytes, SPEC:Int,
                  CR:Bytes, PV:Int, APPD:Bytes, GRD:Bytes, LH:Bytes)
    => LinH( Int2Bytes(1, 141, BE)               // 0x8D
             +Bytes PLD +Bytes PR +Bytes CH +Bytes SCH +Bytes I2B4(SPEC)
             +Bytes CR +Bytes I2B4(PV) +Bytes APPD +Bytes GRD +Bytes LH )

  // ===========================================================================
  // §5. NoCircularAuthority (MODEL.md §4)
  // ===========================================================================

  // own-id membership in the chain
  syntax Bool ::= AzOwnInChain ( List , Bytes ) [function, total]
  rule AzOwnInChain(.List, _:Bytes) => false
  rule AzOwnInChain(ListItem(azStep(_:AuthzDomain, I:Bytes, _:Int)) REST:List,
                    CID:Bytes)
    => BytesEq(I, CID) orBool AzOwnInChain(REST, CID)

  // strict level decrease terminating at a level-0 protocol root, with EVERY
  // step's identity authorized for its domain (context-derived checks — a
  // chain step may never carry an arbitrary claimed id); empty chain is
  // valid iff the source level is already 0.
  syntax Bool ::= AzChainOk ( List , Int , ExecCtx , SecCtx , Int , Bytes ,
                              Bytes ) [function, total]
  rule AzChainOk(.List, CUR:Int, _:ExecCtx, _:SecCtx, _:Int, _:Bytes, _:Bytes)
    => CUR ==Int 0
  rule AzChainOk(ListItem(azStep(D:AuthzDomain, I:Bytes, L:Int)) REST:List,
                 CUR:Int, FC:ExecCtx, SEC:SecCtx, PT:Int, G:Bytes, C:Bytes)
    => L >=Int 0 andBool L <Int CUR
       andBool AzSrcAuthorized(azSrc(D, I, L), FC, SEC, PT, G, C)
       andBool ( ( L ==Int 0
                   andBool (D ==K domConsensus orBool D ==K domPolicy)
                   andBool REST :List ==K .List )
               orBool AzChainOk(REST, L, FC, SEC, PT, G, C) )

  // the mechanized NoCircularAuthority conjunct (non-total: hashes certId)
  syntax Bool ::= AzNonCircular ( AuthzCert , ExecCtx , SecCtx , Int , Bytes ,
                                  Bytes ) [function]
  rule AzNonCircular(C:AuthzCert, FC:ExecCtx, SEC:SecCtx, PT:Int, G:Bytes,
                     CFD:Bytes)
    => notBool BytesEq(azSrcIdOf(azSrcOf(C)), AzCertId(C))
       andBool notBool AzOwnInChain(azChainOf(C), AzCertId(C))
       andBool AzChainOk(azChainOf(C), azSrcLevelOf(azSrcOf(C)),
                         FC, SEC, PT, G, CFD)

  // ===========================================================================
  // §6. Source authorization (context-derived; MODEL.md §5)
  // ===========================================================================

  syntax Bool ::= AzSrcAuthorized ( AuthzSrc , ExecCtx , SecCtx , Int , Bytes ,
                                    Bytes ) [function, total]
  rule AzSrcAuthorized(azSrc(domConsensus, I:Bytes, _:Int), _:ExecCtx,
                       SEC:SecCtx, _:Int, _:Bytes, _:Bytes)
    => BytesEq(I, AuthzConsensusId(secChainIdOf(SEC)))
  rule AzSrcAuthorized(azSrc(domExecution, I:Bytes, _:Int), FC:ExecCtx,
                       SEC:SecCtx, _:Int, _:Bytes, _:Bytes)
    => BytesEq(I, AuthzExecClientId( secChainIdOf(SEC)
                                   , ExecConfigDigest(execCtxSched(FC)
                                                    , execCtxSpec(FC)) ))
  rule AzSrcAuthorized(azSrc(domProof, I:Bytes, _:Int), _:ExecCtx, _:SecCtx,
                       PT:Int, G:Bytes, C:Bytes)
    => BytesEq(I, AuthzProofSysId(PT, G, C))
  rule AzSrcAuthorized(azSrc(domPolicy, I:Bytes, _:Int), _:ExecCtx,
                       SEC:SecCtx, _:Int, _:Bytes, _:Bytes)
    => BytesEq(I, AuthzPolicyAuthId(secPolicyVOf(SEC)))
  rule AzSrcAuthorized(azSrc(D:AuthzDomain, _:Bytes, _:Int), _:ExecCtx,
                       _:SecCtx, _:Int, _:Bytes, _:Bytes)
    => false [owise]

  // rel → required source domain (the catch-all is never consulted: the
  // authtype layer rejects rel outside {1,2,3} first; totality only)
  syntax AuthzDomain ::= AzRelDomain ( Int ) [function, total]
  rule AzRelDomain(1) => domConsensus
  rule AzRelDomain(2) => domExecution
  rule AzRelDomain(3) => domProof
  rule AzRelDomain(_:Int) => domConsensus [owise]

  // ===========================================================================
  // §7. Additive record extension LinRecG (MODEL.md §8)
  // ===========================================================================

  syntax LinRecG ::= "linRecG" "(" base:LinRecF "," linAzCertD:Bytes ","
                       linAzPolicyV:Int ")"

  syntax LinRecF ::= linRecGBase ( LinRecG ) [function, total]
  rule linRecGBase(linRecG(RF:LinRecF, _:Bytes, _:Int)) => RF
  syntax Bytes ::= linAzCertDOf ( LinRecG ) [function, total]
  rule linAzCertDOf(linRecG(_:LinRecF, D:Bytes, _:Int)) => D
  syntax Int ::= linAzPolicyVOf ( LinRecG ) [function, total]
  rule linAzPolicyVOf(linRecG(_:LinRecF, _:Bytes, V:Int)) => V

  // CanonCoreG = CanonCoreF || azCertD || policyV_4 (CanonCoreF STRICT PREFIX)
  syntax Bytes ::= AzCanonCoreG ( LinRecF , Bytes , Int ) [function]
  rule AzCanonCoreG(RF:LinRecF, D:Bytes, V:Int)
    => ExecCanonCoreF( linRecFBase(RF), linExecIdOf(RF), linEffTraceDOf(RF)
                     , linExecWDOf(RF), linExecCfgDOf(RF) )
       +Bytes D +Bytes I2B4(V)

  syntax Bytes ::= AzChildG ( LinRecF , Bytes , Int ) [function]
  rule AzChildG(RF:LinRecF, D:Bytes, V:Int) => LinH(AzCanonCoreG(RF, D, V))

  // honest record construction from an honest F record + an honest cert
  // (the certificate must bind the record's own fields — enforced by the
  //  gate; the builder pins azCertD = AzCertId(cert) and policyV)
  syntax LinRecG ::= AzBuildRecG ( LinRecF , AuthzCert , Int ) [function]
  rule AzBuildRecG(RF:LinRecF, C:AuthzCert, PV:Int)
    => linRecG(RF, AzCertId(C), PV)

  // ===========================================================================
  // §8. Certificate binding (the record↔certificate surface; MODEL.md §9 L28)
  // ===========================================================================

  syntax Bool ::= AzCertBindOk ( AuthzCert , LinRecG , ExecCtx , SecCtx ) [function, total]
  rule AzCertBindOk(C:AuthzCert, RG:LinRecG, FC:ExecCtx, SEC:SecCtx)
    => BytesEq( AzCertId(C), linAzCertDOf(RG) )
       andBool BytesEq( azPayloadDOf(C)
                      , ExecPayloadDigest(execCtxPayload(FC)) )
       andBool BytesEq( azParentRootOf(C), execCtxParentRoot(FC) )
       andBool BytesEq( azExecIdOf(C), linExecIdOf(linRecGBase(RG)) )
       andBool BytesEq( azChildRootOf(C)
                      , linStateRootOf(linRecFBase(linRecGBase(RG))) )
       andBool BytesEq( azEffectDOf(C), linEffTraceDOf(linRecGBase(RG)) )
       andBool ( notBool (azRelOf(C) ==Int 3)
                 orBool
                 BytesEq( azProofPubOf(C)
                        , AzProofPub( azPayloadDOf(C), azParentRootOf(C)
                                    , secChainIdOf(SEC), execCtxSched(FC)
                                    , execCtxSpec(FC), azChildRootOf(C)
                                    , azPolicyVOf(C), secAppSetDOf(SEC)
                                    , secGraphDOf(SEC)
                                    , secLineageHeadOf(SEC) ) ) )
       andBool ( azRelOf(C) ==Int 3
                 orBool azProofPubOf(C) ==K .Bytes )

  // ===========================================================================
  // §9. The G verification context (MODEL.md §9)
  // ===========================================================================

  syntax AzCtx ::= "azCtx" "(" azFctx:ExecCtx "," azSec:SecCtx ","
                      azCert:AuthzCert "," azAuthPT:Int ","
                      azAuthGuestD:Bytes "," azAuthCfgD:Bytes ")"

  syntax ExecCtx ::= azFctxOf ( AzCtx ) [function, total]
  rule azFctxOf(azCtx(C:ExecCtx, _:SecCtx, _:AuthzCert, _:Int, _:Bytes, _:Bytes)) => C
  syntax SecCtx ::= azSecOf ( AzCtx ) [function, total]
  rule azSecOf(azCtx(_:ExecCtx, S:SecCtx, _:AuthzCert, _:Int, _:Bytes, _:Bytes)) => S
  syntax AuthzCert ::= azCertOf ( AzCtx ) [function, total]
  rule azCertOf(azCtx(_:ExecCtx, _:SecCtx, C:AuthzCert, _:Int, _:Bytes, _:Bytes)) => C
  syntax Int ::= azAuthPTOf ( AzCtx ) [function, total]
  rule azAuthPTOf(azCtx(_:ExecCtx, _:SecCtx, _:AuthzCert, P:Int, _:Bytes, _:Bytes)) => P
  syntax Bytes ::= azAuthGuestDOf ( AzCtx ) [function, total]
  rule azAuthGuestDOf(azCtx(_:ExecCtx, _:SecCtx, _:AuthzCert, _:Int, G:Bytes, _:Bytes)) => G
  syntax Bytes ::= azAuthCfgDOf ( AzCtx ) [function, total]
  rule azAuthCfgDOf(azCtx(_:ExecCtx, _:SecCtx, _:AuthzCert, _:Int, _:Bytes, D:Bytes)) => D

  // ===========================================================================
  // §10. VerifyLineageG (first-fail, total; MODEL.md §9)
  //
  // The F-conjunct block (inherited verbatim from the 1F accept rule):
  //   F1 VerifyLineageA(base, authctx, T, HEAD) ==String "valid-a"
  //   F2 ExecBoundsOk(execCtxTrace(FC))
  //   F3 linExecCfgDOf(RF) == ExecConfigDigest(sched, spec)
  //   F4 linExecIdOf(RF) == ExecExecId(parentRoot, payloadD, configD, envD)
  //   F5 linEffTraceDOf(RF) == ExecTraceDigest(trace)
  //   F6 ExecDeclaredOk(declared, trace)
  //   F7 ExecWitnessOk(wit, RF, FC)
  //   F8 ExecReplayOk(inputs, trace, state)
  // ===========================================================================

  syntax String ::= VerifyLineageG ( LinRecG , AzCtx , Int , Bytes ) [function, total]

  // Layer 0: the full 1F chain fires first (unchanged, on the F projection).
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
    requires notBool VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"

  // L23 invalid-authtype — unknown authority relation.
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authtype"
    requires VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"
             andBool notBool ( azRelOf(azCertOf(C)) ==Int 1
                               orBool azRelOf(azCertOf(C)) ==Int 2
                               orBool azRelOf(azCertOf(C)) ==Int 3 )

  // L24 invalid-authrel — rel ↔ source-domain mismatch.
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authrel"
    requires VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"
             andBool ( azRelOf(azCertOf(C)) ==Int 1
                       orBool azRelOf(azCertOf(C)) ==Int 2
                       orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool notBool
                     AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )

  // L25 invalid-authlevel — the claimed level is not the domain's level.
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authlevel"
    requires VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"
             andBool ( azRelOf(azCertOf(C)) ==Int 1
                       orBool azRelOf(azCertOf(C)) ==Int 2
                       orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool notBool
                     azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))

  // L27 invalid-authcircle — NoCircularAuthority (checked BEFORE authsrc so
  // that a self-referencing source is diagnosed as circular even when the
  // source identity cannot be authorized).
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authcircle"
    requires VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"
             andBool ( azRelOf(azCertOf(C)) ==Int 1
                       orBool azRelOf(azCertOf(C)) ==Int 2
                       orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool notBool AzNonCircular(azCertOf(C), azFctxOf(C),
                                           azSecOf(C), azAuthPTOf(C),
                                           azAuthGuestDOf(C),
                                           azAuthCfgDOf(C))

  // L26 invalid-authsrc — the source identity is not the context-derived
  // authorized identity for its domain (CM-G10 lands here for rel=3).
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authsrc"
    requires VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"
             andBool ( azRelOf(azCertOf(C)) ==Int 1
                       orBool azRelOf(azCertOf(C)) ==Int 2
                       orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool AzNonCircular(azCertOf(C), azFctxOf(C), azSecOf(C),
                                   azAuthPTOf(C), azAuthGuestDOf(C),
                                   azAuthCfgDOf(C))
             andBool notBool
                     AzSrcAuthorized( azSrcOf(azCertOf(C)), azFctxOf(C)
                                    , azSecOf(C), azAuthPTOf(C)
                                    , azAuthGuestDOf(C), azAuthCfgDOf(C) )

  // L28 invalid-authbind — certificate↔record binding (certId recomputation,
  // the five bound fields, the proofPub rule).
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authbind"
    requires VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"
             andBool ( azRelOf(azCertOf(C)) ==Int 1
                       orBool azRelOf(azCertOf(C)) ==Int 2
                       orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool AzNonCircular(azCertOf(C), azFctxOf(C), azSecOf(C),
                                   azAuthPTOf(C), azAuthGuestDOf(C),
                                   azAuthCfgDOf(C))
             andBool AzSrcAuthorized( azSrcOf(azCertOf(C)), azFctxOf(C)
                                    , azSecOf(C), azAuthPTOf(C)
                                    , azAuthGuestDOf(C), azAuthCfgDOf(C) )
             andBool notBool AzCertBindOk(azCertOf(C), RG, azFctxOf(C),
                                          azSecOf(C))

  // L29 invalid-policy — the security-policy version binding.
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-policy"
    requires VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"
             andBool ( azRelOf(azCertOf(C)) ==Int 1
                       orBool azRelOf(azCertOf(C)) ==Int 2
                       orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool AzNonCircular(azCertOf(C), azFctxOf(C), azSecOf(C),
                                   azAuthPTOf(C), azAuthGuestDOf(C),
                                   azAuthCfgDOf(C))
             andBool AzSrcAuthorized( azSrcOf(azCertOf(C)), azFctxOf(C)
                                    , azSecOf(C), azAuthPTOf(C)
                                    , azAuthGuestDOf(C), azAuthCfgDOf(C) )
             andBool AzCertBindOk(azCertOf(C), RG, azFctxOf(C), azSecOf(C))
             andBool notBool azPolicyVOf(azCertOf(C))
                             ==Int secPolicyVOf(azSecOf(C))

  // L30 valid-g — the full 21-conjunct accept (MODEL.md §9/§10).
  rule VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "valid-g"
    requires VerifyLineageF(linRecGBase(RG), azFctxOf(C), T, HEAD)
                                        ==String "valid-f"
             andBool ( azRelOf(azCertOf(C)) ==Int 1
                       orBool azRelOf(azCertOf(C)) ==Int 2
                       orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool AzNonCircular(azCertOf(C), azFctxOf(C), azSecOf(C),
                                   azAuthPTOf(C), azAuthGuestDOf(C),
                                   azAuthCfgDOf(C))
             andBool AzSrcAuthorized( azSrcOf(azCertOf(C)), azFctxOf(C)
                                    , azSecOf(C), azAuthPTOf(C)
                                    , azAuthGuestDOf(C), azAuthCfgDOf(C) )
             andBool AzCertBindOk(azCertOf(C), RG, azFctxOf(C), azSecOf(C))
             andBool azPolicyVOf(azCertOf(C)) ==Int secPolicyVOf(azSecOf(C))

  // ===========================================================================
  // §11. Access-list (BAL) analysis object (MODEL.md §12) — ANALYSIS ONLY,
  //      NOT a gate conjunct.
  // ===========================================================================

  syntax BalEntry ::= "balEntry" "(" balApp:Int "," balSlot:Int ","
                       balHasPost:Bool "," balPost:Int ")"

  syntax Int ::= balAppOf ( BalEntry ) [function, total]
  rule balAppOf(balEntry(A:Int, _:Int, _:Bool, _:Int)) => A
  syntax Int ::= balSlotOf ( BalEntry ) [function, total]
  rule balSlotOf(balEntry(_:Int, S:Int, _:Bool, _:Int)) => S
  syntax Bool ::= balHasPostOf ( BalEntry ) [function, total]
  rule balHasPostOf(balEntry(_:Int, _:Int, H:Bool, _:Int)) => H
  syntax Int ::= balPostOf ( BalEntry ) [function, total]
  rule balPostOf(balEntry(_:Int, _:Int, _:Bool, V:Int)) => V

  // canonical BAL encoding (MODEL.md §12): 0x8E || n_4 || entries in order
  syntax Bytes ::= BalEntryCanon ( BalEntry ) [function, total]
  rule BalEntryCanon(balEntry(A:Int, S:Int, H:Bool, V:Int))
    => I2B4(A) +Bytes I2B4(S) +Bytes Int2Bytes(1, 0, BE) +Bytes I2B4(V)
    requires notBool H
  rule BalEntryCanon(balEntry(A:Int, S:Int, H:Bool, V:Int))
    => I2B4(A) +Bytes I2B4(S) +Bytes Int2Bytes(1, 1, BE) +Bytes I2B4(V)
    requires H

  syntax Bytes ::= BalCanon ( List ) [function, total]
  rule BalCanon(.List) => Int2Bytes(1, 142, BE) +Bytes I2B4(0)
  rule BalCanon(ListItem(E:BalEntry) REST:List)
    => Int2Bytes(1, 142, BE) +Bytes I2B4(1 +Int BalListLen(REST))
       +Bytes BalEntryCanon(E) +Bytes BalRestCanon(REST)

  syntax Int ::= BalListLen ( List ) [function, total]
  rule BalListLen(.List) => 0
  rule BalListLen(ListItem(_:BalEntry) REST:List) => 1 +Int BalListLen(REST)

  syntax Bytes ::= BalRestCanon ( List ) [function, total]
  rule BalRestCanon(.List) => .Bytes
  rule BalRestCanon(ListItem(E:BalEntry) REST:List)
    => BalEntryCanon(E) +Bytes BalRestCanon(REST)

  // touched-location map over the flat 1E key space k = app*2^32 + slot
  syntax Map ::= BalTouched ( List ) [function, total]
  rule BalTouched(.List) => .Map
  rule BalTouched(ListItem(exEvt(OP:Int, A:Int, S:Int, _:Int)) REST:List)
    => BalTouched(REST)[ (A *Int ExecTwo32() +Int S) <- 1 ]
    requires OP ==Int 1 orBool OP ==Int 2
  rule BalTouched(ListItem(_:ExecEvt) REST:List) => BalTouched(REST) [owise]

  syntax Map ::= BalKeyMap ( List ) [function, total]
  rule BalKeyMap(.List) => .Map
  rule BalKeyMap(ListItem(E:BalEntry) REST:List)
    => BalKeyMap(REST)[ (balAppOf(E) *Int ExecTwo32() +Int balSlotOf(E)) <- 1 ]

  // footprint equality: the BAL keys are EXACTLY the touched locations
  syntax Bool ::= BalFootprintOk ( List , List ) [function, total]
  rule BalFootprintOk(B:List, T:List)
    => BalKeyMap(B) ==K BalTouched(T)

  // post-value binding: written locations bind the LAST write; read-only
  // locations bind the CURRENT (pre-state) value — what a read would
  // observe. The BAL records what IS, never what was OBSERVED (MODEL.md
  // §12 finding 2).
  syntax Bool ::= BalWritesOk ( List , List , Map ) [function, total]
  rule BalWritesOk(.List, _:List, _:Map) => true
  rule BalWritesOk(ListItem(E:BalEntry) REST:List, T:List, PRE:Map)
    => BalEntryOk(E, T, PRE) andBool BalWritesOk(REST, T, PRE)

  syntax Bool ::= BalEntryOk ( BalEntry , List , Map ) [function, total]
  rule BalEntryOk(E:BalEntry, T:List, PRE:Map)
    => balHasPostOf(E)
       impliesBool
       ( balPostOf(E)
         ==Int LinIntAt( LinMapAt( ExecTraceWrites(T), balAppOf(E) )
                       , balSlotOf(E) ) )
    requires balSlotOf(E) in_keys( LinMapAt( ExecTraceWrites(T)
                                           , balAppOf(E) ) )
  rule BalEntryOk(E:BalEntry, T:List, PRE:Map)
    => balHasPostOf(E)
       impliesBool
       ( balPostOf(E) ==Int LinIntAt(LinMapAt(PRE, balAppOf(E)), balSlotOf(E)) )
    requires notBool ( balSlotOf(E) in_keys( LinMapAt( ExecTraceWrites(T)
                                                     , balAppOf(E) ) ) )

  // ===========================================================================
  // §12. Prover simplifications (the 1E/1F precedents)
  // ===========================================================================

  rule B:Bool ==Bool B => true [simplification]
  rule A:Bytes +Bytes (B:Bytes +Bytes C:Bytes) => (A +Bytes B) +Bytes C [simplification]

endmodule
