// Phase 1S probe E: finer bisect of the T0 fields case.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../semantics/rel-machine.k"

module PROBE-E-PROOFS
  imports SRW3N-REL-S

  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, N:Int, false, adNone),
                     qToQE(absStQ(0, false, false, zeroP, zeroP, N:Int, false, adNone)))
        => true </k>
    [label(PROBE-E-NONLY)]

  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                     qToQE(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone)))
        => true </k>
    [label(PROBE-E-SFONLY)]

  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, 0, false, D:ADiag),
                     qToQE(absStQ(0, false, false, zeroP, zeroP, 0, false, D:ADiag)))
        => true </k>
    [label(PROBE-E-DONLY)]

endmodule
