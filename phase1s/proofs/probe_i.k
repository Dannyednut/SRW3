// Phase 1S probe I: reveal the SF binding direction in StateRel.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../semantics/rel-machine.k"

module PROBE-I-PROOFS
  imports SRW3N-REL-S

  // first-SF symbolic, mirror-SF concrete true (honestly FALSE relation)
  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                     absStQE(false, false, 0, 0, 0, true, adNone))
        => true </k>
    [label(PROBE-I-FIRST-SYMB)]

endmodule
