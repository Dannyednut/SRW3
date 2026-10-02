// =============================================================================
// SRW3 Phase 1D — Demo scenario surface (k/phase1d/srw3lin-demo.k)
//
// One canonical demo scenario, reused by every 1D demonstration program:
//
//   initial state  : { app1: {slot0: 100},  app2: {slot0: 50} }
//   transition A   : declared write app1.slot0 := 30            (tid 0)
//   transition B   : declared write app1.slot0 := 25
//                    UNDECLARED side effect app2.slot1 := 7     (tid 1)
//
//   ctxA           : inputs {1:{0:30}}, true effects {1:{0:30}},
//                    post-state {1:{0:30}, 2:{0:50}}
//   ctxB           : inputs {1:{0:25}}, TRUE effects {1:{0:25}, 2:{1:7}},
//                    post-state {1:{0:25}, 2:{0:50, 1:7}}
//   ctxB-declared  : inputs {1:{0:25}}, declared-only "effects" {1:{0:25}}
//                    (the CM-L5 presentation attempt)
//   registry       : {5 -> true}          (policy version 5 known)
//   authority set  : { addr(key1), addr(key2) }  (two distinct keys)
//
// Authenticated-state-proof interface (Merkle inclusion proofs against the
// prototype committed-state digest): the SORT is declared below but NO rules
// are given — the interface is NOT YET MECHANIZED in this phase and any
// evaluation attempt is stuck, by design (naming discipline: the prototype
// committed-state digest is NOT an Ethereum state root and no trie/Merkle
// property is claimed for it).
// =============================================================================

requires "srw3lin-gate.k"

