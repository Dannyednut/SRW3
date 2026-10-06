// =============================================================================
// SRW3 Phase 1F — GATE_F SOUNDNESS: THE EXEC-EFFECT-BINDING CERTIFICATE
//                          (phase1f/proofs/exec_gate_binding.k)
//
// Backend: HASKELL (kprove).
//
//   EXB1..EXB6 (branch-wise, GA2/GA3 form): every extension verdict is
//     EXACTLY its layer condition on top of the previous layers — the
//     first-fail structure pinned branch by branch (the 1E precedent).
//     Together with the unchanged Phase 1E chain these six claims carry the
//     full content of the EXEC-EFFECT-BINDING certificate branch-wise.
//
//   EXBACC (accept direction): when all extension conjuncts hold on top of
//     valid-a, the verdict IS "valid-f" — no acceptance slack.
//
//   EXGATE (THE EXEC-EFFECT-BINDING THEOREM, single-implication form):
//     valid-f implies the six Level-3 conjuncts. Attempted in full symbolic
//     generality; if the prover exceeds its budget the claim is disclosed
//     (1E GA1 precedent) and the content stands branch-wise via EXB1..EXB6.
//
// Anti-vacuity: the accept premise is SATISFIABLE — witnessed concretely by
// the demo suite (valid-f) on the LLVM backend with real keccak + secp256k1
// and by the Python E0 witness; NC3 (the vacuity probe) fails as designed.
// =============================================================================

requires "srw3exec.k"

