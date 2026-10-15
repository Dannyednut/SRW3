// =============================================================================
// SRW3 Phase 1G — AUTHORITY-BINDING THEOREM CLASSES (G1/G2/G3/G4/G5)
//                          (phase1g/proofs/az_binding_proofs.k)
//
// Backend: HASKELL (kprove).
//
//   Each claim: the FULL 21-conjunct accept condition (stated as the 15
//   atomic requires of the accept rule) implies ONE certificate-binding
//   equality. These are the task brief's theorem classes G1 (payload
//   authority), G2 (parent-root authority), G3 (execution-identity
//   binding), G4 (effect authority), G5 (child-root authority) — the
//   binding halves, each carried by the gate's accept direction.
//
//   The RESULT half of G3 (root == Root(execute(payload, pre))) is a
//   Mode-A property demonstrated at the KEVM layer and a Mode-B property
//   REQUIRES EXTERNAL PROOF SYSTEM — the model binds the identity and the
//   roots; it does not re-derive the execution.
// =============================================================================

requires "srw3authz.k"

module SRW3AUTHZ-BIND-PROOFS
  imports SRW3AUTHZ

  // the shared 15-conjunct accept premise (the accept rule's requires),
  // spelled out per claim (kprove claims cannot share requires macros)

  claim // AZG1: PAYLOAD AUTHORITY — the certificate binds the presented payload
    <k> ( VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes) ==K "valid-g" )
        impliesBool
        ( BytesEq( azPayloadDOf(azCertOf(C:AzCtx))
                 , ExecPayloadDigest(execCtxPayload(azFctxOf(C:AzCtx))) ) )
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

  claim // AZG2: PARENT-ROOT AUTHORITY — binds the threaded 1E parent root
    <k> ( VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes) ==K "valid-g" )
        impliesBool
        ( BytesEq( azParentRootOf(azCertOf(C:AzCtx))
                 , execCtxParentRoot(azFctxOf(C:AzCtx)) ) )
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

  claim // AZG3: EXECUTION-IDENTITY AUTHORITY — binds the recomputed ExecutionId
    <k> ( VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes) ==K "valid-g" )
        impliesBool
        ( BytesEq( azExecIdOf(azCertOf(C:AzCtx))
                 , linExecIdOf(linRecGBase(RG:LinRecG)) ) )
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

  claim // AZG4: EFFECT AUTHORITY — binds the digest-bound ordered effect trace
    <k> ( VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes) ==K "valid-g" )
        impliesBool
        ( BytesEq( azEffectDOf(azCertOf(C:AzCtx))
                 , linEffTraceDOf(linRecGBase(RG:LinRecG)) ) )
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

  claim // AZG5: CHILD-ROOT AUTHORITY — binds the anchored post-state root
    <k> ( VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes) ==K "valid-g" )
        impliesBool
        ( BytesEq( azChildRootOf(azCertOf(C:AzCtx))
                 , linStateRootOf(linRecFBase(linRecGBase(RG:LinRecG))) ) )
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
