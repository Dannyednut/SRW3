// Phase 1S probe H: the manual conjunction (the exact StateRel bindings at
// the tag-0 direct-mirror case) + the StateRel-with-pinned-SF control.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../semantics/rel-machine.k"

module PROBE-H-PROOFS
  imports SRW3N-REL-S

  claim <k> (false ==Bool false) andBool (false ==Bool false) andBool (0 ==Int 0)
         andBool (SF:Bool ==Bool SF:Bool) andBool (adNone ==K adNone)
         andBool CountRel(zeroP, 0) andBool CountRel(zeroP, 0)
         andBool (0 >=Int 0) andBool (0 <=Int 1)
         andBool (0 ==Int 1 impliesBool (false andBool false))
         andBool (0 ==Int 0 impliesBool (notBool false andBool notBool false))
         andBool (0 ==Int 1 impliesBool (false andBool false))
         andBool (0 ==Int 0 impliesBool (notBool false andBool notBool false))
         => true </k>
    [label(PROBE-H-MANUAL)]

  claim <k> StateRel(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                     absStQE(false, false, 0, 0, 0, SF:Bool, adNone))
        => true </k>
        requires SF:Bool ==Bool true
    [label(PROBE-H-SFPINNED)]

endmodule
