// =============================================================================
// SRW3 PHASE 1O — THE MINIMAL REPRODUCER OF THE UNIVERSAL-PROOF OBSTACLE
//                    (mandate §6.4: phase1o/proofs/repro/univ-repro.k)
//
// A stall-free toy model with the SAME shape as the 1N abstract machine:
//   * a state constructor St with one Int field,
//   * a two-constructor command language Cmd,
//   * a TOTAL step function (no stall classes — the purest form),
//   * a decidable invariant invS,
//   * a fold runF mirroring absRunF, and machine rules mirroring the
//     <absjshadow> runner.
//
// Four probes (R1-R4) isolate the exact kprove behavior:
//   R1  the 1N fold formulation over a SYMBOLIC program  -> expect the 1N
//       residual (the fold cannot dispatch on a symbolic list variable);
//   R2  the machine formulation over a symbolic program  -> tests whether
//       kprove branches on the list constructor at the <k> head;
//   R3  the machine formulation over a cons-pinned head with a SYMBOLIC
//       tail -> tests circularity self-application;
//   R4  a function argument with a symbolic constructor variable -> tests
//       whether kprove case-splits constructor variables in function
//       argument position (the state-side question).
//
// Whatever the raw results, they are recorded and never relabeled.
// =============================================================================
//
// To run (from the repo root, after the toolchain env):
//   kompile phase1o/proofs/repro/univ-repro.k --backend haskell \
//     --main-module UNIV-REPRO -o /tmp/univ-repro
//   kprove phase1o/proofs/repro/univ-repro.k -d /tmp/univ-repro \
//     --spec-module UNIV-REPRO-PROOFS --claims <CLAIM>
//
// The runner phase1o/proofs/repro/run_univ_repro.sh executes all probes
// and retains raw logs under phase1o/transcripts/k/repro/.

module UNIV-REPRO
  imports INT
  imports BOOL

  // ---- the toy state, command, invariant, step (total, no stall) --------
  syntax St ::= st ( Int )
  syntax Cmd ::= "inc" | "noop" | "bad" | "dec2"

  syntax Bool ::= invS ( St ) [function, total]
  rule invS(st(I:Int)) => I >=Int 0

  syntax St ::= step ( St , Cmd ) [function, total]
  rule step(st(I:Int), inc)  => st(I +Int 1)
  rule step(st(I:Int), noop) => st(I)
  rule step(st(I:Int), bad)  => st(I -Int 1)  requires I >=Int 1
  rule step(st(I:Int), bad)  => st(0)         [owise]   // bad at 0 saturates
  rule step(st(I:Int), dec2) => st(I -Int 2)

  // ---- the program datatype and the fold (the 1N absRunF mirror) --------
  syntax L ::= "nilL" | consL ( Cmd , L )
  syntax Int ::= lenF ( L ) [function, total]
  rule lenF(nilL) => 0
  rule lenF(consL(_:Cmd, R:L)) => 1 +Int lenF(R)

  syntax St ::= runF ( L , St ) [function, total]
  rule runF(nilL, S:St) => S
  rule runF(consL(C:Cmd, R:L), S:St) => runF(R, step(S, C))

  // ---- the machine runner (the <absjshadow> mirror) ----------------------
  //      configuration: <k> program </k> <s> state </s>
  configuration
    <univrepro>
      <k> $PGM:L </k>
      <s> st(0):St </s>
    </univrepro>

  rule <k> consL(C:Cmd, R:L) => C ~> R ... </k>
  rule <k> nilL => .K ... </k>
  rule <k> inc => .K ... </k>  <s> S:St => step(S, inc) </s>
  rule <k> noop => .K ... </k> <s> S:St => step(S, noop) </s>
  rule <k> bad => .K ... </k>  <s> S:St => step(S, bad) </s>
  rule <k> dec2 => .K ... </k> <s> S:St => step(S, dec2) </s>

  // R9/R10's function-dispatched runner over its OWN universe PrgF (the
  // exact shape of the 1N machine rules: one rule consumes the head and
  // the shadow update goes through the FUNCTION step with the
  // possibly-symbolic head command).  R2/R3/R6 are scoped to Prg (the
  // rewrite-dispatched universe) so each probe's quantifier is exact.
  syntax Prg ::= "nilP" | consP ( Cmd , Prg )
  rule <k> consP(C:Cmd, R:Prg) => C ~> R ... </k>
  rule <k> nilP => .K ... </k>

  syntax PrgF ::= "nilPF" | consF ( Cmd , PrgF )
  rule <k> consF(C:Cmd, R:PrgF) => R ... </k> <s> S:St => step(S, C) </s>
  rule <k> nilPF => .K ... </k> <s> S:St => S </s>

  // R4's probe function (syntax lives in the base module, not proofs)
  syntax Int ::= f(Cmd) [function, total]
  rule f(inc)  => 1
  rule f(noop) => 0

  // the responded-domain predicate for R6/R10 (the absExecutable mirror)
  syntax Bool ::= okRun ( Prg ) [function, total]
  rule okRun(nilP) => true
  rule okRun(consP(inc, R:Prg))  => okRun(R)
  rule okRun(consP(noop, R:Prg)) => okRun(R)
  rule okRun(consP(C:Cmd, R:Prg)) => false [owise]

  syntax Bool ::= okRunF ( PrgF ) [function, total]
  rule okRunF(nilPF) => true
  rule okRunF(consF(inc, R:PrgF))  => okRunF(R)
  rule okRunF(consF(noop, R:PrgF)) => okRunF(R)
  rule okRunF(consF(C:Cmd, R:PrgF)) => false [owise]

