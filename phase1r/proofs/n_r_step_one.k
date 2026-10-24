// =============================================================================
// SRW3 PHASE 1R — EXPERIMENT B: THE EXPLICIT ONE-STEP PRESERVATION THEOREM
//                    (phase1r/proofs/n_r_step_one.k)
//
// The target (mission §6), machine form over the 1Q constructor-count
// model:
//
//   ∀ s, c, s'. Safe_Q(s) ∧ Executable_Q(cons(c, ·), s) ∧ Step_Q(s,c,s')
//               → Safe_Q(s')
//
// stated as ONE reachability claim with the head command SYMBOLIC and the
// state symbolic under ABSInvQ — NO circularity, ONE unrolling. Coverage:
// the runner's branch rows (8 ground command shapes × the tag-0/tag-1
// families, gate/commit forked on the 2×2 pool-head grid) PLUS the [owise]
// complement are all part of the explored relation; a terminal with zero
// residual (#Top) means every branch closed. Exhaustiveness is NOT taken
// from the generator's row count alone: the [owise] complement is IN the
// rewrite system, so any uncovered case surfaces as an explored identity
// branch — which still must preserve the invariant to close; and the
// generator's 8-cell grid check is re-run as the structural witness
// (phase1r/scripts/verify_grid_1r.py output in the audit).
//
// WARNING (mission §6, kept explicit): one-step preservation alone proves
// NOTHING about arbitrary program folds. The composition argument is
// Experiment C's separate obligation.
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1q/semantics/abs-machine-q.k"

module R-STEP-PROOFS
  imports SRW3N-ABS-Q

  claim // 1R-STEP-ONE-Q: THE ONE-STEP PRESERVATION THEOREM (all commands,
        // both branch families, the fork, the complement).
    <srw3closureJ>
      <k> aConsJ(AC:ACmd, R:APProg) => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absExecutableQ(aConsJ(AC:ACmd, R:APProg), AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [label(1R-STEP-ONE-Q)]

endmodule
