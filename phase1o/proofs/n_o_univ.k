// =============================================================================
// SRW3 PHASE 1O — THE MACHINE-FORM UNIVERSAL THEOREM ATTEMPTS
//                    (phase1o/proofs/n_o_univ.k)
//
// The 1N universal attempts (ABS-UNIV-STEP/-TAIL/ABS-PREFIX-SAFE) were
// stated in the FOLD form: ABSInv(absRunF(RUN, AX)) with RUN a symbolic
// APProg variable.  The 1O minimal reproducer (proofs/repro/univ-repro.k,
// probes R1-R7) located the boundary PRECISELY:
//
//   * a FOLD (function-position recursion) cannot dispatch on a symbolic
//     program variable — function equations MATCH, they do not branch
//     (R1 fails with the 1N residual signature; R4 isolates the general
//     no-function-argument-case-split behavior; R4b is the control);
//   * a MACHINE run (rewrite-position recursion over the <k> sequence)
//     DOES dispatch: the engine branches on the head constructor and the
//     [circularity] closes the symbolic tail (R2 PROVES non-trivially);
//   * the composition is SOUND-SENSITIVE: a command branch that breaks
//     the invariant makes the universal fail (R5, as required), and the
//     responded-domain restriction closes it (R6, non-trivially).
//
// The claims below restate the universal theorem in MACHINE form over the
// SAME frozen-1N M4 machine + additive abstract machine (NOTHING in the
// 1N semantics is modified):
//
//   1O-UNIV-MACHINE — for every abstract program RUN (symbolic!), every
//     state AX with ABSInv(AX) from which the machine responds to every
//     command (absExecutable), the machine's final state satisfies ABSInv.
//     [THE UNIVERSAL TRANSITION-PRESERVATION THEOREM — Layer C + D.]
//   1O-UNIV-PREFIX — the committed-prefix corollary in the same form.
//   1O-NEG-DEST    — destination-sanity control (MUST FAIL): the final
//     state is not always the genesis.
//
// The soundness control lives in n_o_univ_weak.k over the derived weak
// machine (scripts/make_abs_weak.py): there the universal MUST FAIL.
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine.k"

module O-UNIV-PROOFS
  imports SRW3N-ABS

  // ===========================================================================
  // 1O-UNIV-MACHINE — THE UNIVERSAL THEOREM, machine form.
  //     For all RUN:APProg (a fully symbolic program variable) and all
  //     AX:AState: if AX satisfies the abstract invariant and the machine
  //     responds to every command of RUN from the state reached so far
  //     (absExecutable — the responded-command domain, the 1N predicate
  //     reused verbatim), then the machine's final state satisfies ABSInv.
  //     The proof obligation covers: the empty run (the base), every
  //     command-constructor branch (the machine's own per-constructor
  //     rules — the same partition the 1N ABS-STEP claims pin), the
  //     bit-branch evaluation of absStepJ on the pinned state constructor,
  //     the stall-class pruning (exec on an unpinned shadow is excluded by
  //     absExecutable = false on that branch), and the symbolic-tail
  //     circularity.  EXPECTED: PROVED non-trivially (the toy predicts
  //     it); whatever happens is recorded.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AState => ?AX2:AState </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInv(AX) andBool absExecutable(RUN:APProg, AX:AState)
    ensures ABSInv(?AX2:AState)
    [circularity, label(1O-UNIV-MACHINE)]

  // ===========================================================================
  // 1O-UNIV-PREFIX — the committed-prefix corollary, machine form:
  //     an initialized invariant state, driven by any responded finite
  //     run, ends INITIALIZED with the safety bookkeeping held
  //     (absInitShaped — the abstract counterpart of the committed-prefix
  //     branch of JInvPlusJ).  EXPECTED: PROVED if 1O-UNIV-MACHINE is.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AState => ?AX2:AState </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInv(AX) andBool absCfgPinnedOf(AX)
         andBool absExecutable(RUN:APProg, AX:AState)
    ensures absInitShaped(?AX2:AState)
    [circularity, label(1O-UNIV-PREFIX)]

  // ===========================================================================
  // 1O-NEG-DEST — destination-sanity control (MUST FAIL): the universal's
  //     destination is not degenerate — the final state is NOT always the
  //     genesis (the honest pipeline moves; a proof here would mean the
  //     destination is vacuously matched).
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AState => ?AX2:AState </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInv(AX) andBool absExecutable(RUN:APProg, AX:AState)
    ensures ?AX2:AState ==K absGenesis
    [label(1O-NEG-DEST)]

endmodule
