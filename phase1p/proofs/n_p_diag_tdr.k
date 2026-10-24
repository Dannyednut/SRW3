// =============================================================================
// SRW3 PHASE 1P (r2) — THE NIL/CONS BUDGET DIAGNOSTICS OVER THE TDR MACHINE
//                    (phase1p/proofs/n_p_diag_tdr.k)
//
// RECONSTRUCTION r2 (the r1 tree was lost before any commit; see
// phase1p/spec/branch-tag-design.md §0).
//
// The universal's proof obligation decomposes over the program structure:
//   NIL  — the base case alone (the destination is the start state; the
//          claim closes by evaluation of the fold and the hypothesis);
//   CONS — one unfold plus the circularity self-application (the tail is
//          symbolic).  Where the TDR budget goes, this pair says: if NIL
//          closes and CONS burns the budget, the cost is the one-step
//          unfold's branch tree + z3 work, not the base case.
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-tdr.k"

module P-DIAG-TDR
  imports SRW3N-ABS-TDR

  claim // 1P-UNIV-NIL-TDR (MUST PROVE): the base case alone.
    <srw3closureJ>
      <k> aRunNilJ => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absExecutableT(aRunNilJ, AX:AStateT)
    ensures ABSInvT(?AX2:AStateT)
    [label(1P-UNIV-NIL-TDR)]

  claim // 1P-UNIV-CONS-TDR (ATTEMPT — the budget diagnostic): one unfold +
        // circularity over a cons-pinned symbolic head and tail.
    <srw3closureJ>
      <k> aConsJ(AC:ACmd, R:APProg) => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absExecutableT(aConsJ(AC:ACmd, R:APProg), AX:AStateT)
    ensures ABSInvT(?AX2:AStateT)
    [circularity, label(1P-UNIV-CONS-TDR)]

endmodule
