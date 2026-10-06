// =============================================================================
// SRW3 Phase 1F — Authenticated execution-effect binding
//                          (phase1f/semantics/srw3exec.k — ADDITIVE)
//
// Normative model spec: phase1f/semantics/MODEL.md (FROZEN).
//
// The frozen Phase 1D-R1 / 1E modules (srw3lin*.k, srw3auth.k) are NOT
// modified. This module is purely additive (linCtxP / linRecE precedents):
//
//   * minimal execution-effect vocabulary (MODEL.md §2): Read(1)/Write(2)/
//     Call(3)/Return(4) events exEvt(op, app, a1, a2), fragment bounds
//     explicit (invalid-execbounds refuse), everything else documented OUT.
//
//   * canonical ORDER-PRESERVING trace encoding (MODEL.md §3):
//       EventBytes  = op1 ‖ app4 ‖ a1_8 ‖ a2_8
//       TraceBytes  = 0x03 ‖ n4 ‖ EventBytes*          (exact trace order)
//       EffectTraceDigest = Keccak256(TraceBytes)
//
//   * execution identity (MODEL.md §4):
//       PayloadDigest = H(0x11 ‖ payload)
//       EnvDigest     = H(0x12 ‖ caller20 ‖ value8)
//       ConfigDigest  = H(0x13 ‖ schedule8 ‖ specVersion4)
//       ExecutionId   = H(0x1F ‖ parentRoot ‖ payloadD ‖ configD ‖ envD)
//
//   * execution witness (MODEL.md §5) and its digest; signature ≠ authenticity.
//
//   * trace semantics (MODEL.md §6): ExecTraceWrites (last-write-wins),
//     ExecReplayMap, ExecReadsOk (read observations validated against the
//     replayed working state), ExecReplayOk (replay + canonical post
//     equality), ExecProj (π_P — reads dropped), ExecReplayRefuseOk
//     (fragment bounds).
//
//   * additive record extension LinRecF = (LinRecE, execId, effTraceDigest,
//     execWDigest, execConfigDigest) with CanonCoreF = CanonCoreE ‖ (new
//     fields) — CanonCoreE is a strict PREFIX; childE carried unchanged.
//
//   * extended verifier chain VerifyLineageF — first-fail:
//       [1D chain → corrected composition → capacity → padkey → state-root
//        → anchor → childe  (Phase 1E VerifyLineageA, unchanged, fires first)]
//       "invalid-execbounds"  fragment bounds violated        (model REFUSE)
//       "invalid-execconfig"  execConfigDigest ≠ recomputed
//       "invalid-execid"      execId ≠ recomputed from context
//       "invalid-efftrace"    effTraceDigest ≠ H(TraceBytes(presented trace))
//       "invalid-effdecl"     declared effects ≠ Writes(presented trace)
//                             [THE LEVEL-3 CORE CHECK]
//       "invalid-witness"     witness digest mismatch or coherence failure
//       "invalid-effbind"     NOT ExecReplayOk(pre, presented trace, post)
//       "valid-f"
//     valid-f = 14 atomic conjuncts (MODEL.md §8 — the task-brief candidate
//     count of 12 is recorded as superseded by the actual decomposition).
//
// LEVELS ARE SEPARATE: valid-f is a BINDING statement (MODEL.md §9). It does
// NOT authenticate the presented trace as the historical execution's trace
// (A-F3); that closure is demonstrated at the instrumented-execution layer
// (KEVM) and otherwise REQUIRES CLIENT/PROTOCOL SUPPORT.
// =============================================================================

requires "srw3auth.k"

