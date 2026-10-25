// Phase 1S probe D: bisect the T0-symbolic stuck leaf.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../semantics/rel-machine.k"

module PROBE-D-PROOFS
  imports SRW3N-REL-S

  // (a) pools symbolic only
  claim <k> StateRel(absStQ(0, false, false, G:PoolCount, E:PoolCount, 0, false, adNone),
                     qToQE(absStQ(0, false, false, G:PoolCount, E:PoolCount, 0, false, adNone)))
        => true </k>
    [label(PROBE-D-POOLS)]

  // (b) slot/flag/diag symbolic only
  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag),
                     qToQE(absStQ(0, false, false, zeroP, zeroP, N:Int, SF:Bool, D:ADiag)))
        => true </k>
    [label(PROBE-D-FIELDS)]

  // (b1) SF reflexivity alone
  claim <k> SF:Bool ==Bool SF:Bool => true </k>
    [label(PROBE-D-SFREFLEX)]

  // (b2) diag K-reflexivity alone
  claim <k> D:ADiag ==K D:ADiag => true </k>
    [label(PROBE-D-DREFLEX)]

endmodule
