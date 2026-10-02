// =============================================================================
// SRW3 Phase 1D — Part XIII: cryptographic lineage over REAL EVM execution
// (k/kevm/srw3-lin-evm.k — ADDITIVE; the 1A/1B bindings stay frozen)
//
// Composition the Phase-1C report named as the next opening: the KEVM
// storage binding (Phase 1B, multi-contract) and the cryptographic lineage
// (Phase 1C/1D) are composed into ONE definition. The marker #w3GateL is the
// Phase-1B gate EXTENDED with a real Λ record: ONE evaluated obligation
// conjunction (#w3OblG, unchanged), and the ONLY rule that touches the
// storages/lineage. On accept it updates BOTH carriers:
//
//   #w3State    (the 1B carrier: s/ln/n/h — unchanged semantics)
//   #w3LinState (the 1D carrier: lin/n/head/snap — the real-keccak Λ chain)
//
// On reject it performs the SAME restore as the 1B gate and appends NO
// lineage record (commit/lineage atomicity; demo: lin_evm_overflow).
//
//   EffectDigest = Keccak256(CanonKV(TRUE effects)) — diff(pre-snapshot,
//                  current storages) across ALL accounts (multi-contract,
//                  multi-slot): everything the transition actually changed,
//                  declared or not, is bound into the record
//   StateDigest  = Keccak256(CanonKV(current storages))
//                  ("prototype committed-state digest" — NOT an Ethereum
//                  state root; no trie/Merkle property claimed)
//   InputDigest  = Keccak256(CanonKV(pre-snapshot)) — pre-state context
//                  binding; a calldata-level declared-input binding is
//                  REQUIRES CLIENT/PROTOCOL SUPPORT (recorded, not silent)
//   AppSet       = ascending account ids of the TRUE effects
//   Evidence/Sig = secp256k1 signatures via the pinned libsecp256k1 path
//   Child        = Keccak256(CanonicalSerialize(Λ minus Child))
//
// Carriers are emitted #w3State-first so the 1B head-anchored threading
// patterns stay satisfiable within a single gate; multi-gate 1D runs thread
// the 1D carrier behind the state carrier (single-gate-per-run demos in this
// phase; multi-gate 1D threading recorded as future work).
// =============================================================================

requires "srw3-gen-binding.k"
requires "srw3lin.k"

module SRW3-LIN-EVM
  imports SRW3-GEN-EVM
  imports SRW3LIN

  syntax EthereumSimulation ::= "#w3GateL"

  // 1D lineage carrier: the real Λ chain over REAL EVM storage
  //   lin: Map tid -> LinRec ; n: next tid ; head: current head commitment ;
  //   snap: the pre-transition storage snapshot (diff base / input context)
  syntax KItem ::= "#w3LinState" "(" lin:Map "," n:Int "," head:Bytes "," snap:Map ")"

  // ---- true effects: entries of CUR that differ from the snapshot -----------
  syntax Map ::= "#w3TrueEffects" "(" Map "," Map ")" [function, total]
  rule #w3TrueEffects(PS:Map, CUR:Map) => #w3TEAccounts(CUR:Map, PS:Map)

  syntax Map ::= "#w3TEAccounts" "(" Map "," Map ")" [function, total]
  rule #w3TEAccounts(.Map, _:Map) => .Map
  rule #w3TEAccounts(CUR:Map, PS:Map)
    => #w3TEMerge( #w3TESlots(LinMapAt(CUR, MinKeyOfMap(CUR)),
                              LinMapAt(PS, MinKeyOfMap(CUR)),
                              MinKeyOfMap(CUR))
                 , #w3TEAccounts(CUR[MinKeyOfMap(CUR) <- undef], PS) )
    requires sizeMap(CUR) >=Int 1

  syntax Map ::= "#w3TESlots" "(" Map "," Map "," Int ")" [function, total]
  rule #w3TESlots(.Map, _:Map, _:Int) => .Map
  rule #w3TESlots(S_CUR:Map, S_PS:Map, A:Int)
    => #w3TESlotInsert( MinKeyOfMap(S_CUR)
                      , LinIntAt(S_CUR, MinKeyOfMap(S_CUR))
                      , LinIntAt(S_PS, MinKeyOfMap(S_CUR))
                      , A
                      , #w3TESlots(S_CUR[MinKeyOfMap(S_CUR) <- undef], S_PS, A) )
    requires sizeMap(S_CUR) >=Int 1

  syntax Map ::= "#w3TESlotInsert" "(" Int "," Int "," Int "," Int "," Map ")" [function, total]
  rule #w3TESlotInsert(S1:Int, V1:Int, V2:Int, A1:Int, M1:Map)
    => LinSetKV(M1, A1, S1, V1) requires V1 =/=Int V2
  rule #w3TESlotInsert(S1:Int, V1:Int, V2:Int, A1:Int, M1:Map)
    => M1 requires V1 ==Int V2

  // merge one account's effect entry into the accumulator (accounts are
  // visited once each, so the accumulator has no entry for that account yet)
  syntax Map ::= "#w3TEMerge" "(" Map "," Map ")" [function, total]
  rule #w3TEMerge(.Map, M2:Map) => M2
  rule #w3TEMerge(A:Int |-> S:Map, M2:Map)
    => M2[A <- S] requires sizeMap(LinMapAt(M2, A)) ==Int 0

  // EVM-side Λ builder: computes the true effects ONCE and delegates to the
  // Phase-1D record constructor (pre-state snapshot = input context binding;
  // see the header note on InputDigest scope).
  syntax LinRec ::= "#w3LinBuildRec" "(" Int "," Bytes "," Map "," Map "," Bytes "," Int ")" [function]
  rule #w3LinBuildRec(T:Int, P:Bytes, PS:Map, CUR:Map, KEY:Bytes, PV:Int)
    => LinBuildRec(T, P, PS, #w3TrueEffects(PS, CUR), CUR, KEY, PV)

  // ---- the 1D gate: the 1B gate extended with a real Λ record ---------------
  // ACCEPT (fresh — first gate of the run; no 1D carrier yet): the Λ chain
  // starts at the root commitment.
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateL REST:EthereumSimulation )
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
           ~> #w3LinState( .Map[0 <- #w3LinBuildRec(0, LinRoot, SG, #w3allStorages(), LinDemoKey1, 5)]
                         , 1
                         , linChildOf(#w3LinBuildRec(0, LinRoot, SG, #w3allStorages(), LinDemoKey1, 5))
                         , #w3allStorages() )
           ~> REST ... </k>
    requires #w3OblG()

  // ACCEPT (continuing — a 1D carrier exists from an earlier gate)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> ( #w3GateL REST:EthereumSimulation )
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
           ~> #w3LinState( LIN[NB:Int <- #w3LinBuildRec(NB, HB, PS, #w3allStorages(), LinDemoKey1, 5)]
                         , NB +Int 1
                         , linChildOf(#w3LinBuildRec(NB, HB, PS, #w3allStorages(), LinDemoKey1, 5))
                         , #w3allStorages() )
           ~> REST ... </k>
    requires #w3OblG()

  // REJECT (atomicity): the same restore as the 1B gate; NO lineage record.
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateL REST:EthereumSimulation )
        => #w3RestoreAll(SG) ~> #w3State(SG, LN, N, H) ~> REST ... </k>
    [owise]
endmodule
