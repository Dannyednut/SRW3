// =============================================================================
// SRW3 PHASE 1Q — THE MINIMAL CONSTRUCTOR-COUNT REPRODUCER (DIRECT FORM —
//                    the unforked diagnostic; the architecture of record is
//                    univ-repro-qf.k, the same toy with the runner fork)
//                    (phase1q/proofs/repro/univ-repro-q.k)
//
// The 1P toy (phase1p/proofs/repro/univ-repro-t.k) with the ONE independent
// variable of Phase 1Q applied: the Int counter becomes a free-constructor
// exact count.  Everything else mirrors the 1P toy shape claim-for-claim.
//
//   * a state constructor stQ with an explicit Int branch tag + one
//     PoolCount (zeroP | succP(_)) — the EXACT count, not occupancy,
//   * a conjunctive invariant invQ (tag range + the tag-0 constructor
//     equality; the 1P tag-1 `iv >=Int 0` conjunct has NO Q counterpart —
//     structural nonnegativity is a theorem of the representation (C1),
//     not invariant content; disclosed in spec/count-representation.md §3),
//   * a total step tstepQ with the class partition; THE INT-GUARDED CLASS
//     (subC, the 1P requires-split subject) becomes a CONSTRUCTOR-PATTERN
//     split: succP rows decrement (strip the successor), zeroP rows refuse,
//     NO requires on any pool anywhere,
//   * the disclosed toy liberty of the 1P toy carried over (re-open at
//     tag 1 resets the pool, tag stays 1),
//   * THE BREAK: the 1P toy broke via arithmetic underflow
//     (iv -Int 1 < 0), which the constructor encoding makes inexpressible
//     BY DESIGN; the Q break forges a receipt pre-init
//     (stQ(0, _) -> stQ(0, succP(_))), violating the tag-0 `iv ==K zeroP`
//     conjunct — the "bookkeeping says a receipt exists when it must not"
//     shape, at toy scale.  Disclosed deviation (spec §4).
//   * a DIRECT rewrite-dispatched runner (variable shadow patterns — the
//     1P toy shape): the diagnostic that asks whether the pinned engine
//     constructor-splits a FUNCTION-ARGUMENT pool variable on its own.
//     1O/1P predict NO (the function-argument boundary); the residual of
//     Q1/Q2 on THIS file is that prediction's 1Q test.
//
// Probes (Q1-Q5):
//   Q1  THE CONSTRUCTOR UNIVERSAL (machine form, okQ-restricted, symbolic
//       program) — the direct runner's answer: does the engine evaluate
//       tstepQ over a symbolic pool WITHOUT the fork?
//   Q2  the cons-pinned head with a symbolic tail — circularity
//       self-application in isolation (the 1P T2 analog).
//   Q3  the domain predicate's own discipline (breakC excluded — closes
//       by evaluation over constructors).
//   Q4  THE SOUNDNESS PROBE (MUST FAIL): the unrestricted universal —
//       breakC is reachable and breaks invQ (the pre-init forgery).
//   Q4B the breaking run itself, ground (MUST PROVE — the violation
//       witness; the dual of Q3).
//   Q5  THE C1 DIAGNOSTIC: countToInt(N:PoolCount) >=Int 0 — the
//       representation nonnegativity claim (expected: needs structural
//       induction; the residual IS the record).
//
// To run (from the repo root, after the toolchain env):
//   kompile phase1q/proofs/repro/univ-repro-q.k --backend haskell \
//     --main-module TOY-Q -o /tmp/p1q-toy-def
//   kprove phase1q/proofs/repro/univ-repro-q.k -d /tmp/p1q-toy-def \
//     --spec-module TOY-Q-PROOFS --claims <CLAIM>
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

