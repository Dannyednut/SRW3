// =============================================================================
// SRW3 Phase 1C — Cryptographic commitment lineage (k/phase1c/srw3ck.k)
//
// Minimal faithful instance of the Phase-1B commitment-gate architecture in
// which lineage commitments are REAL keccak256 hashes (Part IV) and the gate
// VERIFIES the presented commitment by recomputation:
//
//   * a transition declares its post-write and PRESENTS the new head H:Bytes
//   * the gate accepts iff (ICK-PRESENT) H equals the recomputed
//     H(head, slot, v) of the single pending declared write, AND
//     (ICK-CHAIN) the whole existing lineage re-derives record-by-record
//   * accept: committed := prospective, lineage append with the real hash
//     pair (parent=head, child=H); reject: prospective discarded (restore)
//
// Hash encoding: H(p, slot, v) = Keccak256raw(p || slot_4BE || v_4BE);
// the root commitment is 32 zero bytes. Keccak-256 is Ethereum's (0x01
// padding), provided by the Phase-1C krypto shim on the LLVM backend.
//
// Backend note: the Haskell backend has no KRYPTO evaluators (finding 1C-1);
// these demos run on LLVM + krypto shim.
// =============================================================================

requires "krypto.md"

module SRW3CK
  imports KRYPTO
  imports DOMAINS
  imports BYTES

  // ---- syntax ---------------------------------------------------------------
  syntax CkCmd ::= "ckInit" "(" slot:Int "," v:Int ")"
                 | "ckBegin"
                 | "ckW" "(" slot:Int "," v:Int ")"
                 | "ckGate" "(" h:Bytes ")"
  syntax CkPgm ::= List{CkCmd,","}

  syntax CkLin ::= "cklin" "(" parent:Bytes "," tid:Int "," slot:Int "," v:Int "," child:Bytes ")"

  // ---- configuration (shape mirrors srw3gen.k; single-app instance) ---------
  configuration <srw3ck>
                  <k> $PGM:CkPgm </k>
                  <committed> .Map </committed>    // Map slot -> value
                  <prospective> .Map </prospective>
                  <pend> .Map </pend>              // pending declared writes (==1 at gate)
                  <lineage> .Map </lineage>        // Map tid -> CkLin
                  <lineageNext> 0 </lineageNext>
                  <head> CkRoot </head>            // 32-byte head commitment
                  <result> "" </result>
                </srw3ck>

  // ---- hex input helper (pure K; avoids 0x literal non-syntax) ---------------
  syntax Bytes ::= "CkHex" "(" String ")" [function]
                 | "CkHexAux" "(" String ")" [function]
  syntax String ::= "CkHexAlign" "(" String ")" [function]

  rule CkHex(S:String)      => CkHexAux(CkHexAlign(S))
  rule CkHexAlign(S:String)     => S             requires         lengthString(S) modInt 2 ==Int 0
  rule CkHexAlign(S:String)     => "0" +String S requires notBool lengthString(S) modInt 2 ==Int 0
  rule CkHexAux("")  => .Bytes
  rule CkHexAux(S:String)   => Int2Bytes(lengthString(S) /Int 2, String2Base(S, 16), BE)
    requires lengthString(S) >=Int 2

  // ---- hash helpers ----------------------------------------------------------
  syntax Bytes ::= "CkRoot" [function]
  rule CkRoot => Int2Bytes(32, 0, BE)

  syntax Bytes ::= "CkHash" "(" Bytes "," Int "," Int ")" [function]
  rule CkHash(P:Bytes, S:Int, V:Int)
    => Keccak256raw(P +Bytes Int2Bytes(4, S, BE) +Bytes Int2Bytes(4, V, BE))

  // ---- lineage accessors (explicit recursion; Phase-0 discipline) ------------
  syntax Bytes ::= "ckLinParent" "(" CkLin ")" [function]
  rule ckLinParent(cklin(P:Bytes, _:Int, _:Int, _:Int, _:Bytes)) => P

  syntax Int ::= "ckLinSlot" "(" CkLin ")" [function]
  rule ckLinSlot(cklin(_:Bytes, _:Int, S:Int, _:Int, _:Bytes)) => S

  syntax Int ::= "ckLinVal" "(" CkLin ")" [function]
  rule ckLinVal(cklin(_:Bytes, _:Int, _:Int, V:Int, _:Bytes)) => V

  syntax Bytes ::= "ckLinChild" "(" CkLin ")" [function]
  rule ckLinChild(cklin(_:Bytes, _:Int, _:Int, _:Int, C:Bytes)) => C

  syntax CkLin ::= "ckLinAt" "(" Map "," Int ")" [function, total]
  rule ckLinAt(N:Int |-> CL:CkLin REST:Map, N:Int) => CL
  rule ckLinAt(N:Int |-> _:CkLin REST:Map, M:Int) => ckLinAt(REST, M) requires N =/=K M
  rule ckLinAt(.Map, _:Int) => cklin(Int2Bytes(32, 1, BE), -1, -1, -1, Int2Bytes(32, 1, BE)) // sentinel

  // ---- ICK-CHAIN: re-derive the whole lineage from the root ------------------
  syntax Bool ::= "CkChainOk" "(" Map "," Int "," Bytes ")" [function, total]

  rule CkChainOk(L:Map, N:Int, EXPECTED:Bytes)
    => ckLinParent(ckLinAt(L, N)) ==K EXPECTED
       andBool ckLinChild(ckLinAt(L, N)) ==K CkHash(EXPECTED, ckLinSlot(ckLinAt(L, N)), ckLinVal(ckLinAt(L, N)))
       andBool CkChainOk(L, N +Int 1, CkHash(EXPECTED, ckLinSlot(ckLinAt(L, N)), ckLinVal(ckLinAt(L, N))))
    requires N in_keys(L)
  rule CkChainOk(L:Map, N:Int, _:Bytes) => true
    requires notBool N in_keys(L)
  rule CkChainOk(.Map, _:Int, _:Bytes) => true

  // ---- pending-write accessors (exactly one declared write per transition) ---
  syntax Int ::= "CkPendSlot" "(" Map ")" [function, total]
  rule CkPendSlot(S:Int |-> _:Int .Map) => S
  rule CkPendSlot(_:Map) => -1 [owise]

  syntax Int ::= "CkPendVal" "(" Map ")" [function, total]
  rule CkPendVal(_S:Int |-> V:Int .Map) => V
  rule CkPendVal(_:Map) => 0 [owise]

  // ---- gate decision function (ICK-PRESENT + ICK-CHAIN), total ---------------
  syntax Bool ::= "CkGateOk" "(" Map "," Bytes "," Bytes "," Map ")" [function, total]
  rule CkGateOk(Q:Map, H:Bytes, HEADB:Bytes, L:Map)
    => H ==K CkHash(HEADB, CkPendSlot(Q), CkPendVal(Q))
       andBool CkChainOk(L, 0, CkRoot)
    requires sizeMap(Q) ==Int 1
  rule CkGateOk(_:Map, _:Bytes, _:Bytes, _:Map) => false [owise]

  // ---- transition commands ---------------------------------------------------
  rule <k> (C:CkCmd , REST:CkPgm) => C ~> REST ... </k>

  rule <k> ckInit(S:Int, V:Int) => .K ... </k>
       <committed> M:Map => M[S <- V] </committed>

  rule <k> ckBegin => .K ... </k>
       <committed> C:Map </committed>
       <prospective> _:Map => C </prospective>
       <pend> _:Map => .Map </pend>

  rule <k> ckW(S:Int, V:Int) => .K ... </k>
       <prospective> P:Map => P[S <- V] </prospective>
       <pend> Q:Map => Q[S <- V] </pend>

  // ---- gate: ACCEPT (only rule that updates committed/head/lineage) ----------
  rule <k> ckGate(H:Bytes) => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <committed> _:Map => P </committed>
       <pend> Q:Map => .Map </pend>
       <lineage> L:Map => L[N:Int <- cklin(HEADB:Bytes, N:Int, CkPendSlot(Q), CkPendVal(Q), H:Bytes)] </lineage>
       <lineageNext> N:Int => N +Int 1 </lineageNext>
       <head> HEADB:Bytes => H:Bytes </head>
       <result> _:String => "commit" </result>
    requires CkGateOk(Q:Map, H:Bytes, HEADB:Bytes, L:Map)

  // ---- gate: REJECT (restore) — commitment boundary ---------------------------
  rule <k> ckGate(H:Bytes) => .K ... </k>
       <prospective> _:Map => .Map </prospective>
       <pend> Q:Map => .Map </pend>
       <lineage> L:Map </lineage>
       <head> HEADB:Bytes </head>
       <result> _:String => "reject" </result>
    requires notBool CkGateOk(Q:Map, H:Bytes, HEADB:Bytes, L:Map)

endmodule
