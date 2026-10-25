// =============================================================================
// SRW3 PHASE 1S — the negative-control definitions (the mutant functions of
//                    record: the STALE count map and the TAG-BREAK step)
//                    (phase1s/tests/n_s_neg_defs.k)
//
// CONFINED to tests/: these definitions exist ONLY to be broken. The stale
// map (mission §7: 过期/错误计数映射) forgets the outermost successor; the
// tag-break step re-tags the init-accept to 0. Neither is imported by any
// of-record battery.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/rel-machine.k"

module SRW3N-NEG-DEFS-S
  imports SRW3N-REL-S

  // ---- the STALE count map: every successor reads as its inner count ----
  syntax Int ::= countToIntStale ( PoolCount ) [function, total]
  rule countToIntStale(zeroP) => 0
  rule countToIntStale(succP(P:PoolCount)) => countToIntStale(P)

  syntax AStateQE ::= eraseQStale ( AStateQ ) [function, total]
  rule eraseQStale(absStQ(_:Int, C:Bool, T:Bool, G:PoolCount, E:PoolCount,
                          N:Int, SF:Bool, D:ADiag))
    => absStQE(C, T, countToIntStale(G), countToIntStale(E), N, SF, D)

  // ---- the TAG-BREAK step: the init-accept re-tags to 0 ----
  syntax AStateQ ::= absStepQBroken ( AStateQ , ACmd ) [function, total]
  rule absStepQBroken(absStQ(0, false, false, _:PoolCount, _:PoolCount, _:Int,
                             _:Bool, D:ADiag),
                      aInitJ(aOkT))
    => absStQ(0, true, true, zeroP, zeroP, 0, true, D)   // BROKEN: re-tag to 0

endmodule
