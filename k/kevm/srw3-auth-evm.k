// =============================================================================
// SRW3 Phase 1E — authenticated state over REAL EVM execution
//                          (k/kevm/srw3-auth-evm.k — ADDITIVE)
//
// The Phase-1D KEVM composition (srw3-lin-evm.k, frozen) is extended with the
// authenticated-state layer (srw3auth.k). The marker #w3GateA(anchor) is the
// 1D gate EXTENDED with:
//
//   * the canonical key universe over (pre-snapshot, TRUE effects, current
//     storages) — the true-effects diff is the EVM-level ground truth of what
//     the transition actually changed (declared or not);
//   * stateRoot  = AuthRootOf(U, current storages)   (real keccak, real
//     Merkle tree over REAL EVM storage);
//   * the EXTENDED record recE = linRecE(Λ, stateRoot, childE);
//   * an explicit ANCHOR parameter standing for the independently published
//     authoritative state commitment (provenance NOT mechanized — the demo
//     anchor constants are computed by the Python reference, giving a
//     cross-layer byte check by construction);
//   * VERDICT = VerifyLineageA(recE, authCtx(linCtxP(PS,TE,CUR,reg,auth),
//     anchor), tid, head).
//
// Rules (commit/lineage atomicity preserved):
//   ACCEPT : obligations hold AND VerifyLineageA = "valid-a" -> commit both
//            carriers + emit #w3AuthState(recE, root, proof, "valid-a").
//   AUTH-REJECT : obligations hold, verdict != "valid-a" -> NO lineage
//            record, storages restored, #w3AuthState carries the failing
//            verdict (the demonstration carrier).
//   OBL-REJECT : [owise] the same restore as the 1D gate.
//
// This is a Level-2 (anchored state) demonstration on real execution. It is
// NOT a Level-3 result: nothing here authenticates historically-true
// execution effects beyond the KEVM run itself; the anchor's provenance
// remains REQUIRES CLIENT/PROTOCOL SUPPORT.
// =============================================================================

requires "srw3-lin-evm.k"
requires "srw3auth.k"

