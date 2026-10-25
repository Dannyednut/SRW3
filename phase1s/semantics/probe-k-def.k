// Phase 1S probe K definition: V1 conjunct-by-conjunct.

requires "../../phase1r/semantics/abs-machine-qs.k"
requires "rel-machine.k"

module SRW3N-REL-PROBE-K
  imports SRW3N-ABS-QS
  imports SRW3N-REL-S

  syntax Bool ::= ChkA ( AStateQ , AStateQE ) [function, total]
  rule ChkA(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag),
          absStQE(C2:Bool, T2:Bool, G2:Int, E2:Int, N2:Int, SF2:Bool, D2:ADiag))
    => C2 ==Bool C

  syntax Bool ::= ChkB ( AStateQ , AStateQE ) [function, total]
  rule ChkB(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag),
          absStQE(C2:Bool, T2:Bool, G2:Int, E2:Int, N2:Int, SF2:Bool, D2:ADiag))
    => SF2 ==Bool SF

  syntax Bool ::= ChkC ( AStateQ , AStateQE ) [function, total]
  rule ChkC(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag),
          absStQE(C2:Bool, T2:Bool, G2:Int, E2:Int, N2:Int, SF2:Bool, D2:ADiag))
    => D2 ==K D

  syntax Bool ::= ChkD ( AStateQ , AStateQE ) [function, total]
  rule ChkD(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag),
          absStQE(C2:Bool, T2:Bool, G2:Int, E2:Int, N2:Int, SF2:Bool, D2:ADiag))
    => C2 ==Bool C andBool SF2 ==Bool SF

  syntax Bool ::= ChkE ( AStateQ , AStateQE ) [function, total]
  rule ChkE(absStQ(TG:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount, N:Int, SF:Bool, D:ADiag),
          absStQE(C2:Bool, T2:Bool, G2:Int, E2:Int, N2:Int, SF2:Bool, D2:ADiag))
    => C2 ==Bool C andBool T2 ==Bool T andBool SF2 ==Bool SF

endmodule
