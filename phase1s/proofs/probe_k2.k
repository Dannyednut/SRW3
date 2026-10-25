// Phase 1S probe K spec.

requires "../semantics/probe-k-def.k"

module PROBE-K2-PROOFS
  imports SRW3N-REL-PROBE-K

  claim <k> ChkA(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
               absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-K-ChkA)]

  claim <k> ChkB(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
               absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-K-ChkB)]

  claim <k> ChkC(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
               absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-K-ChkC)]

  claim <k> ChkD(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
               absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-K-ChkD)]

  claim <k> ChkE(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
               absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-K-ChkE)]

endmodule
