// =============================================================================
// SRW3 Phase 1F — EXECUTION-DERIVED EFFECT TRACES over REAL EVM execution
//                          (k/kevm/srw3-exec-evm.k — ADDITIVE)
//
// The Phase 1E KEVM binding (srw3-auth-evm.k, frozen) is extended with
// INSTRUMENTED EXECUTION (MODEL.md §9 / report Level-3 boundary):
//
//   * #w3ExecRun(A, OPS): REAL EVM execution of the demo program with
//     SOURCE-LEVEL INSTRUMENTATION — ExecInstr inserts a marker opcode
//     (#tSLOAD/#tSSTORE/#tCALL/#tRETURN) immediately before each effectful
//     opcode; each marker appends the event (op, app, a1, a2) to the
//     RESERVED TRACE ACCOUNT (4096, outside the observed state) and
//     rewrites to the REAL opcode, which the frozen KEVM rules then execute
//     normally. The trace is therefore EXECUTION-DERIVED: order = actual
//     execution order, values = the actual stack/storage operands the real
//     opcodes consume; the producer cannot present or alter it.
//
//   * #w3GateF(ANCHOR, PAYLOAD, DECLARED, PRESENTED): the 1F gate over REAL
//     EVM storage. VerifyLineageF runs on the PRESENTED trace (as at the
//     abstract layer); on top of valid-f, the LEVEL-3 EXECUTION CHECK
//     compares the declared effects against the WRITE PROJECTION OF THE
//     EXECUTION-DERIVED trace: "invalid-declared-exec" — this rejects
//     state-invisible hidden writes that Levels 1/2 cannot see (the demo:
//     an SSTORE of a slot's own value; every state layer is blind to it;
//     only the trace catches it).
//
//   * #w3ExecState(recF, root, trace, verdict): the demonstration carrier
//     (accept: committed; reject: restored, no lineage record — commit/
//     lineage atomicity preserved).
//
// Fragment: SLOAD/SSTORE/CALL/RETURN (MODEL.md §2); all other opcodes pass
// through untraced. This is a Level-3 demonstration on real execution: the
// anchor's provenance remains REQUIRES CLIENT/PROTOCOL SUPPORT (A-E3), and
// the abstract-layer trace-authenticity boundary (A-F3) is CLOSED here by
// construction — the trace never passes through producer hands.
// =============================================================================

requires "srw3-auth-evm.k"
requires "srw3exec.k"

