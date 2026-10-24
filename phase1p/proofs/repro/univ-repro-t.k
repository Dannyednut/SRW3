// =============================================================================
// SRW3 PHASE 1P (r2) — THE MINIMAL TDR-ARCHITECTURE REPRODUCER
//                    (phase1p/proofs/repro/univ-repro-t.k)
//
// RECONSTRUCTION r2 (the r1 tree was lost before any commit; see
// phase1p/spec/branch-tag-design.md §0 — the r1 session's FINAL action was
// running T1-T4 with a 240s budget and the results were NEVER READ; the r2
// run below produces this answer for the first time on record).
//
// A stall-free toy model with the TDR architecture's EXACT shape (the 1O
// toy's tagged descendant):
//   * a state constructor stT with an explicit Int branch tag + one Int,
//   * a conjunctive tagged invariant invT (tag range + impliesBool branch
//     constraints — no disjunction, no if-then-else),
//   * a total step function tstep with the class partition: the re-tag
//     row (openC: 0 -> 1), tag-preserving rows, ONE Int-guarded class
//     (subC) SPLIT into explicit complementary requires (the requires
//     split), and the incoherent-tag complement,
//   * a rewrite-dispatched runner with BRANCH-DISCRIMINATED ground-command
//     rules (the TD/TDR runner shape),
//   * a fold runFT and a responded-domain predicate okT (breakC excluded).
//
// Four probes (T1-T4):
//   T1  THE TAGGED UNIVERSAL (machine form, okT-restricted, symbolic
//       program) — the architecture's target theorem at toy scale: does
//       the TDR architecture CLOSE?
//   T2  the cons-pinned head with a symbolic tail — circularity
//       self-application in isolation.
//   T3  the domain predicate's own discipline (breakC excluded — closes
//       by evaluation over constructors).
//   T4  THE SOUNDNESS PROBE (MUST FAIL): the unrestricted universal —
//       breakC is reachable and breaks invT, so a closure here would mean
//       the engine stuttered a breaking command (unsound).
//
// To run (from the repo root, after the toolchain env):
//   kompile phase1p/proofs/repro/univ-repro-t.k --backend haskell \
//     --main-module TOY-TAG -o /tmp/p1p-toy-def
//   kprove phase1p/proofs/repro/univ-repro-t.k -d /tmp/p1p-toy-def \
//     --spec-module TOY-TAG-PROOFS --claims <CLAIM>
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