module SRW3LIN-DEMO
  imports SRW3LIN-GATE

  // ---- NOT YET MECHANIZED: authenticated-state-proof interface ---------------
  // (declaration only; no defining rules; kept unevaluable by design)
  syntax MerkleInterface ::= LinStateProof ( Bytes , Map ) [function]

  // ---- claimed-artifact constructors (static demo data) ----------------------
  syntax LinCtx ::= "LinDemoCtxA" [function, total]
  rule LinDemoCtxA
    => linCtx( LinKV1(1, 0, 30)                    // declared inputs
             , LinKV1(1, 0, 30)                    // true effects
             , LinSetKV(LinKV1(1, 0, 30), 2, 0, 50) // post-state {1:{0:30}, 2:{0:50}}
             , 5 |-> true                          // registry
             , LinDemoAuthSet )

  syntax LinCtx ::= "LinDemoCtxB" [function, total]
  rule LinDemoCtxB
    => linCtx( LinKV1(1, 0, 25)                          // declared inputs
             , LinSetKV(LinKV1(1, 0, 25), 2, 1, 7)       // TRUE effects (hidden!)
             , LinSetKV(LinSetKV(LinKV1(1, 0, 25), 2, 0, 50), 2, 1, 7) // post
             , 5 |-> true
             , LinDemoAuthSet )

  syntax LinCtx ::= "LinDemoCtxBDeclaredOnly" [function, total]
  rule LinDemoCtxBDeclaredOnly
    => linCtx( LinKV1(1, 0, 25)                          // declared inputs
             , LinKV1(1, 0, 25)                          // declared-only "effects"
             , LinSetKV(LinSetKV(LinKV1(1, 0, 25), 2, 0, 50), 2, 1, 7)
             , 5 |-> true
             , LinDemoAuthSet )

  syntax LinCtx ::= "LinDemoCtxC" [function, total]
  rule LinDemoCtxC
    => linCtx( LinKV1(1, 0, 20)                                // declared inputs
             , LinKV1(1, 0, 20)                                // true effects
             , LinSetKV(LinSetKV(LinKV1(1, 0, 20), 2, 0, 50), 2, 1, 7) // post
             , 5 |-> true
             , LinDemoAuthSet )

  syntax Map ::= LinKV1 ( Int , Int , Int ) [function, total]   // {a:{s:v}}
  rule LinKV1(A:Int, S:Int, V:Int) => A |-> (S |-> V)

  syntax Set ::= "LinDemoAuthSet" [function, total]
  rule LinDemoAuthSet => SetItem(LinAddrOf(LinDemoKey1)) SetItem(LinAddrOf(LinDemoKey2))

  syntax Map ::= "LinDemoCtxBook" [function, total]
  rule LinDemoCtxBook => 0 |-> LinDemoCtxA  1 |-> LinDemoCtxB  2 |-> LinDemoCtxC

  syntax LinCtx ::= LinDemoCtxAt ( Int ) [function, total]
  rule LinDemoCtxAt(0) => LinDemoCtxA
  rule LinDemoCtxAt(1) => LinDemoCtxB
  rule LinDemoCtxAt(2) => LinDemoCtxC
  rule LinDemoCtxAt(_:Int) => linCtx(.Map, .Map, .Map, .Map, .Set)

  // ---- self-verification commands (records from the <lineage> cell; claimed
  //      artifacts passed explicitly — the verifier function itself stays
  //      stateless and cell-free) ----------------------------------------------
  syntax LinCmd ::= "linVerifySelf" "(" Int ")"
  rule <k> linVerifySelf(N:Int) => .K ... </k>
       <lineage> L:Map </lineage>
       <result> R:String => R +String LinVerifyChain(L, LinDemoCtxBook, 0, N, LinRoot) +String ";" </result>

  // CM-L5: verify the chain against DECLARED-ONLY artifacts for tid 1 —
  // the hidden side effect cannot hide (apps/effect digest divergence detected)
  syntax LinCmd ::= "linVerifyDeclaredOnly" "(" Int ")"
  rule <k> linVerifyDeclaredOnly(N:Int) => .K ... </k>
       <lineage> L:Map </lineage>
       <result> R:String
          => R +String LinVerifyChain(L, 0 |-> LinDemoCtxA 1 |-> LinDemoCtxBDeclaredOnly, 0, N, LinRoot) +String ";" </result>

  // Part IX: tamper matrix on record 0 against ctxA
  syntax LinCmd ::= "linTamperSelf"
  rule <k> linTamperSelf => .K ... </k>
       <lineage> L:Map </lineage>
       <result> R:String
          => R +String LinTamperMatrix(linRecAt(L, 0), LinDemoCtxA, 0, LinRoot,
               ListItem(fVersion) ListItem(fParent) ListItem(fTid) ListItem(fApps)
               ListItem(fInputD) ListItem(fEffectD) ListItem(fStateD) ListItem(fPolicyV)
               ListItem(fAuthority) ListItem(fEvidence) ListItem(fSig) ListItem(fChild)) +String ";" </result>

  // CM-L4: impersonation — authority swapped to the OTHER in-set member
  syntax LinCmd ::= "linImpersonateSelf"
  rule <k> linImpersonateSelf => .K ... </k>
       <lineage> L:Map </lineage>
       <result> R:String
          => R +String "impersonate=" +String VerifyLineage(
               LinImpersonate(linRecAt(L, 0), LinAddrOf(LinDemoKey2)),
               LinDemoCtxA, 0, LinRoot) +String ";" </result>

  // ---- replay commands (present a record already in the chain) ---------------
  // R1: replay record T verbatim at the current position (stale tid)
  syntax LinCmd ::= "linGateReplay" "(" Int ")"
  rule <k> linGateReplay(T:Int) => linGatePresent(linRecAt(L:Map, T), LinDemoCtxAt(T)) ... </k>
       <lineage> L:Map </lineage>

  // R2/R3: replay with the transition id forged to the current position
  syntax LinRec ::= LinForgeTid ( LinRec , Int ) [function]
  rule LinForgeTid(R:LinRec, T:Int)
    => linRec(linVersionOf(R), linParentOf(R), T, linAppsOf(R), linInputDOf(R),
              linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R),
              linEvOf(R), linSigOf(R), linChildOf(R))

  syntax LinCmd ::= "linGateReplayForged" "(" Int ")"
  rule <k> linGateReplayForged(T:Int) => linGatePresent(LinForgeTid(linRecAt(L:Map, T), N:Int), LinDemoCtxAt(T)) ... </k>
       <lineage> L:Map </lineage>
       <lineageNext> N:Int </lineageNext>

  // tid-bumped replay of a chain record into a FRESH chain (R3 variant)
  syntax LinCmd ::= "linGateReplayCross" "(" Int ")"
  rule <k> linGateReplayCross(T:Int) => linGatePresent(LinForgeTid(linRecAt(L:Map, T), 0), LinDemoCtxAt(T)) ... </k>
       <lineage> L:Map </lineage>
endmodule
