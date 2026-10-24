// =============================================================================
// SRW3 PHASE 1Q — THE WEAK-MACHINE SOUNDNESS BATTERY (over SRW3N-ABS-WEAK-Q:
//                    the presented-bit commit W1 + the Q-specific empty-pool
//                    accept W2).  (phase1q/proofs/n_q_neg_weak_q.k)
//
//   1Q-NEG-WEAK-UNIV-Q      the universal over the weak machine MUST FAIL
//                           (W1 lands safe=false — the invariant is
//                           load-bearing at the commit class; the K port of
//                           the 1P/Python S4 control);
//   1Q-WEAK-BREAKING-RUN-Q  the ground breaking run MUST PROVE (the unsafe
//                           accept is genuinely reachable, safe=false);
//   1Q-NEG-WEAK-INV-Q       the ground Bool form MUST FAIL (the violation
//                           witness at the definition level);
//   1Q-NEG-C3-WEAK-Q        the W2 empty-pool accept breaks the C2/C3
//                           CORRESPONDENCE (MUST FAIL — the erased weak
//                           accept is NOT the 1P step: the 1P machine
//                           rejects from empty pools).  This is the Q-
//                           specific witness that the Q invariant does NOT
//                           capture acceptance correctness — C3 is
//                           independent and load-bearing.
//   1Q-WEAK-EMPTY-ACCEPT-RUN-Q the W2 branch is genuinely reachable
//                           (MUST PROVE — the ground witness).
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-weak-q.k"

module Q-NEG-WEAK-PROOFS
  imports SRW3N-ABS-WEAK-Q

  claim // 1Q-NEG-WEAK-UNIV-Q (MUST FAIL)
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool absExecutableQW(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1Q-NEG-WEAK-UNIV-Q)]

  claim // 1Q-WEAK-BREAKING-RUN-Q (MUST PROVE): the honest prefix to the
        // weak commit lands on safe=false.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkF:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisQW => absStQ(1, true, true, zeroP, zeroP, 1, false, adNone):AStateQ </absjshadow>
      ...
    </srw3closureJ>
    [label(1Q-WEAK-BREAKING-RUN-Q)]

  claim // 1Q-NEG-WEAK-INV-Q (MUST FAIL): the strong invariant is FALSE
        // after the weak breaking step (the ground violation witness).
    <k> ABSInvQ(absStepWQ(absStQ(1, true, true, succP(zeroP), succP(zeroP), 0, true, adNone),
                          aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    [label(1Q-NEG-WEAK-INV-Q)]

  // DISCLOSURE (r2 of this file): the first draft of 1Q-NEG-C3-WEAK-Q
  // stated the correspondence at the (zeroP,zeroP)+(aOkT,aOkT) shape — but
  // that shape ALSO matches the carried reject row A-Z*, so the claim
  // closed VACUOUSLY through the reject branch (log
  // kprove_1Q-NEG-C3-WEAK-Q.log, rc=0 — retained as the recorded lesson).
  // The witness below pins the W2 RESULT ITSELF (concrete): the erasure of
  // the empty-pool accept diverges from the 1P step (which rejects, keeping
  // N=0).  1Q-WEAK-EMPTY-ACCEPT-RUN-Q witnesses that the W2 branch is
  // genuinely reachable through the runner.
  claim // 1Q-NEG-C3-WEAK-Q (MUST FAIL): the W2 empty-pool accept's erasure
        // (N advanced to 1) is NOT the 1P integer step's result (row A
        // rejects, N stays 0).  A closure here would mean the empty-pool
        // accept is correspondence-faithful — it is not.
    <k> ( absStQE(true, true, 0, 0, 1, true, adNone)
        ==K absStepE(eraseQ(absStQ(1, true, true, zeroP, zeroP, 0, true, adNone)),
                     aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    [label(1Q-NEG-C3-WEAK-Q)]

  claim // 1Q-WEAK-W2-STEP-EVAL-Q (MUST PROVE — the definition-level W2
        // witness): the weak step function ITSELF accepts from the empty
        // pools and advances the slot counter (the W2 row fires; the
        // carried identity branch also matches and diverges — the claim
        // closes through the W2 branch, which is exactly the existential
        // content: the weak machine CAN accept from empty).
    <k> absStepWQ(absStQ(1, true, true, zeroP, zeroP, 0, true, adNone),
                  aCommitJ(aOkT:AOk, aOkT:AOk))
        => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone) </k>
    [label(1Q-WEAK-W2-STEP-EVAL-Q)]

  claim // 1Q-WEAK-EMPTY-ACCEPT-RUN-Q (MUST PROVE): the empty-pool commit is
        // genuinely accepted on the weak machine (the W2 branch is
        // reachable through the runner; the identity branch diverges and
        // the engine closes the claim through the W2 branch).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)) => .K ... </k>
      <absjshadow> absGenesisQW => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone):AStateQ </absjshadow>
      ...
    </srw3closureJ>
    [label(1Q-WEAK-EMPTY-ACCEPT-RUN-Q)]

endmodule
