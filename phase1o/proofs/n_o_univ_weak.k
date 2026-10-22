// =============================================================================
// SRW3 PHASE 1O — THE WEAK-MACHINE SOUNDNESS CONTROL (MUST FAIL)
//                    (phase1o/proofs/n_o_univ_weak.k)
//
// The SAME machine-form universal claim, stated over the derived WEAK
// machine (abs-machine-weak.k; scripts/make_abs_weak.py — the K port of
// the 1N Python S4 control: the accept-commit carries the PRESENTED bit).
// The ground run [init-accept, exec-mint, gate-mint, commit(aOkT,aOkF)]
// ends at absSt(true,true,0,0,1,false,adNone) — ABSInv FALSE — so this
// claim MUST FAIL.  If it closes, the real machine's proof is
// guard-insensitive (the stutter-artifact hazard) and CANNOT be
// presented as a universal-theorem proof.  Level III only.
// =============================================================================

requires "../semantics/abs-machine-weak.k"

module O-UNIV-WEAK-PROOFS
  imports SRW3N-ABS-WEAK

  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AState => ?AX2:AState </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInv(AX) andBool absExecutable(RUN:APProg, AX:AState)
    ensures ABSInv(?AX2:AState)
    [circularity, label(1O-NEG-WEAK-UNIV)]

endmodule
