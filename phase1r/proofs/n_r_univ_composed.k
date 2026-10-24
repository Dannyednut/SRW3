// =============================================================================
// SRW3 PHASE 1R — EXPERIMENT C: THE FOLD DECOMPOSITION (the
//                    initialized/uninitialized split and the composition)
//                    (phase1r/proofs/n_r_univ_composed.k)
//
// The architecture under test (spec/fold-decomposition.md §3):
//
//   1R-UNIV-TAG1-Q      the tag-1-pinned UNIVERSAL invariant theorem —
//                       PREFIX-Q's big sibling (same start-state pins as
//                       the 1Q form of record: the tag pinned by ==Int 1
//                       AND the cfg Bool pinned by ==K true — the 1Q
//                       unsound-closure lesson: a non-constraining Bool
//                       accessor alone is NOT a pin); the conclusion is
//                       the full invariant, not the destination shape.
//   1R-UNIV-TAG0-Q      the tag-0-pinned universal: every executable step
//                       from a coherent pre-init state is an
//                       identity/diagnostic row until the init-accept —
//                       the ONLY re-tag — whose successor is the FULLY
//                       CONCRETE absStQ(1,true,true,zeroP,zeroP,0,true,D);
//                       the post-init tail is governed by the PROVED
//                       1R-UNIV-TAG1-Q (passed via kprove --trusted; the
//                       trust boundary: TAG1's own proof log).
//   1R-UNIV-COMPOSED-Q  the UNPINNED universal with both pinned universals
//                       in scope (--trusted): the start branch splits at
//                       the first unrolling (the rows pattern the tag
//                       literal), and each branch is an instance of a
//                       pinned lemma — the mission's "state-branch
//                       decomposition with an explicit
//                       transition-to-initialized-suffix argument".
//
// The fold-form exhibits (the composition's negative space):
//   1R-FOLD-FORM-OPEN-Q   the function-form universal WITHOUT circularity:
//                         the expected residual IS the missing induction
//                         hypothesis (structural induction over APProg),
//                         recorded as the diagnosis.
//   1R-NEG-FOLD-SELF-Q    the SAME statement WITH [circularity]: the
//                         self-application trap — it closes with ZERO
//                         unrolling (the 1Q-UNIV-PREFIX-UNPATCHED hole, at
//                         the universal's own level). Classified
//                         SELF-ASSUMED-NOT-A-PROOF; NEVER a proof; never
//                         cited as the theorem. This is the mechanical
//                         answer to "why not just state the fold form":
//                         on this toolchain the fold-form circularity
//                         assumes exactly what it must prove.
//
// Trust discipline: TAG1 and TAG0 are proved FIRST (own claims, own logs);
// the trusted uses are disclosed per claim in claims/claims.csv. No claim
// here assumes its own conclusion except the DELIBERATE negative exhibit.
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1q/semantics/abs-machine-q.k"

