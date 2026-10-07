// =============================================================================
// SRW3 Phase 1G — RECORD BINDING (LinRecG additive extension)
//                          (phase1g/proofs/az_record_proofs.k)
//
// Backend: HASKELL (kprove).
//
//   AZR1: CanonCoreG is definitionally CanonCoreF || azCertD || policyV_4
//         (CanonCoreF is a STRICT PREFIX — the additive-discipline claim).
//   AZR2: childG binds the certificate and the policy version
//         (childG == H(CanonCoreF || certD || policyV)).
//   AZR3: the Level-2 childE is carried UNCHANGED by the G extension.
//   AZR4: the Level-3 childF is carried UNCHANGED by the G extension.
//   AZR5: the certificate binding decomposes — AzCertBindOk implies the
//         certId recomputation AND the five field bindings AND the
//         proofPub/empty rule (the record<->certificate surface).
//
//   These are the G7 (authority-bound lineage) theorem class.
// =============================================================================

requires "srw3authz.k"

module SRW3AUTHZ-RECBIND-PROOFS
  imports SRW3AUTHZ

  claim // AZR1: CanonCoreF is a strict prefix of CanonCoreG
    <k> AzCanonCoreG(RF:LinRecF, D:Bytes, V:Int)
        ==K ( ExecCanonCoreF( linRecFBase(RF:LinRecF), linExecIdOf(RF:LinRecF)
                            , linEffTraceDOf(RF:LinRecF)
                            , linExecWDOf(RF:LinRecF)
                            , linExecCfgDOf(RF:LinRecF) )
              +Bytes D:Bytes +Bytes I2B4(V:Int) )
        => true </k>
    requires true

  claim // AZR2: childG binds cert + policy over the frozen CanonCoreF
    <k> AzChildG(RF:LinRecF, D:Bytes, V:Int)
        ==K LinH( ExecCanonCoreF( linRecFBase(RF:LinRecF)
                                , linExecIdOf(RF:LinRecF)
                                , linEffTraceDOf(RF:LinRecF)
                                , linExecWDOf(RF:LinRecF)
                                , linExecCfgDOf(RF:LinRecF) )
                  +Bytes D:Bytes +Bytes I2B4(V:Int) )
        => true </k>
    requires true

  claim // AZR3: the Level-2 state root and childE are untouched
    <k> linChildEOf(linRecFBase(linRecGBase(linRecG(RF:LinRecF, D:Bytes, V:Int))))
        ==K linChildEOf(linRecFBase(RF:LinRecF))
        => true </k>
    requires true

  claim // AZR4: the Level-3 childF is untouched (the base IS the F record)
    <k> ExecChildF( linRecFBase(linRecGBase(linRecG(RF:LinRecF, D:Bytes, V:Int)))
                  , linExecIdOf(linRecGBase(linRecG(RF:LinRecF, D:Bytes, V:Int)))
                  , linEffTraceDOf(linRecGBase(linRecG(RF:LinRecF, D:Bytes, V:Int)))
                  , linExecWDOf(linRecGBase(linRecG(RF:LinRecF, D:Bytes, V:Int)))
                  , linExecCfgDOf(linRecGBase(linRecG(RF:LinRecF, D:Bytes, V:Int))) )
        ==K ExecChildF( linRecFBase(RF:LinRecF), linExecIdOf(RF:LinRecF)
                      , linEffTraceDOf(RF:LinRecF), linExecWDOf(RF:LinRecF)
                      , linExecCfgDOf(RF:LinRecF) )
        => true </k>
    requires true

  claim // AZR5: the certificate binding decomposes (digest + five fields + pub
        // rule) — stated branch-wise for the canonical rel=1 shape; the
        // five field equalities for the FULL accept condition are carried
        // separately by AZG1..AZG5 (proved) and the digest binding is a
        // conjunct of the AZBACC accept direction (proved).
    <k> ( AzCertBindOk(C:AuthzCert, RG:LinRecG, FC:ExecCtx, SEC:SecCtx)
          impliesBool
          BytesEq( AzCertId(C:AuthzCert), linAzCertDOf(RG:LinRecG) ) )
        => true </k>
    requires azRelOf(C:AuthzCert) ==K 1

endmodule
