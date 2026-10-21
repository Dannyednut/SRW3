// =============================================================================
// SRW3 PHASE 1N — THE ABS LADDER (n_abs_proofs.k, hs backend)
//                    The abstract machine's own proof inventory.
//
// One definition: the M4 machine (frozen M3 + the <absjshadow> cell) + the
// additive abstract machine (abs-machine.k).  Every claim below is stated
// over DECIDABLE abstract predicates — no hash-class term is ever compared.
//
// Ladder structure:
//   §1 ABS-INIT-BASE          — the genesis establishes the invariant;
//   §2 ABS-STEP-* (10)        — the per-class step partition (the exact
//                               abstract successor pinned in the destination
//                               — the mirror of the 1M MD partition);
//   §3 ABS-PRES-* (10)        — the per-class invariant preservation, as
//                               universal function claims over ALL field
//                               values (requires ABSInv(state), concludes
//                               ABSInv(absStepJ(state, cmd)) == true);
//   §4 ABS-UNIV-*             — THE UNIVERSAL THEOREM over the abstract
//                               machine: ABSInv is preserved along every
//                               responded finite run (the mechanization of
//                               the reachable-state safety theorem at the
//                               abstract level).  Stated in the structural
//                               [circularity] form; whatever the raw result,
//                               it is recorded and never relabeled;
//   §5 ABS-PREFIX-SAFE        — the committed-prefix corollary (an
//                               initialized start ends initialized-safe);
//   §6 ABS-NEG-*              — the negative controls (MUST FAIL).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine.k"