module R-COMPOSE-PROOFS
  imports SRW3N-ABS-Q

  // ===========================================================================
  // 1R-UNIV-TAG1-Q — the tag-1-pinned universal invariant theorem
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absCfgPinnedQ(AX) ==K true
         andBool absTagOfQ(AX) ==Int 1
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1R-UNIV-TAG1-Q)]

  // ===========================================================================
  // 1R-UNIV-TAG0-SYMB-Q — the DIAGNOSTIC tag-0 attempt (symbolic pools):
  //   the expected failure records WHY the plain tag-0 pin does not close:
  //   ABSInvQ's tag-0 conjunct (isZeroP(G) andBool isZeroP(E)) is UNDECIDABLE
  //   on symbolic pool variables, so the circular axiom's side condition
  //   ABSInvQ(successor) cannot evaluate at any tag-0 step (every tag-0 row
  //   preserves the pool variables) — the engine unrolls without bound.
  //   Recorded as the diagnosis; NEVER the theorem.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absTagOfQ(AX) ==Int 0
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1R-UNIV-TAG0-SYMB-Q)]

  // ===========================================================================
  // 1R-UNIV-TAG0-NF-Q — THE TAG-0 FRAGMENT UNIVERSAL (normal form).
  //
  // DISCLOSED NORMAL-FORM STEP (the composition's meta-content): ABSInvQ at
  // tag 0 is a conjunction of field equalities — (notBool C andBool notBool T
  // andBool isZeroP(G) andBool isZeroP(E) andBool N ==Int 0) — so EVERY
  // tag-0 invariant state is EXACTLY absStQ(0,false,false,zeroP,zeroP,0,SF,D)
  // for some SF:Bool, D:ADiag (isZeroP(G)=true forces G=zeroP by the two
  // isZeroP equations; likewise E; the remaining conjuncts are literal
  // equalities). The claim below states the tag-0 fragment over that normal
  // form: the LHS state is the fragment's canonical shape (SF, D symbolic —
  // the invariant leaves both free at tag 0). The implication
  // "ABSInvQ(s) andBool absTagOfQ(s)==Int 0  =>  s matches the normal form"
  // is immediate by inspection of the conjunctive definition and is
  // RECORDED AS A DISCLOSED META-STEP (not a mechanized checker claim — the
  // case analysis over a symbolic state is exactly the function-argument
  // split this toolchain lacks; see 1R-UNIV-COMPOSED-Q's residual).
  //
  // The init-accept is the ONLY re-tag (the tag-0 rows are the eight ground
  // command shapes; exec has NO tag-0 row — its owise stall branch is killed
  // by the executable requires, exactly as the domain predicate declares).
  // The init-accept's successor is the FULLY CONCRETE
  // absStQ(1,true,true,zeroP,zeroP,0,true,D); the post-init tail is
  // governed by the PROVED 1R-UNIV-TAG1-Q (passed via kprove --trusted —
  // the trust boundary is TAG1's own proof log).
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, D:ADiag) => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg,
                absStQ(0, false, false, zeroP, zeroP, 0, SF:Bool, D:ADiag))
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1R-UNIV-TAG0-NF-Q)]

  // ===========================================================================
  // 1R-UNIV-COMPOSED-Q — the UNPINNED single-claim universal (both pinned
  //   universals in scope as proved lemmas). THE EXPECTED DIAGNOSTIC: the
  //   start state is symbolic, so the tag-0 branches carry symbolic pools
  //   whose invariant conjuncts are undecidable at the circular side
  //   conditions (the TAG0-SYMB failure, now inside the composed claim), and
  //   the fragment join would need a DISJUNCTIVE start-state constraint —
  //   the exact form the 1O record shows this checker cannot evaluate. The
  //   residual (or the timeout) IS the recorded boundary between the
  //   two-fragment decomposition and the single-claim form.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1R-UNIV-COMPOSED-Q)]

  // ===========================================================================
  // 1R-FOLD-FORM-OPEN-Q — the fold-form universal, NO circularity: the
  //                       expected residual IS the missing structural
  //                       induction over APProg (the diagnosis of record).
  // ===========================================================================
  claim
    <k> ( ( ABSInvQ(AX:AStateQ)
            andBool absExecutableQ(R:APProg, AX:AStateQ) )
          impliesBool ABSInvQ(absRunFQ(R:APProg, AX:AStateQ)) )
        => true </k>
    [label(1R-FOLD-FORM-OPEN-Q)]

  // ===========================================================================
  // 1R-NEG-FOLD-SELF-Q — the self-application trap (MUST be classified
  //                      SELF-ASSUMED-NOT-A-PROOF; NEVER a proof).
  // ===========================================================================
  claim
    <k> ( ( ABSInvQ(AX:AStateQ)
            andBool absExecutableQ(R:APProg, AX:AStateQ) )
          impliesBool ABSInvQ(absRunFQ(R:APProg, AX:AStateQ)) )
        => true </k>
    [circularity, label(1R-NEG-FOLD-SELF-Q)]

endmodule
