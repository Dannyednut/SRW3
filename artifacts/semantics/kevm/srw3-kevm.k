// =============================================================================
// SRW3 Phase 0-D — KEVM binding (k/kevm/srw3-kevm.k)
//
// Layers REAL KEVM execution semantics (module EVM from evm.md) with SRW3
// commitment-gate semantics. The KEVM configuration is used UNMODIFIED: the
// SRW3 gate state (committed snapshot, lineage chain, counters) is threaded
// through the <k> program itself, keeping the extension purely additive.
//
//   #w3Setup    create the three contracts with REAL assembled bytecode
//   #w3Snap0    capture the committed storage snapshot (threaded state)
//   #w3Run(A, OPS)  REAL EVM execution: SSTORE/CALL/RETURN/MSTORE/MLOAD/SLOAD
//   #w3Gate(S,LN,N,H)  evaluate SRW3 obligations over REAL prospective storage
//                 accept -> snapshot := post-storage (commit) + lineage append
//                 reject -> restore storages from S (prospective EVM state
//                           discarded: the commitment boundary)
//
// Applications: w3Oracle = addr 1, w3Lending = addr 2, w3Liq = addr 3.
// Obligations (handoff §16) evaluated over genuine KEVM storage:
//   IOL  : lending slot0 == oracle slot0        (price used == oracle price)
//   ILD  : liq slot0 <= lending slot1           (transfer <= authorized debt)
//   IOLD : liq slot1 == lending slot0 /\ lending slot0 == oracle slot0
//          (three-way settlement price-lineage property)
//
// Authority mechanics are mechanized at the abstract layer (Claims 1-4); this
// layer carries the binding finding: the gate mediates REAL prospective EVM
// state and restores it on rejection.
// =============================================================================

requires "evm.md"
requires "asm.md"

