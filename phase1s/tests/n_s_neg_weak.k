// =============================================================================
// SRW3 PHASE 1S — THE WEAK-MACHINE NEGATIVE CONTROL (mission §7; the 1R
//                    weak battery adapted to the 1S image terms)
//                    (phase1s/tests/n_s_neg_weak.k)
//
// The weak machine (phase1q/semantics/abs-machine-weak-q.k — the 1Q weak
// variant whose commit class accepts the (aOkT,aOkF) shape with safe=false)
// is the invariant-violation control of record. In the 1S terms: the weak
// breaking step's IMAGE violates the integer safety predicate ABSInvE —
// the weak machine's unsafe accept is unsafe on BOTH models. MUST FAIL.
// (The machine-level universal MUST-FAIL regression is the 1R battery's
// 1Q-NEG-WEAK-UNIV-Q, retained there; this file adds the 1S-image witness.)
// Self-contained: requires ONLY the weak machine (sorts would collide with
// the strong machine's in one module).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1q/semantics/abs-machine-weak-q.k"

module S-NEG-WEAK-PROOFS
  imports SRW3N-ABS-WEAK-Q

  // ===========================================================================
  // 1S-NEG-WEAK-IMAGE-UNSAFE (MUST FAIL): the weak breaking accept (the
  //   (aOkT,aOkF) commit from both pools nonempty) lands safe=false, so
  //   the integer invariant on its image is FALSE (the tag-1 SF conjunct).
  //   The strong machine rejects this shape (row D-SS identity) — the
  //   invariant is load-bearing on BOTH models.
  // ===========================================================================
  claim <k> ABSInvE(eraseQ(absStepWQ(absStQ(1, true, true, succP(zeroP), succP(zeroP),
                                            0, true, adNone),
                                     aCommitJ(aOkT, aOkF)))) => true </k>
    [label(1S-NEG-WEAK-IMAGE-UNSAFE)]

  // ===========================================================================
  // 1S-NEG-WEAK-UNIV-Q (MUST FAIL — the 1R regression re-run in the 1S
  //   ledger): the universal invariant-preservation over the WEAK machine.
  //   Its failure is the machine-level witness that the strong machine's
  //   guard structure (the C2/C3 content) is load-bearing for the
  //   universal — the migration inherits the strong machine, never the
  //   weak one.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool absExecutableQW(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1S-NEG-WEAK-UNIV-Q)]

endmodule
