// Phase 1S probe J spec: the bisection claims.

requires "../semantics/probe-j-def.k"

module PROBE-J2-PROOFS
  imports SRW3N-REL-PROBE-J

  claim <k> StateRelV1(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                       absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-J-V1)]

  claim <k> StateRelV2(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                       absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-J-V2)]

  claim <k> StateRelV3(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                       absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-J-V3)]

endmodule