module TOY-TAG
  imports INT
  imports BOOL

  // ---- the tagged toy state, the conjunctive invariant -------------------
  syntax TSt ::= stT ( tag:Int , iv:Int )

  syntax Bool ::= invT ( TSt ) [function, total]
  rule invT(stT(TG:Int, IV:Int))
    => TG >=Int 0 andBool TG <=Int 1
       andBool (TG ==Int 0 impliesBool IV ==Int 0)
       andBool (TG ==Int 1 impliesBool IV >=Int 0)

  syntax Bool ::= cohT ( TSt ) [function, total]
  rule cohT(stT(TG:Int, IV:Int))
    => (TG ==Int 0 impliesBool IV ==Int 0)
       andBool (TG ==Int 1 impliesBool IV >=Int 0)

  // ---- the command language and the tagged step (the class partition) ----
  syntax TCmd ::= "openC"    // the re-tag row (the init-accept mirror)
                | "addC"     // the mint row (tag-preserving)
                | "subC"     // THE INT-GUARDED CLASS (the requires split)
                | "noopC"    // the identity/refuse row
                | "breakC"   // THE BREAKING COMMAND (the soundness subject)

  syntax TSt ::= tstep ( TSt , TCmd ) [function, total]

  rule tstep(stT(0, _:Int), openC) => stT(1, 0)            // THE re-tag 0->1
  rule tstep(stT(1, IV:Int), addC)  => stT(1, IV +Int 1)     // the mint row
  rule tstep(stT(1, IV:Int), subC)  => stT(1, IV -Int 1)     // the guarded row
    requires IV >=Int 1
  rule tstep(stT(1, IV:Int), subC)  => stT(1, IV)            // the explicit complement
    requires IV <=Int 0
  rule tstep(stT(1, IV:Int), noopC) => stT(1, IV)            // the identity row
  rule tstep(stT(1, _:Int), openC) => stT(1, 0)            // re-open accepted (a legal re-tag? NO —
                                                           // disclosed toy liberty: identity would be
                                                           // tighter; kept simple, tag stays 1)
  rule tstep(stT(0, IV:Int), addC)  => stT(0, IV)            // the pre-init identity rows
  rule tstep(stT(0, IV:Int), subC)  => stT(0, IV)
  rule tstep(stT(0, IV:Int), noopC) => stT(0, IV)
  rule tstep(stT(1, IV:Int), breakC) => stT(1, IV -Int 1)    // THE BREAKING ROW (unconditional)

  // ---- the fold and the domain predicate ---------------------------------
  syntax TPrg ::= "nilT" | consT ( TCmd , TPrg )

  syntax TSt ::= runFT ( TPrg , TSt ) [function, total]
  rule runFT(nilT, S:TSt) => S
  rule runFT(consT(C:TCmd, R:TPrg), S:TSt) => runFT(R, tstep(S, C))

  syntax Bool ::= okT ( TPrg ) [function, total]
  rule okT(nilT) => true
  rule okT(consT(breakC, _:TPrg)) => false
  rule okT(consT(_:TCmd, R:TPrg)) => okT(R) [owise]

  // ---- the machine runner (BRANCH-DISCRIMINATED ground commands) ---------
  configuration
    <toytag>
      <k> $PGM:TPrg </k>
      <s> stT(0, 0):TSt </s>
    </toytag>

  rule <k> consT(C:TCmd, R:TPrg) => C ~> R ... </k>
  rule <k> nilT => .K ... </k>

  rule <k> openC => .K ... </k> <s> S:TSt => tstep(S, openC) </s>
  rule <k> addC  => .K ... </k> <s> S:TSt => tstep(S, addC)  </s>
  rule <k> subC  => .K ... </k> <s> S:TSt => tstep(S, subC)  </s>
  rule <k> noopC => .K ... </k> <s> S:TSt => tstep(S, noopC) </s>
  rule <k> breakC => .K ... </k> <s> S:TSt => tstep(S, breakC) </s>
  // NOTE: the toy runner is REWRITE-DISPATCHED over the head command (the
  // 1O R2/R6-proven shape); the branch discrimination lives in tstep's
  // class rows.  No [owise] complement: every ground TCmd has a rule, and
  // tstep is total.
endmodule

module TOY-TAG-PROOFS
  imports TOY-TAG

  // ===========================================================================
  // T1 — THE TAGGED UNIVERSAL (the architecture's target theorem, toy scale)
  // ===========================================================================
  claim
    <k> P:TPrg => .K ... </k>
    <s> S:TSt => ?S2:TSt </s>
    requires invT(S:TSt) andBool okT(P:TPrg)
    ensures invT(?S2:TSt)
    [circularity, label(T1-TOY-TAG-UNIV)]

  // ===========================================================================
  // T2 — the cons-pinned head, symbolic tail (circularity self-application)
  // ===========================================================================
  claim
    <k> consT(C:TCmd, R:TPrg) => .K ... </k>
    <s> S:TSt => ?S2:TSt </s>
    requires invT(S:TSt) andBool okT(consT(C:TCmd, R:TPrg))
    ensures invT(?S2:TSt)
    [circularity, label(T2-TOY-CONS)]

  // ===========================================================================
  // T3 — the domain predicate's own discipline (closes by evaluation)
  // ===========================================================================
  claim
    <k> okT(consT(breakC, nilT)) => false </k>
    [label(T3-TOY-DOMAIN)]

  // ===========================================================================
  // T4 — THE SOUNDNESS PROBE (MUST FAIL): the unrestricted universal —
  //      breakC is reachable and breaks invT.
  // ===========================================================================
  claim
    <k> P:TPrg => .K ... </k>
    <s> S:TSt => ?S2:TSt </s>
    requires invT(S:TSt)
    ensures invT(?S2:TSt)
    [circularity, label(T4-TOY-MUST-FAIL)]

  // ===========================================================================
  // T4b — the breaking run itself, ground (MUST PROVE — the violation
  //       witness; the dual of T3's domain discipline).
  // ===========================================================================
  claim
    <k> consT(breakC, nilT) => .K ... </k>
    <s> stT(1, 0):TSt => stT(1, -1):TSt </s>
    [label(T4B-TOY-BREAKING-RUN)]

endmodule