module SRW3-EVM
  imports EVM
  imports EVM-ASSEMBLY

  // ---- SRW3 program syntax ($PGM : EthereumSimulation, declared in evm.md) --
  syntax EthereumSimulation ::= "#w3Nil"
                              | "#w3Setup"
                              | "#w3Snap0"
                              | "#w3Gate0"
                              | "#w3Run"  "(" Int "," OpCodes ")"
  // gate + state carrier are K items (k-sequence natives; no operator clash)
  syntax EthereumSimulation ::= EthereumSimulation EthereumSimulation [right]

  syntax KItem ::= "#w3Gate"  "(" s:Map "," ln:Map "," n:Int "," h:Int ")"
                 | "#w3State" "(" s:Map "," ln:Map "," n:Int "," h:Int ")"
                 | "#w3RestoreAll" "(" s:Map ")"
                 | "#w3RestoreOne" "(" s:Map "," Int ")"
                 | "#w3SetCtx" "(" Int "," Bytes ")"

  syntax KItem ::= "#w3Gate"  "(" s:Map "," ln:Map "," n:Int "," h:Int ")"
                 | "#w3State" "(" s:Map "," ln:Map "," n:Int "," h:Int ")"

  // Contract addresses (fixed and documented; no CREATE/keccak needed)
  syntax Int ::= "w3Oracle"  [function, total]
  syntax Int ::= "w3Lending" [function, total]
  syntax Int ::= "w3Liq"     [function, total]
  rule w3Oracle  => 4097
  rule w3Lending => 4098
  rule w3Liq     => 4099

  syntax W3LinRec ::= "w3lin" "(" parent:Int "," tid:Int "," price:Int ")"

  // ---- typed storage read over REAL KEVM accounts ---------------------------
  // Unset slots and absent accounts read as 0 (EVM empty-account semantics).
  syntax Int ::= "#w3read" "(" addr:Int "," key:Int ")" [function, total]
  rule [[ #w3read(ACCT, KEY) => {WS[KEY]}:>Int ]]
       <account> <acctID> ACCT </acctID> <storage> WS </storage> ... </account>
    requires KEY in_keys(WS)
  rule [[ #w3read(ACCT, KEY) => 0 ]]
       <account> <acctID> ACCT </acctID> <storage> WS </storage> ... </account>
    requires notBool KEY in_keys(WS)
  rule #w3read(_ACCT, _KEY) => 0 [owise]

  // current full storage maps of the three contracts
  syntax Map ::= "#w3allStorages" "(" ")" [function, total]
  rule [[ #w3allStorages() => 4097 |-> WS1  4098 |-> WS2  4099 |-> WS3 ]]
       <accounts>
         ( <account> <acctID> 4097 </acctID> <storage> WS1 </storage> ... </account>
           <account> <acctID> 4098 </acctID> <storage> WS2 </storage> ... </account>
           <account> <acctID> 4099 </acctID> <storage> WS3 </storage> ... </account>
           _REST:Bag )
       </accounts>

  // ---- obligations over REAL storage (handoff §16) --------------------------
  syntax Bool ::= "#w3IOL"  "(" ")" [function, total]
  syntax Bool ::= "#w3ILD"  "(" ")" [function, total]
  syntax Bool ::= "#w3IOLD" "(" ")" [function, total]
  rule #w3IOL()  => #w3read(w3Lending, 0) ==Int #w3read(w3Oracle, 0)
  rule #w3ILD()  => #w3read(w3Liq, 0) <=Int #w3read(w3Lending, 1)
  rule #w3IOLD() => ( #w3read(w3Liq, 1) ==Int #w3read(w3Lending, 0) )
                andBool ( #w3read(w3Lending, 0) ==Int #w3read(w3Oracle, 0) )

  // ---- contract bytecode (assembled by the REAL KEVM assembler) -------------
  syntax OpCodes ::= "#w3OracleCode"  [function, total]
  syntax OpCodes ::= "#w3LendingCode" [function, total]
  rule #w3OracleCode  => PUSH(1, 0) ; SLOAD ; PUSH(1, 0) ; MSTORE ; PUSH(1, 32) ; PUSH(1, 0) ; RETURN ; .OpCodes
  rule #w3LendingCode => PUSH(1, 0) ; SLOAD ; PUSH(1, 0) ; MSTORE ; PUSH(1, 32) ; PUSH(1, 0) ; RETURN ; .OpCodes

  // ---- program decomposition (mirrors driver.md's command sequencing) -------
  rule <k> C:EthereumSimulation REST:EthereumSimulation => C ~> REST ... </k> requires C =/=K #w3Nil
  rule <k> #w3Nil => .K ... </k>

  // ---- setup ----------------------------------------------------------------
  rule <k> #w3Setup => .K ... </k>
       <accounts>
         ( .Bag
        => <account>
             <acctID>           w3Oracle  </acctID>
             <balance>          0         </balance>
             <code>             #asmOpCodes(#w3OracleCode)  </code>
             <storage>          .Map      </storage>
             <origStorage>      .Map      </origStorage>
             <transientStorage> .Map      </transientStorage>
             <nonce>            0         </nonce>
           </account>
           <account>
             <acctID>           w3Lending </acctID>
             <balance>          0         </balance>
             <code>             #asmOpCodes(#w3LendingCode) </code>
             <storage>          .Map      </storage>
             <origStorage>      .Map      </origStorage>
             <transientStorage> .Map      </transientStorage>
             <nonce>            0         </nonce>
           </account>
           <account>
             <acctID>           w3Liq     </acctID>
             <balance>          0         </balance>
             <code>             .Bytes:AccountCode </code>
             <storage>          .Map      </storage>
             <origStorage>      .Map      </origStorage>
             <transientStorage> .Map      </transientStorage>
             <nonce>            0         </nonce>
           </account>
         )
         ...
       </accounts>

  // ---- mini-driver: REAL EVM execution of one segment -----------------------
  rule <k> #w3Run(A:Int, OPS:OpCodes)
        => #w3SetCtx(A, #asmOpCodes(OPS)) ~> #execute ... </k>

  rule <k> #w3SetCtx(A:Int, CODE:Bytes) => #loadProgram CODE ~> #initVM ... </k>
       <id>        _ => A       </id>
       <codeAddr>  _ => A       </codeAddr>
       <caller>    _ => A       </caller>
       <callData>  _ => .Bytes  </callData>
       <callValue> _ => 0       </callValue>

  // after a segment halts, clear #halt and continue with the next SRW3 command
  rule <k> #halt ~> (C:EthereumSimulation) => C ... </k>
  rule <k> #halt ~> #w3State(SG:Map, LN:Map, N:Int, H:Int)
        => #w3State(SG, LN, N, H) ... </k>

  // ---- threaded gate state --------------------------------------------------
  // initial snapshot: committed storages at bundle start, empty lineage
  rule <k> #w3Snap0 => #w3State(#w3allStorages(), .Map, 0, -1) ... </k>

  // thread the state past the next run (both continuation shapes)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int) ~> #w3Run(A:Int, OPS:OpCodes)
        => #w3Run(A, OPS) ~> #w3State(SG:Map, LN:Map, N:Int, H:Int) ... </k>
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
        ~> ( #w3Run(A:Int, OPS:OpCodes) REST:EthereumSimulation )
        => #w3Run(A, OPS) ~> #w3State(SG, LN, N, H) ~> REST ... </k>

  // hand the threaded committed state to the gate at the commitment point
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int) ~> #w3Gate0
        => #w3Gate(SG, LN, N, H) ... </k>
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
        ~> ( #w3Gate0 REST:EthereumSimulation )
        => #w3Gate(SG, LN, N, H) ~> REST ... </k>

  // ---- the commitment gate --------------------------------------------------
  // ACCEPT: all obligations hold on REAL prospective storage -> commit
  // (snapshot := post-storage) and append lineage (parent = head, child = next).
  rule <k> #w3Gate(SG:Map, LN:Map, N:Int, H:Int)
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))], N +Int 1, N)
           ... </k>
    requires #w3IOL() andBool #w3ILD() andBool #w3IOLD()

  // REJECT: restore committed storages; prospective effects discarded.
  rule <k> #w3Gate(SG:Map, LN:Map, N:Int, H:Int)
        => #w3RestoreAll(SG) ~> #w3State(SG, LN, N, H)
           ... </k>
    requires notBool ( #w3IOL() andBool #w3ILD() andBool #w3IOLD() )

  rule <k> #w3RestoreAll(S:Map)
        => #w3RestoreOne(S, w3Oracle) ~> #w3RestoreOne(S, w3Lending) ~> #w3RestoreOne(S, w3Liq) ... </k>

  rule <k> #w3RestoreOne(S:Map, A:Int) => .K ... </k>
       <account> <acctID> A </acctID> <storage> _WS => {S[A]}:>Map </storage> ... </account>
    requires A in_keys(S)

  rule <k> #w3RestoreOne(S:Map, A:Int) => .K ... </k>
       <account> <acctID> A </acctID> <storage> _WS => .Map </storage> ... </account>
    requires notBool A in_keys(S)

endmodule
