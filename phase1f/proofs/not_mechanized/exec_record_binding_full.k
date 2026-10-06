// =============================================================================
// SRW3 Phase 1F — RECORD BINDING (LinRecF)
//                          (phase1f/proofs/exec_record_binding.k)
//
// Backend: HASKELL (kprove). The additive record extension binds the
// execution identity, the trace digest, the witness digest, and the config
// digest into the commitment chain WITHOUT touching any frozen field.
// =============================================================================

requires "srw3exec.k"

module SRW3EXEC-RECBIND-PROOFS
  imports SRW3EXEC

  claim // EX5a: CanonCoreF exact form — CanonCoreE is a strict PREFIX
    // (associativity form; the 1E canonical bytes are the leading segment)
    <k> ( ExecCanonCoreF(RE:LinRecE, EID:Bytes, TD:Bytes, WD:Bytes, CD:Bytes)
          ==K AuthCanonCoreE(linRecOfE(RE:LinRecE), linStateRootOf(RE:LinRecE))
              +Bytes ( EID:Bytes
                       +Bytes ( TD:Bytes
                                +Bytes ( WD:Bytes +Bytes CD:Bytes ) ) ) )
        => true </k>
    requires true

  claim // EX5b: childE invariance under the Level-3 extension
    <k> ( linChildEOf( linRecFBase( linRecF( RE:LinRecE, _:Bytes, _:Bytes,
                                             _:Bytes, _:Bytes ) ) )
          ==K linChildEOf(RE:LinRecE) )
        => true </k>
    requires true

  claim // EX5c: childF digest form (MODEL.md §7)
    <k> ( ExecChildF(RE:LinRecE, EID:Bytes, TD:Bytes, WD:Bytes, CD:Bytes)
          ==K LinH( ExecCanonCoreF(RE:LinRecE, EID:Bytes, TD:Bytes,
                                   WD:Bytes, CD:Bytes) ) )
        => true </k>
    requires true

  claim // EX5d: honest construction coherence — the record's execution id is
    // exactly the recomputed identity over the given components (symbolic
    // form: the id/trace/witness/config fields evaluate independently of
    // the signature path, which stays symbolic on this backend)
    <k> ( linExecIdOf(
            ExecBuildRecF( N:Int, HEAD:Bytes, Q:Map, E:Map, P:Map
                         , KEY:Bytes, PV:Int, T:List, PL:Bytes
                         , SCH:Bytes, SPEC:Int, CL:Bytes, VL:Int, PR:Bytes ) )
          ==K ExecExecId( PR:Bytes
                        , ExecPayloadDigest(PL:Bytes)
                        , ExecConfigDigest(SCH:Bytes, SPEC:Int)
                        , ExecEnvDigest(CL:Bytes, VL:Int) ) )
        => true </k>
    requires true

  claim // EX5e: witness digest binding — ExecWitDigest is exactly the canon
    // digest over the eight witness fields (definitional pin)
    <k> ( ExecWitDigest(W:ExecWit) ==K LinH(ExecWitCanon(W:ExecWit)) )
        => true </k>
    requires true

  claim // EX5f: trace digest of the honest construction equals the standalone
    // digest of the same trace (binding coherence, symbolic form)
    <k> ( linEffTraceDOf(
            ExecBuildRecF( N:Int, HEAD:Bytes, Q:Map, E:Map, P:Map
                         , KEY:Bytes, PV:Int, T:List, PL:Bytes
                         , SCH:Bytes, SPEC:Int, CL:Bytes, VL:Int, PR:Bytes ) )
          ==K ExecTraceDigest(T:List) )
        => true </k>
    requires true

  claim // EX5g: config digest of the honest construction equals the standalone
    // recomputation (symbolic form)
    <k> ( linExecCfgDOf(
            ExecBuildRecF( N:Int, HEAD:Bytes, Q:Map, E:Map, P:Map
                         , KEY:Bytes, PV:Int, T:List, PL:Bytes
                         , SCH:Bytes, SPEC:Int, CL:Bytes, VL:Int, PR:Bytes ) )
          ==K ExecConfigDigest(SCH:Bytes, SPEC:Int) )
        => true </k>
    requires true

  claim // EX5h: witness digest of the honest construction equals the digest
    // of the standalone witness with the same components (symbolic form)
    <k> ( linExecWDOf(
            ExecBuildRecF( N:Int, HEAD:Bytes, Q:Map, E:Map, P:Map
                         , KEY:Bytes, PV:Int, T:List, PL:Bytes
                         , SCH:Bytes, SPEC:Int, CL:Bytes, VL:Int, PR:Bytes ) )
          ==K ExecWitDigest( execWit( 1
                                    , PR:Bytes
                                    , ExecExecId( PR:Bytes
                                                , ExecPayloadDigest(PL:Bytes)
                                                , ExecConfigDigest(SCH:Bytes, SPEC:Int)
                                                , ExecEnvDigest(CL:Bytes, VL:Int) )
                                    , ExecPayloadDigest(PL:Bytes)
                                    , LinH(LinCanonKV(E:Map))
                                    , ExecTraceDigest(T:List)
                                    , AuthRootOf(AuthUnion3(AuthKeysOfMap(Q:Map)
                                                           ,AuthKeysOfMap(E:Map)
                                                           ,AuthKeysOfMap(P:Map)), P:Map)
                                    , ExecConfigDigest(SCH:Bytes, SPEC:Int) ) ) )
        => true </k>
    requires true

endmodule
