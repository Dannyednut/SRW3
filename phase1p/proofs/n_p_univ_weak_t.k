// =============================================================================
// SRW3 PHASE 1P (r2) — THE SOUNDNESS CONTROLS OVER THE WEAK-T MACHINE
//                    (the 1O weak-commit edit composed on the T rung)
//                    (phase1p/proofs/n_p_univ_weak_t.k)
//
// RECONSTRUCTION r2 (the r1 tree was lost before any commit; see
// phase1p/spec/branch-tag-design.md §0).
//
// The weak edit: aCommitJ(aOkT, B2) ACCEPTS with safe := B2 ==K aOkT (the
// presented bit carried).  On the strong machine the (aOkT,aOkF) shape is
// refused; on the weak machine it "succeeds" with safe=false — breaking
// ABSInvT.  The controls:
//   1P-NEG-WEAK-UNIV-T     the universal over the weak machine MUST FAIL
//                          (the guard is load-bearing at the tagged layer —
//                          the K port of the Python S4 control);
//   1P-WEAK-BREAKING-RUN-T the ground breaking run MUST PROVE (the unsafe
//                          accept is genuinely reachable, safe=false);
//   1P-NEG-WEAK-INV        the ground Bool form of the strong invariant
//                          over the weak breaking step MUST FAIL (the
//                          violation witness at the definition level).
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-weak-t.k"

module P-UNIV-WEAK-T-PROOFS
  imports SRW3N-ABS-WEAK-T

  claim // 1P-NEG-WEAK-UNIV-T (MUST FAIL): the weak machine does not
        // preserve the strong invariant — the (aOkT,aOkF) accept branch
        // lands outside ABSInvT.
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateT => ?AX2:AStateT </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvT(AX) andBool absExecutableT(RUN:APProg, AX:AStateT)
    ensures ABSInvT(?AX2:AStateT)
    [circularity, label(1P-NEG-WEAK-UNIV-T)]

  claim // 1P-WEAK-BREAKING-RUN-T (MUST PROVE): the ground breaking run
        // reaches the unsafe accept (safe=false) — the S4 control, K port.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkF:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisT => absStT(1, true, true, 0, 0, 1, false, adNone):AStateT </absjshadow>
      ...
    </srw3closureJ>
    [label(1P-WEAK-BREAKING-RUN-T)]

  claim // 1P-NEG-WEAK-INV (MUST FAIL): the strong invariant is FALSE after
        // the weak breaking step (the ground violation witness).
    <k> ABSInvT(absStepT(absStT(1, true, true, 1, 1, 0, true, adNone),
                         aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    [label(1P-NEG-WEAK-INV)]

endmodule
