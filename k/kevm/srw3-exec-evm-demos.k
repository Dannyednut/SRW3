// =============================================================================
// SRW3 Phase 1F — KEVM demo constants (srw3-exec-evm demos).
// The ANCHOR is computed by the Python reference (phase1f/python) for the
// exact honest demo storages — cross-layer byte check by construction
// (the 1E AAnchorHonest precedent):
//   universe  = { (4098,0), (4098,1) }
//   post      = { 4098: {0:100, 1:7} }
//   stateRoot = 0a22556b9f074913e929db417297f15170204c20b3345e1888cf598d32b163c9
// The demos share one anchor because the hidden write in evm_exec_hidden is
// STATE-INVISIBLE (SSTORE of a slot's own value): every state layer —
// including the anchor — sees the same post; only the execution-derived
// trace distinguishes it.
// =============================================================================

requires "srw3-exec-evm.k"

module SRW3-EXEC-EVM-DEMOS
  imports SRW3-EXEC-EVM

  // anchor over the honest demo post (Python-computed; see header)
  syntax Bytes ::= "FAnchorHonest" [function, total]
  rule FAnchorHonest
    => LinHex("0a22556b9f074913e929db417297f15170204c20b3345e1888cf598d32b163c9")
  // gate-1 anchor of the TWO-GATE scenario (universe includes slot9 := 0)
  syntax Bytes ::= "FAnchorTwo" [function, total]
  rule FAnchorTwo
    => LinHex("3a233c286643e1cb4115a84d2467a91f09727c030d5c39b09c35caa1a79ef61a")

  // payload "BORROW1"
  syntax Bytes ::= "FPayload" [function, total]
  rule FPayload => LinHex("424f52524f5731")

  // honest DECLARED effects (producer input, hand-written — NOT a post-hoc
  // diff): the lending contract writes slots 0 := 100 and 1 := 7
  syntax Map ::= "FDeclHonest" [function, total]
  rule FDeclHonest
    => LinSetKV(LinSetKV(LinSetKV(LinSetKV(LinSetKV(LinSetKV(LinSetKV(LinSetKV(LinSetKV(4097 |-> (0 |-> 100), 4097, 2, 100), 4098, 0, 100), 4098, 1, 5), 4098, 2, 30), 4098, 3, 7), 4099, 0, 4), 4099, 1, 100), 4099, 2, 40), 4099, 3, 7)

  // honest PRESENTED trace (producer input, hand-written)
  syntax List ::= "FTraceHonest" [function, total]
  rule FTraceHonest
    => ListItem( exEvt(2, 4097, 0, 100) )
       ListItem( exEvt(2, 4097, 2, 100) )
       ListItem( exEvt(2, 4098, 0, 100) )
       ListItem( exEvt(2, 4098, 1, 5) )
       ListItem( exEvt(2, 4098, 2, 30) )
       ListItem( exEvt(2, 4098, 3, 7) )
       ListItem( exEvt(2, 4099, 0, 4) )
       ListItem( exEvt(2, 4099, 1, 100) )
       ListItem( exEvt(2, 4099, 2, 40) )
       ListItem( exEvt(2, 4099, 3, 7) )


  // ---- the two-gate hidden-write scenario -------------------------------------
  // gate 1: honest 3-contract transition INCLUDING the declared slot9 := 0
  // write (11 events); gate 2: the INVISIBLE SSTORE (slot9 already 0) with
  // an EMPTY declared-effect map and an EMPTY presented trace — every
  // abstract layer accepts (state unchanged, presentation coherent), and
  // the execution-derived trace is what rejects (invalid-declared-exec).
  syntax Map ::= "FDeclTwo" [function, total]
  rule FDeclTwo
    => LinSetKV(FDeclHonest, 4098, 9, 0)

  syntax List ::= "FTraceTwo" [function, total]
  rule FTraceTwo
    => ListItem( exEvt(2, 4097, 0, 100) )
       ListItem( exEvt(2, 4097, 2, 100) )
       ListItem( exEvt(2, 4098, 9, 0) )
       ListItem( exEvt(2, 4098, 0, 100) )
       ListItem( exEvt(2, 4098, 1, 5) )
       ListItem( exEvt(2, 4098, 2, 30) )
       ListItem( exEvt(2, 4098, 3, 7) )
       ListItem( exEvt(2, 4099, 0, 4) )
       ListItem( exEvt(2, 4099, 1, 100) )
       ListItem( exEvt(2, 4099, 2, 40) )
       ListItem( exEvt(2, 4099, 3, 7) )

  // gate-2 anchor: root over the post-of-gate-1 universe (state unchanged)
  syntax Bytes ::= "FAnchorTwo" [function, total]
  rule FAnchorTwo
    => LinHex("3a233c286643e1cb4115a84d2467a91f09727c030d5c39b09c35caa1a79ef61a")
  syntax Bytes ::= "FPayloadTwo" [function, total]
  rule FPayloadTwo => LinHex("544f55434832")
  syntax Map ::= "FDeclEmpty" [function, total]
  rule FDeclEmpty => FNoSlots
  syntax List ::= "FTraceEmpty" [function, total]
  rule FTraceEmpty => .List

  // tampered PRESENTED trace: the second write claims 8 instead of 7
  syntax List ::= "FTraceTampered" [function, total]
  rule FTraceTampered
    => ListItem( exEvt(2, 4097, 0, 100) )
       ListItem( exEvt(2, 4097, 2, 100) )
       ListItem( exEvt(2, 4098, 0, 100) )
       ListItem( exEvt(2, 4098, 1, 8) )
       ListItem( exEvt(2, 4098, 2, 30) )
       ListItem( exEvt(2, 4098, 3, 7) )
       ListItem( exEvt(2, 4099, 0, 4) )
       ListItem( exEvt(2, 4099, 1, 100) )
       ListItem( exEvt(2, 4099, 2, 40) )
       ListItem( exEvt(2, 4099, 3, 7) )

  // debug carrier: evaluate the verdict WITHOUT the accept/reject requires
  syntax EthereumSimulation ::= "#w3GateFDbg"
  syntax KItem ::= "#w3DbgState" "(" String ")"
  // the #w3Snap0 snapshot shape: all three contracts present, all empty
  syntax Map ::= "FPSDemo" [function, total]
  rule FPSDemo => FEmptyAcct(4097) FEmptyAcct(4098) FEmptyAcct(4099)
  syntax Map ::= FEmptyAcct ( Int ) [function, total]
  rule FEmptyAcct(I:Int) => I |-> (FNoSlots)
  syntax Map ::= "FNoSlots" [function, total]
  rule FNoSlots => LinMapAt((4097 |-> (0 |-> 0)), 424242)
  // (the pre-run snapshot shape: all three contracts present, all empty;
  //  FNoSlots = an empty slot map via the frozen LinMapAt miss path)

  rule <k> #w3GateFDbg
        => #w3DbgState( #w3FVerdictK( FPSDemo, FDeclHonest, 0, LinRoot, FPayload
                                    , FTraceHonest, FAnchorHonest ) )
        ... </k>

  syntax KItem ::= "#w3DbgBytes" "(" String ")"
  rule <k> #w3GateFDbg
        => #w3DbgBytes( Bytes2StringX2(ExecCanonTrace(#w3ExecTrace))
                        +String "||" +String
                        Bytes2StringX2(ExecCanonTrace(FTraceHonest))
                        +String "||" +String
                        Bytes2StringX2(LinCanonKV(#w3FCUR))
                        +String "|" +String
                        Bytes2StringX2(LinCanonKV(LinApplyEff2(FPSDemo, FDeclHonest))) )
        ... </k>
  syntax String ::= Bytes2StringX2 ( Bytes ) [function, total]
  rule Bytes2StringX2(B) => Bytes2StringX2Aux(B, 0, lengthBytes(B))
  syntax String ::= Bytes2StringX2Aux ( Bytes , Int , Int ) [function, total]
  rule Bytes2StringX2Aux(B, I, N) => XHexDigit2(Bytes2Int(substrBytes(B, I, I +Int 1), BE, Unsigned)) +String Bytes2StringX2Aux(B, I +Int 1, N) requires I <Int N
  rule Bytes2StringX2Aux(_B, I, N) => "" requires I >=Int N
  syntax String ::= XHexDigit2 ( Int ) [function, total]
  rule XHexDigit2(I:Int) => XHD2(I /Int 16) +String XHD2(I modInt 16)
  syntax String ::= XHD2 ( Int ) [function, total]
  rule XHD2(0) => "0" rule XHD2(1) => "1" rule XHD2(2) => "2"
  rule XHD2(3) => "3" rule XHD2(4) => "4" rule XHD2(5) => "5"
  rule XHD2(6) => "6" rule XHD2(7) => "7" rule XHD2(8) => "8"
  rule XHD2(9) => "9" rule XHD2(10) => "a" rule XHD2(11) => "b"
  rule XHD2(12) => "c" rule XHD2(13) => "d" rule XHD2(14) => "e"
  rule XHD2(15) => "f"
  rule XHexDigit2(12) => "c" rule XHexDigit2(13) => "d" rule XHexDigit2(14) => "e"
  rule XHexDigit2(15) => "f"

endmodule