module SRW3EXEC-GATE-PROOFS
  imports SRW3EXEC

  claim // EXGATE: THE EXEC-EFFECT-BINDING THEOREM (single-implication form)
    <k> ( VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes) ==K "valid-f" )
        impliesBool
        ( VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                        , T:Int, HEAD:Bytes )
              ==K "valid-a"
          andBool ExecBoundsOk(execCtxTrace(C:ExecCtx))
          andBool BytesEq( linExecCfgDOf(RF:LinRecF)
                         , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                           ,execCtxSpec(C:ExecCtx)) )
          andBool BytesEq( linExecIdOf(RF:LinRecF)
                         , ExecExecId( execCtxParentRoot(C:ExecCtx)
                                     , ExecPayloadDigest(execCtxPayload(C:ExecCtx))
                                     , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                                       ,execCtxSpec(C:ExecCtx))
                                     , ExecEnvDigest(execCtxCaller(C:ExecCtx)
                                                    ,execCtxValue(C:ExecCtx)) ) )
          andBool BytesEq( linEffTraceDOf(RF:LinRecF)
                         , ExecTraceDigest(execCtxTrace(C:ExecCtx)) )
          andBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C:ExecCtx)))
                                , execCtxTrace(C:ExecCtx) )
          andBool ExecWitnessOk(execCtxWit(C:ExecCtx), RF:LinRecF, C:ExecCtx)
          andBool ExecReplayOk( linCtxInputs(linCtxOfAuth(execCtxAuth(C:ExecCtx)))
                              , execCtxTrace(C:ExecCtx)
                              , linCtxState(linCtxOfAuth(execCtxAuth(C:ExecCtx))) ) )
        => true </k>
    requires true

  claim // EXB1: bounds refusal is exact (model REFUSE, explicit)
    <k> VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
        ==K "invalid-execbounds"
        => true </k>
    requires VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-a"
     andBool notBool ExecBoundsOk(execCtxTrace(C:ExecCtx))

  claim // EXB2: config mismatch verdict is exact
    <k> VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
        ==K "invalid-execconfig"
        => true </k>
    requires VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-a"
     andBool ExecBoundsOk(execCtxTrace(C:ExecCtx))
     andBool notBool BytesEq( linExecCfgDOf(RF:LinRecF)
                            , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                              ,execCtxSpec(C:ExecCtx)) )

  claim // EXB3: execution-identity recomputation verdict is exact
    <k> VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
        ==K "invalid-execid"
        => true </k>
    requires VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-a"
     andBool ExecBoundsOk(execCtxTrace(C:ExecCtx))
     andBool BytesEq( linExecCfgDOf(RF:LinRecF)
                    , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                      ,execCtxSpec(C:ExecCtx)) )
     andBool notBool BytesEq( linExecIdOf(RF:LinRecF)
                            , ExecExecId( execCtxParentRoot(C:ExecCtx)
                                        , ExecPayloadDigest(execCtxPayload(C:ExecCtx))
                                        , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                                          ,execCtxSpec(C:ExecCtx))
                                        , ExecEnvDigest(execCtxCaller(C:ExecCtx)
                                                       ,execCtxValue(C:ExecCtx)) ) )

  claim // EXB4: presented-trace digest binding verdict is exact
    <k> VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
        ==K "invalid-efftrace"
        => true </k>
    requires VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-a"
     andBool ExecBoundsOk(execCtxTrace(C:ExecCtx))
     andBool BytesEq( linExecCfgDOf(RF:LinRecF)
                    , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                      ,execCtxSpec(C:ExecCtx)) )
     andBool BytesEq( linExecIdOf(RF:LinRecF)
                    , ExecExecId( execCtxParentRoot(C:ExecCtx)
                                , ExecPayloadDigest(execCtxPayload(C:ExecCtx))
                                , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                                  ,execCtxSpec(C:ExecCtx))
                                , ExecEnvDigest(execCtxCaller(C:ExecCtx)
                                               ,execCtxValue(C:ExecCtx)) ) )
     andBool notBool BytesEq( linEffTraceDOf(RF:LinRecF)
                            , ExecTraceDigest(execCtxTrace(C:ExecCtx)) )

  claim // EXB5: witness verdict is exact (digest + coherence)
    <k> VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
        ==K "invalid-witness"
        => true </k>
    requires VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-a"
     andBool ExecBoundsOk(execCtxTrace(C:ExecCtx))
     andBool BytesEq( linExecCfgDOf(RF:LinRecF)
                    , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                      ,execCtxSpec(C:ExecCtx)) )
     andBool BytesEq( linExecIdOf(RF:LinRecF)
                    , ExecExecId( execCtxParentRoot(C:ExecCtx)
                                , ExecPayloadDigest(execCtxPayload(C:ExecCtx))
                                , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                                  ,execCtxSpec(C:ExecCtx))
                                , ExecEnvDigest(execCtxCaller(C:ExecCtx)
                                               ,execCtxValue(C:ExecCtx)) ) )
     andBool BytesEq( linEffTraceDOf(RF:LinRecF)
                    , ExecTraceDigest(execCtxTrace(C:ExecCtx)) )
     andBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C:ExecCtx)))
                           , execCtxTrace(C:ExecCtx) )
     andBool notBool ExecWitnessOk(execCtxWit(C:ExecCtx), RF:LinRecF, C:ExecCtx)

  claim // EXB6: replay-binding verdict is exact (reads + composition)
    <k> VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
        ==K "invalid-effbind"
        => true </k>
    requires VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-a"
     andBool ExecBoundsOk(execCtxTrace(C:ExecCtx))
     andBool BytesEq( linExecCfgDOf(RF:LinRecF)
                    , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                      ,execCtxSpec(C:ExecCtx)) )
     andBool BytesEq( linExecIdOf(RF:LinRecF)
                    , ExecExecId( execCtxParentRoot(C:ExecCtx)
                                , ExecPayloadDigest(execCtxPayload(C:ExecCtx))
                                , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                                  ,execCtxSpec(C:ExecCtx))
                                , ExecEnvDigest(execCtxCaller(C:ExecCtx)
                                               ,execCtxValue(C:ExecCtx)) ) )
     andBool BytesEq( linEffTraceDOf(RF:LinRecF)
                    , ExecTraceDigest(execCtxTrace(C:ExecCtx)) )
     andBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C:ExecCtx)))
                           , execCtxTrace(C:ExecCtx) )
     andBool ExecWitnessOk(execCtxWit(C:ExecCtx), RF:LinRecF, C:ExecCtx)
     andBool notBool ExecReplayOk( linCtxInputs(linCtxOfAuth(execCtxAuth(C:ExecCtx)))
                                 , execCtxTrace(C:ExecCtx)
                                 , linCtxState(linCtxOfAuth(execCtxAuth(C:ExecCtx))) )

  claim // EXBACC: accept direction — all extension conjuncts imply valid-f
    <k> VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
        ==K "valid-f"
        => true </k>
    requires VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-a"
     andBool ExecBoundsOk(execCtxTrace(C:ExecCtx))
     andBool BytesEq( linExecCfgDOf(RF:LinRecF)
                    , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                      ,execCtxSpec(C:ExecCtx)) )
     andBool BytesEq( linExecIdOf(RF:LinRecF)
                    , ExecExecId( execCtxParentRoot(C:ExecCtx)
                                , ExecPayloadDigest(execCtxPayload(C:ExecCtx))
                                , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                                  ,execCtxSpec(C:ExecCtx))
                                , ExecEnvDigest(execCtxCaller(C:ExecCtx)
                                               ,execCtxValue(C:ExecCtx)) ) )
     andBool BytesEq( linEffTraceDOf(RF:LinRecF)
                    , ExecTraceDigest(execCtxTrace(C:ExecCtx)) )
     andBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C:ExecCtx)))
                           , execCtxTrace(C:ExecCtx) )
     andBool ExecWitnessOk(execCtxWit(C:ExecCtx), RF:LinRecF, C:ExecCtx)
     andBool ExecReplayOk( linCtxInputs(linCtxOfAuth(execCtxAuth(C:ExecCtx)))
                         , execCtxTrace(C:ExecCtx)
                         , linCtxState(linCtxOfAuth(execCtxAuth(C:ExecCtx))) )

  claim // EXB4b: the LEVEL-3 CORE verdict is exact — declared effects must
    // be byte-canonically equal to the write projection of the bound trace
    <k> VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
        ==K "invalid-effdecl"
        => true </k>
    requires VerifyLineageA( linRecFBase(RF:LinRecF), execCtxAuth(C:ExecCtx)
                           , T:Int, HEAD:Bytes ) ==K "valid-a"
     andBool ExecBoundsOk(execCtxTrace(C:ExecCtx))
     andBool BytesEq( linExecCfgDOf(RF:LinRecF)
                    , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                      ,execCtxSpec(C:ExecCtx)) )
     andBool BytesEq( linExecIdOf(RF:LinRecF)
                    , ExecExecId( execCtxParentRoot(C:ExecCtx)
                                , ExecPayloadDigest(execCtxPayload(C:ExecCtx))
                                , ExecConfigDigest(execCtxSched(C:ExecCtx)
                                                  ,execCtxSpec(C:ExecCtx))
                                , ExecEnvDigest(execCtxCaller(C:ExecCtx)
                                               ,execCtxValue(C:ExecCtx)) ) )
     andBool BytesEq( linEffTraceDOf(RF:LinRecF)
                    , ExecTraceDigest(execCtxTrace(C:ExecCtx)) )
     andBool notBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C:ExecCtx)))
                                   , execCtxTrace(C:ExecCtx) )

endmodule
