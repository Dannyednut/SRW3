// =============================================================================
// SRW3 PHASE 1Q — THE UNIVERSAL ATTEMPTS OVER THE CONSTRUCTOR-COUNT MACHINE
//                    (phase1q/proofs/n_q_univ_q.k)
//
// The full-machine ladder head: the same claims as 1P-UNIV-MACHINE-TDRR
// (the 1P frontier claim whose residual is reproduced in
// transcripts/k/kprove_1P-UNIV-MACHINE-TDRR-repro.log), restated over
// SRW3N-ABS-Q — the TDRR architecture with the pools as free-constructor
// exact counts and the runner's CONSTRUCTOR FORK (no requires anywhere in
// the dispatch path).
//
//   1Q-UNIV-MACHINE-Q   THE UNIVERSAL THEOREM, machine form (the target).
//   1Q-UNIV-PREFIX-Q    the committed-prefix corollary, machine form.
//   1Q-NEG-DEST-Q       destination-sanity control (MUST FAIL).
//   1Q-RUN-HONEST-Q     ground execution: the honest pipeline lands on the
//                       exact post-commit state (MUST PROVE by real
//                       rewriting — the 1P execution-evidence discipline).
//   1Q-RUN-INIT-EXEC-Q  ground execution: init then exec (the mint makes
//                       the E pool succP(zeroP)).
//   1Q-NEG-UNSAFE-COMMIT-Q (MUST FAIL): the presented-bit commit cannot
//                       reach the accept state (the reject class fires).
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-q.k"

module Q-UNIV-PROOFS
  imports SRW3N-ABS-Q

  // ===========================================================================
  // 1Q-UNIV-MACHINE-Q — THE UNIVERSAL THEOREM, machine form.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [circularity, label(1Q-UNIV-MACHINE-Q)]

  // ===========================================================================
  // 1Q-UNIV-PREFIX-Q — the committed-prefix corollary, machine form.
  //
  // DISCLOSURE (the r2 form of record): the FIRST draft required only
  // `absCfgPinnedQ(AX)` — a Bool-VALUED accessor that constrains nothing —
  // so the claim was semantically FALSE (the tag-0 refuse-run ends
  // uninitialized) and the engine still closed it in 18s by circularity
  // self-application with the base case never discharged
  // (transcripts/k/kprove_1Q-UNIV-PREFIX-Q.log, rc=0, zero
  // WarnTrivialClaim — a NON-VACUOUS PROOF OF A FALSE CLAIM, retained as
  // the recorded circularity hole; 1Q-NEG-PREFIX-CEX-Q below is the
  // mechanical falsity witness).  THE FORM OF RECORD pins the start tag:
  // every executable run from an INITIALIZED invariant state ends
  // initialized — semantically true (the tag-1 rows preserve the tag; the
  // PRESV family is the per-class content).
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool absCfgPinnedQ(AX) ==K true
         andBool absTagOfQ(AX) ==Int 1
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures absInitShapedQ(?AX2:AStateQ)
    [circularity, label(1Q-UNIV-PREFIX-Q)]

  // ===========================================================================
  // 1Q-NEG-PREFIX-CEX-Q (MUST FAIL — the PREFIX falsity witness): the
  //     refuse-run from the genesis ends at tag 0, NOT init-shaped.  A
  //     closure of THIS claim would mean the tag-0 refuse-run lands
  //     initialized (unsound); its rc=1 is the mechanical counterpart of
  //     the disclosure above.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkF:AOk),aRunNilJ) => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    ensures absInitShapedQ(?AX2:AStateQ)
    [label(1Q-NEG-PREFIX-CEX-Q)]

  // ===========================================================================
  // 1Q-NEG-DEST-Q — destination-sanity control (MUST FAIL): the final state
  //     is not always the tagged genesis.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ?AX2:AStateQ ==K absGenesisQ
    [label(1Q-NEG-DEST-Q)]

  // ===========================================================================
  // 1Q RUN EXECUTION CLAIMS — multi-step machine-level execution evidence
  //     (kprove executes them by real rewriting; the 1P discipline).
  // ===========================================================================
  claim // 1Q-RUN-HONEST-Q: the honest pipeline executes on the Q machine
        // from the constructor genesis to the exact post-commit state
        // (both pools back to zeroP, the slot counter advanced to 1).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisQ => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone):AStateQ </absjshadow>
      ...
    </srw3closureJ>
    [label(1Q-RUN-HONEST-Q)]

  claim // 1Q-RUN-INIT-EXEC-Q: the honest init-then-exec run (the exec mint
        // consumes nothing and makes the E pool succP(zeroP) — the exact
        // count, not occupancy).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aRunNilJ)) => .K ... </k>
      <absjshadow> absGenesisQ => absStQ(1, true, true, zeroP, succP(zeroP), 0, true, adNone):AStateQ </absjshadow>
      ...
    </srw3closureJ>
    [label(1Q-RUN-INIT-EXEC-Q)]

  claim // 1Q-NEG-UNSAFE-COMMIT-Q (MUST FAIL): the unsafe commit cannot
        // reach the accept successor — the Q machine's commit rows refuse
        // the (aOkT,aOkF) shape (row C-SS: the reject class).
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aExecJ(aOkT:AOk,aSrcAuth:ASrc),aConsJ(aGateJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkF:AOk),aRunNilJ)))) => .K ... </k>
      <absjshadow> absGenesisQ => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone):AStateQ </absjshadow>
      ...
    </srw3closureJ>
    [label(1Q-NEG-UNSAFE-COMMIT-Q)]

  claim // 1Q-STRONG-EMPTY-REJECT-STEP-Q (MUST PROVE — mission control #1
        // at the definition level): the strong machine's step from BOTH
        // POOLS EMPTY under a well-formed commit is DETERMINISTIC — only
        // the A-Z* complement matches (B-SS needs successor constructors)
        // — and it is the REJECT identity: N stays 0, pools stay zeroP.
        // This is the exact behavioral content whose ground-run form
        // (1Q-NEG-COMMIT-EMPTY-Q) timed out.
    <k> absStepQ(absStQ(1, true, true, zeroP, zeroP, 0, true, adNone),
                 aCommitJ(aOkT:AOk, aOkT:AOk))
        => absStQ(1, true, true, zeroP, zeroP, 0, true, adNone) </k>
    [label(1Q-STRONG-EMPTY-REJECT-STEP-Q)]

  claim // 1Q-NEG-COMMIT-EMPTY-Q (MUST FAIL — mission control #1: a commit
        // with BOTH POOLS EMPTY): from the genesis, the honest init then a
        // well-formed commit command cannot reach the accept successor —
        // the only matching commit row is the A-Z* complement (reject,
        // identity: N stays 0, pools stay zeroP).  A closure here would
        // mean the strong machine accepts from empty pools.
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk),aConsJ(aCommitJ(aOkT:AOk,aOkT:AOk),aRunNilJ)) => .K ... </k>
      <absjshadow> absGenesisQ => absStQ(1, true, true, zeroP, zeroP, 1, true, adNone):AStateQ </absjshadow>
      ...
    </srw3closureJ>
    [label(1Q-NEG-COMMIT-EMPTY-Q)]

endmodule
