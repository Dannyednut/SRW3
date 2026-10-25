// =============================================================================
// SRW3 PHASE 1S — THE PER-CLASS TRANSITION-CORRESPONDENCE BATTERY (mission §4)
//                    (phase1s/proofs/n_s_correspondence.k)
//
// THE STATEMENT CLASS OF RECORD (functional, deterministic form of the
// forward-simulation cell; see spec/state-correspondence.md §5):
//
//     eraseQ(absStepQ(SQ, c)) ==K absStepE(eraseQ(SQ), c)
//
// for every declared command class, with the class's constructor pattern
// pinned on SQ (the state branch the class's Q row matches). Where the
// mirror row's Int requires does not fire by evaluation alone, the claim
// carries the requires EXPLICITLY on the WRAPPED count (the C12-COND
// form) and the unconditional NODEP probe records the exact residual —
// the C1-dependence is MEASURED, never assumed away.
//
// This is a ONE-DIRECTIONAL correspondence restricted to the coherent
// fragment — never called a bisimulation. Whatever the raw results, they
// are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/rel-machine.k"

module S-CORR-PROOFS
  imports SRW3N-REL-S

  // ===========================================================================
  // init class (rows 1-3)
  // ===========================================================================
  claim <k> eraseQ(absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aInitJ(aOkT)))
        => absStepE(eraseQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aInitJ(aOkT)) </k>
    [label(1S-CORR-INIT-ACCEPT)]

  claim <k> eraseQ(absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aInitJ(aOkF)))
        => absStepE(eraseQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aInitJ(aOkF)) </k>
    [label(1S-CORR-INIT-REFUSE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aInitJ(A:AOk)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aInitJ(A:AOk)) </k>
    [label(1S-CORR-REINIT)]

  // ===========================================================================
  // exec class (the tag-0 stall + rows 7-9)
  // ===========================================================================
  claim <k> eraseQ(absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aExecJ(A1:AOk, A2:ASrc)))
        => absStepE(eraseQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aExecJ(A1:AOk, A2:ASrc)) </k>
    [label(1S-CORR-STALL)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aExecJ(aOkT, aSrcAuth)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aExecJ(aOkT, aSrcAuth)) </k>
    [label(1S-CORR-EXE-MINT)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aExecJ(aOkT, aSrcOther)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aExecJ(aOkT, aSrcOther)) </k>
    [label(1S-CORR-EXE-SRC)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aExecJ(aOkF, A2:ASrc)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aExecJ(aOkF, A2:ASrc)) </k>
    [label(1S-CORR-EXE-UNSUP)]

  // ===========================================================================
  // gate class (rows 5, 10): the empty cell closes unconditionally (the
  // zeroP interpretation fires the mirror's row A by evaluation); the
  // successor cells carry the wrapped requires (C12-COND) + the NODEP probe.
  // ===========================================================================
  claim <k> eraseQ(absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(A:AOk)))
        => absStepE(eraseQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(A:AOk)) </k>
    [label(1S-CORR-GATE-PRE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, zeroP,
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(A:AOk)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, zeroP,
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(A:AOk)) </k>
    [label(1S-CORR-GATE-EMPTY)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkT)) </k>
        requires countToInt(succP(E0:PoolCount)) >=Int 1
    [label(1S-CORR-GATE-MINT-COND)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkT)) </k>
    [label(1S-CORR-GATE-MINT-NODEP)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aGateJ(aOkF)))
        => absStepE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aGateJ(aOkF)) </k>
        requires countToInt(succP(E0:PoolCount)) >=Int 1
    [label(1S-CORR-GATE-REFUSE-COND)]

  // ===========================================================================
  // commit class (rows 6, 11-12)
  // ===========================================================================
  claim <k> eraseQ(absStepQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(A1:AOk, A2:AOk)))
        => absStepE(eraseQ(absStQ(0, false, false, G:PoolCount, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(A1:AOk, A2:AOk)) </k>
    [label(1S-CORR-COMMIT-PRE)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkT)) </k>
        requires countToInt(succP(G0:PoolCount)) >=Int 1
             andBool countToInt(succP(E0:PoolCount)) >=Int 1
    [label(1S-CORR-COMMIT-ACCEPT-COND)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkT)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkT)) </k>
    [label(1S-CORR-COMMIT-ACCEPT-NODEP)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkT, aOkF)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkT, aOkF)) </k>
        requires countToInt(succP(G0:PoolCount)) >=Int 1
             andBool countToInt(succP(E0:PoolCount)) >=Int 1
    [label(1S-CORR-COMMIT-C-COND)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(aOkF, A2:AOk)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(aOkF, A2:AOk)) </k>
        requires countToInt(succP(G0:PoolCount)) >=Int 1
             andBool countToInt(succP(E0:PoolCount)) >=Int 1
    [label(1S-CORR-COMMIT-D-COND)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, zeroP, E:PoolCount,
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(A1:AOk, A2:AOk)))
        => absStepE(eraseQ(absStQ(1, true, true, zeroP, E:PoolCount,
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(A1:AOk, A2:AOk)) </k>
    [label(1S-CORR-COMMIT-GEMPTY)]

  claim <k> eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), zeroP,
                                   N:Int, SF:Bool, D:ADiag),
                            aCommitJ(A1:AOk, A2:AOk)))
        => absStepE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), zeroP,
                                  N:Int, SF:Bool, D:ADiag)),
                    aCommitJ(A1:AOk, A2:AOk)) </k>
    [label(1S-CORR-COMMIT-EEMPTY)]

  // ===========================================================================
  // the invariant-preservation cells (the ABSInvE chain, one per class —
  // the content the migration theorem composes; the cond forms carry the
  // wrapped requires; the NODEP form records the exact C1.2 residual)
  // ===========================================================================
  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aExecJ(aOkT, aSrcAuth)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1S-PRESV-INT-EXE-MINT)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aGateJ(aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, G:PoolCount, succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1S-PRESV-INT-GATE-MINT)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aCommitJ(aOkT, aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
    [label(1S-PRESV-INT-COMMIT-ACCEPT-NODEP)]

  claim <k> ABSInvE(eraseQ(absStepQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                            N:Int, SF:Bool, D:ADiag),
                                    aCommitJ(aOkT, aOkT)))) => true </k>
        requires ABSInvE(eraseQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                        N:Int, SF:Bool, D:ADiag)))
             andBool tagCoherentQ(absStQ(1, true, true, succP(G0:PoolCount), succP(E0:PoolCount),
                                         N:Int, SF:Bool, D:ADiag))
             andBool countToInt(succP(G0:PoolCount)) >=Int 1
             andBool countToInt(succP(E0:PoolCount)) >=Int 1
    [label(1S-PRESV-INT-COMMIT-ACCEPT-COND)]

endmodule