module SRW3-EXEC-EVM
  imports SRW3-AUTH-EVM
  imports SRW3EXEC

  // ---- EXECUTION-LEVEL INSTRUMENTATION (additive #next interception) --------
  // The frozen loop decodes each opcode via #next [OP] (stack intact) and
  // dispatches it. These rules INTERCEPT the four fragment opcodes at that
  // point with HIGHER PRIORITY ([priority(20)] vs the frozen default 50),
  // append the event to the reserved trace account, and re-emit #next [OP]
  // UNCHANGED, so the frozen semantics executes the opcode exactly as
  // before. The <pc> guard (last-logged pc stored in the tracer's reserved
  // slot, encoded pc+1 so the initial .Map reads 0) guarantees each
  // execution step logs exactly once. Event data = the operands the real
  // opcode consumes, captured BEFORE the frozen dispatch pops the stack.
  // KEVM operand convention (evm.md #exec): SSTORE INDEX NEW with W0 = top =
  // slot, W1 = value; SLOAD W0 (slot); CALL W0..W6 (W1 = target, W2 =
  // value); RETURN W0 W1 (offset, size).

  // ---- the reserved trace account (outside the observed state) ----------------
  syntax Int ::= "#w3Tracer" [function, total]
  rule #w3Tracer => 4096

  // 4 storage slots per event: op, app, a1, a2 — ascending index = order.
  // The index is the first FREE multiple-of-4 slot (scan), so the reserved
  // lastpc key never disturbs the event layout.
  syntax Map ::= "#tAppend" "(" Map "," Int "," Int "," Int "," Int ")" [function, total]
  rule #tAppend(T:Map, OP:Int, A:Int, X:Int, Y:Int)
    => #tAppendAt(T, 0, OP, A, X, Y)
  syntax Map ::= "#tAppendAt" "(" Map "," Int "," Int "," Int "," Int "," Int ")" [function, total]
  rule #tAppendAt(T:Map, I:Int, OP:Int, A:Int, X:Int, Y:Int)
    => #tAppendAt(T, I +Int 4, OP, A, X, Y)
    requires I in_keys(T)
  rule #tAppendAt(T:Map, I:Int, OP:Int, A:Int, X:Int, Y:Int)
    => ( T[ I <- OP ][ I +Int 1 <- A ][ I +Int 2 <- X ][ I +Int 3 <- Y ] )
    requires notBool I in_keys(T) [owise]

  syntax KItem ::= "#tLog" "(" Int "," Int "," Int "," Int ")"

  // reserved tracer slots: last-logged pc (encoded pc+1) and last-logged
  // executing account — the guard is (account, pc) so per-run pc restarts
  // across #w3ExecRun segments still log
  syntax Int ::= "#tLastPC" [function, total]
  rule #tLastPC => 62254582195389320100580592519289165425292395498781195888245806345541950185472
  syntax Int ::= "#tLastRun" [function, total]
  rule #tLastRun => 62254582195389320100580592519289165425292395498781195888245806345541950185473

  rule <k> #next [ SSTORE ] => #tLog(2, A, W0, W1) ~> #next [ SSTORE ] ... </k>
       <id> A:Int </id> <pc> PCOUNT </pc>
       <wordStack> W0:Int : W1:Int : _:WordStack </wordStack>
       <account> <acctID> TC:Int </acctID>
                 <storage> T:Map => T[ #tLastPC <- PCOUNT +Int 1 ][ #tLastRun <- A ] </storage>
                 ...
       </account>
  requires ( TC ==Int 4096
             andBool ( LinIntAt(T, #tLastRun) =/=Int A
                       orBool LinIntAt(T, #tLastPC) =/=Int PCOUNT +Int 1 ) )
   [priority(20)]

  rule <k> #tLog(OP:Int, A:Int, X:Int, Y:Int) => .K ... </k>
       <account> <acctID> TC:Int </acctID>
                 <storage> T:Map => #tAppend(T, OP, A, X, Y) </storage>
                 ...
       </account>
  requires TC ==Int #w3Tracer

  rule <k> #next [ SLOAD ] => #tLog(1, A, W0, LinIntAt(ST, W0)) ~> #next [ SLOAD ] ... </k>
       <id> A:Int </id> <pc> PCOUNT </pc>
       <wordStack> W0:Int : _:WordStack </wordStack>
       <account> <acctID> A:Int </acctID> <storage> ST:Map </storage> ... </account>
       <account> <acctID> TC:Int </acctID>
                 <storage> T:Map => T[ #tLastPC <- PCOUNT +Int 1 ][ #tLastRun <- A ] </storage>
                 ...
       </account>
  requires ( TC ==Int 4096
             andBool ( LinIntAt(T, #tLastRun) =/=Int A
                       orBool LinIntAt(T, #tLastPC) =/=Int PCOUNT +Int 1 ) )
   [priority(20)]

  rule <k> #next [ CALL ] => #tLog(3, A, W1, W2) ~> #next [ CALL ] ... </k>
       <id> A:Int </id> <pc> PCOUNT </pc>
       <wordStack> _:Int : W1:Int : W2:Int : _:WordStack </wordStack>
       <account> <acctID> TC:Int </acctID>
                 <storage> T:Map => T[ #tLastPC <- PCOUNT +Int 1 ][ #tLastRun <- A ] </storage>
                 ...
       </account>
  requires ( TC ==Int 4096
             andBool ( LinIntAt(T, #tLastRun) =/=Int A
                       orBool LinIntAt(T, #tLastPC) =/=Int PCOUNT +Int 1 ) )
   [priority(20)]

  rule <k> #next [ RETURN ] => #tLog(4, A, W0, W1) ~> #next [ RETURN ] ... </k>
       <id> A:Int </id> <pc> PCOUNT </pc>
       <wordStack> W0:Int : W1:Int : _:WordStack </wordStack>
       <account> <acctID> TC:Int </acctID>
                 <storage> T:Map => T[ #tLastPC <- PCOUNT +Int 1 ][ #tLastRun <- A ] </storage>
                 ...
       </account>
  requires ( TC ==Int 4096
             andBool ( LinIntAt(T, #tLastRun) =/=Int A
                       orBool LinIntAt(T, #tLastPC) =/=Int PCOUNT +Int 1 ) )
   [priority(20)]

  // ---- driver: setup + instrumented runs (mirror of the frozen #w3Setup/
  // #w3Run shapes; the threading rules mirror the frozen ones) ---------------
  syntax EthereumSimulation ::= "#w3ExecSetup"
  rule <k> #w3ExecSetup => #w3Setup ... </k>
       <accounts>
         ( .Bag
        => <account>
             <acctID>           #w3Tracer  </acctID>
             <balance>          0          </balance>
             <code>             .Bytes:AccountCode </code>
             <storage>          .Map       </storage>
             <origStorage>      .Map       </origStorage>
             <transientStorage> .Map       </transientStorage>
             <nonce>            0          </nonce>
           </account>
         )
         ...
       </accounts>

  syntax EthereumSimulation ::= "#w3ExecRun" "(" Int "," OpCodes ")"
  rule <k> #w3ExecRun(A:Int, OPS:OpCodes)
        => #w3SetCtx(A, #asmOpCodes(OPS)) ~> #execute ... </k>

  rule <k> P:K ~> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3ExecRun(A:Int, OPS:OpCodes)
        => P:K ~> #w3ExecRun(A, OPS) ~> #w3State(SG, LN, N, H) ... </k>
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int) ~> #w3ExecRun(A:Int, OPS:OpCodes)
        => #w3ExecRun(A, OPS) ~> #w3State(SG, LN, N, H) ... </k>
  rule <k> P:K ~> #w3State(SG:Map, LN:Map, N:Int, H:Int)
        ~> ( #w3ExecRun(A:Int, OPS:OpCodes) REST:EthereumSimulation )
        => P:K ~> #w3ExecRun(A, OPS) ~> #w3State(SG, LN, N, H) ~> REST ... </k>
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
        ~> ( #w3ExecRun(A:Int, OPS:OpCodes) REST:EthereumSimulation )
        => #w3ExecRun(A, OPS) ~> #w3State(SG, LN, N, H) ~> REST ... </k>

  // snapshot command: the frozen #w3Snap0 PLUS a tracer reset — the
  // executed trace of a transition starts at its own snapshot
  syntax EthereumSimulation ::= "#w3ExecSnap"
  rule <k> #w3ExecSnap => #w3Snap0 ... </k>
       <account> <acctID> TC:Int </acctID>
                 <storage> _:Map => .Map </storage>
                 ...
       </account>
  requires TC ==Int 4096

  // ---- trace collection (ascending slots = execution order) -------------------
  syntax List ::= "#w3TraceOf" "(" Map "," Int ")" [function, total]
  rule #w3TraceOf(T:Map, I:Int) => .List
    requires notBool (4 *Int I) in_keys(T)
  rule #w3TraceOf(T:Map, I:Int)
    => ListItem( exEvt( LinIntAt(T, 4 *Int I), LinIntAt(T, 4 *Int I +Int 1)
                      , LinIntAt(T, 4 *Int I +Int 2), LinIntAt(T, 4 *Int I +Int 3) ) )
       #w3TraceOf(T, I +Int 1)
    requires (4 *Int I) in_keys(T)

  syntax List ::= "#w3ExecTrace" [function]
  rule [[ #w3ExecTrace => #w3TraceOf(T:Map, 0) ]]
       <account> <acctID> TC:Int </acctID> <storage> T:Map </storage> ... </account>
  requires TC ==Int #w3Tracer

  // ---- gate-side functions -----------------------------------------------------
  syntax Map ::= "#w3FCUR" [function, total]
  rule [[ #w3FCUR => #w3allStorages() ]] <accounts> _BAG:Bag </accounts>

  syntax Bytes ::= "#w3FCaller" [function, total]
  rule #w3FCaller => LinAddrOf(LinDemoKey1)

  // parent state commitment: the root over the PRE-state content of the
  // current transition's canonical universe (single-transition demos; chain
  // threading is demonstrated at the abstract layer)
  syntax Bytes ::= "#w3FParRoot" "(" Map "," Map "," Map ")" [function, total]
  rule #w3FParRoot(PS:Map, DECL:Map, CUR:Map)
    => AuthRootOf( AuthUnion3( AuthKeysOfMap(PS), AuthKeysOfMap(DECL)
                             , AuthKeysOfMap(CUR) )
                 , PS )

  syntax LinRecF ::= "#w3FRec" "(" Map "," Map "," Map "," Int "," Bytes "," Bytes "," List ")" [function]
  rule #w3FRec(PS:Map, DECL:Map, CUR:Map, NB:Int, HB:Bytes, PL:Bytes, ET:List)
    => ExecBuildRecF( NB, HB, PS, DECL, CUR, LinDemoKey1, 5
                    , ET, PL, ExecSchedCANCUN(), ExecSpecV1()
                    , #w3FCaller, 0
                    , #w3FParRoot(PS, DECL, CUR) )

  // the honest witness (same construction as ExecBuildRecF's)
  syntax ExecWit ::= "#w3FWit" "(" Map "," Map "," Map "," Bytes "," Bytes "," List ")" [function]
  rule #w3FWit(PS:Map, DECL:Map, CUR:Map, PL:Bytes, PR:Bytes, ET:List)
    => execWit( 1, PR
              , ExecExecId( PR, ExecPayloadDigest(PL)
                          , ExecConfigDigest(ExecSchedCANCUN(), ExecSpecV1())
                          , ExecEnvDigest(#w3FCaller, 0) )
              , ExecPayloadDigest(PL)
              , LinH(LinCanonKV(DECL))
              , ExecTraceDigest(ET)
              , AuthRootOf( AuthUnion3( AuthKeysOfMap(PS), AuthKeysOfMap(DECL)
                                      , AuthKeysOfMap(CUR) )
                          , CUR )
              , ExecConfigDigest(ExecSchedCANCUN(), ExecSpecV1()) )

  // VerifyLineageF over the PRESENTED trace (abstract-layer binding)
  syntax String ::= "#w3FVerdict" "(" Map "," Map "," Int "," Bytes "," Bytes ","
                      List "," List "," Bytes ")" [function]
  rule #w3FVerdict(PS:Map, DECL:Map, NB:Int, HB:Bytes, PL:Bytes,
                   PRESENTED:List, ET:List, ANCHOR:Bytes)
    => VerifyLineageF( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED)
                     , execCtx( authCtx( linCtxP(PS, DECL, #w3FCUR, ARegE, AAuthE)
                                       , ANCHOR )
                              , #w3FParRoot(PS, DECL, #w3FCUR)
                              , PL, ExecSchedCANCUN(), ExecSpecV1()
                              , #w3FCaller, 0
                              , PRESENTED
                              , #w3FWit(PS, DECL, #w3FCUR, PL
                                       , #w3FParRoot(PS, DECL, #w3FCUR)
                                       , PRESENTED) )
                     , NB, HB )

  // THE LEVEL-3 EXECUTION CHECK: on top of valid-f (over the presented
  // trace), the declared effects must equal the write projection of the
  // EXECUTION-DERIVED trace — state-invisible hidden writes are rejected
  // here and nowhere else.
  syntax String ::= "#w3FVerdictK" "(" Map "," Map "," Int "," Bytes "," Bytes ","
                      List "," Bytes ")" [function]
  rule [[ #w3FVerdictK(PS:Map, DECL:Map, NB:Int, HB:Bytes, PL:Bytes,
                       PRESENTED:List, ANCHOR:Bytes)
          => "invalid-declared-exec" ]]
       <account> <acctID> TC:Int </acctID> <storage> T:Map </storage> ... </account>
    requires TC ==Int #w3Tracer
     andBool #w3FVerdict(PS, DECL, NB, HB, PL, PRESENTED, #w3TraceOf(T, 0), ANCHOR)
                                       ==String "valid-f"
     andBool notBool ExecDeclaredOk(DECL, #w3TraceOf(T, 0))

  rule [[ #w3FVerdictK(PS:Map, DECL:Map, NB:Int, HB:Bytes, PL:Bytes,
                       PRESENTED:List, ANCHOR:Bytes)
          => "valid-f" ]]
       <account> <acctID> TC:Int </acctID> <storage> T:Map </storage> ... </account>
    requires TC ==Int #w3Tracer
     andBool #w3FVerdict(PS, DECL, NB, HB, PL, PRESENTED, #w3TraceOf(T, 0), ANCHOR)
                                       ==String "valid-f"
     andBool ExecDeclaredOk(DECL, #w3TraceOf(T, 0))

  rule [[ #w3FVerdictK(PS:Map, DECL:Map, NB:Int, HB:Bytes, PL:Bytes,
                       PRESENTED:List, ANCHOR:Bytes)
          => #w3FVerdict(PS, DECL, NB, HB, PL, PRESENTED, #w3TraceOf(T, 0), ANCHOR) ]]
       <account> <acctID> TC:Int </acctID> <storage> T:Map </storage> ... </account>
    requires TC ==Int #w3Tracer
     andBool notBool #w3FVerdict(PS, DECL, NB, HB, PL, PRESENTED, #w3TraceOf(T, 0), ANCHOR)
                                       ==String "valid-f"

  // multi-gate threading: runs hoist past the carriers; the demonstration
  // carrier hoists past every other command (1E recorded single-gate-per-run
  // only; these rules make two-gate runs executable)
  rule <k> P:K ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> #w3ExecRun(A:Int, OPS:OpCodes)
        => P:K ~> #w3ExecRun(A, OPS) ~> #w3LinState(LIN, NB, HB, PS) ... </k>
  rule <k> P:K ~> #w3ExecState(R:LinRecF, RT:Bytes, TR:List, V:String)
           ~> #w3ExecRun(A:Int, OPS:OpCodes)
        => P:K ~> #w3ExecRun(A, OPS) ~> #w3ExecState(R, RT, TR, V) ... </k>
     [priority(20)]
  rule <k> P:K ~> #w3ExecState(R:LinRecF, RT:Bytes, TR:List, V:String)
           ~> ( C:EthereumSimulation REST:EthereumSimulation )
        => P:K ~> C ~> #w3ExecState(R, RT, TR, V) ~> REST ... </k>
     [priority(30)]

  // ---- the gate -----------------------------------------------------------------
  syntax EthereumSimulation ::= "#w3GateF" "(" Bytes "," Bytes "," Map "," List ")"
  syntax KItem ::= "#w3ExecState" "(" recF:LinRecF "," root:Bytes
                                "," trace:List "," verdict:String ")"

  // ACCEPT (continuing — a 1D carrier exists): obligations + full 1F verdict
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> ( #w3GateF(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
           ~> #w3LinState( LIN[NB:Int <- linRecOfE(linRecFBase(#w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, #w3ExecTrace)))]
                         , NB +Int 1
                         , linChildOf(linRecOfE(linRecFBase(#w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, #w3ExecTrace))))
                         , #w3allStorages() )
           ~> #w3ExecState( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, #w3ExecTrace)
                          , linStateRootOf(linRecFBase(#w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, #w3ExecTrace)))
                          , #w3ExecTrace
                          , "valid-f" )
           ~> REST ... </k>
    requires #w3OblG()
     andBool #w3FVerdictK(PS, DECL, NB, HB, PL, PRESENTED, ANCHOR) ==String "valid-f"

  // REJECT: no lineage record; storages restored; carrier records WHY
  // (commit/lineage atomicity preserved — the 1B/1D/1E gate shape)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> ( #w3GateF(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3ExecState( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, #w3ExecTrace)
                       , linStateRootOf(linRecFBase(#w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, #w3ExecTrace)))
                       , #w3ExecTrace
                       , #w3FVerdictK(PS, DECL, NB, HB, PL, PRESENTED, ANCHOR) )
           ~> #w3RestoreAll(SG)
           ~> #w3State(SG, LN, N, H)
           ~> #w3LinState(LIN, NB, HB, PS)
           ~> REST ... </k>
    requires #w3OblG()
     andBool notBool #w3FVerdictK(PS, DECL, NB, HB, PL, PRESENTED, ANCHOR)
                                       ==String "valid-f"

  // ACCEPT (fresh — first gate; no 1D carrier yet)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateF(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
           ~> #w3LinState( .Map[N:Int <- linRecOfE(linRecFBase(#w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, #w3ExecTrace)))]
                         , N +Int 1
                         , linChildOf(linRecOfE(linRecFBase(#w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, #w3ExecTrace))))
                         , #w3allStorages() )
           ~> #w3ExecState( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, #w3ExecTrace)
                          , linStateRootOf(linRecFBase(#w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, #w3ExecTrace)))
                          , #w3ExecTrace
                          , "valid-f" )
           ~> REST ... </k>
    requires #w3OblG()
     andBool #w3FVerdictK(SG, DECL, N, LinRoot, PL, PRESENTED, ANCHOR) ==String "valid-f"

  // REJECT (fresh)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateF(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3ExecState( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, #w3ExecTrace)
                       , linStateRootOf(linRecFBase(#w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, #w3ExecTrace)))
                       , #w3ExecTrace
                       , #w3FVerdictK(SG, DECL, N, LinRoot, PL, PRESENTED, ANCHOR) )
           ~> #w3RestoreAll(SG)
           ~> #w3State(SG, LN, N, H)
           ~> REST ... </k>
    requires #w3OblG()
     andBool notBool #w3FVerdictK(SG, DECL, N, LinRoot, PL, PRESENTED, ANCHOR)
                                       ==String "valid-f"

endmodule
