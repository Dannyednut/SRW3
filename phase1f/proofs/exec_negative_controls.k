// =============================================================================
// SRW3 Phase 1F — NEGATIVE CONTROLS (designed-fail)
//                          (phase1f/proofs/exec_negative_controls.k)
//
// Backend: HASKELL (kprove). EVERY claim in this file is designed to FAIL
// (kprove does NOT prove it). A green run here is a defect in the control.
//
//   NC1 (hash injectivity — the A-F1 boundary): the claim that differing
//     ExecutionId INPUTS imply equal digests is the direction hash
//     collision-resistance does not provide; the prover must get stuck
//     (the honest boundary of the cryptographic assumption).
//   NC2 (acceptance with a tampered trace): a concrete record whose
//     presented trace digest differs from the record's bound digest MUST
//     NOT be accepted; the claim asserts valid-f and must fail.
//   NC3 (vacuity probe): "the gate never accepts" — the claim derives false
//     from a valid-f premise that IS concretely satisfiable (the honest
//     witness); it must fail.
// =============================================================================

requires "srw3exec.k"

module SRW3EXEC-NEG-PROOFS
  imports SRW3EXEC

  claim // NC1 (DESIGNED STUCK): injectivity direction is NOT available
    // (differing parent roots would have to imply differing digests — this
    // is exactly Keccak256 collision resistance, ASSUMED, never mechanized)
    <k> ( ExecExecId( Int2Bytes(32, 1, BE), PLD:Bytes, CFG:Bytes, ENV:Bytes )
          ==K ExecExecId( Int2Bytes(32, 2, BE), PLD:Bytes, CFG:Bytes, ENV:Bytes ) )
        impliesBool
        ( Int2Bytes(32, 1, BE) ==K Int2Bytes(32, 2, BE) )
        => true </k>
    requires true

  claim // NC2 (DESIGNED FAIL): acceptance with a tampered presented trace
    // The record binds digest D_exec; the presented trace has digest
    // D_presented != D_exec (concretely different byte strings), so the
    // gate verdict is invalid-efftrace — asserting valid-f MUST fail.
    <k> ( VerifyLineageF(
            linRecF( AuthBuildRecE( 0, LinRoot
                                  , 4097 |-> (0 |-> 0)
                                  , 4097 |-> (0 |-> 100)
                                  , 4097 |-> (0 |-> 100)
                                  , LinDemoKey1, 5 )
                   , ExecExecId( LinRoot
                               , ExecPayloadDigest(LinHex("4f5241434c4531"))
                               , ExecConfigDigest(ExecSchedCANCUN, 1)
                               , ExecEnvDigest(LinAddrOf(LinDemoKey1), 0) )
                   , ExecTraceDigest( ListItem( exEvt(2, 4097, 0, 100) ) )
                   , ExecWitDigest( execWit( 1, LinRoot
                                           , ExecExecId( LinRoot
                                                       , ExecPayloadDigest(LinHex("4f5241434c4531"))
                                                       , ExecConfigDigest(ExecSchedCANCUN, 1)
                                                       , ExecEnvDigest(LinAddrOf(LinDemoKey1), 0) )
                                           , ExecPayloadDigest(LinHex("4f5241434c4531"))
                                           , LinH(LinCanonKV(4097 |-> (0 |-> 100)))
                                           , ExecTraceDigest( ListItem( exEvt(2, 4097, 0, 100) ) )
                                           , AuthRootOf( AuthUnion3( AuthKeysOfMap(4097 |-> (0 |-> 0))
                                                                   , AuthKeysOfMap(4097 |-> (0 |-> 100))
                                                                   , AuthKeysOfMap(4097 |-> (0 |-> 100)) )
                                                       , 4097 |-> (0 |-> 100) )
                                           , ExecConfigDigest(ExecSchedCANCUN, 1) ) )
                   , ExecConfigDigest(ExecSchedCANCUN, 1) )
          , execCtx( authCtx( linCtxP( 4097 |-> (0 |-> 0)
                                     , 4097 |-> (0 |-> 100)
                                     , 4097 |-> (0 |-> 100)
                                     , 5 |-> true 6 |-> true
                                     , SetItem(LinAddrOf(LinDemoKey1)) )
                            , AuthRootOf( AuthUnion3( AuthKeysOfMap(4097 |-> (0 |-> 0))
                                                    , AuthKeysOfMap(4097 |-> (0 |-> 100))
                                                    , AuthKeysOfMap(4097 |-> (0 |-> 100)) )
                                        , 4097 |-> (0 |-> 100) ) )
                   , LinRoot
                   , LinHex("4f5241434c4531")
                   , ExecSchedCANCUN, 1
                   , LinAddrOf(LinDemoKey1), 0
                   , ListItem( exEvt(2, 4097, 0, 101) )
                   , execWit( 1, LinRoot
                            , ExecExecId( LinRoot
                                        , ExecPayloadDigest(LinHex("4f5241434c4531"))
                                        , ExecConfigDigest(ExecSchedCANCUN, 1)
                                        , ExecEnvDigest(LinAddrOf(LinDemoKey1), 0) )
                            , ExecPayloadDigest(LinHex("4f5241434c4531"))
                            , LinH(LinCanonKV(4097 |-> (0 |-> 100)))
                            , ExecTraceDigest( ListItem( exEvt(2, 4097, 0, 100) ) )
                            , AuthRootOf( AuthUnion3( AuthKeysOfMap(4097 |-> (0 |-> 0))
                                                    , AuthKeysOfMap(4097 |-> (0 |-> 100))
                                                    , AuthKeysOfMap(4097 |-> (0 |-> 100)) )
                                        , 4097 |-> (0 |-> 100) )
                            , ExecConfigDigest(ExecSchedCANCUN, 1) ) ) )
          , 0, LinRoot ) ==K "valid-f" )
        => true </k>
    requires true

  claim // NC3 (DESIGNED FAIL, vacuity probe): the gate premise is NOT
    // unsatisfiable — the honest witness exists, so valid-f does NOT imply
    // false. This claim must FAIL (its premise is concretely TRUE).
    <k> ( VerifyLineageF(
            ExecBuildRecF( 0, LinRoot
                         , 4097 |-> (0 |-> 0)
                         , 4097 |-> (0 |-> 100)
                         , 4097 |-> (0 |-> 100)
                         , LinDemoKey1, 5
                         , ListItem( exEvt(2, 4097, 0, 100) )
                         , LinHex("4f5241434c4531")
                         , ExecSchedCANCUN, 1
                         , LinAddrOf(LinDemoKey1), 0
                         , LinRoot )
          , execCtx( authCtx( linCtxP( 4097 |-> (0 |-> 0)
                                     , 4097 |-> (0 |-> 100)
                                     , 4097 |-> (0 |-> 100)
                                     , 5 |-> true 6 |-> true
                                     , SetItem(LinAddrOf(LinDemoKey1)) )
                            , AuthRootOf( AuthUnion3( AuthKeysOfMap(4097 |-> (0 |-> 0))
                                                    , AuthKeysOfMap(4097 |-> (0 |-> 100))
                                                    , AuthKeysOfMap(4097 |-> (0 |-> 100)) )
                                        , 4097 |-> (0 |-> 100) ) )
                   , LinRoot
                   , LinHex("4f5241434c4531")
                   , ExecSchedCANCUN, 1
                   , LinAddrOf(LinDemoKey1), 0
                   , ListItem( exEvt(2, 4097, 0, 100) )
                   , execWit( 1, LinRoot
                            , ExecExecId( LinRoot
                                        , ExecPayloadDigest(LinHex("4f5241434c4531"))
                                        , ExecConfigDigest(ExecSchedCANCUN, 1)
                                        , ExecEnvDigest(LinAddrOf(LinDemoKey1), 0) )
                            , ExecPayloadDigest(LinHex("4f5241434c4531"))
                            , LinH(LinCanonKV(4097 |-> (0 |-> 100)))
                            , ExecTraceDigest( ListItem( exEvt(2, 4097, 0, 100) ) )
                            , AuthRootOf( AuthUnion3( AuthKeysOfMap(4097 |-> (0 |-> 0))
                                                    , AuthKeysOfMap(4097 |-> (0 |-> 100))
                                                    , AuthKeysOfMap(4097 |-> (0 |-> 100)) )
                                        , 4097 |-> (0 |-> 100) )
                            , ExecConfigDigest(ExecSchedCANCUN, 1) ) ) )
          , 0, LinRoot ) ==K "valid-f" )
        impliesBool ( false )
        => true </k>
    requires true

endmodule
