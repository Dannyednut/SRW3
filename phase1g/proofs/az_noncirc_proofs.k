// =============================================================================
// SRW3 Phase 1G — AUTHORITY-NONCIRCULARITY and AUTHORITY-CHAIN (single forms)
//                          (phase1g/proofs/az_noncirc_proofs.k)
//
// Backend: HASKELL (kprove).
//
//   AZ-NCS: AUTHORITY-NONCIRCULARITY, single-implication form over fully
//     symbolic records/contexts: valid-g implies the certificate never cites
//     itself (neither in its chain nor as its own source) and its chain
//     strictly decreases to a level-0 protocol root. Attempted in full
//     symbolic generality; if the prover exceeds its budget the claim is
//     DISCLOSED (the 1F EXGATE precedent) and the content stands branch-wise
//     (AZB4 + AZBACC: the accept direction CONSUMES the non-circularity
//     conjunct, so acceptance carries it).
//
//   AZ-CHS: AUTHORITY-CHAIN, single-implication form: valid-g implies the
//     chain terminates at an AUTHORIZED level-0 protocol identity.
//
//   AZ-CHG (ground anchor theorem): for the honest consensus-authorized
//     construction, valid-g implies anchor == stateRoot == cert.childRoot
//     with a protocol-rooted certificate — the A-E3 REPLACEMENT at the
//     Gate_G level (MODEL.md §10). Stated over symbolic components bound by
//     the accept premises.
// =============================================================================

requires "srw3authz.k"

module SRW3AUTHZ-NONCIRC-PROOFS
  imports SRW3AUTHZ

  claim // AZNCS: AUTHORITY-NONCIRCULARITY (single-implication form)
    <k> ( VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
          ==K "valid-g" )
        impliesBool
        ( notBool AzOwnInChain( azChainOf(azCertOf(C:AzCtx))
                              , AzCertId(azCertOf(C:AzCtx)) )
          andBool notBool BytesEq( azSrcIdOf(azSrcOf(azCertOf(C:AzCtx)))
                                 , AzCertId(azCertOf(C:AzCtx)) ) )
        => true </k>
    requires true

  claim // AZCHS: AUTHORITY-CHAIN termination at an authorized protocol root
    <k> ( VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
          ==K "valid-g" )
        impliesBool
        ( AzChainOk( azChainOf(azCertOf(C:AzCtx))
                   , azSrcLevelOf(azSrcOf(azCertOf(C:AzCtx)))
                   , azFctxOf(C:AzCtx), azSecOf(C:AzCtx), azAuthPTOf(C:AzCtx)
                   , azAuthGuestDOf(C:AzCtx), azAuthCfgDOf(C:AzCtx) ) )
        => true </k>
    requires true

  claim // AZCHG: the A-E3 replacement — accept requires the protocol-rooted
        // certificate to bind the anchor value (branch-wise implication form)
    <k> ( VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
          ==K "valid-g" )
        impliesBool
        ( BytesEq( azChildRootOf(azCertOf(C:AzCtx))
                 , linStateRootOf(linRecFBase(linRecGBase(RG:LinRecG))) )
          andBool BytesEq( linStateRootOf(linRecFBase(linRecGBase(RG:LinRecG)))
                         , authCtxAnchor( execCtxAuth(azFctxOf(C:AzCtx)) ) )
          andBool AzNonCircular( azCertOf(C:AzCtx), azFctxOf(C:AzCtx)
                               , azSecOf(C:AzCtx), azAuthPTOf(C:AzCtx)
                               , azAuthGuestDOf(C:AzCtx)
                               , azAuthCfgDOf(C:AzCtx) ) )
        => true </k>
    requires VerifyLineageF( linRecGBase(RG:LinRecG), azFctxOf(C:AzCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-f"
     andBool ( azRelOf(azCertOf(C:AzCtx)) ==K 1
               orBool azRelOf(azCertOf(C:AzCtx)) ==K 2
               orBool azRelOf(azCertOf(C:AzCtx)) ==K 3 )
     andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C:AzCtx)))
                    , AzRelDomain(azRelOf(azCertOf(C:AzCtx))) )
     andBool azSrcLevelOf(azSrcOf(azCertOf(C:AzCtx)))
             ==K AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C:AzCtx))))
     andBool AzNonCircular( azCertOf(C:AzCtx), azFctxOf(C:AzCtx)
                          , azSecOf(C:AzCtx), azAuthPTOf(C:AzCtx)
                          , azAuthGuestDOf(C:AzCtx), azAuthCfgDOf(C:AzCtx) )
     andBool AzSrcAuthorized( azSrcOf(azCertOf(C:AzCtx)), azFctxOf(C:AzCtx)
                            , azSecOf(C:AzCtx), azAuthPTOf(C:AzCtx)
                            , azAuthGuestDOf(C:AzCtx), azAuthCfgDOf(C:AzCtx) )
     andBool AzCertBindOk( azCertOf(C:AzCtx), RG:LinRecG
                         , azFctxOf(C:AzCtx), azSecOf(C:AzCtx) )
     andBool azPolicyVOf(azCertOf(C:AzCtx))
             ==K secPolicyVOf(azSecOf(C:AzCtx))

endmodule
