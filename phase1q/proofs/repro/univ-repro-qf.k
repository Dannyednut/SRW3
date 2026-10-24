// =============================================================================
// SRW3 PHASE 1Q — THE MINIMAL CONSTRUCTOR-COUNT REPRODUCER (FORKED FORM —
//                    THE ARCHITECTURE OF RECORD)
//                    (phase1q/proofs/repro/univ-repro-qf.k)
//
// The DIRECT toy (univ-repro-q.k) with the runner replaced by the Q
// architecture: REWRITE-LEVEL CONSTRUCTOR DISCRIMINATION — the 1P TD/TDRR
// mechanism (branch-patterned ground-command rows) applied to the pools.
// Every other module byte (state, invariant, step, fold, domain, break)
// is the DIRECT toy's, so the two files differ ONLY in the runner — the
// experiment's independent variable stays isolated.
//
// The QF runner:
//   * tag-discriminated rows (the TD mechanism: tag-0 rows pattern
//     stQ(0, _); tag-1 rows pattern stQ(1, _)),
//   * THE CONSTRUCTOR FORK on the pool-discriminating command (subC):
//     the tag-1 rows are forked on the pool head — succP(IV) / zeroP —
//     at the <s> cell, a REWRITE position (the position 1O/1P proved the
//     checker discriminates).  Exhaustive by free-constructor totality;
//     NO requires anywhere.
//   * the [owise] complement covers the incoherent-tag fragment (the 1P
//     discipline).
//
// After a fork row matches, the term handed to tstepQ has a CONCRETE
// constructor head at the discriminating position, so function evaluation
// is direct matching.  Q1F is the architecture's target theorem at toy
// scale: if Q1F closes non-trivially (real rewriting through the fork)
// while the 1P T1 could not, the Phase 1P compound-guard obstruction is
// REMOVED AT TOY SCALE by the constructor encoding.
//
// Probes (the DIRECT toy's, relabeled F; identical statements):
//   Q1F  THE CONSTRUCTOR UNIVERSAL (forked runner) — the target.
//   Q2F  the cons-pinned head, symbolic tail.
//   Q3F  the domain predicate's own discipline (evaluation).
//   Q4F  THE SOUNDNESS PROBE (MUST FAIL): the unrestricted universal.
//   Q4FB the breaking run itself, ground (MUST PROVE).
//   Q5F  THE C1 DIAGNOSTIC (identical to Q5 — carried for same-file
//        comparability of the residual).
//
// To run (from the repo root, after the toolchain env):
//   kompile phase1q/proofs/repro/univ-repro-qf.k --backend haskell \
//     --main-module TOY-QF -o /tmp/p1q-toyf-def
//   kprove phase1q/proofs/repro/univ-repro-qf.k -d /tmp/p1q-toyf-def \
//     --spec-module TOY-QF-PROOFS --claims <CLAIM>
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

