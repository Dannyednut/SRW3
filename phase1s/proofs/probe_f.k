// Phase 1S probe F: direct-mirror StateRel (no qToQE) + conjunct bisection.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../semantics/rel-machine.k"

module PROBE-F-PROOFS
  imports SRW3N-REL-S

  // direct mirror argument, SF symbolic
  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                     absStQE(false, false, 0, 0, 0, SF:Bool, adNone))
        => true </k>
    [label(PROBE-F-DIRECT)]

  // qToQE again for comparison
  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                     qToQE(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone)))
        => true </k>
    [label(PROBE-F-VIA-QTOQE)]

endmodule
