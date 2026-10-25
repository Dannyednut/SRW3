// Phase 1S probe J definition: StateRel variants for conjunct bisection.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "rel-machine.k"

module SRW3N-REL-PROBE-J
  imports SRW3N-ABS-QS
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

  // variant 3: V1 + the tag RANGE only
  syntax Bool ::= StateRelV3 ( AStateQ , AStateQE ) [function, total]
  rule StateRelV3(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount,
                         N:Int, SF:Bool, D:ADiag),
                  absStQE(C2:Bool, T2:Bool, G2:Int, E2:Int, N2:Int,
                          SF2:Bool, D2:ADiag))
    => C2 ==Bool C  andBool T2 ==Bool T
       andBool N2 ==Int N
       andBool SF2 ==Bool SF
       andBool D2 ==K D
       andBool CountRel(G, G2) andBool CountRel(E, E2)
       andBool TG >=Int 0 andBool TG <=Int 1

endmodule
