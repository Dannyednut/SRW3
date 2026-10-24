// =============================================================================
// SRW3 PHASE 1R — EXPERIMENT D (part 2): THE STALL ISOLATION TOY
//                    (phase1r/proofs/n_r_toy_stall.k)
//
// The 1R isolation ladder so far: the forked toy universal Q1F CLOSES; the
// state-THREADING predicate (okX: breakC excluded, the state threaded
// through tstepQ) CLOSES AT TOY SCALE (QT-UNIV-THREADED, 4s, non-trivial)
// — threading is NOT the missing-capability trigger.  The one structural
// phenomenon the 1Q machine has and the toy lacks: A COMMAND WITH NO STEP
// ROW AT THE CURRENT TAG (the machine's pre-init exec STALL: the runner's
// [owise] complement consumes it; the executable predicate marks the run
// non-executable).  This file adds EXACTLY that phenomenon to the toy:
//
//   stallC — no tstepQ row at tag 0 (the stall); an identity row at tag 1;
//   okX excludes runs whose head is stallC at a tag-0 state (the machine's
//          exec-at-tag-0 discipline, mirrored);
//   the runner has NO tag-0 stallC row (the [owise] complement covers —
//          the machine's exact stall shape).
//
//   QTS-UNIV          the universal with the threading+stall-exclusion
//                     predicate — THE ISOLATION RESULT (if the stall is
//                     the trigger, this does not terminate/close while
//                     QT-UNIV-THREADED does);
//   QTS-BOUND-1       the bounded control (the finite ladder must survive);
//   QTS-STALL-STEP    the ground stall step (consume; state unchanged —
//                     the [owise] behavior, made observable);
//   QTS-DOMAIN-FALSE  the domain discipline at tag 0 (evaluation).
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "n_r_toy_threaded.k"

module TOY-STALL
  imports TOY-THREADED

  syntax TCmd ::= "stallC"   // the pre-init stall command (the machine's
                             // exec-at-tag-0 mirror)

  // the step rows: tag-1 identity ONLY — NO tag-0 row (the stall)
  rule tstepQ(stQ(1, IV:PoolCount), stallC) => stQ(1, IV)

  // the threading predicate: the stall is executable ONLY at tag 1
  rule okX(consT(stallC, R:TPrg), stQ(0, _:PoolCount)) => false
  rule okX(consT(stallC, R:TPrg), S:TStQ) => okX(R, tstepQ(S, stallC)) [owise]

  // the runner: the tag-1 row only; at tag 0 the [owise] complement of
  // TOY-QF covers (consume; state unchanged) — the machine's stall shape
  rule <k> stallC => .K ... </k> <s> stQ(1, IV:PoolCount) => tstepQ(stQ(1, IV), stallC) </s>

endmodule

module TOY-STALL-PROOFS
  imports TOY-STALL

  claim // QTS-UNIV: the universal over the stall toy (THE ISOLATION RESULT).
    <k> P:TPrg => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okX(P:TPrg, S:TStQ)
    ensures invQ(?S2:TStQ)
    [circularity, label(QTS-UNIV)]

  claim // QTS-BOUND-1: the bounded control.
    <k> consT(C1:TCmd, nilT) => .K ... </k>
    <s> S:TStQ => ?S2:TStQ </s>
    requires invQ(S:TStQ) andBool okX(consT(C1:TCmd, nilT), S:TStQ)
    ensures invQ(?S2:TStQ)
    [label(QTS-BOUND-1)]

  claim // QTS-STALL-STEP: the ground stall step (the [owise] consumes the
        // command; the state is unchanged).
    <k> stallC => .K ... </k>
    <s> stQ(0, zeroP):TStQ => stQ(0, zeroP):TStQ </s>
    [label(QTS-STALL-STEP)]

  claim // QTS-DOMAIN-FALSE: the stall run is non-executable at tag 0
        // (evaluation, the Q3F arrow form — the toy grammar has no ==K;
        // the machine's exec-at-tag-0 discipline mirrored).
    <k> okX(consT(stallC, nilT), stQ(0, zeroP)) => false </k>
    [label(QTS-DOMAIN-FALSE)]

endmodule
