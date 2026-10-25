// Phase 1S probe G: chain-member reflexivity semantics.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../semantics/rel-machine.k"

module PROBE-G-PROOFS
  imports SRW3N-REL-S

  // ==Bool as an andBool chain member
  claim <k> SF:Bool ==Bool SF:Bool andBool true => true </k>
    [label(PROBE-G-BOOLCHAIN)]

  // ==Int as an andBool chain member
  claim <k> countToInt(G:PoolCount) ==Int countToInt(G:PoolCount) andBool true => true </k>
    [label(PROBE-G-INTCHAIN)]

  // ==K as an andBool chain member
  claim <k> D:ADiag ==K D:ADiag andBool true => true </k>
    [label(PROBE-G-KCHAIN)]

endmodule
