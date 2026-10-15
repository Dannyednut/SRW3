// =============================================================================
// SRW3 Phase 1G — GATE_G SOUNDNESS: THE AUTHORITY-BOUND COMMITMENT CERTIFICATE
//                          (phase1g/proofs/az_gate_proofs.k)
//
// Backend: HASKELL (kprove).
//
//   AZB1..AZB7 (branch-wise, the 1F EXB precedent): every new authority
//     verdict is EXACTLY its layer condition on top of the previous layers —
//     the first-fail structure pinned branch by branch. Together with the
//     unchanged 1E/1F chains these seven claims carry the full content of
//     the AUTHORITY-BOUND COMMITMENT GATE certificate branch-wise.
//
//   AZBACC (accept direction): when all seven authority conjuncts hold on
//     top of valid-f, the verdict IS "valid-g" — no acceptance slack. The
//     accept condition is 21 atomic conjuncts (MODEL.md §9).
//
// Anti-vacuity: the accept premise is SATISFIABLE — witnessed concretely by
// the demo suite (valid-g for rel=1/2/3) on the LLVM backend with real
// keccak + secp256k1, mirrored by the Python suite (25/25).
// =============================================================================

requires "srw3authz.k"

module SRW3AUTHZ-GATE-PROOFS
  imports SRW3AUTHZ

  claim // AZB1: unknown authority relation is exact (model REFUSE, explicit)
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "invalid-authtype"
        => true </k>
    requires VerifyLineageF( linRecGBase(RG:LinRecG), azFctxOf(C:AzCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-f"
     andBool notBool ( azRelOf(azCertOf(C:AzCtx)) ==K 1
                       orBool azRelOf(azCertOf(C:AzCtx)) ==K 2
                       orBool azRelOf(azCertOf(C:AzCtx)) ==K 3 )

  claim // AZB2: rel/domain mismatch verdict is exact
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "invalid-authrel"
        => true </k>
    requires VerifyLineageF( linRecGBase(RG:LinRecG), azFctxOf(C:AzCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-f"
     andBool ( azRelOf(azCertOf(C:AzCtx)) ==K 1
               orBool azRelOf(azCertOf(C:AzCtx)) ==K 2
               orBool azRelOf(azCertOf(C:AzCtx)) ==K 3 )
     andBool notBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C:AzCtx)))
                            , AzRelDomain(azRelOf(azCertOf(C:AzCtx))) )

  claim // AZB3: authority-level violation verdict is exact (CM-G3a class)
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "invalid-authlevel"
        => true </k>
    requires VerifyLineageF( linRecGBase(RG:LinRecG), azFctxOf(C:AzCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-f"
     andBool ( azRelOf(azCertOf(C:AzCtx)) ==K 1
               orBool azRelOf(azCertOf(C:AzCtx)) ==K 2
               orBool azRelOf(azCertOf(C:AzCtx)) ==K 3 )
     andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C:AzCtx)))
                    , AzRelDomain(azRelOf(azCertOf(C:AzCtx))) )
     andBool notBool azSrcLevelOf(azSrcOf(azCertOf(C:AzCtx)))
                   ==K AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C:AzCtx))))

  claim // AZB4: NoCircularAuthority violation verdict is exact
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "invalid-authcircle"
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
     andBool notBool AzNonCircular( azCertOf(C:AzCtx), azFctxOf(C:AzCtx)
                                  , azSecOf(C:AzCtx), azAuthPTOf(C:AzCtx)
                                  , azAuthGuestDOf(C:AzCtx)
                                  , azAuthCfgDOf(C:AzCtx) )

  claim // AZB5: unauthorized source verdict is exact (CM-G10 class)
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "invalid-authsrc"
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
     andBool notBool AzSrcAuthorized( azSrcOf(azCertOf(C:AzCtx))
                                    , azFctxOf(C:AzCtx), azSecOf(C:AzCtx)
                                    , azAuthPTOf(C:AzCtx)
                                    , azAuthGuestDOf(C:AzCtx)
                                    , azAuthCfgDOf(C:AzCtx) )

  claim // AZB6: certificate-binding failure verdict is exact (CM-G4/5/7 class)
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "invalid-authbind"
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
     andBool notBool AzCertBindOk( azCertOf(C:AzCtx), RG:LinRecG
                                 , azFctxOf(C:AzCtx), azSecOf(C:AzCtx) )

  claim // AZB7: policy-binding failure verdict is exact (CM-G8 class)
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "invalid-policy"
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
     andBool notBool azPolicyVOf(azCertOf(C:AzCtx))
                   ==K secPolicyVOf(azSecOf(C:AzCtx))

  claim // AZBACC: THE ACCEPT DIRECTION — all 21 conjuncts imply valid-g
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "valid-g"
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
