// Phase 1S probe J: bisect the StateRel rule conjuncts.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../semantics/rel-machine.k"

module PROBE-J-PROOFS
  imports SRW3N-REL-S

  // variant 1: the field equalities + CountRel ONLY (no tag conjuncts)
  syntax Bool ::= StateRelV1 ( AStateQ , AStateQE ) [function, total]
  rule StateRelV1(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount,
                         N:Int, SF:Bool, D:ADiag),
                  absStQE(C2:Bool, T2:Bool, G2:Int, E2:Int, N2:Int,
                          SF2:Bool, D2:ADiag))
    => C2 ==Bool C  andBool T2 ==Bool T
       andBool N2 ==Int N
       andBool SF2 ==Bool SF
       andBool D2 ==K D
       andBool CountRel(G, G2) andBool CountRel(E, E2)

  // variant 2: the tag conjuncts ONLY
  syntax Bool ::= StateRelV2 ( AStateQ , AStateQE ) [function, total]
  rule StateRelV2(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount,
                         N:Int, SF:Bool, D:ADiag),
                  absStQE(C2:Bool, T2:Bool, G2:Int, E2:Int, N2:Int,
                          SF2:Bool, D2:ADiag))
    => TG >=Int 0 andBool TG <=Int 1
       andBool (TG ==Int 1 impliesBool (C  andBool T ))
       andBool (TG ==Int 0 impliesBool (notBool C andBool notBool T))
       andBool (TG ==Int 1 impliesBool (C2 andBool T2))
       andBool (TG ==Int 0 impliesBool (notBool C2 andBool notBool T2))

  claim <k> StateRelV1(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                       absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-J-V1)]

  claim <k> StateRelV2(absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, adNone),
                       absStQE(false, false, 0, 0, 0, SF:Bool, adNone)) => true </k>
    [label(PROBE-J-V2)]

endmodule