module TOY-QF
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

  // ---- the QF runner (REWRITE-LEVEL constructor discrimination) -----------
  configuration
    <toyq>
      <k> $PGM:TPrg </k>
      <s> stQ(0, zeroP):TStQ </s>
    </toyq>

  rule <k> consT(C:TCmd, R:TPrg) => C ~> R ... </k>
  rule <k> nilT => .K ... </k>

  // ---- the tag-0 rows (the TD tag discrimination) --------------------------
  rule <k> openC  => .K ... </k> <s> stQ(0, IV:PoolCount) => tstepQ(stQ(0, IV), openC)  </s>
  rule <k> addC   => .K ... </k> <s> stQ(0, IV:PoolCount) => tstepQ(stQ(0, IV), addC)   </s>
  rule <k> subC   => .K ... </k> <s> stQ(0, IV:PoolCount) => tstepQ(stQ(0, IV), subC)   </s>
  rule <k> noopC  => .K ... </k> <s> stQ(0, IV:PoolCount) => tstepQ(stQ(0, IV), noopC)  </s>
  rule <k> breakC => .K ... </k> <s> stQ(0, IV:PoolCount) => tstepQ(stQ(0, IV), breakC) </s>
  // ---- the tag-1 rows (non-discriminating commands keep variable pools) ----
  rule <k> openC  => .K ... </k> <s> stQ(1, IV:PoolCount) => tstepQ(stQ(1, IV), openC)  </s>
  rule <k> addC   => .K ... </k> <s> stQ(1, IV:PoolCount) => tstepQ(stQ(1, IV), addC)   </s>
  rule <k> noopC  => .K ... </k> <s> stQ(1, IV:PoolCount) => tstepQ(stQ(1, IV), noopC)  </s>
  rule <k> breakC => .K ... </k> <s> stQ(1, IV:PoolCount) => tstepQ(stQ(1, IV), breakC) </s>
  // ---- THE CONSTRUCTOR FORK (subC: the pool-discriminating command) --------
  //   Exhaustive over {zeroP, succP} at the <s> cell — a REWRITE position.
  //   No requires.  After a fork row matches, tstepQ evaluates directly.
  rule <k> subC => .K ... </k> <s> stQ(1, succP(IV:PoolCount)) => tstepQ(stQ(1, succP(IV)), subC) </s>
  rule <k> subC => .K ... </k> <s> stQ(1, zeroP)               => tstepQ(stQ(1, zeroP), subC)     </s>
  // ---- the incoherent-tag complement (the 1P discipline) -------------------
  rule <k> C:TCmd => .K ... </k> <s> S:TStQ => S </s> [owise]
  // NOTE: the fork rows hand tstepQ a term whose discriminating position
  // holds a CONCRETE constructor; the function's succP/zeroP rows match
  // directly.  The fork is exhaustive by free-constructor totality.
endmodule

module TOY-QF-PROOFS
  imports TOY-QF

  // ===========================================================================
  // Q1F — THE CONSTRUCTOR UNIVERSAL, FORKED form (the target theorem)
  // ===========================================================================
  claim
    <k> P:TPrg => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okQ(P:TPrg)
    ensures invQ(?S2:TStQ)
    [circularity, label(Q1F-TOY-UNIV-FORKED)]

  // ===========================================================================
  // Q2 — the cons-pinned head, symbolic tail (circularity self-application)
  // ===========================================================================
  claim
    <k> consT(C:TCmd, R:TPrg) => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okQ(consT(C:TCmd, R:TPrg))
    ensures invQ(?S2:TStQ)
    [circularity, label(Q2F-TOY-CONS)]

  // ===========================================================================
  // Q3 — the domain predicate's own discipline (closes by evaluation)
  // ===========================================================================
  claim
    <k> okQ(consT(breakC, nilT)) => false </k>
    [label(Q3F-TOY-DOMAIN)]

  // ===========================================================================
  // Q4 — THE SOUNDNESS PROBE (MUST FAIL): the unrestricted universal —
  //      breakC is reachable and breaks invQ (the pre-init forgery).
  // ===========================================================================
  claim
    <k> P:TPrg => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ)
    ensures invQ(?S2:TStQ)
    [circularity, label(Q4F-TOY-MUST-FAIL)]

  // ===========================================================================
  // Q4B — the breaking run itself, ground (MUST PROVE — the violation
  //       witness; the dual of Q3's domain discipline).
  // ===========================================================================
  claim
    <k> consT(breakC, nilT) => .K ... </k>
    <s> stQ(0, zeroP):TStQ => stQ(0, succP(zeroP)):TStQ </s>
    [label(Q4FB-TOY-BREAKING-RUN)]

  // ===========================================================================
  // Q5 — THE C1 DIAGNOSTIC: representation nonnegativity.  Expected shape
  //      per the 1N/1O/1P record: needs structural induction over the free
  //      constructor sort; if it sticks, the residual is the record and the
  //      obligation stays open (concrete-depth witnesses are the mechanized
  //      fragment, run from the lemmas module).
  // ===========================================================================
  claim
    <k> ctI(N:PoolCount) >=Int 0 => true </k>
    [label(Q5F-TOY-C1-NONNEG)]

endmodule
