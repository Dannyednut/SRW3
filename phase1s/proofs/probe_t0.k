// Phase 1S probe C: isolate the T0 image-lemma stuck leaf.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../semantics/rel-machine.k"

module PROBE-C-PROOFS
  imports SRW3N-REL-S

  // fully concrete tag-0 image
  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, 0, false, adNone),
                     qToQE(absStQ(0, false, false, zeroP, zeroP, 0, false, adNone)))
        => true </k>
    [label(PROBE-T0-CONCRETE)]

  // symbolic pools tag-0 image
  claim <k> StateRel(absStQ(0, false, false, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag),
                     qToQE(absStQ(0, false, false, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag)))
        => true </k>
    [label(PROBE-T0-SYMBOLIC)]

  // the CountRel reflexivity spot alone
  claim <k> CountRel(G:PoolCount, countToInt(G:PoolCount)) => true </k>
    [label(PROBE-COUNTREL-REFLEX)]

endmodule
