// =============================================================================
// SRW3 Phase 1F — TRACE REPLAY SEMANTICS
//                          (phase1f/proofs/exec_replay.k)
//
// Backend: HASKELL (kprove).
//
//   EX4a: ExecReplayOk decomposes exactly as read-consistency ∧ canonical
//     equality of the presented post against the replay-final map.
//   EX4b: concrete replay pin — an honest (read, write) sequence replays to
//     the expected post; a tampered READ OBSERVATION is caught (the F2
//     detection mechanism when the trace is presented).
//   EX4c: last-write-wins — two writes to the same slot replay to the LAST
//     value; the reversed order replays to the other value (F4 same-slot
//     order sensitivity, order-preserving by construction).
//   EX5w: THE REPLAY-WRITES LEMMA — ExecReplayMap(T, PRE) equals
//     LinApplyEff2(PRE, ExecTraceWrites(T)). If PROVED, the replay's final
//     map is exactly the corrected-composition apply of the trace's write
//     projection. Attempted in full symbolic generality; if the prover
//     reaches its budget the claim is disclosed as NOT YET MECHANIZED
//     (the gate's binding does not depend on it: ExecReplayOk compares the
//     replay-final map directly).
// =============================================================================

requires "srw3exec.k"

module SRW3EXEC-REPLAY-PROOFS
  imports SRW3EXEC

  claim // EX4a: ExecReplayOk exact decomposition (definitional pin)
    <k> ( ExecReplayOk(PRE:Map, T:List, POST:Map)
          ==K ( ExecReadsOk(T:List, PRE:Map)
                andBool BytesEq( LinCanonKV(POST:Map)
                               , LinCanonKV(ExecReplayMap(T:List, PRE:Map)) ) ) )
        => true </k>
    requires true

  claim // EX4b: honest replay — read observation consistent, writes produce post
    <k> ( ExecReplayOk( 4097 |-> (0 |-> 100) 4098 |-> (1 |-> 0)
                      , ListItem( exEvt(1, 4097, 0, 100) )
                        ListItem( exEvt(2, 4098, 1, 100) )
                      , 4097 |-> (0 |-> 100) 4098 |-> (1 |-> 100) )
          ==K true )
        => true </k>
    requires true

  claim // EX4b-neg: tampered read observation caught by the replay (F2 pin)
    <k> ( ExecReplayOk( 4097 |-> (0 |-> 100) 4098 |-> (1 |-> 0)
                      , ListItem( exEvt(1, 4097, 0, 7) )
                        ListItem( exEvt(2, 4098, 1, 100) )
                      , 4097 |-> (0 |-> 100) 4098 |-> (1 |-> 100) )
          ==K false )
        => true </k>
    requires true

  claim // EX4c: same-slot last-write-wins (order sensitivity, F4 pin)
    <k> ( ExecReplayMap( ListItem( exEvt(2, 4098, 0, 1) )
                         ListItem( exEvt(2, 4098, 0, 2) )
                       , 4098 |-> (0 |-> 0) )
          ==K ( 4098 |-> (0 |-> 2) ) )
        andBool
        ( ExecReplayMap( ListItem( exEvt(2, 4098, 0, 2) )
                         ListItem( exEvt(2, 4098, 0, 1) )
                       , 4098 |-> (0 |-> 0) )
          ==K ( 4098 |-> (0 |-> 1) ) )
        => true </k>
    requires true

  claim // EX4d: cross-slot write order does NOT change the replay-final map
    // (the fragment's documented order-insensitivity where it is
    // security-irrelevant: distinct slots commute)
    <k> ( ExecReplayMap( ListItem( exEvt(2, 4098, 0, 1) )
                         ListItem( exEvt(2, 4098, 1, 2) )
                       , 4098 |-> (0 |-> 0) (1 |-> 0) )
          ==K ExecReplayMap( ListItem( exEvt(2, 4098, 1, 2) )
                             ListItem( exEvt(2, 4098, 0, 1) )
                           , 4098 |-> (0 |-> 0) (1 |-> 0) ) )
        => true </k>
    requires true

  claim // EX5w: THE REPLAY-WRITES LEMMA (full symbolic generality)
    <k> ( ExecReplayMap(T:List, PRE:Map)
          ==K LinApplyEff2(PRE:Map, ExecTraceWrites(T:List)) )
        => true </k>
    requires true

endmodule