endmodule

module UNIV-REPRO-PROOFS
  imports UNIV-REPRO

  // ===========================================================================
  // R1 — the 1N fold formulation (the ABS-UNIV-STEP shape, minimized):
  //      invS(runF(L, st(I))) holds for every L, given invS at the start.
  //      Expected obstruction: runF cannot dispatch on a symbolic L.
  // ===========================================================================
  claim
    <k> invS(runF(L:L, st(I:Int))) => true </k>
    requires I >=Int 0
    [circularity, label(R1-UNIV-FOLD)]

  // ===========================================================================
  // R2 — the machine formulation over a SYMBOLIC program: the run consumes
  //      the program step by step; the final state satisfies the invariant.
  //      Tests whether kprove branches on the list constructor at the <k>
  //      head (nilL vs consL) and whether the circularity closes the tail.
  // ===========================================================================
  claim
    <k> P:Prg => .K ... </k>
    <s> S:St => ?S2:St </s>
    requires invS(S:St)
    ensures invS(?S2:St)
    [circularity, label(R2-UNIV-MACHINE)]

  // ===========================================================================
  // R3 — the cons-pinned head with a SYMBOLIC tail: after one step the goal
  //      is <k> R:L </k>, an instance of R2's LHS — if the circularity pool
  //      carries R2 (or R3 re-applies), the tail closes.  Tests circularity
  //      self-application in isolation.
  // ===========================================================================
  claim
    <k> consP(C:Cmd, R:Prg) => .K ... </k>
    <s> S:St => ?S2:St </s>
    requires invS(S:St) andBool okRun(consP(C:Cmd, R:Prg))
    ensures invS(?S2:St)
    [circularity, label(R3-UNIV-CONS)]

  // ===========================================================================
  // R4 — the function-argument case-split probe: does kprove split a
  //      symbolic constructor variable in FUNCTION ARGUMENT position?
  //      f(C:Cmd) is 1 on inc and 0 on noop; the claim f(C) >=Int 0 holds
  //      iff the prover case-splits C.  If it closes, constructor splitting
  //      happens (somewhere); if it fails, the boundary is in matching.
  // ===========================================================================
  claim
    <k> f(C:Cmd) >=Int 0 => true </k>
    [label(R4-CMD-SPLIT)]

  // R4b — the evaluation control: the same function over a CONSTRUCTOR
  //      argument must close by evaluation (if R4b passes and R4 fails,
  //      the boundary is exactly the symbolic-constructor variable).
  claim
    <k> (I >=Int 0 impliesBool invS(st(I:Int))) => true </k>
    [label(R4B-EVAL-CONTROL)]

  // ===========================================================================
  // R5 — THE SOUNDNESS PROBE (must FAIL): dec2 breaks the invariant
  //      (I-2 < 0 when I < 2), so the universal machine claim must NOT
  //      close.  If it closes, the engine stuttered the symbolic command
  //      via an [owise]-style artifact and the machine-form approach is
  //      UNSOUND for bit-discriminating machines.
  // ===========================================================================
  claim
    <k> L:L => .K ... </k>
    <s> S:St => ?S2:St </s>
    requires invS(S:St)
    ensures invS(?S2:St)
    [circularity, label(R5-SOUNDNESS-MUST-FAIL)]

  // ===========================================================================
  // R6 — the domain-restricted universal (must PROVE): the same universal
  //      with the run restricted to inc/noop — the responded-command
  //      discipline mirrored (bad/dec2 excluded by a decidable domain
  //      predicate over the program).
  // ===========================================================================
  claim
    <k> P:Prg => .K ... </k>
    <s> S:St => ?S2:St </s>
    requires invS(S:St) andBool okRun(P:Prg)
    ensures invS(?S2:St)
    [circularity, label(R6-DOMAIN-RESTRICTED)]

  // R7 — the domain predicate's own completeness control (must PROVE by
  //      evaluation over constructors): okRun(consL(bad, nilL)) == false.
  claim
    <k> okRun(consP(bad, nilP)) => false </k>
    [label(R7-DOMAIN-CONTROL)]

  // ===========================================================================
  // R9 — the function-dispatched runner with a SYMBOLIC head command
  //      (the absStepJ shape), unrestricted: MUST FAIL (dec2 is reachable
  //      and breaks the invariant).  If it closes, the engine stuttered
  //      the symbolic command — unsound.
  // ===========================================================================
  claim
    <k> P:PrgF => .K ... </k>
    <s> S:St => ?S2:St </s>
    requires invS(S:St)
    ensures invS(?S2:St)
    [circularity, label(R9-FUNC-DISPATCH-MUST-FAIL)]

  // ===========================================================================
  // R10 — the SAME function-dispatched runner, okRun-restricted (must
  //      PROVE iff the engine case-splits a symbolic function argument
  //      when the domain predicate can prune): each command branch binds
  //      C to a constructor, okRun evaluates by matching, bad/dec2 are
  //      pruned, inc/noop evaluate genuinely.
  // ===========================================================================
  claim
    <k> P:PrgF => .K ... </k>
    <s> S:St => ?S2:St </s>
    requires invS(S:St) andBool okRunF(P:PrgF)
    ensures invS(?S2:St)
    [circularity, label(R10-FUNC-DISPATCH-DOMAIN)]

endmodule