module SRW3-AUTH-EVM
  imports SRW3-LIN-EVM
  imports SRW3AUTH

  syntax EthereumSimulation ::= "#w3GateA" "(" Bytes ")"

  // 1E auth carrier: the extended record, the root over real storages, a
  // 260-byte content-binding proof for AProofKey, and the verifier verdict.
  syntax KItem ::= "#w3AuthState" "(" recE:LinRecE "," root:Bytes
                                 "," proof:Bytes "," verdict:String ")"

  // verifier-side constants (mirror the abstract demo; PV=5 registry)
  syntax Map ::= "ARegE" [function, total]
  rule ARegE => 5 |-> true  6 |-> true
  syntax Set ::= "AAuthE" [function, total]
  rule AAuthE => SetItem(LinAddrOf(LinDemoKey1))
  syntax Int ::= "AProofKey" [function, total]
  rule AProofKey => 4098 *Int AuthTwo32() +Int 2

  // ANCHOR constants — computed by the Python reference (phase1e/python) for
  // the exact honest storages of the demo programs (cross-layer byte check
  // by construction). Values are recorded in the Part-5 transcript; they are
  // placeholders here and are FILLED from the Python computation before the
  // demos run (see the transcript for the exact literals).
  syntax Bytes ::= "AAnchorHonest" [function, total]
  rule AAnchorHonest => LinHex(AAnchorHonestHex)
  syntax String ::= "AAnchorHonestHex" [function, total]
  rule AAnchorHonestHex => "0a22556b9f074913e929db417297f15170204c20b3345e1888cf598d32b163c9"

  syntax Bytes ::= "AAnchorStale" [function, total]
  rule AAnchorStale => LinHex(AAnchorStaleHex)
  syntax String ::= "AAnchorStaleHex" [function, total]
  rule AAnchorStaleHex => "42a6d8070aacb56999b6a65ff327023b23b5c3f10ad3be9607b1e00f44cb802e"

  // ---- shared pieces --------------------------------------------------------
  syntax LinRec ::= "#w3ARec1" "(" Map "," Map "," Map "," Int "," Bytes ")" [function]
  rule #w3ARec1(PS:Map, TE:Map, CUR:Map, NB:Int, HB:Bytes)
    => #w3LinBuildRec(NB, HB, PS, CUR, LinDemoKey1, 5)

  syntax Bytes ::= "#w3ARoot" "(" Map "," Map "," Map ")" [function]
  rule #w3ARoot(PS:Map, TE:Map, CUR:Map)
    => AuthRootOf( AuthUnion3( AuthKeysOfMap(PS), AuthKeysOfMap(TE)
                             , AuthKeysOfMap(CUR) )
                 , CUR )

  syntax LinRecE ::= "#w3ARecE" "(" Map "," Map "," Map "," Int "," Bytes ")" [function]
  rule #w3ARecE(PS:Map, TE:Map, CUR:Map, NB:Int, HB:Bytes)
    => linRecE( #w3ARec1(PS, TE, CUR, NB, HB)
              , #w3ARoot(PS, TE, CUR)
              , AuthChildE( #w3ARec1(PS, TE, CUR, NB, HB)
                          , #w3ARoot(PS, TE, CUR) ) )

  syntax String ::= "#w3AVerdict" "(" Map "," Map "," Map "," Int "," Bytes
                                 "," Bytes ")" [function]
  rule #w3AVerdict(PS:Map, TE:Map, CUR:Map, NB:Int, HB:Bytes, ANCHOR:Bytes)
    => VerifyLineageA( #w3ARecE(PS, TE, CUR, NB, HB)
                     , authCtx( linCtxP(PS, TE, CUR, ARegE, AAuthE), ANCHOR )
                     , NB, HB )

  syntax Bytes ::= "#w3AProof" "(" Map "," List ")" [function]
  rule #w3AProof(CUR:Map, U:List)
    => AuthProofOf(U, CUR, AProofKey)

  // config-bound current storages and true effects (cell context functions)
  syntax Map ::= "#w3ACUR" [function, total]
  rule [[ #w3ACUR => #w3allStorages() ]] <accounts> _BAG:Bag </accounts>

  syntax Map ::= "#w3ATE" "(" Map ")" [function, total]
  rule [[ #w3ATE(PS:Map) => #w3TrueEffects(PS, #w3allStorages()) ]]
       <accounts> _BAG2:Bag </accounts>

  syntax LinRecE ::= "#w3ARec1E" "(" Map "," Int "," Bytes ")" [function, total]
  rule [[ #w3ARec1E(PS:Map, NB:Int, HB:Bytes)
        => #w3ARecE(PS, #w3TrueEffects(PS, #w3allStorages()), #w3allStorages(), NB, HB) ]]
       <accounts> _BAG5:Bag </accounts>

  syntax String ::= "#w3AVerdictE" "(" Map "," Int "," Bytes "," Bytes ")" [function, total]
  rule [[ #w3AVerdictE(PS:Map, NB:Int, HB:Bytes, ANCHOR:Bytes)
        => #w3AVerdict(PS, #w3TrueEffects(PS, #w3allStorages()), #w3allStorages(), NB, HB, ANCHOR) ]]
       <accounts> _BAG6:Bag </accounts>

  syntax Bytes ::= "#w3AProofE" "(" Map ")" [function, total]
  rule [[ #w3AProofE(PS:Map)
        => AuthProofOf( AuthUnion3( AuthKeysOfMap(PS)
                                  , AuthKeysOfMap(#w3TrueEffects(PS, #w3allStorages()))
                                  , AuthKeysOfMap(#w3allStorages()) )
                      , #w3allStorages()
                      , AProofKey ) ]]
       <accounts> _BAG7:Bag </accounts>

  syntax LinRec ::= "#w3ARec1C" "(" Map "," Int "," Bytes ")" [function, total]
  rule [[ #w3ARec1C(PS:Map, NB:Int, HB:Bytes)
        => #w3ARec1(PS, #w3TrueEffects(PS, #w3allStorages()), #w3allStorages(), NB, HB) ]]
       <accounts> _BAG8:Bag </accounts>

  syntax Bytes ::= "#w3ARootC" "(" Map ")" [function, total]
  rule [[ #w3ARootC(PS:Map)
        => AuthRootOf( AuthUnion3( AuthKeysOfMap(PS)
                                 , AuthKeysOfMap(#w3TrueEffects(PS, #w3allStorages()))
                                 , AuthKeysOfMap(#w3allStorages()) )
                     , #w3allStorages() ) ]]
       <accounts> _BAG9:Bag </accounts>

  // ---- ACCEPT: obligations hold and the anchored verifier says valid-a ------
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> ( #w3GateA(ANCHOR:Bytes) REST:EthereumSimulation )
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
           ~> #w3LinState( LIN[NB:Int <- #w3ARec1C(PS, NB, HB)]
                         , NB +Int 1
                         , linChildOf(#w3ARec1C(PS, NB, HB))
                         , #w3allStorages() )
           ~> #w3AuthState( #w3ARec1E(PS, NB, HB)
                          , #w3ARootC(PS)
                          , #w3AProofE(PS)
                          , "valid-a" )
           ~> REST ... </k>
    requires #w3OblG()
     andBool #w3AVerdictE(PS, NB, HB, ANCHOR) ==String "valid-a"

  // ---- AUTH-REJECT: obligations hold but the anchored verdict fails ---------
  // NO lineage record; storages restored; the carrier records WHY.
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> ( #w3GateA(ANCHOR:Bytes) REST:EthereumSimulation )
        => #w3AuthState( #w3ARec1E(PS, NB, HB)
                       , #w3ARootC(PS)
                       , #w3AProofE(PS)
                       , #w3AVerdictE(PS, NB, HB, ANCHOR) )
           ~> #w3RestoreAll(SG)
           ~> #w3State(SG, LN, N, H)
           ~> #w3LinState(LIN, NB, HB, PS)
           ~> REST ... </k>
    requires #w3OblG()
     andBool notBool #w3AVerdictE(PS, NB, HB, ANCHOR) ==String "valid-a"

  // ACCEPT (fresh): first gate of the run — no 1D carrier yet; the pre-state
  // snapshot is the #w3State carrier's own snapshot (SG), tid = N (= 0 at the
  // first gate), parent = LinRoot (the 1D fresh-rule convention).
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateA(ANCHOR:Bytes) REST:EthereumSimulation )
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
           ~> #w3LinState( .Map[N:Int <- #w3ARec1C(SG, N, LinRoot)]
                         , N +Int 1
                         , linChildOf(#w3ARec1C(SG, N, LinRoot))
                         , #w3allStorages() )
           ~> #w3AuthState( #w3ARec1E(SG, N, LinRoot)
                          , #w3ARootC(SG)
                          , #w3AProofE(SG)
                          , "valid-a" )
           ~> REST ... </k>
    requires #w3OblG()
     andBool #w3AVerdictE(SG, N, LinRoot, ANCHOR) ==String "valid-a"

  // AUTH-REJECT (fresh)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateA(ANCHOR:Bytes) REST:EthereumSimulation )
        => #w3AuthState( #w3ARec1E(SG, N, LinRoot)
                       , #w3ARootC(SG)
                       , #w3AProofE(SG)
                       , #w3AVerdictE(SG, N, LinRoot, ANCHOR) )
           ~> #w3RestoreAll(SG)
           ~> #w3State(SG, LN, N, H)
           ~> REST ... </k>
    requires #w3OblG()
     andBool notBool #w3AVerdictE(SG, N, LinRoot, ANCHOR) ==String "valid-a"

  // ---- OBL-REJECT: the 1B obligations fail (same restore as the 1D gate) ----
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateA(ANCHOR:Bytes) REST:EthereumSimulation )
        => #w3RestoreAll(SG) ~> #w3State(SG, LN, N, H) ~> REST ... </k>
    [owise]

endmodule
