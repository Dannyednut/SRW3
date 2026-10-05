// =============================================================================
// SRW3 Phase 1E — root-lineage binding mechanized proofs
//                          (phase1e/proofs/root_lineage_binding.k)
//
// Backend: HASKELL (kprove).
//
//   RL1 (L13 layer identity) : NOT MECHANIZED as a standalone identity — the
//        claim body reduces both sides into the symbolic-universe root term
//        and the simplifier stalls there; the layer's semantics IS mechanized
//        where it matters: RL4/RL5 (verdict characterization) and GA-claims,
//        where the guard term appears verbatim.
//   RL2 (L15 layer identity) : the extended-child layer IS the byte equality
//        childE == Keccak256(CanonCoreE) with CanonCoreE = legacy-full bytes
//        || stateRoot.
//   RL3 (schema prefix property — version compatibility): the legacy canonical
//        full bytes are a strict PREFIX of CanonCoreE; in particular the
//        legacy child commitment over the legacy layout is unaffected by the
//        extension. Mechanized via length + substr over the canonical layout.
//   RL4 (rejection direction of L13): with all preceding layers green, a
//        state-root mismatch is EXACTLY the "invalid-state-root" verdict.
// =============================================================================

requires "srw3auth.k"

module SRW3AUTH-BINDING-PROOFS
  imports SRW3AUTH

  claim // RL1: L13 is the byte equality against the recomputed canonical root
    <k> AuthStateRootOk(RE:LinRecE, C:AuthCtx)
        ==Bool BytesEq( linStateRootOf(RE:LinRecE)
                      , AuthRootOf( AuthUniverseOf(C:AuthCtx)
                                  , linCtxState(authCtxLin(C:AuthCtx)) ) )
        => true </k>
    requires true

  claim // RL2: L15 is the byte equality against the extended child commitment
    <k> AuthChildEOk(RE:LinRecE)
        ==Bool BytesEq( linChildEOf(RE:LinRecE)
                      , AuthChildE(linRecOfE(RE:LinRecE), linStateRootOf(RE:LinRecE)) )
        => true </k>
    requires true

  claim // RL3a: CanonCoreE extends the legacy full bytes by exactly 32 bytes
    <k> lengthBytes( AuthCanonCoreE(REC:LinRec, SR:Bytes) )
        ==Int lengthBytes( LinCanonFull( linVersionOf(REC:LinRec)
                                       , linParentOf(REC:LinRec), linTidOf(REC:LinRec)
                                       , linAppsOf(REC:LinRec), linInputDOf(REC:LinRec)
                                       , linEffectDOf(REC:LinRec), linStateDOf(REC:LinRec)
                                       , linPolicyVOf(REC:LinRec), linAuthOf(REC:LinRec)
                                       , linEvOf(REC:LinRec), linSigOf(REC:LinRec) ) )
            +Int 32
        => true </k>
    requires true

  claim // RL3b: the legacy full bytes are a PREFIX of CanonCoreE (the legacy
        // child commitment is unaffected by the extension — version compat)
    <k> BytesEq( substrBytes( AuthCanonCoreE(REC:LinRec, SR:Bytes)
                            , 0
                            , lengthBytes( LinCanonFull( linVersionOf(REC:LinRec)
                                                       , linParentOf(REC:LinRec), linTidOf(REC:LinRec)
                                                       , linAppsOf(REC:LinRec), linInputDOf(REC:LinRec)
                                                       , linEffectDOf(REC:LinRec), linStateDOf(REC:LinRec)
                                                       , linPolicyVOf(REC:LinRec), linAuthOf(REC:LinRec)
                                                       , linEvOf(REC:LinRec), linSigOf(REC:LinRec) ) ) )
               , LinCanonFull( linVersionOf(REC:LinRec)
                             , linParentOf(REC:LinRec), linTidOf(REC:LinRec)
                             , linAppsOf(REC:LinRec), linInputDOf(REC:LinRec)
                             , linEffectDOf(REC:LinRec), linStateDOf(REC:LinRec)
                             , linPolicyVOf(REC:LinRec), linAuthOf(REC:LinRec)
                             , linEvOf(REC:LinRec), linSigOf(REC:LinRec) ) )
        ==Bool true
        => true </k>
    requires true

  claim // RL4: with legacy green and universe ok, a state-root mismatch is
        // exactly the "invalid-state-root" verdict (rejection direction)
    <k> VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
        ==K "invalid-state-root"
        => true </k>
    requires VerifyLineagePE(linRecOfE(RE:LinRecE), authCtxLin(C:AuthCtx), T:Int, HEAD:Bytes)
                                       ==K "valid"
     andBool AuthCapacityOk(AuthUniverseOf(C:AuthCtx))
     andBool AuthPadOk(AuthUniverseOf(C:AuthCtx))
     andBool notBool AuthStateRootOk(RE:LinRecE, C:AuthCtx)

  claim // RL5: with all layers green the verdict is exactly "valid-a"
        // (acceptance direction at the symbolic level — no vacuity: the
        //  requires are satisfiable, witnessed concretely by the demo pos case)
    <k> VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
        ==K "valid-a"
        => true </k>
    requires VerifyLineagePE(linRecOfE(RE:LinRecE), authCtxLin(C:AuthCtx), T:Int, HEAD:Bytes)
                                       ==K "valid"
     andBool AuthCapacityOk(AuthUniverseOf(C:AuthCtx))
     andBool AuthPadOk(AuthUniverseOf(C:AuthCtx))
     andBool AuthStateRootOk(RE:LinRecE, C:AuthCtx)
     andBool AuthAnchorOk(RE:LinRecE, C:AuthCtx)
     andBool AuthChildEOk(RE:LinRecE)

endmodule

  claim // RL6: with all root layers green and the extended child mismatched,
        // the verdict is exactly "invalid-childe" (rejection direction)
    <k> VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
        ==K "invalid-childe"
        => true </k>
    requires VerifyLineagePE(linRecOfE(RE:LinRecE), authCtxLin(C:AuthCtx), T:Int, HEAD:Bytes)
                                       ==K "valid"
     andBool AuthCapacityOk(AuthUniverseOf(C:AuthCtx))
     andBool AuthPadOk(AuthUniverseOf(C:AuthCtx))
     andBool AuthStateRootOk(RE:LinRecE, C:AuthCtx)
     andBool AuthAnchorOk(RE:LinRecE, C:AuthCtx)
     andBool notBool AuthChildEOk(RE:LinRecE)
