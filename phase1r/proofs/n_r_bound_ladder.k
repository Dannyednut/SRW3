// =============================================================================
// SRW3 PHASE 1R — EXPERIMENT A: THE BOUNDED UNIVERSAL DIAGNOSTICS (the
//                    depth ladder over the Phase 1Q machine of record)
//                    (phase1r/proofs/n_r_bound_ladder.k)
//
// The bounded-run formulation of record: for each concrete depth d, the
// claim quantifies over a SYMBOLIC COMMAND SPINE of length d —
//   aConsJ(AC1, aConsJ(AC2, ... aConsJ(ACd, aRunNilJ)))   (each ACi:ACmd)
// — with the state symbolic under the invariant and BOTH POOL TAILS
// ARBITRARY (PoolCount variables; the fork only ever inspects pool HEADS).
// No machine change: the ORIGINAL 1Q runner executes the spine; no
// hard-coded successful pipeline (every command position is universally
// quantified; the executable domain predicate prunes the non-executable
// branches — pre-init exec commands are stalls and are excluded by the
// requires exactly as the 1Q domain predicate declares).
//
// LABELING CONTRACT (mission §5): a claim at one fixed depth is a BOUNDED
// THEOREM (finite unrolling + evaluation). The ladder is a FINITE TEST at
// every d. NO claim here is the arbitrary-finite-run theorem, and no
// depth increase is described as an induction proof.
//
// Controls in this file:
//   1R-BOUND-0-DEST-Q  (MUST PROVE): the depth-0 destination goal closes —
//                      the bounded family has real content (the same goal
//                      is FALSE at depth 1, see the -1-DEST control).
//   1R-BOUND-1-DEST-Q  (MUST FAIL): the destination goal at depth 1 — the
//                      init-accept step re-tags, so the final state is not
//                      always the genesis; a closure would be unsound.
//
// To run (from the repo root, after the toolchain env):
//   kprove phase1r/proofs/n_r_bound_ladder.k $INC -d /tmp/p1q-q-def \
//     --spec-module R-BOUND-PROOFS --claims <CLAIM>
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1q/semantics/abs-machine-q.k"

module R-BOUND-PROOFS
  imports SRW3N-ABS-Q

  // ===========================================================================
  // THE DEPTH LADDER (d = 0,1,2,3,4,5; extended only as the observed
  // runtime justifies — the mission's staged-ladder rule)
  // ===========================================================================

  claim // 1R-BOUND-0-Q: the empty program (d = 0)
    <srw3closureJ>
      <k> aRunNilJ => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool absExecutableQ(aRunNilJ, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [label(1R-BOUND-0-Q)]

  claim // 1R-BOUND-1-Q: one symbolic step (d = 1)
    <srw3closureJ>
      <k> aConsJ(AC1:ACmd, aRunNilJ) => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absExecutableQ(aConsJ(AC1:ACmd, aRunNilJ), AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [label(1R-BOUND-1-Q)]

  claim // 1R-BOUND-2-Q: two symbolic steps (d = 2)
    <srw3closureJ>
      <k> aConsJ(AC1:ACmd, aConsJ(AC2:ACmd, aRunNilJ)) => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absExecutableQ(aConsJ(AC1:ACmd, aConsJ(AC2:ACmd, aRunNilJ)), AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [label(1R-BOUND-2-Q)]

  claim // 1R-BOUND-3-Q: three symbolic steps (d = 3)
    <srw3closureJ>
      <k> aConsJ(AC1:ACmd, aConsJ(AC2:ACmd, aConsJ(AC3:ACmd, aRunNilJ))) => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absExecutableQ(aConsJ(AC1:ACmd, aConsJ(AC2:ACmd, aConsJ(AC3:ACmd, aRunNilJ))), AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [label(1R-BOUND-3-Q)]

  claim // 1R-BOUND-4-Q: four symbolic steps (d = 4)
    <srw3closureJ>
      <k> aConsJ(AC1:ACmd, aConsJ(AC2:ACmd, aConsJ(AC3:ACmd, aConsJ(AC4:ACmd, aRunNilJ)))) => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absExecutableQ(aConsJ(AC1:ACmd, aConsJ(AC2:ACmd, aConsJ(AC3:ACmd, aConsJ(AC4:ACmd, aRunNilJ)))), AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [label(1R-BOUND-4-Q)]

  claim // 1R-BOUND-5-Q: five symbolic steps (d = 5)
    <srw3closureJ>
      <k> aConsJ(AC1:ACmd, aConsJ(AC2:ACmd, aConsJ(AC3:ACmd, aConsJ(AC4:ACmd, aConsJ(AC5:ACmd, aRunNilJ))))) => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool absExecutableQ(aConsJ(AC1:ACmd, aConsJ(AC2:ACmd, aConsJ(AC3:ACmd, aConsJ(AC4:ACmd, aConsJ(AC5:ACmd, aRunNilJ))))), AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
    [label(1R-BOUND-5-Q)]

  // ===========================================================================
  // THE DEST CONTROLS (the bounded family's content boundary)
  // ===========================================================================

  claim // 1R-BOUND-0-DEST-Q (MUST PROVE): at depth 0 the state is
        // unchanged; with the genesis pinned the destination goal closes
        // by evaluation — the SAME goal is FALSE at depth 1 (next claim).
    <srw3closureJ>
      <k> aRunNilJ => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool AX ==K absGenesisQ
    ensures ?AX2:AStateQ ==K absGenesisQ
    [label(1R-BOUND-0-DEST-Q)]

  claim // 1R-BOUND-1-DEST-Q (MUST FAIL): one symbolic step can be the
        // honest init-accept — the final state is NOT always the genesis.
        // A closure of THIS claim would mean the bounded family carries
        // no information (unsound).
    <srw3closureJ>
      <k> aConsJ(AC1:ACmd, aRunNilJ) => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX) andBool AX ==K absGenesisQ
         andBool absExecutableQ(aConsJ(AC1:ACmd, aRunNilJ), AX:AStateQ)
    ensures ?AX2:AStateQ ==K absGenesisQ
    [label(1R-BOUND-1-DEST-Q)]

endmodule
