// =============================================================================
// SRW3 Phase 1B — generalized binding extension (ADDITIVE; srw3-kevm.k is
// NOT modified — the Phase-1A binding stays frozen as recorded).
//
// Purpose: demonstrate that the two Phase-1B countermodel obligation classes
// compose with REAL KEVM execution through the EXISTING commitment-gate
// architecture (prospective effects -> obligation evaluation -> commit /
// reject+restore). No new gate mechanism: the generalized gate #w3GateG has
// the SAME shape as the base #w3Gate — ONE evaluated conjunction over the
// applicable obligations, with the same threaded state carrier and the same
// restore machinery.
//
// Obligation classes over REAL prospective EVM storage:
//   #w3IAliasG (CM2 alias shape)  : the two delegate accounts' slot-3
//        storages mirror ONE logical resource (distinct physical keys
//        (4098,3) != (4099,3), shared logical identity) — they must agree.
//   #w3IAggG   (CM3 aggregate)    : the delegates' slot-2 consumption sum
//        must stay within the root account's slot-2 budget.
//   (the base Phase-0 obligations #w3IOL/#w3ILD/#w3IOLD remain in force.)
// Slot discipline: slots 0/1 carry the base price/liquidation demo data
// (obligations unchanged); slots 2/3 carry the generalized classes so the
// two obligation generations compose without interfering.
// =============================================================================

requires "evm.md"
requires "asm.md"
requires "srw3-kevm.k"

module SRW3-GEN-EVM
  imports EVM
  imports EVM-ASSEMBLY
  imports SRW3-EVM

  // generalized-gate threading command (demo marker, mirrors #w3Gate0)
  syntax EthereumSimulation ::= "#w3Gate1"

  syntax KItem ::= "#w3GateG" "(" s:Map "," ln:Map "," n:Int "," h:Int ")"

  // ---- generalized obligation classes (evaluated, like every other) --------
  syntax Bool ::= "#w3IAliasG" "(" ")" [function, total]
  syntax Bool ::= "#w3IAggG"   "(" ")" [function, total]
  syntax Bool ::= "#w3OblG"    "(" ")" [function, total]

  rule #w3IAliasG() => #w3read(w3Lending, 3) ==Int #w3read(w3Liq, 3)
  rule #w3IAggG()   => #w3read(w3Lending, 2) +Int #w3read(w3Liq, 2)
                    <=Int #w3read(w3Oracle, 2)
  rule #w3OblG()    => #w3IOL() andBool #w3ILD() andBool #w3IOLD()
                    andBool #w3IAliasG() andBool #w3IAggG()

  // ---- threading (mirrors the #w3Gate0 rules) -------------------------------
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int) ~> #w3Gate1
        => #w3GateG(SG, LN, N, H) ... </k>
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
        ~> ( #w3Gate1 REST:EthereumSimulation )
        => #w3GateG(SG, LN, N, H) ~> REST ... </k>

  // ---- ACCEPT: extended conjunction holds on REAL prospective storage ------
  rule <k> #w3GateG(SG:Map, LN:Map, N:Int, H:Int)
        => #w3State(#w3allStorages(),
                    LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
        ... </k>
    requires #w3OblG()

  // ---- REJECT: restore committed storages (same restore machinery) ---------
  rule <k> #w3GateG(SG:Map, LN:Map, N:Int, H:Int)
        => #w3RestoreAll(SG) ~> #w3State(SG, LN, N, H)
        ... </k>
    requires notBool #w3OblG()

endmodule