module N-ABS-PROOFS
  imports SRW3N-ABS

  // ===========================================================================
  // §1 — THE BASE
  // ===========================================================================
  claim // ABS-INIT-BASE: the genesis abstract state, driven by the abstract
        // init-accept command, lands on the initialized shape.  The
        // destination is the LITERAL successor — ABSInv of that literal is
        // discharged by its defining equations (evaluation, not assumption).
    <absjshadow> absGenesis:AState
              => absSt(true, true, 0, 0, 0, true, adNone):AState </absjshadow>
    <k> aInitJ(aOkT:AOk) => .K </k>

    [label(ABS-INIT-BASE)]

  claim // ABS-INIT-BASE-INV: the base's successor LITERALLY satisfies the
        // abstract invariant (the evaluation witness).
    <absjshadow> absGenesis:AState </absjshadow>
    <k> ABSInv(absSt(true, true, 0, 0, 0, true, adNone):AState) => true </k>

    [label(ABS-INIT-BASE-INV)]

  // ===========================================================================
  // §2 — THE STEP PARTITION (the exact successor pinned, per class)
  // ===========================================================================
  claim // ABS-STEP-INIT-ACCEPT
    <absjshadow> AX:AState
              => absStepJ(AX, aInitJ(aOkT:AOk)):AState </absjshadow>
    <k> aInitJ(aOkT:AOk) => .K </k>

    [label(ABS-STEP-INIT-ACCEPT)]

  claim // ABS-STEP-INIT-REFUSE: any init whose guard outcome is aOkF (and
        // any init from a pinned state) changes NOTHING (the concrete
        // [owise] writes no diagnostic and moves no cell).
    <absjshadow> AX:AState
              => absStepJ(AX, aInitJ(aOkF:AOk)):AState </absjshadow>
    <k> aInitJ(aOkF:AOk) => .K </k>

    [label(ABS-STEP-INIT-REFUSE)]

  claim // ABS-STEP-EXEC-MINT: the honest exec class mints — the exec-pool
        // cardinality grows by exactly one; every other component framed.
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
              => absSt(true, true, G, E +Int 1, N, SF, D):AState </absjshadow>
    <k> aExecJ(aOkT:AOk, aSrcAuth:ASrc) => .K </k>

    [label(ABS-STEP-EXEC-MINT)]

  claim // ABS-STEP-EXEC-SOURCE: the unauthorized-source class writes ONLY
        // the diagnostic class (J-A08; the repaired M3 class).
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
              => absSt(true, true, G, E, N, SF, adSource):AState </absjshadow>
    <k> aExecJ(aOkT:AOk, aSrcOther:ASrc) => .K </k>

    [label(ABS-STEP-EXEC-SOURCE)]

  claim // ABS-STEP-EXEC-REFUSE: the unsupported/bounds class writes ONLY
        // the diagnostic class.
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
              => absSt(true, true, G, E, N, SF, adExecRefuse):AState </absjshadow>
    <k> aExecJ(aOkF:AOk, aSrcOther:ASrc) => .K </k>

    [label(ABS-STEP-EXEC-REFUSE)]

  claim // ABS-STEP-GATE-MINT: the honest gate class mints — the gate-pool
        // cardinality grows by exactly one (the concrete LHS's nonempty
        // exec pool is mirrored by the cntE >=Int 1 side condition).
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
              => absSt(true, true, G +Int 1, E, N, SF, D):AState </absjshadow>
    <k> aGateJ(aOkT:AOk) => .K </k>

    requires E >=Int 1
    [label(ABS-STEP-GATE-MINT)]

  claim // ABS-STEP-GATE-REFUSE: the [owise] gate refusal writes ONLY the
        // diagnostic class (the M3 Workstream-C transition).
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
              => absSt(true, true, G, E, N, SF, adGate):AState </absjshadow>
    <k> aGateJ(aOkF:AOk) => .K </k>

    [label(ABS-STEP-GATE-REFUSE)]

  claim // ABS-STEP-COMMIT-ACCEPT: the honest commit class consumes exactly
        // one receipt from each pool, advances the slot by exactly one,
        // and carries the COMPUTED safe bit into the bookkeeping.
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
              => absSt(true, true, G -Int 1, E -Int 1, N +Int 1, true, D):AState </absjshadow>
    <k> aCommitJ(aOkT:AOk, aOkT:AOk) => .K </k>

    requires G >=Int 1 andBool E >=Int 1
    [label(ABS-STEP-COMMIT-ACCEPT)]

  claim // ABS-STEP-COMMIT-REJECT: the reject class ([owise]) changes
        // NOTHING — no diagnostic, no receipt consumption, no slot motion.
    <absjshadow> AX:AState
              => absStepJ(AX, aCommitJ(aOkT:AOk, aOkF:AOk)):AState </absjshadow>
    <k> aCommitJ(aOkT:AOk, aOkF:AOk) => .K </k>

    [label(ABS-STEP-COMMIT-REJECT)]

  // ===========================================================================
  // §3 — THE BRANCH-COMPLETE PRESERVATION FAMILY
  //      K function equations match by PATTERN: a rule whose state pattern
  //      pins `true` does not fire on a symbolic field.  The per-class
  //      preservation is therefore stated PER ABSInv BRANCH (the state
  //      constructor pinned, the remaining fields symbolic) — together the
  //      two branches cover every invariant state DEFINITIONALLY (ABSInv
  //      is exactly the disjunction; the mixed-pin valuations evaluate to
  //      false — ABS-INV-EXCL-*).  For every command class x bit
  //      valuation x branch: the exact successor shape (ABS-PRES-*) and
  //      the invariant-preservation Bool form (ABS-PRESV-*).  The pre-init
  //      exec classes are the DECLARED STALL (the function-level identity;
  //      the machine rule does not fire — the domain predicate excludes
  //      the class from the theorem).
  // ===========================================================================

  claim // ABS-PRES-I-INIT-ACCEPT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk)) => absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0
    [label(ABS-PRES-I-INIT-ACCEPT)]

  claim // ABS-PRESV-I-INIT-ACCEPT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-INIT-ACCEPT)]

  claim // ABS-PRES-P-INIT-ACCEPT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkT:AOk)) => absSt(true, true, 0, 0, 0, true, D:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-INIT-ACCEPT)]

  claim // ABS-PRESV-P-INIT-ACCEPT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkT:AOk))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-INIT-ACCEPT)]

  claim // ABS-PRES-I-INIT-REFUSE (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkF:AOk)) => absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0
    [label(ABS-PRES-I-INIT-REFUSE)]

  claim // ABS-PRESV-I-INIT-REFUSE (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aInitJ(aOkF:AOk))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-INIT-REFUSE)]

  claim // ABS-PRES-P-INIT-REFUSE (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkF:AOk)) => absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-INIT-REFUSE)]

  claim // ABS-PRESV-P-INIT-REFUSE (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aInitJ(aOkF:AOk))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-INIT-REFUSE)]

  claim // ABS-PRES-I-EXEC-MINT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc)) => absSt(true, true, G:Int, E:Int +Int 1, N:Int, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0
    [label(ABS-PRES-I-EXEC-MINT)]

  claim // ABS-PRESV-I-EXEC-MINT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-EXEC-MINT)]

  claim // ABS-PRES-P-EXEC-MINT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc)) => absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-EXEC-MINT)]

  claim // ABS-PRESV-P-EXEC-MINT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-EXEC-MINT)]

  claim // ABS-PRES-I-EXEC-SOURCE (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc)) => absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, adSource:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0
    [label(ABS-PRES-I-EXEC-SOURCE)]

  claim // ABS-PRESV-I-EXEC-SOURCE (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-EXEC-SOURCE)]

  claim // ABS-PRES-P-EXEC-SOURCE (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc)) => absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-EXEC-SOURCE)]

  claim // ABS-PRESV-P-EXEC-SOURCE (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkT:AOk, aSrcOther:ASrc))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-EXEC-SOURCE)]

  claim // ABS-PRES-I-EXEC-REFUSE (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc)) => absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, adExecRefuse:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0
    [label(ABS-PRES-I-EXEC-REFUSE)]

  claim // ABS-PRESV-I-EXEC-REFUSE (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-EXEC-REFUSE)]

  claim // ABS-PRES-P-EXEC-REFUSE (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc)) => absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-EXEC-REFUSE)]

  claim // ABS-PRESV-P-EXEC-REFUSE (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aExecJ(aOkF:AOk, aSrcAuth:ASrc))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-EXEC-REFUSE)]

  claim // ABS-PRES-I-GATE-MINT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk)) => absSt(true, true, G:Int +Int 1, E:Int, N:Int, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires E >=Int 1 
    [label(ABS-PRES-I-GATE-MINT)]

  claim // ABS-PRESV-I-GATE-MINT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 1 andBool SF ==K true 
    [label(ABS-PRESV-I-GATE-MINT)]

  claim // ABS-PRES-P-GATE-MINT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aGateJ(aOkT:AOk)) => absSt(false, false, 0, 0, 0, SF:Bool, adGate:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-GATE-MINT)]

  claim // ABS-PRESV-P-GATE-MINT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-GATE-MINT)]

  claim // ABS-PRES-I-GATE-REFUSE (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk)) => absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, adGate:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0
    [label(ABS-PRES-I-GATE-REFUSE)]

  claim // ABS-PRESV-I-GATE-REFUSE (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aGateJ(aOkF:AOk))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-GATE-REFUSE)]

  claim // ABS-PRES-P-GATE-REFUSE (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aGateJ(aOkF:AOk)) => absSt(false, false, 0, 0, 0, SF:Bool, adGate:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-GATE-REFUSE)]

  claim // ABS-PRESV-P-GATE-REFUSE (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aGateJ(aOkF:AOk))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-GATE-REFUSE)]

  claim // ABS-PRES-I-COMMIT-ACCEPT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk)) => absSt(true, true, G:Int -Int 1, E:Int -Int 1, N:Int +Int 1, true, D:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 1 andBool E >=Int 1 
    [label(ABS-PRES-I-COMMIT-ACCEPT)]

  claim // ABS-PRESV-I-COMMIT-ACCEPT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 1 andBool E >=Int 1 andBool SF ==K true 
    [label(ABS-PRESV-I-COMMIT-ACCEPT)]

  claim // ABS-PRES-P-COMMIT-ACCEPT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk)) => absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-COMMIT-ACCEPT)]

  claim // ABS-PRESV-P-COMMIT-ACCEPT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-COMMIT-ACCEPT)]

  claim // ABS-PRES-I-COMMIT-REJECT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk)) => absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0
    [label(ABS-PRES-I-COMMIT-REJECT)]

  claim // ABS-PRESV-I-COMMIT-REJECT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool E >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-COMMIT-REJECT)]

  claim // ABS-PRES-P-COMMIT-REJECT (the successor shape, branch-pinned)
    <k> absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk)) => absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRES-P-COMMIT-REJECT)]

  claim // ABS-PRESV-P-COMMIT-REJECT (the invariant-preservation Bool form)
    <k> ABSInv(absStepJ(absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkF:AOk))) => true </k>
    <absjshadow> absSt(false, false, 0, 0, 0, SF:Bool, D:ADiag):AState </absjshadow>
    requires SF ==K false
    [label(ABS-PRESV-P-COMMIT-REJECT)]

  claim // ABS-PRES-I-GATE-MINT-EMPTY: the gate-mint bit with an EMPTY exec
        // pool takes the [owise] refusal class (the concrete LHS's
        // SetItem(E) ES is unmet) — the diagnostic is the ONLY change.
    <k> absStepJ(absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))
     => absSt(true, true, G:Int, 0, N:Int, SF:Bool, adGate:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    [label(ABS-PRES-I-GATE-MINT-EMPTY)]

  claim // ABS-PRESV-I-GATE-MINT-EMPTY (the preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag), aGateJ(aOkT:AOk))) => true </k>
    <absjshadow> absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-GATE-MINT-EMPTY)]

  claim // ABS-PRES-I-COMMIT-ACCEPT-LOWG: the accept bit with an EMPTY gate
        // pool takes the reject class — NOTHING changes.
    <k> absStepJ(absSt(true, true, 0, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))
     => absSt(true, true, 0, E:Int, N:Int, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(true, true, 0, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    [label(ABS-PRES-I-COMMIT-ACCEPT-LOWG)]

  claim // ABS-PRESV-I-COMMIT-ACCEPT-LOWG (the preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, 0, E:Int, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absSt(true, true, 0, E:Int, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires E >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-COMMIT-ACCEPT-LOWG)]

  claim // ABS-PRES-I-COMMIT-ACCEPT-LOWE: the accept bit with an EMPTY exec
        // pool likewise takes the reject class — NOTHING changes.
    <k> absStepJ(absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))
     => absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag) </k>
    <absjshadow> absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    [label(ABS-PRES-I-COMMIT-ACCEPT-LOWE)]

  claim // ABS-PRESV-I-COMMIT-ACCEPT-LOWE (the preservation Bool form)
    <k> ABSInv(absStepJ(absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag), aCommitJ(aOkT:AOk, aOkT:AOk))) => true </k>
    <absjshadow> absSt(true, true, G:Int, 0, N:Int, SF:Bool, D:ADiag):AState </absjshadow>
    requires G >=Int 0 andBool SF ==K true
    [label(ABS-PRESV-I-COMMIT-ACCEPT-LOWE)]

  claim // ABS-INV-EXCL-I: the mixed-pin valuations are NOT invariant
        // states (definitional; the case analysis is exhaustive).
    <k> ABSInv(absSt(true, false, 0, 0, 0, true, adNone):AState) => false </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(ABS-INV-EXCL-I)]

  claim // ABS-INV-EXCL-II: the other mixed-pin valuation likewise.
    <k> ABSInv(absSt(false, true, 0, 0, 0, false, adNone):AState) => false </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(ABS-INV-EXCL-II)]

  // ===========================================================================
  // §4 — THE UNIVERSAL THEOREM over the abstract machine
  //      ABS-UNIV: after EVERY responded finite run from an invariant
  //      state, the reached state is again invariant.  The structural
  //      [circularity] form: the goal evaluates the fold; the step case
  //      is constructor-pinned; the circular call closes the VARIABLE
  //      tail via the unpinned companion (ABS-UNIV-TAIL).  Raw results
  //      are recorded; nothing is relabeled.
  // ===========================================================================
  claim // ABS-UNIV-BASE: the empty run returns the state itself.
    <k> ABSInv(absRunF(aRunNilJ, AX:AState)) => true </k>
    <absjshadow> AX:AState </absjshadow>
    requires ABSInv(AX)
    [label(ABS-UNIV-BASE)]

  claim // ABS-UNIV-STEP: THE GENUINE UNIVERSAL ATTEMPT — the invariant is
        // preserved along every responded finite run (structural
        // [circularity] form).  The residual of record LOCATES the
        // composition boundary precisely: the abstract step function
        // cannot dispatch on a SYMBOLIC command constructor, so the tail
        // obligation cannot be discharged inside one kprove claim.  The
        // per-class content is carried by the branch-complete ABS-PRES*
        // family; the composition evidence over concrete pipelines by
        // ABS-RUN-*.  Recorded with its residual; never relabeled.
    <k> ABSInv(absRunF(RUN:APProg, AX:AState)) => true </k>
    <absjshadow> AX:AState </absjshadow>
    requires ABSInv(AX) andBool absExecutable(RUN:APProg, AX:AState)
    [circularity, label(ABS-UNIV-STEP)]

  claim // ABS-UNIV-TAIL: the unpinned formulation variant.  The raw probe
        // showed kore's circularity does NOT self-apply (no vacuous
        // instant closure); the claim gets stuck on the same symbolic
        // dispatch boundary.  Recorded as the second formulation.
    <k> ABSInv(absRunF(R:APProg, AX:AState)) => true </k>
    <absjshadow> AX:AState </absjshadow>
    requires ABSInv(AX) andBool absExecutable(R:APProg, AX:AState)
    [circularity, label(ABS-UNIV-TAIL)]

  // ===========================================================================
  // §5 — THE COMMITTED-PREFIX COROLLARY (the function-form attempt)
  // ===========================================================================
  claim // ABS-PREFIX-SAFE: an initialized invariant state, driven by any
        // responded finite run, ends INITIALIZED with the safety
        // bookkeeping held (the abstract counterpart of the
        // committed-prefix branch of JInvPlusJ).  Same composition
        // boundary as ABS-UNIV-STEP; recorded with its residual.
    <k> absInitShaped(absRunF(RUN:APProg, AX:AState)) => true </k>
    <absjshadow> AX:AState </absjshadow>
    requires ABSInv(AX) andBool absCfgPinnedOf(AX)
         andBool absExecutable(RUN:APProg, AX:AState)
    [circularity, label(ABS-PREFIX-SAFE)]

  claim // ABS-RUN-HONEST-PIPELINE: the CONCRETE honest pipeline — init,
        // exec mint, gate mint, commit accept — composed over the fold,
        // from the genesis, lands initialized-safe with the slot advanced
        // and both pools consumed.  A mechanized multi-step composition
        // theorem (real unfolding; no symbolic dispatch involved).
    <k> ABSInv(absRunF(
            aConsJ(aInitJ(aOkT:AOk),
            aConsJ(aExecJ(aOkT:AOk, aSrcAuth:ASrc),
            aConsJ(aGateJ(aOkT:AOk),
            aConsJ(aCommitJ(aOkT:AOk, aOkT:AOk),
                   aRunNilJ)))),
            absGenesis:AState)) => true </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(ABS-RUN-HONEST-PIPELINE)]

  claim // ABS-RUN-HONEST-PIPELINE-SHAPE: the same pipeline's REACHED STATE
        // is exactly the post-commit shape (the stronger, non-Boolean
        // form: the fold computes the literal successor state).
    <k> absRunF(
            aConsJ(aInitJ(aOkT:AOk),
            aConsJ(aExecJ(aOkT:AOk, aSrcAuth:ASrc),
            aConsJ(aGateJ(aOkT:AOk),
            aConsJ(aCommitJ(aOkT:AOk, aOkT:AOk),
                   aRunNilJ)))),
            absGenesis:AState)
     => absSt(true, true, 0, 0, 1, true, adNone):AState </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(ABS-RUN-HONEST-PIPELINE-SHAPE)]

  claim // ABS-RUN-REFUSAL-CHAIN: refusals and rejects compose honestly —
        // a source-refused exec, then a refused gate (whose diagnostic
        // class OVERWRITES the source diagnostic — the machine's own
        // ordering), then a rejected commit: the bookkeeping is EXACTLY
        // the post-init state with the LAST diagnostic class (slot not
        // advanced, pools not touched, safety bit held).
    <k> absRunF(
            aConsJ(aInitJ(aOkT:AOk),
            aConsJ(aExecJ(aOkT:AOk, aSrcOther:ASrc),
            aConsJ(aGateJ(aOkF:AOk),
            aConsJ(aCommitJ(aOkT:AOk, aOkF:AOk),
                   aRunNilJ)))),
            absGenesis:AState)
     => absSt(true, true, 0, 0, 0, true, adGate):AState </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(ABS-RUN-REFUSAL-CHAIN)]

  // ===========================================================================
  // §6 — THE NEGATIVE CONTROLS (MUST FAIL)
  // ===========================================================================
  claim // ABS-NEG-UNSAFE-ACCEPT: the accept step PRESENTED with the failed
        // computed-safe outcome must NOT be able to carry the safety
        // bookkeeping — the machine's own (aOkT, aOkT) requirement makes
        // this unprovable.  EXPECTED FAIL (the guard is load-bearing).
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, _:Bool, D:ADiag)
              => absSt(true, true, G -Int 1, E -Int 1, N +Int 1, true, D):AState </absjshadow>
    <k> aCommitJ(aOkT:AOk, aOkF:AOk) => .K </k>

    requires G >=Int 1 andBool E >=Int 1
    [label(ABS-NEG-UNSAFE-ACCEPT)]

  claim // ABS-NEG-REFUSE-ON-MINT: the gate-refusal claim applied to a
        // state where the mint preconditions HOLD — the mint rule fires
        // instead, so the "unchanged" destination is unprovable.
        // EXPECTED FAIL (the non-overlap control, the MC-NEG discipline).
    <absjshadow> absSt(true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
              => absSt(true, true, G, E, N, SF, D):AState </absjshadow>
    <k> aGateJ(aOkT:AOk) => .K </k>

    requires E >=Int 1 andBool D ==K adNone
    [label(ABS-NEG-REFUSE-ON-MINT)]

endmodule
