// =============================================================================
// SRW3 Phase 1G — NEGATIVE CONTROLS (designed-fail canaries)
//                          (phase1g/proofs/az_negative_proofs.k)
//
// Backend: HASKELL (kprove). Every claim here is DESIGNED to fail; a PROVE
// on any of them would mean the gate is broken (the canary died).
//
//   NCG1: with the NoCircularAuthority conjunct VIOLATED, the gate must
//     NOT accept — the claim asserts it accepts anyway (must fail).
//   NCG2: with an UNAUTHORIZED source identity, the gate must NOT accept
//     (must fail).
//   NCG3: vacuity probe — the accept premises are satisfiable, so the claim
//     "the accept premises imply false" must fail (non-vacuity canary; the
//     1F NC3 precedent). The concrete witnesses are the demo suite
//     (valid-g for rel=1/2/3 on the LLVM backend, real krypto) and the
//     Python suite (25/25).
// =============================================================================

requires "srw3authz.k"

module SRW3AUTHZ-NEGATIVE-PROOFS
  imports SRW3AUTHZ

  claim // NCG1 (DESIGNED FAIL): circular certificate must never be accepted
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
     andBool notBool AzNonCircular( azCertOf(C:AzCtx), azFctxOf(C:AzCtx)
                                  , azSecOf(C:AzCtx), azAuthPTOf(C:AzCtx)
                                  , azAuthGuestDOf(C:AzCtx)
                                  , azAuthCfgDOf(C:AzCtx) )

  claim // NCG2 (DESIGNED FAIL): unauthorized source must never be accepted
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
     andBool notBool AzSrcAuthorized( azSrcOf(azCertOf(C:AzCtx))
                                    , azFctxOf(C:AzCtx), azSecOf(C:AzCtx)
                                    , azAuthPTOf(C:AzCtx)
                                    , azAuthGuestDOf(C:AzCtx)
                                    , azAuthCfgDOf(C:AzCtx) )

  claim // NCG3 (DESIGNED FAIL): vacuity probe — the accept premises are SAT
    <k> VerifyLineageG(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
        ==K "valid-g" impliesBool false
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
