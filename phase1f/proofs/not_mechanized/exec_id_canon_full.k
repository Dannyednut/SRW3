// =============================================================================
// SRW3 Phase 1F — EXECUTION IDENTITY AND CANONICAL TRACE EXACTNESS
//                          (phase1f/proofs/exec_id_canon.k)
//
// Backend: HASKELL (kprove). Structural claims — no hash evaluation is
// consumed; hash applications appear as uninterpreted terms and the claimed
// equalities are exact byte-construction equalities (the MODEL.md §3/§4
// forms, pinned verbatim as permanent regressions).
// =============================================================================

requires "srw3exec.k"

module SRW3EXEC-ID-CANON-PROOFS
  imports SRW3EXEC

  claim // EX1: ExecutionId exact byte construction (MODEL.md §4)
    <k> ( ExecExecId(PR:Bytes, PLD:Bytes, CFG:Bytes, ENV:Bytes)
          ==K LinH( Int2Bytes(1, 31, BE) +Bytes PR:Bytes +Bytes PLD:Bytes
                    +Bytes CFG:Bytes +Bytes ENV:Bytes ) )
        => true </k>
    requires true

  claim // EX2a: PayloadDigest exact form (domain tag 0x11)
    <k> ( ExecPayloadDigest(P:Bytes)
          ==K LinH( Int2Bytes(1, 17, BE) +Bytes P:Bytes ) ) => true </k>
    requires true

  claim // EX2b: EnvDigest exact form (domain tag 0x12; caller + 8B value)
    <k> ( ExecEnvDigest(CL:Bytes, V:Int)
          ==K LinH( Int2Bytes(1, 18, BE) +Bytes CL:Bytes +Bytes ExecI2B8(V:Int) ) )
        => true </k>
    requires true

  claim // EX2c: ConfigDigest exact form (domain tag 0x13; schedule + spec)
    <k> ( ExecConfigDigest(S:Bytes, SP:Int)
          ==K LinH( Int2Bytes(1, 19, BE) +Bytes S:Bytes +Bytes I2B4(SP:Int) ) )
        => true </k>
    requires true

  claim // EX3a: order preservation — event bytes concatenate in trace order
    <k> ( ExecEventsBytes(ListItem(E:ExecEvt) REST:List)
          ==K ExecEvtBytes(E:ExecEvt) +Bytes ExecEventsBytes(REST:List) )
        => true </k>
    requires true

  claim // EX3b: canonical trace frame — tag 0x03, count4, events in order
    <k> ( ExecCanonTrace(T:List)
          ==K Int2Bytes(1, 3, BE) +Bytes I2B4(size(T:List))
              +Bytes ExecEventsBytes(T:List) )
        => true </k>
    requires true

  claim // EX3c: concrete two-event trace — exact bytes, order fixed
    // events: Write(4098,1,100) then Read(4097,0,100) — the REVERSED order
    // yields DIFFERENT bytes (pinned by the second conjunct).
    <k> ( ExecCanonTrace( ListItem( exEvt(2, 4098, 1, 100) )
                          ListItem( exEvt(1, 4097, 0, 100) ) )
          ==K Int2Bytes(1, 3, BE)
              +Bytes I2B4(2)
              +Bytes ( Int2Bytes(1, 2, BE) +Bytes I2B4(4098)
                       +Bytes ExecI2B8(1) +Bytes ExecI2B8(100) )
              +Bytes ( Int2Bytes(1, 1, BE) +Bytes I2B4(4097)
                       +Bytes ExecI2B8(0) +Bytes ExecI2B8(100) ) )
        andBool ( ExecCanonTrace( ListItem( exEvt(1, 4097, 0, 100) )
                                  ListItem( exEvt(2, 4098, 1, 100) ) )
                  =/=K ExecCanonTrace( ListItem( exEvt(2, 4098, 1, 100) )
                                       ListItem( exEvt(1, 4097, 0, 100) ) ) )
        => true </k>
    requires true

  claim // EX3d: same multiset, different order ⇒ different trace bytes (F4 pin)
    <k> ( ExecCanonTrace( ListItem( exEvt(2, 4098, 1, 100) )
                          ListItem( exEvt(2, 4098, 0, 50) ) )
          =/=K ExecCanonTrace( ListItem( exEvt(2, 4098, 0, 50) )
                               ListItem( exEvt(2, 4098, 1, 100) ) ) )
        => true </k>
    requires true

endmodule
