// =============================================================================
// SRW3 PHASE 1O — THE WEAK-R SOUNDNESS CONTROL (MUST FAIL)
//                    (phase1o/proofs/n_o_univ_weak_r.k)
//
// The machine-form universal over the WEAK + R machine: the weak accept
// carries the PRESENTED bit (the make_abs_weak.py edit) AND the runner is
// the rewrite-dispatched R form (the make_abs_r.py edit — composed here by
// make_abs_weak_r.py).  Because the R runner dispatches on the 12 GROUND
// command shapes, the weak accept branch is GENUINELY evaluated: the ground
// run [init-accept, exec-mint, gate-mint, commit(aOkT,aOkF)] ends at
// absSt(true,true,0,0,1,false,adNone) with ABSInv FALSE, so this claim
// MUST FAIL.  Its failure is the soundness witness for the R architecture:
// the R universal's proof (if it had closed) would have been guard-sensitive.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-weak-r.k"

module O-UNIV-WEAK-R-PROOFS
  imports SRW3N-ABS-WEAK-R

  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AState => ?AX2:AState </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInv(AX) andBool absExecutable(RUN:APProg, AX:AState)
    ensures ABSInv(?AX2:AState)
    [circularity, label(1O-NEG-WEAK-UNIV-R)]

endmodule