module SRW3EXEC
  imports SRW3AUTH

  // ===========================================================================
  // §0. Effect-trace vocabulary and fragment bounds (MODEL.md §2)
  // ===========================================================================

  syntax ExecEvt ::= "exEvt" "(" op:Int "," app:Int "," a1:Int "," a2:Int ")"

  // smart constructors (demo convenience; proofs use exEvt directly)
  syntax ExecEvt ::= ExRead ( Int , Int , Int ) [function, total]
  rule ExRead(A:Int, S:Int, V:Int) => exEvt(1, A, S, V)
  syntax ExecEvt ::= ExWrite ( Int , Int , Int ) [function, total]
  rule ExWrite(A:Int, S:Int, V:Int) => exEvt(2, A, S, V)
  syntax ExecEvt ::= ExCall ( Int , Int , Int ) [function, total]
  rule ExCall(A:Int, T:Int, V:Int) => exEvt(3, A, T, V)
  syntax ExecEvt ::= ExReturn ( Int , Int , Int ) [function, total]
  rule ExReturn(A:Int, O:Int, SZ:Int) => exEvt(4, A, O, SZ)

  syntax Int ::= ExecTwo32 () [function, total]
  rule ExecTwo32() => 4294967296
  syntax Int ::= ExecTwo64 () [function, total]
  rule ExecTwo64() => 18446744073709551616

  // MODEL.md §2 bounds: op ∈ {1,2,3,4}; app < 2^32; a1 < 2^64 with the
  // READ/WRITE slot refinement a1 < 2^32; a2 < 2^64.
  syntax Bool ::= ExecEvtBoundsOk ( ExecEvt ) [function, total]
  rule ExecEvtBoundsOk(exEvt(OP:Int, A:Int, S:Int, V:Int))
    => (OP ==Int 1 orBool OP ==Int 2 orBool OP ==Int 3 orBool OP ==Int 4)
       andBool A >=Int 0 andBool A <Int ExecTwo32()
       andBool S >=Int 0 andBool S <Int ExecTwo64()
       andBool V >=Int 0 andBool V <Int ExecTwo64()
       andBool ( notBool (OP ==Int 1 orBool OP ==Int 2)
                 orBool (S >=Int 0 andBool S <Int ExecTwo32()) )

  syntax Bool ::= ExecBoundsOk ( List ) [function, total]
  rule ExecBoundsOk(.List) => true
  rule ExecBoundsOk(ListItem(E:ExecEvt) REST:List)
    => ExecEvtBoundsOk(E) andBool ExecBoundsOk(REST)

  // ===========================================================================
  // §1. Canonical, order-preserving trace encoding (MODEL.md §3)
  // ===========================================================================

  syntax Bytes ::= ExecI2B8 ( Int ) [function, total]
  rule ExecI2B8(X:Int) => Int2Bytes(8, X, BE)

  syntax Bytes ::= ExecEvtBytes ( ExecEvt ) [function, total]
  rule ExecEvtBytes(exEvt(OP:Int, A:Int, S:Int, V:Int))
    => Int2Bytes(1, OP, BE) +Bytes I2B4(A) +Bytes ExecI2B8(S) +Bytes ExecI2B8(V)

  syntax Bytes ::= ExecEventsBytes ( List ) [function, total]
  rule ExecEventsBytes(.List) => .Bytes
  rule ExecEventsBytes(ListItem(E:ExecEvt) REST:List)
    => ExecEvtBytes(E) +Bytes ExecEventsBytes(REST)

  syntax Bytes ::= ExecCanonTrace ( List ) [function, total]
  rule ExecCanonTrace(T:List)
    => Int2Bytes(1, 3, BE) +Bytes I2B4(size(T)) +Bytes ExecEventsBytes(T)

  syntax Bytes ::= ExecTraceDigest ( List ) [function]
  rule ExecTraceDigest(T:List) => LinH(ExecCanonTrace(T))

  // ===========================================================================
  // §2. Execution identity (MODEL.md §4)
  // ===========================================================================

  syntax Bytes ::= ExecPayloadDigest ( Bytes ) [function]
  rule ExecPayloadDigest(P:Bytes) => LinH(Int2Bytes(1, 17, BE) +Bytes P)

  syntax Bytes ::= ExecEnvDigest ( Bytes , Int ) [function]
  rule ExecEnvDigest(CL:Bytes, VL:Int)
    => LinH(Int2Bytes(1, 18, BE) +Bytes CL +Bytes ExecI2B8(VL))

  syntax Bytes ::= ExecConfigDigest ( Bytes , Int ) [function]
  rule ExecConfigDigest(SCHED:Bytes, SPEC:Int)
    => LinH(Int2Bytes(1, 19, BE) +Bytes SCHED +Bytes I2B4(SPEC))

  syntax Bytes ::= ExecExecId ( Bytes , Bytes , Bytes , Bytes ) [function]
  rule ExecExecId(PARROOT:Bytes, PLD:Bytes, CFG:Bytes, ENV:Bytes)
    => LinH( Int2Bytes(1, 31, BE) +Bytes PARROOT +Bytes PLD +Bytes CFG +Bytes ENV )

  // fragment schedule constant: ASCII "CANCUN" zero-padded to 8 bytes
  // (MODEL.md §4); specVersion 1
  syntax Bytes ::= ExecSchedCANCUN () [function, total]
  rule ExecSchedCANCUN()
    => Int2Bytes(1, 67, BE) +Bytes Int2Bytes(1, 65, BE) +Bytes Int2Bytes(1, 78, BE)
       +Bytes Int2Bytes(1, 67, BE) +Bytes Int2Bytes(1, 85, BE) +Bytes Int2Bytes(1, 78, BE)
       +Bytes Int2Bytes(2, 0, BE)
  syntax Int ::= ExecSpecV1 () [function, total]
  rule ExecSpecV1() => 1

  // ===========================================================================
  // §3. The execution witness (MODEL.md §5)
  // ===========================================================================

  syntax ExecWit ::= "execWit" "(" witVersion:Int "," witParentRoot:Bytes ","
                       witExecId:Bytes "," witPayloadD:Bytes ","
                       witDeclaredD:Bytes "," witTraceD:Bytes ","
                       witPostRoot:Bytes "," witConfigD:Bytes ")"

  syntax Bytes ::= ExecWitCanon ( ExecWit ) [function, total]
  rule ExecWitCanon(execWit(V:Int, PR:Bytes, EID:Bytes, PLD:Bytes,
                            DEC:Bytes, TD:Bytes, POR:Bytes, CFG:Bytes))
    => Int2Bytes(1, 87, BE) +Bytes I2B4(V) +Bytes PR +Bytes EID +Bytes PLD
       +Bytes DEC +Bytes TD +Bytes POR +Bytes CFG

  syntax Bytes ::= ExecWitDigest ( ExecWit ) [function]
  rule ExecWitDigest(W:ExecWit) => LinH(ExecWitCanon(W))

  // ===========================================================================
  // §4. Trace semantics: writes, replay, reads, projection (MODEL.md §6)
  // ===========================================================================

  // writes: last-write-wins over (app, slot), other events state-silent
  syntax Map ::= ExecTraceWrites ( List ) [function, total]
  rule ExecTraceWrites(T:List) => ExecTW(T, .Map)
  syntax Map ::= ExecTW ( List , Map ) [function, total]
  rule ExecTW(.List, M:Map) => M
  rule ExecTW(ListItem(exEvt(2, A:Int, S:Int, V:Int)) REST:List, M:Map)
    => ExecTW(REST, LinSetKV(M, A, S, V))
  rule ExecTW(ListItem(_:ExecEvt) REST:List, M:Map) => ExecTW(REST, M) [owise]

  // replay final map (write-accumulating walk; unconditional)
  syntax Map ::= ExecReplayMap ( List , Map ) [function, total]
  rule ExecReplayMap(.List, W:Map) => W
  rule ExecReplayMap(ListItem(exEvt(2, A:Int, S:Int, V:Int)) REST:List, W:Map)
    => ExecReplayMap(REST, LinSetKV(W, A, S, V))
  rule ExecReplayMap(ListItem(_:ExecEvt) REST:List, W:Map)
    => ExecReplayMap(REST, W) [owise]

  // read-observation consistency against the replayed working state
  syntax Bool ::= ExecReadsOk ( List , Map ) [function, total]
  rule ExecReadsOk(.List, _W:Map) => true
  rule ExecReadsOk(ListItem(exEvt(1, A:Int, S:Int, V:Int)) REST:List, W:Map)
    => (V ==Int LinIntAt(LinMapAt(W, A), S)) andBool ExecReadsOk(REST, W)
  rule ExecReadsOk(ListItem(exEvt(2, A:Int, S:Int, V:Int)) REST:List, W:Map)
    => ExecReadsOk(REST, LinSetKV(W, A, S, V))
  rule ExecReadsOk(ListItem(_:ExecEvt) REST:List, W:Map)
    => ExecReadsOk(REST, W) [owise]

  // full replay validation: read consistency + canonical post equality
  syntax Bool ::= ExecReplayOk ( Map , List , Map ) [function, total]
  rule ExecReplayOk(PRE:Map, T:List, POST:Map)
    => ExecReadsOk(T, PRE)
       andBool BytesEq( LinCanonKV(POST)
                      , LinCanonKV(ExecReplayMap(T, PRE)) )

  // THE LEVEL-3 CORE CHECK (MODEL.md §6/§9): the DECLARED effects map must
  // be byte-canonically EQUAL to the write projection of the presented
  // trace — PresentedEffects == TrueEffects(execution) as a digest
  // equality. This is what makes effect equality DECIDABLE rather than
  // post-relative (two different effect maps producing the same post are
  // distinguished by their traces).
  syntax Bool ::= ExecDeclaredOk ( Map , List ) [function, total]
  rule ExecDeclaredOk(DECL:Map, T:List)
    => BytesEq( LinH(LinCanonKV(DECL))
              , LinH(LinCanonKV(ExecTraceWrites(T))) )

  // π_P projection: reads dropped, Write/Call/Return kept IN ORDER
  syntax List ::= ExecProj ( List ) [function, total]
  rule ExecProj(.List) => .List
  rule ExecProj(ListItem(exEvt(1, _:Int, _:Int, _:Int)) REST:List) => ExecProj(REST)
  rule ExecProj(ListItem(E:ExecEvt) REST:List) => ListItem(E) ExecProj(REST) [owise]

  // ===========================================================================
  // §5. Additive record extension LinRecF (MODEL.md §7)
  // ===========================================================================

  syntax LinRecF ::= "linRecF" "(" base:LinRecE "," linExecId:Bytes ","
                       linEffTraceD:Bytes "," linExecWD:Bytes ","
                       linExecCfgD:Bytes ")"

  syntax LinRecE ::= linRecFBase ( LinRecF ) [function]
  rule linRecFBase(linRecF(RE:LinRecE, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => RE

  syntax Bytes ::= linExecIdOf    ( LinRecF ) [function]
  rule linExecIdOf(linRecF(_:LinRecE, EID:Bytes, _:Bytes, _:Bytes, _:Bytes)) => EID
  syntax Bytes ::= linEffTraceDOf ( LinRecF ) [function]
  rule linEffTraceDOf(linRecF(_:LinRecE, _:Bytes, TD:Bytes, _:Bytes, _:Bytes)) => TD
  syntax Bytes ::= linExecWDOf    ( LinRecF ) [function]
  rule linExecWDOf(linRecF(_:LinRecE, _:Bytes, _:Bytes, WD:Bytes, _:Bytes)) => WD
  syntax Bytes ::= linExecCfgDOf  ( LinRecF ) [function]
  rule linExecCfgDOf(linRecF(_:LinRecE, _:Bytes, _:Bytes, _:Bytes, CD:Bytes)) => CD

  // CanonCoreF = CanonCoreE ‖ execId ‖ effTraceD ‖ execWD ‖ execCfgD
  syntax Bytes ::= ExecCanonCoreF ( LinRecE , Bytes , Bytes , Bytes , Bytes ) [function]
  rule ExecCanonCoreF(RE:LinRecE, EID:Bytes, TD:Bytes, WD:Bytes, CD:Bytes)
    => AuthCanonCoreE(linRecOfE(RE), linStateRootOf(RE))
       +Bytes EID +Bytes TD +Bytes WD +Bytes CD

  syntax Bytes ::= ExecChildF ( LinRecE , Bytes , Bytes , Bytes , Bytes ) [function]
  rule ExecChildF(RE:LinRecE, EID:Bytes, TD:Bytes, WD:Bytes, CD:Bytes)
    => LinH(ExecCanonCoreF(RE, EID, TD, WD, CD))

  // honest record construction from a transition + a trace + an identity
  // (parentRoot is the threaded parent state root; the record's OWN state
  //  root comes from AuthBuildRecE over the same artifacts as Phase 1E)
  syntax LinRecF ::= ExecBuildRecF ( Int , Bytes , Map , Map , Map , Bytes , Int ,
                                     List , Bytes , Bytes , Int , Bytes , Int ,
                                     Bytes ) [function]
  // ExecBuildRecF(N, HEAD, Q, E, P, KEY, PV, TRACE, PAYLOAD, SCHED, SPEC,
  //               CALLER, VALUE, PARROOT)
  rule ExecBuildRecF(N:Int, HEAD:Bytes, Q:Map, E:Map, P:Map, KEY:Bytes, PV:Int,
                     T:List, PL:Bytes, SCH:Bytes, SPEC:Int, CL:Bytes, VL:Int,
                     PR:Bytes)
    => linRecF( AuthBuildRecE(N, HEAD, Q, E, P, KEY, PV)
              , ExecExecId(PR, ExecPayloadDigest(PL),
                           ExecConfigDigest(SCH, SPEC), ExecEnvDigest(CL, VL))
              , ExecTraceDigest(T)
              , ExecWitDigest( execWit( 1
                                     , PR
                                     , ExecExecId(PR, ExecPayloadDigest(PL),
                                                  ExecConfigDigest(SCH, SPEC),
                                                  ExecEnvDigest(CL, VL))
                                     , ExecPayloadDigest(PL)
                                     , LinH(LinCanonKV(E))
                                     , ExecTraceDigest(T)
                                     , AuthRootOf(AuthUnion3(AuthKeysOfMap(Q),
                                                             AuthKeysOfMap(E),
                                                             AuthKeysOfMap(P)), P)
                                     , ExecConfigDigest(SCH, SPEC) ) )
              , ExecConfigDigest(SCH, SPEC) )

  // ===========================================================================
  // §6. The Level-3 verification context (AuthCtx + execution inputs) [ADDITIVE]
  // ===========================================================================

  syntax ExecCtx ::= "execCtx" "(" ectx:AuthCtx "," execParentRoot:Bytes ","
                       execPayload:Bytes "," execSched:Bytes "," execSpec:Int ","
                       execCaller:Bytes "," execValue:Int ","
                       execTrace:List "," execWitness:ExecWit ")"

  syntax AuthCtx ::= execCtxAuth ( ExecCtx ) [function]
  rule execCtxAuth(execCtx(C:AuthCtx, _:Bytes, _:Bytes, _:Bytes, _:Int,
                           _:Bytes, _:Int, _:List, _:ExecWit)) => C

  syntax Bytes ::= execCtxParentRoot ( ExecCtx ) [function]
  rule execCtxParentRoot(execCtx(_:AuthCtx, PR:Bytes, _:Bytes, _:Bytes, _:Int,
                                 _:Bytes, _:Int, _:List, _:ExecWit)) => PR
  syntax Bytes ::= execCtxPayload ( ExecCtx ) [function]
  rule execCtxPayload(execCtx(_:AuthCtx, _:Bytes, PL:Bytes, _:Bytes, _:Int,
                              _:Bytes, _:Int, _:List, _:ExecWit)) => PL
  syntax Bytes ::= execCtxSched ( ExecCtx ) [function]
  rule execCtxSched(execCtx(_:AuthCtx, _:Bytes, _:Bytes, SCH:Bytes, _:Int,
                            _:Bytes, _:Int, _:List, _:ExecWit)) => SCH
  syntax Int ::= execCtxSpec ( ExecCtx ) [function]
  rule execCtxSpec(execCtx(_:AuthCtx, _:Bytes, _:Bytes, _:Bytes, SPEC:Int,
                           _:Bytes, _:Int, _:List, _:ExecWit)) => SPEC
  syntax Bytes ::= execCtxCaller ( ExecCtx ) [function]
  rule execCtxCaller(execCtx(_:AuthCtx, _:Bytes, _:Bytes, _:Bytes, _:Int,
                             CL:Bytes, _:Int, _:List, _:ExecWit)) => CL
  syntax Int ::= execCtxValue ( ExecCtx ) [function]
  rule execCtxValue(execCtx(_:AuthCtx, _:Bytes, _:Bytes, _:Bytes, _:Int,
                            _:Bytes, VL:Int, _:List, _:ExecWit)) => VL
  syntax List ::= execCtxTrace ( ExecCtx ) [function]
  rule execCtxTrace(execCtx(_:AuthCtx, _:Bytes, _:Bytes, _:Bytes, _:Int,
                            _:Bytes, _:Int, T:List, _:ExecWit)) => T
  syntax ExecWit ::= execCtxWit ( ExecCtx ) [function]
  rule execCtxWit(execCtx(_:AuthCtx, _:Bytes, _:Bytes, _:Bytes, _:Int,
                          _:Bytes, _:Int, _:List, W:ExecWit)) => W

  // ===========================================================================
  // §7. Extension predicates and VerifyLineageF (first-fail, total)
  // ===========================================================================

  syntax Bool ::= ExecStateRootOkF ( LinRecE , AuthCtx ) [function, total]
  rule ExecStateRootOkF(RE:LinRecE, C:AuthCtx) => AuthStateRootOk(RE, C)

  syntax Bool ::= ExecWitnessOk ( ExecWit , LinRecF , ExecCtx ) [function, total]
  rule ExecWitnessOk(W:ExecWit, RF:LinRecF, C:ExecCtx)
    => witVersionOf(W) ==Int 1
       andBool BytesEq( ExecWitDigest(W), linExecWDOf(RF) )
       andBool BytesEq( witParentRootOf(W), execCtxParentRoot(C) )
       andBool BytesEq( witExecIdOf(W), linExecIdOf(RF) )
       andBool BytesEq( witPayloadDOf(W),
                        ExecPayloadDigest(execCtxPayload(C)) )
       andBool BytesEq( witDeclaredDOf(W),
                        linEffectDOf(linRecOfE(linRecFBase(RF))) )
       andBool BytesEq( witTraceDOf(W), linEffTraceDOf(RF) )
       andBool BytesEq( witPostRootOf(W),
                        linStateRootOf(linRecFBase(RF)) )
       andBool BytesEq( witConfigDOf(W),
                        ExecConfigDigest(execCtxSched(C), execCtxSpec(C)) )

  syntax Int ::= witVersionOf    ( ExecWit ) [function]
  rule witVersionOf(execWit(V:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => V
  syntax Bytes ::= witParentRootOf ( ExecWit ) [function]
  rule witParentRootOf(execWit(_:Int, PR:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => PR
  syntax Bytes ::= witExecIdOf ( ExecWit ) [function]
  rule witExecIdOf(execWit(_:Int, _:Bytes, EID:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => EID
  syntax Bytes ::= witPayloadDOf ( ExecWit ) [function]
  rule witPayloadDOf(execWit(_:Int, _:Bytes, _:Bytes, PLD:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => PLD
  syntax Bytes ::= witDeclaredDOf ( ExecWit ) [function]
  rule witDeclaredDOf(execWit(_:Int, _:Bytes, _:Bytes, _:Bytes, DEC:Bytes, _:Bytes, _:Bytes, _:Bytes)) => DEC
  syntax Bytes ::= witTraceDOf ( ExecWit ) [function]
  rule witTraceDOf(execWit(_:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes, TD:Bytes, _:Bytes, _:Bytes)) => TD
  syntax Bytes ::= witPostRootOf ( ExecWit ) [function]
  rule witPostRootOf(execWit(_:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, POR:Bytes, _:Bytes)) => POR
  syntax Bytes ::= witConfigDOf ( ExecWit ) [function]
  rule witConfigDOf(execWit(_:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes, CFG:Bytes)) => CFG

  syntax String ::= VerifyLineageF ( LinRecF , ExecCtx , Int , Bytes ) [function, total]

  // Layer 1: the full Phase 1E chain fires first (unchanged).
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
    requires notBool VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"

  // Layer 2: model REFUSE — fragment bounds (explicit, never silent).
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => "invalid-execbounds"
    requires VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"
             andBool notBool ExecBoundsOk(execCtxTrace(C))

  // Layer 3: config binding.
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => "invalid-execconfig"
    requires VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"
             andBool ExecBoundsOk(execCtxTrace(C))
             andBool notBool BytesEq( linExecCfgDOf(RF)
                                    , ExecConfigDigest(execCtxSched(C),
                                                       execCtxSpec(C)) )

  // Layer 4: execution identity recomputation.
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => "invalid-execid"
    requires VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"
             andBool ExecBoundsOk(execCtxTrace(C))
             andBool BytesEq( linExecCfgDOf(RF)
                            , ExecConfigDigest(execCtxSched(C), execCtxSpec(C)) )
             andBool notBool BytesEq( linExecIdOf(RF)
                                    , ExecExecId( execCtxParentRoot(C)
                                                , ExecPayloadDigest(execCtxPayload(C))
                                                , ExecConfigDigest(execCtxSched(C), execCtxSpec(C))
                                                , ExecEnvDigest(execCtxCaller(C), execCtxValue(C)) ) )

  // Layer 5: presented-trace digest binding.
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => "invalid-efftrace"
    requires VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"
             andBool ExecBoundsOk(execCtxTrace(C))
             andBool BytesEq( linExecCfgDOf(RF)
                            , ExecConfigDigest(execCtxSched(C), execCtxSpec(C)) )
             andBool BytesEq( linExecIdOf(RF)
                            , ExecExecId( execCtxParentRoot(C)
                                        , ExecPayloadDigest(execCtxPayload(C))
                                        , ExecConfigDigest(execCtxSched(C), execCtxSpec(C))
                                        , ExecEnvDigest(execCtxCaller(C), execCtxValue(C)) ) )
             andBool notBool BytesEq( linEffTraceDOf(RF)
                                    , ExecTraceDigest(execCtxTrace(C)) )

  // Layer 6: DECLARED-EFFECTS binding (the Level-3 core check).
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => "invalid-effdecl"
    requires VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"
             andBool ExecBoundsOk(execCtxTrace(C))
             andBool BytesEq( linExecCfgDOf(RF)
                            , ExecConfigDigest(execCtxSched(C), execCtxSpec(C)) )
             andBool BytesEq( linExecIdOf(RF)
                            , ExecExecId( execCtxParentRoot(C)
                                        , ExecPayloadDigest(execCtxPayload(C))
                                        , ExecConfigDigest(execCtxSched(C), execCtxSpec(C))
                                        , ExecEnvDigest(execCtxCaller(C), execCtxValue(C)) ) )
             andBool BytesEq( linEffTraceDOf(RF)
                            , ExecTraceDigest(execCtxTrace(C)) )
             andBool notBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C)))
                                           , execCtxTrace(C) )

  // Layer 7: witness digest + coherence.
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => "invalid-witness"
    requires VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"
             andBool ExecBoundsOk(execCtxTrace(C))
             andBool BytesEq( linExecCfgDOf(RF)
                            , ExecConfigDigest(execCtxSched(C), execCtxSpec(C)) )
             andBool BytesEq( linExecIdOf(RF)
                            , ExecExecId( execCtxParentRoot(C)
                                        , ExecPayloadDigest(execCtxPayload(C))
                                        , ExecConfigDigest(execCtxSched(C), execCtxSpec(C))
                                        , ExecEnvDigest(execCtxCaller(C), execCtxValue(C)) ) )
             andBool BytesEq( linEffTraceDOf(RF)
                            , ExecTraceDigest(execCtxTrace(C)) )
             andBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C)))
                                   , execCtxTrace(C) )
             andBool notBool ExecWitnessOk(execCtxWit(C), RF, C)

  // Layer 7: trace replay binding (read consistency + exact composition
  // from the trace's writes).
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => "invalid-effbind"
    requires VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"
             andBool ExecBoundsOk(execCtxTrace(C))
             andBool BytesEq( linExecCfgDOf(RF)
                            , ExecConfigDigest(execCtxSched(C), execCtxSpec(C)) )
             andBool BytesEq( linExecIdOf(RF)
                            , ExecExecId( execCtxParentRoot(C)
                                        , ExecPayloadDigest(execCtxPayload(C))
                                        , ExecConfigDigest(execCtxSched(C), execCtxSpec(C))
                                        , ExecEnvDigest(execCtxCaller(C), execCtxValue(C)) ) )
             andBool BytesEq( linEffTraceDOf(RF)
                            , ExecTraceDigest(execCtxTrace(C)) )
             andBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C)))
                                   , execCtxTrace(C) )
             andBool ExecWitnessOk(execCtxWit(C), RF, C)
             andBool notBool ExecReplayOk( linCtxInputs(linCtxOfAuth(execCtxAuth(C)))
                                         , execCtxTrace(C)
                                         , linCtxState(linCtxOfAuth(execCtxAuth(C))) )

  // Accept: the full 13-conjunct certificate (MODEL.md §8).
  rule VerifyLineageF(RF:LinRecF, C:ExecCtx, T:Int, HEAD:Bytes)
    => "valid-f"
    requires VerifyLineageA(linRecFBase(RF), execCtxAuth(C), T, HEAD)
                                        ==String "valid-a"
             andBool ExecBoundsOk(execCtxTrace(C))
             andBool BytesEq( linExecCfgDOf(RF)
                            , ExecConfigDigest(execCtxSched(C), execCtxSpec(C)) )
             andBool BytesEq( linExecIdOf(RF)
                            , ExecExecId( execCtxParentRoot(C)
                                        , ExecPayloadDigest(execCtxPayload(C))
                                        , ExecConfigDigest(execCtxSched(C), execCtxSpec(C))
                                        , ExecEnvDigest(execCtxCaller(C), execCtxValue(C)) ) )
             andBool BytesEq( linEffTraceDOf(RF)
                            , ExecTraceDigest(execCtxTrace(C)) )
             andBool ExecDeclaredOk( linCtxEffects(linCtxOfAuth(execCtxAuth(C)))
                                   , execCtxTrace(C) )
             andBool ExecWitnessOk(execCtxWit(C), RF, C)
             andBool ExecReplayOk( linCtxInputs(linCtxOfAuth(execCtxAuth(C)))
                                 , execCtxTrace(C)
                                 , linCtxState(linCtxOfAuth(execCtxAuth(C))) )

  // accessor: the LinCtx inside an AuthCtx (srw3auth names it authCtxLin)
  syntax LinCtx ::= linCtxOfAuth ( AuthCtx ) [function]
  rule linCtxOfAuth(C:AuthCtx) => authCtxLin(C)

  // Bool reflexivity (syntactic identity) — 1E precedent.
  rule B:Bool ==Bool B => true [simplification]

  // Bytes concatenation associativity (left-normalizing simplification) —
  // prover-only; makes the byte-construction equalities of the claims close.
  rule A:Bytes +Bytes (B:Bytes +Bytes C:Bytes) => (A +Bytes B) +Bytes C [simplification]

endmodule