module TOY-Q
  imports INT
  imports BOOL

  // ---- the free-constructor exact count ----------------------------------
  syntax PoolCount ::= "zeroP" [constructor]
  syntax PoolCount ::= succP(PoolCount) [constructor]

  syntax Bool ::= isZeroP ( PoolCount ) [function, total]
  rule isZeroP(zeroP) => true
  rule isZeroP(succP(_:PoolCount)) => false

  // ---- the erasure (the C1 subject at toy scale) --------------------------
  syntax Int ::= ctI ( PoolCount ) [function, total]
  rule ctI(zeroP) => 0
  rule ctI(succP(N:PoolCount)) => ctI(N) +Int 1

  // ---- the tagged toy state, the conjunctive invariant -------------------
  syntax TStQ ::= stQ ( tag:Int , iv:PoolCount )

  syntax Bool ::= invQ ( TStQ ) [function, total]
  rule invQ(stQ(TG:Int, IV:PoolCount))
    => TG >=Int 0 andBool TG <=Int 1
       andBool (TG ==Int 0 impliesBool isZeroP(IV))

  syntax Bool ::= cohQ ( TStQ ) [function, total]
  rule cohQ(stQ(TG:Int, IV:PoolCount))
    => (TG ==Int 0 impliesBool isZeroP(IV))

  // ---- the command language and the tagged step (the class partition) ----
  syntax TCmd ::= "openC"    // the re-tag row (the init-accept mirror)
                | "addC"     // the mint row (tag-preserving)
                | "subC"     // THE POOL-DISCRIMINATING CLASS (constructor split)
                | "noopC"    // the identity/refuse row
                | "breakC"   // THE BREAKING COMMAND (the soundness subject)

  syntax TStQ ::= tstepQ ( TStQ , TCmd ) [function, total]

  rule tstepQ(stQ(0, _:PoolCount), openC) => stQ(1, zeroP)  // THE re-tag 0->1
  rule tstepQ(stQ(1, IV:PoolCount), addC)  => stQ(1, succP(IV))  // the mint row
  rule tstepQ(stQ(1, succP(IV)), subC)     => stQ(1, IV)   // guarded: strip the successor
                                                           // (NO requires)
  rule tstepQ(stQ(1, zeroP), subC)         => stQ(1, zeroP) // the explicit complement
                                                           // (NO requires)
  rule tstepQ(stQ(1, IV:PoolCount), noopC) => stQ(1, IV)   // the identity row
  rule tstepQ(stQ(1, IV:PoolCount), openC) => stQ(1, zeroP) // re-open accepted (a legal re-tag? NO —
                                                           // disclosed toy liberty (the 1P toy's):
                                                           // identity would be tighter; kept
                                                           // simple, tag stays 1)
  rule tstepQ(stQ(0, IV:PoolCount), addC)  => stQ(0, IV)   // the pre-init identity rows
  rule tstepQ(stQ(0, IV:PoolCount), subC)  => stQ(0, IV)
  rule tstepQ(stQ(0, IV:PoolCount), noopC) => stQ(0, IV)
  rule tstepQ(stQ(TG:Int, IV:PoolCount), breakC) => stQ(TG, succP(IV))
                                                           // THE FORGER (unconditional):
                                                           // a receipt appears from nowhere;
                                                           // breaks invQ at tag 0.

  // ---- the fold and the domain predicate ---------------------------------
  syntax TPrg ::= "nilT" | consT ( TCmd , TPrg )

  syntax TStQ ::= runFQ ( TPrg , TStQ ) [function, total]
  rule runFQ(nilT, S:TStQ) => S
  rule runFQ(consT(C:TCmd, R:TPrg), S:TStQ) => runFQ(R, tstepQ(S, C))

  syntax Bool ::= okQ ( TPrg ) [function, total]
  rule okQ(nilT) => true
  rule okQ(consT(breakC, _:TPrg)) => false
  rule okQ(consT(_:TCmd, R:TPrg)) => okQ(R) [owise]

  // ---- the DIRECT runner (variable shadow patterns — the 1P toy shape) ----
  configuration
    <toyq>
      <k> $PGM:TPrg </k>
      <s> stQ(0, zeroP):TStQ </s>
    </toyq>

  rule <k> consT(C:TCmd, R:TPrg) => C ~> R ... </k>
  rule <k> nilT => .K ... </k>

  rule <k> openC => .K ... </k> <s> S:TStQ => tstepQ(S, openC) </s>
  rule <k> addC  => .K ... </k> <s> S:TStQ => tstepQ(S, addC)  </s>
  rule <k> subC  => .K ... </k> <s> S:TStQ => tstepQ(S, subC)  </s>
  rule <k> noopC => .K ... </k> <s> S:TStQ => tstepQ(S, noopC) </s>
  rule <k> breakC => .K ... </k> <s> S:TStQ => tstepQ(S, breakC) </s>
  // NOTE: the DIRECT runner passes the SYMBOLIC state into tstepQ.  The 1O
  // record predicts the engine cannot constructor-split the pool variable
  // inside the function argument; the Q1/Q2 residual on this file tests
  // that prediction for free constructors (the 1P residual was Int guards).
endmodule

module TOY-Q-PROOFS
  imports TOY-Q

  // ===========================================================================
  // Q1 — THE CONSTRUCTOR UNIVERSAL, DIRECT form (the diagnostic + target)
  // ===========================================================================
  claim
    <k> P:TPrg => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okQ(P:TPrg)
    ensures invQ(?S2:TStQ)
    [circularity, label(Q1-TOY-UNIV-DIRECT)]

  // ===========================================================================
  // Q2 — the cons-pinned head, symbolic tail (circularity self-application)
  // ===========================================================================
  claim
    <k> consT(C:TCmd, R:TPrg) => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okQ(consT(C:TCmd, R:TPrg))
    ensures invQ(?S2:TStQ)
    [circularity, label(Q2-TOY-CONS)]

  // ===========================================================================
  // Q3 — the domain predicate's own discipline (closes by evaluation)
  // ===========================================================================
  claim
    <k> okQ(consT(breakC, nilT)) => false </k>
    [label(Q3-TOY-DOMAIN)]

  // ===========================================================================
  // Q4 — THE SOUNDNESS PROBE (MUST FAIL): the unrestricted universal —
  //      breakC is reachable and breaks invQ (the pre-init forgery).
  // ===========================================================================
  claim
    <k> P:TPrg => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ)
    ensures invQ(?S2:TStQ)
    [circularity, label(Q4-TOY-MUST-FAIL)]

  // ===========================================================================
  // Q4B — the breaking run itself, ground (MUST PROVE — the violation
  //       witness; the dual of Q3's domain discipline).
  // ===========================================================================
  claim
    <k> consT(breakC, nilT) => .K ... </k>
    <s> stQ(0, zeroP):TStQ => stQ(0, succP(zeroP)):TStQ </s>
    [label(Q4B-TOY-BREAKING-RUN)]

  // ===========================================================================
  // Q5 — THE C1 DIAGNOSTIC: representation nonnegativity.  Expected shape
  //      per the 1N/1O/1P record: needs structural induction over the free
  //      constructor sort; if it sticks, the residual is the record and the
  //      obligation stays open (concrete-depth witnesses are the mechanized
  //      fragment, run from the lemmas module).
  // ===========================================================================
  claim
    <k> ctI(N:PoolCount) >=Int 0 => true </k>
    [label(Q5-TOY-C1-NONNEG)]

endmodule
