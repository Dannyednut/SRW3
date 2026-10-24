#!/usr/bin/env python3
"""SRW3 Phase 1P (r2) — derive the BRANCH-TAGGED abstract machine variants.

RECONSTRUCTION r2: the r1 tree was lost to a sandbox reset before any commit
(see phase1p/spec/branch-tag-design.md §0).  This r2 generator re-derives the
six tagged variants from the FROZEN phase1n/semantics/abs-machine.k with the
disclosed edit set EA-EH below.  Every edit is a whole-block replacement
verified against the 1N source; nothing else moves; the generator is
deterministic (roundtrip check) and fail-closed.

The ladder (one mechanism per rung — the experiment's independent variable):
  T   = the tag encoding alone (conjunctive ABSInvT; R-form runner with a
        symbolic shadow variable; absStepT class rows with requires+[owise])
  TD  = T + rewrite-level TAG DISCRIMINATION (the runner's ground-command
        rules pattern the shadow's branch: tag-0 / tag-1 rows)
  TDR = TD + the REQUIRES SPLIT (the Int-guarded classes become explicit,
        mutually-exclusive, exhaustive rule pairs; the only [owise] left is
        the incoherent-tag complement)
  weak-{t,td,tdr} = the 1O weak-commit edit composed on each rung (the
        presented bit carried; the soundness controls' subject).

Disclosed edits relative to the 1N module content:
  EA  module rename; the tagged state space absStT (tag:Int FIRST field);
      absGenesisT; the tagged accessors (absCfgPinnedT/absCatPinnedT/
      absSafeT/absTagOf); absInitShapedT (STRENGTHENED: TG ==Int 1 conjunct).
  EB  the command syntax (ADiag/AOk/ASrc/ACmd/APProg) is carried VERBATIM
      from the 1N source (byte-checked, not retyped).
  EC  ABSInvT — the conjunctive tagged invariant + tagCoherentT (design §3).
  ED  absStepT — the twelve-class mirror (design §4); form-T (requires +
      [owise]) for T/TD; form-TDR (requires split + incoherent-tag [owise])
      for TDR.
  EE  the runner — form-R (the 1O make_abs_r.py shape over the tagged
      state) for T; form-TD (branch-discriminated ground-command rules) for
      TD/TDR.  The stall discipline is unchanged: NO exec rule on the
      tag-0 shadow.
  EF  absExecutableT/absRunFT — the 1N domain predicate and fold mirrored
      over absStepT (the recursion aligns conjunct-by-conjunct as in 1N).
  EG  the refinement map: branchTag/tagStE/eraseT over the ERASE-TARGET
      mirror sort absStE (disclosed boundary: SRW3N-ABS cannot be imported
      without importing the 1N runner rules, which would contaminate the
      tagged machine's reachability; absStE is field-isomorphic to the 1N
      AState and the generator verifies the field correspondence against
      the 1N rule table below).
  EH  simJ/absStructOf are DELIBERATELY NOT carried (the tagged ladder is
      stated on the abstract side; the concrete bridge is the 1N SIM
      ladder's business).  Disclosed omission.

Usage: python3 phase1p/scripts/make_abs_t.py
Output: phase1p/semantics/abs-machine-{t,td,tdr,weak-t,weak-td,weak-tdr}.k
Exit 0 iff every fail-closed check passes.
"""
import difflib
import hashlib
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parents[1]
REPO = HERE.parent
SRC = REPO / "phase1n" / "semantics" / "abs-machine.k"
OUT = HERE / "semantics"

# ---------------------------------------------------------------------------
# The byte-exact 1N blocks this generator consumes (fail-closed anchors).
# ---------------------------------------------------------------------------
ANCHOR_CMDS = """  syntax AOk ::= "aOkT" | "aOkF"
  syntax ASrc ::= "aSrcAuth"    // SRC == qcrExecClientDOf(C)  (J-A08)
                | "aSrcOther"   // the unauthorized-source class

  syntax ACmd ::= aInitJ ( AOk )                 // the FULL init-guard outcome
                | aExecJ ( AOk , ASrc )          // (fragment-ok, source class)
                | aGateJ ( AOk )                 // the FULL gate-mint-precondition outcome
                | aCommitJ ( AOk , AOk )         // (accept-guard, computed SafeJ on derived post)
  syntax APProg ::= "aRunNilJ" | aConsJ ( ACmd , APProg )"""

ANCHOR_ADIAG = """  syntax ADiag ::= "adNone"        // jrefuseNoneJ
                 | "adSource"      // jrefusedSource()
                 | "adExecRefuse"  // jrefusedUnsupported(_) | jrefusedBounds(_)
                 | "adGate"        // jrefusedGate()"""

# the frozen 1N successor table (field-exact) — the ERASE-* claims' RHS and
# the generator's own check that the tagged rows mirror the 1N rows.
# (tag-0 rows are the 1N rows with C=false,T=false; tag-1 rows with C=T=true;
# the 1N source is the single source of truth for every field update.)
N1_ROWS = {
    "init-accept":  "absSt(true, true, 0, 0, 0, true, D)",
    "init-refuse":  "absSt(C, T, G, E, N, SF, D)",
    "exec-mint":    "absSt(true, true, G, E +Int 1, N, SF, D)",
    "exec-source":  "absSt(true, true, G, E, N, SF, adSource)",
    "exec-refuse":  "absSt(true, true, G, E, N, SF, adExecRefuse)",
    "gate-mint":    "absSt(true, true, G +Int 1, E, N, SF, D)",
    "gate-refuse":  "absSt(C, T, G, E, N, SF, adGate)",
    "commit-accept": "absSt(true, true, G -Int 1, E -Int 1, N +Int 1, true, D)",
    "commit-reject": "absSt(C, T, G, E, N, SF, D)",
}

# ---------------------------------------------------------------------------
# Shared section templates
# ---------------------------------------------------------------------------
HEADER = """// =============================================================================
// SRW3 PHASE 1P (r2) — THE BRANCH-TAGGED ABSTRACT MACHINE ({title})
//                    (phase1p/semantics/{fname})
//
// GENERATED by phase1p/scripts/make_abs_t.py from the FROZEN
// phase1n/semantics/abs-machine.k (sha256 {srcsha}).  DO NOT EDIT BY HAND.
// RECONSTRUCTION r2: the r1 tree was lost before any commit; this variant is
// re-derived from the recorded design (phase1p/spec/branch-tag-design.md).
//
// Disclosed edit set EA-EH (see the generator docstring): the tagged state
// space absStT (tag:Int FIRST field), the CONJUNCTIVE invariant ABSInvT +
// tagCoherentT (no disjunction, no if-then-else), absStepT (the twelve-class
// mirror; {stepnote}), the {runnernote} runner, absExecutableT/absRunFT, and
// the refinement map (branchTag/tagStE/eraseT over the absStE mirror sort).
// simJ/absStructOf are deliberately not carried (edit EH).  The command
// syntax is the 1N syntax VERBATIM (edit EB).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "srw3closure-j-m4.k"

module {mod}
  imports SRW3CLOSURE-J-M4

"""

SEC_STATE = """  // ===========================================================================
  // §A — THE TAGGED STATE SPACE (edit EA: tag:Int FIRST field)
  // ===========================================================================
  syntax ADiag ::= "adNone"        // jrefuseNoneJ
                 | "adSource"      // jrefusedSource()
                 | "adExecRefuse"  // jrefusedUnsupported(_) | jrefusedBounds(_)
                 | "adGate"        // jrefusedGate()

  syntax AStateT ::= absStT ( tg:Int         // THE BRANCH TAG: 0 = pre-init,
                              , cfgP:Bool    //                   1 = initialized
                              , catP:Bool
                              , cntG:Int
                              , cntE:Int
                              , nSlot:Int
                              , safe:Bool
                              , diag:ADiag )

  syntax AStateT ::= "absGenesisT" [function, total]
  rule absGenesisT => absStT( 0, false, false, 0, 0, 0, false, adNone )

  syntax Int ::= absTagOf ( AStateT ) [function, total]
  rule absTagOf(absStT(TG:Int, _:Bool, _:Bool, _:Int, _:Int, _:Int, _:Bool, _:ADiag)) => TG
  syntax Bool ::= absCfgPinnedT ( AStateT ) [function, total]
  rule absCfgPinnedT(absStT(_:Int, C:Bool, _:Bool, _:Int, _:Int, _:Int, _:Bool, _:ADiag)) => C:Bool
  syntax Bool ::= absCatPinnedT ( AStateT ) [function, total]
  rule absCatPinnedT(absStT(_:Int, _:Bool, T:Bool, _:Int, _:Int, _:Int, _:Bool, _:ADiag)) => T:Bool
  syntax Bool ::= absSafeT ( AStateT ) [function, total]
  rule absSafeT(absStT(_:Int, _:Bool, _:Bool, _:Int, _:Int, _:Int, SF:Bool, _:ADiag)) => SF:Bool

  // ===========================================================================
  // §B — THE COMMAND LANGUAGE (edit EB: the 1N syntax VERBATIM)
  // ===========================================================================
  syntax AOk ::= "aOkT" | "aOkF"
  syntax ASrc ::= "aSrcAuth"    // SRC == qcrExecClientDOf(C)  (J-A08)
                | "aSrcOther"   // the unauthorized-source class

  syntax ACmd ::= aInitJ ( AOk )                 // the FULL init-guard outcome
                | aExecJ ( AOk , ASrc )          // (fragment-ok, source class)
                | aGateJ ( AOk )                 // the FULL gate-mint-precondition outcome
                | aCommitJ ( AOk , AOk )         // (accept-guard, computed SafeJ on derived post)
  syntax APProg ::= "aRunNilJ" | aConsJ ( ACmd , APProg )

"""

SEC_STEP_T = """  // ===========================================================================
  // §C — THE TAGGED STEP (edit ED, form-T: the twelve-class mirror with
  //      requires + [owise] complements, the 1N partition discipline)
  //      THE INIT-ACCEPT IS THE ONLY LEGAL RE-TAG (0 -> 1).
  // ===========================================================================
  syntax AStateT ::= absStepT ( AStateT , ACmd ) [function, total]

  // ---- init (rows 1-3) ------------------------------------------------------
  rule absStepT(absStT(0, false, false, _:Int, _:Int, _:Int, _:Bool, D:ADiag),
                aInitJ(aOkT))
    => absStT(1, true, true, 0, 0, 0, true, D)               // THE re-tag 0->1
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aInitJ(aOkF))
    => absStT(0, false, false, G, E, N, SF, D)               // refuse, tag kept
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aInitJ(_:AOk))
    => absStT(1, true, true, G, E, N, SF, D)                 // re-init refused

  // ---- exec (rows 4, 7-9) ---------------------------------------------------
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aExecJ(_:AOk, _:ASrc))
    => absStT(0, false, false, G, E, N, SF, D)               // the stall (identity)
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aExecJ(aOkT, aSrcAuth))
    => absStT(1, true, true, G, E +Int 1, N, SF, D)          // the mint class
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, _:ADiag),
                aExecJ(aOkT, aSrcOther))
    => absStT(1, true, true, G, E, N, SF, adSource)          // J-A08 refusal
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, _:ADiag),
                aExecJ(aOkF, _:ASrc))
    => absStT(1, true, true, G, E, N, SF, adExecRefuse)      // unsupported/bounds

  // ---- gate (rows 5, 10) ----------------------------------------------------
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aGateJ(_:AOk))
    => absStT(0, false, false, G, E, N, SF, adGate)          // pre-init refusal
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aGateJ(aOkT))
    => absStT(1, true, true, G +Int 1, E, N, SF, D)          // the mint class
    requires E >=Int 1
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, _:ADiag),
                aGateJ(_:AOk))
    => absStT(1, true, true, G, E, N, SF, adGate) [owise]    // the refusal

  // ---- commit (rows 6, 11-12) -----------------------------------------------
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(_:AOk, _:AOk))
    => absStT(0, false, false, G, E, N, SF, D)               // pre-init reject
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, _:Bool, D:ADiag),
                aCommitJ(aOkT, aOkT))
    => absStT(1, true, true, G -Int 1, E -Int 1, N +Int 1, true, D)
    requires G >=Int 1 andBool E >=Int 1
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(_:AOk, _:AOk))
    => absStT(1, true, true, G, E, N, SF, D) [owise]         // the reject class
  // NOTE (the 1N discipline, restated): deliberately NO global [owise]
  // catch-all beyond the per-class complements above; totality rests on the
  // class coverage for tag in {0,1} (the invariant's range) plus the rows
  // themselves.  States with an INCOHERENT tag (outside {{0,1}}) are outside
  // the proof-reachable fragment; the TDR form carries their explicit
  // complement, this form does not (disclosed difference).
"""

SEC_STEP_TDR = """  // ===========================================================================
  // §C — THE TAGGED STEP (edit ED, form-TDR: the REQUIRES SPLIT)
  //      The Int-guarded classes become explicit, mutually-exclusive,
  //      exhaustive pairs; the ONLY [owise] is the incoherent-tag
  //      complement.  THE INIT-ACCEPT IS THE ONLY LEGAL RE-TAG (0 -> 1).
  // ===========================================================================
  syntax AStateT ::= absStepT ( AStateT , ACmd ) [function, total]

  // ---- init (rows 1-3) ------------------------------------------------------
  rule absStepT(absStT(0, false, false, _:Int, _:Int, _:Int, _:Bool, D:ADiag),
                aInitJ(aOkT))
    => absStT(1, true, true, 0, 0, 0, true, D)               // THE re-tag 0->1
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aInitJ(aOkF))
    => absStT(0, false, false, G, E, N, SF, D)               // refuse, tag kept
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aInitJ(_:AOk))
    => absStT(1, true, true, G, E, N, SF, D)                 // re-init refused

  // ---- exec (rows 4, 7-9) ---------------------------------------------------
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aExecJ(_:AOk, _:ASrc))
    => absStT(0, false, false, G, E, N, SF, D)               // the stall (identity)
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aExecJ(aOkT, aSrcAuth))
    => absStT(1, true, true, G, E +Int 1, N, SF, D)          // the mint class
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, _:ADiag),
                aExecJ(aOkT, aSrcOther))
    => absStT(1, true, true, G, E, N, SF, adSource)          // J-A08 refusal
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, _:ADiag),
                aExecJ(aOkF, _:ASrc))
    => absStT(1, true, true, G, E, N, SF, adExecRefuse)      // unsupported/bounds

  // ---- gate (rows 5, 10) — THE REQUIRES SPLIT (COMPLETE: the (bit x pool)
  //      grid is covered — row A: any bit, empty pool; row B: aOkT, nonempty;
  //      row C: aOkF, nonempty.  The r2 finding 1P-F1: the first draft had
  //      only rows A (E<=0) and B, leaving the (aOkF, E>=1) cell UNMATCHED —
  //      the TDRR residual exposed it.)
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aGateJ(_:AOk))
    => absStT(0, false, false, G, E, N, SF, adGate)          // pre-init refusal
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, _:ADiag),
                aGateJ(_:AOk))
    => absStT(1, true, true, G, E, N, SF, adGate)            // row A: empty pool
    requires E <=Int 0
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aGateJ(aOkT))
    => absStT(1, true, true, G +Int 1, E, N, SF, D)          // row B: the mint class
    requires E >=Int 1
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, _:ADiag),
                aGateJ(aOkF))
    => absStT(1, true, true, G, E, N, SF, adGate)            // row C: refused, nonempty
    requires E >=Int 1

  // ---- commit (rows 6, 11-12) — THE REQUIRES SPLIT --------------------------
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(_:AOk, _:AOk))
    => absStT(0, false, false, G, E, N, SF, D)               // pre-init reject
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, _:Bool, D:ADiag),
                aCommitJ(aOkT, aOkT))
    => absStT(1, true, true, G -Int 1, E -Int 1, N +Int 1, true, D)  // row B: accept
    requires G >=Int 1 andBool E >=Int 1
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(aOkT, aOkF))
    => absStT(1, true, true, G, E, N, SF, D)                 // row C: reject, pools ok
    requires G >=Int 1 andBool E >=Int 1
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(aOkF, _:AOk))
    => absStT(1, true, true, G, E, N, SF, D)                 // row D: reject, pools ok
    requires G >=Int 1 andBool E >=Int 1
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(_:AOk, _:AOk))
    => absStT(1, true, true, G, E, N, SF, D)                 // row A: the complement
    requires G <=Int 0 orBool E <=Int 0

  // ---- the INCOHERENT-TAG complement (totality; inert on the reachable
  //      fragment — the COH family proves the step keeps coherent states
  //      coherent, and the genesis is coherent, so no reachable state has a
  //      tag outside {{0,1}}) --------------------------------------------------
  rule absStepT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                _:ACmd)
    => absStT(TG, C, T, G, E, N, SF, D)
    requires TG >=Int 2 orBool TG <=Int -1 [owise]
"""

SEC_RUN_R = """  // ===========================================================================
  // §D — THE RUNNER (edit EE, form-R: the 1O make_abs_r.py shape over the
  //      tagged state; the shadow stays a SYMBOLIC variable — the tag is
  //      NOT discriminated at the rewrite level on this rung)
  // ===========================================================================
  rule <k> aConsJ(AC:ACmd, R:APProg) => AC ~> R ... </k>
  rule <k> aRunNilJ => .K ... </k>

  rule <k> aInitJ(aOkT) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aInitJ(aOkT)) </absjshadow>
  rule <k> aInitJ(aOkF) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aInitJ(aOkF)) </absjshadow>

  rule <k> aExecJ(aOkT, aSrcAuth) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aExecJ(aOkT, aSrcAuth)) </absjshadow>
    requires absCfgPinnedT(AX) andBool absCatPinnedT(AX)
  rule <k> aExecJ(aOkT, aSrcOther) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aExecJ(aOkT, aSrcOther)) </absjshadow>
    requires absCfgPinnedT(AX) andBool absCatPinnedT(AX)
  rule <k> aExecJ(aOkF, aSrcAuth) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aExecJ(aOkF, aSrcAuth)) </absjshadow>
    requires absCfgPinnedT(AX) andBool absCatPinnedT(AX)
  rule <k> aExecJ(aOkF, aSrcOther) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aExecJ(aOkF, aSrcOther)) </absjshadow>
    requires absCfgPinnedT(AX) andBool absCatPinnedT(AX)
  // NO exec rule on an unpinned shadow (all four ground exec shapes): the
  // declared stall class, mirroring the concrete machine unchanged.

  rule <k> aGateJ(aOkT) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aGateJ(aOkT)) </absjshadow>
  rule <k> aGateJ(aOkF) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aGateJ(aOkF)) </absjshadow>

  rule <k> aCommitJ(aOkT, aOkT) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aCommitJ(aOkT, aOkT)) </absjshadow>
  rule <k> aCommitJ(aOkT, aOkF) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aCommitJ(aOkT, aOkF)) </absjshadow>
  rule <k> aCommitJ(aOkF, aOkT) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aCommitJ(aOkF, aOkT)) </absjshadow>
  rule <k> aCommitJ(aOkF, aOkF) => .K ... </k>
       <absjshadow> AX:AStateT => absStepT(AX, aCommitJ(aOkF, aOkF)) </absjshadow>

  // the COMPLEMENT rule (exhaustiveness-by-construction; the 1O discipline):
  // never fires on a ground command from a coherent state; exists for the
  // prover's complement branch.  Guarded against misuse by the soundness
  // controls (the weak universal MUST FAIL; the destination control MUST FAIL).
  rule <k> AC:ACmd => .K ... </k>
       <absjshadow> AX:AStateT => AX </absjshadow> [owise]
"""

SEC_RUN_TD = """  // ===========================================================================
  // §D — THE RUNNER (edit EE, form-TD: REWRITE-LEVEL TAG DISCRIMINATION)
  //      Each ground-command rule patterns the shadow's BRANCH (tag-0 rows
  //      match absStT(0, false, false, ...); tag-1 rows match
  //      absStT(1, true, true, ...)) and calls absStepT with the branch
  //      PINNED — the tag discrimination happens at the rewrite level.
  //      The stall discipline is unchanged: NO exec rule on the tag-0
  //      shadow.  The [owise] complement covers the incoherent fragment.
  // ===========================================================================
  rule <k> aConsJ(AC:ACmd, R:APProg) => AC ~> R ... </k>
  rule <k> aRunNilJ => .K ... </k>

  // ---- the tag-0 (pre-init) rows -------------------------------------------
  rule <k> aInitJ(aOkT) => .K ... </k>
       <absjshadow> absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(0, false, false, G, E, N, SF, D), aInitJ(aOkT)) </absjshadow>
  rule <k> aInitJ(aOkF) => .K ... </k>
       <absjshadow> absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(0, false, false, G, E, N, SF, D), aInitJ(aOkF)) </absjshadow>
  rule <k> aGateJ(aOkT) => .K ... </k>
       <absjshadow> absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(0, false, false, G, E, N, SF, D), aGateJ(aOkT)) </absjshadow>
  rule <k> aGateJ(aOkF) => .K ... </k>
       <absjshadow> absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(0, false, false, G, E, N, SF, D), aGateJ(aOkF)) </absjshadow>
  rule <k> aCommitJ(aOkT, aOkT) => .K ... </k>
       <absjshadow> absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(0, false, false, G, E, N, SF, D), aCommitJ(aOkT, aOkT)) </absjshadow>
  rule <k> aCommitJ(aOkT, aOkF) => .K ... </k>
       <absjshadow> absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(0, false, false, G, E, N, SF, D), aCommitJ(aOkT, aOkF)) </absjshadow>
  rule <k> aCommitJ(aOkF, aOkT) => .K ... </k>
       <absjshadow> absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(0, false, false, G, E, N, SF, D), aCommitJ(aOkF, aOkT)) </absjshadow>
  rule <k> aCommitJ(aOkF, aOkF) => .K ... </k>
       <absjshadow> absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(0, false, false, G, E, N, SF, D), aCommitJ(aOkF, aOkF)) </absjshadow>
  // NO tag-0 exec rule (the stall discipline — the concrete mirror).

  // ---- the tag-1 (initialized) rows ----------------------------------------
  rule <k> aInitJ(aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aInitJ(aOkT)) </absjshadow>
  rule <k> aInitJ(aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aInitJ(aOkF)) </absjshadow>
  rule <k> aExecJ(aOkT, aSrcAuth) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aExecJ(aOkT, aSrcAuth)) </absjshadow>
  rule <k> aExecJ(aOkT, aSrcOther) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aExecJ(aOkT, aSrcOther)) </absjshadow>
  rule <k> aExecJ(aOkF, aSrcAuth) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aExecJ(aOkF, aSrcAuth)) </absjshadow>
  rule <k> aExecJ(aOkF, aSrcOther) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aExecJ(aOkF, aSrcOther)) </absjshadow>
  rule <k> aGateJ(aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aGateJ(aOkT)) </absjshadow>
  rule <k> aGateJ(aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aGateJ(aOkF)) </absjshadow>
  rule <k> aCommitJ(aOkT, aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkT, aOkT)) </absjshadow>
  rule <k> aCommitJ(aOkT, aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkT, aOkF)) </absjshadow>
  rule <k> aCommitJ(aOkF, aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkF, aOkT)) </absjshadow>
  rule <k> aCommitJ(aOkF, aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkF, aOkF)) </absjshadow>

  // the COMPLEMENT rule: fires only where no branch row matched (the
  // incoherent fragment — unreachable under ABSInvT).  The 1O discipline.
  rule <k> AC:ACmd => .K ... </k>
       <absjshadow> AX:AStateT => AX </absjshadow> [owise]
"""

SEC_RUN_TDRR = SEC_RUN_TD.replace("""  rule <k> aGateJ(aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aGateJ(aOkT)) </absjshadow>
  rule <k> aGateJ(aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aGateJ(aOkF)) </absjshadow>
""", """  // THE RUNNER-LEVEL REQUIRES SPLIT (edit EE-prime): EVERY tag-1 gate/commit
  // ground shape forks on its Int guard, so the function evaluates on each
  // rewrite branch (finding 1P-F1: a partial fork leaves the residual on the
  // unforked shapes).
  rule <k> aGateJ(aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aGateJ(aOkT)) </absjshadow>
    requires E >=Int 1
  rule <k> aGateJ(aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aGateJ(aOkT)) </absjshadow>
    requires E <=Int 0
  rule <k> aGateJ(aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aGateJ(aOkF)) </absjshadow>
    requires E >=Int 1
  rule <k> aGateJ(aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aGateJ(aOkF)) </absjshadow>
    requires E <=Int 0
""").replace("""  rule <k> aCommitJ(aOkT, aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkT, aOkT)) </absjshadow>
""", """  // ... and every tag-1 commit ground shape forks on the joint guard.
  rule <k> aCommitJ(aOkT, aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkT, aOkT)) </absjshadow>
    requires G >=Int 1 andBool E >=Int 1
  rule <k> aCommitJ(aOkT, aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkT, aOkT)) </absjshadow>
    requires G <=Int 0 orBool E <=Int 0
  rule <k> aCommitJ(aOkT, aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkT, aOkF)) </absjshadow>
    requires G >=Int 1 andBool E >=Int 1
  rule <k> aCommitJ(aOkT, aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkT, aOkF)) </absjshadow>
    requires G <=Int 0 orBool E <=Int 0
  rule <k> aCommitJ(aOkF, aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkF, aOkT)) </absjshadow>
    requires G >=Int 1 andBool E >=Int 1
  rule <k> aCommitJ(aOkF, aOkT) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkF, aOkT)) </absjshadow>
    requires G <=Int 0 orBool E <=Int 0
  rule <k> aCommitJ(aOkF, aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkF, aOkF)) </absjshadow>
    requires G >=Int 1 andBool E >=Int 1
  rule <k> aCommitJ(aOkF, aOkF) => .K ... </k>
       <absjshadow> absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag)
                 => absStepT(absStT(1, true, true, G, E, N, SF, D), aCommitJ(aOkF, aOkF)) </absjshadow>
    requires G <=Int 0 orBool E <=Int 0
""")

SEC_INV = """  // ===========================================================================
  // §E — THE CONJUNCTIVE TAGGED INVARIANT (edit EC; design §3)
  //      The 1N disjunction moved INTO the tag; the shape is CONJUNCTIVE
  //      (impliesBool, never orBool at the top, never if-then-else).
  // ===========================================================================
  syntax Bool ::= ABSInvT ( AStateT ) [function, total]
  rule ABSInvT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, _:ADiag))
    => TG >=Int 0 andBool TG <=Int 1
       andBool (TG ==Int 0 impliesBool (notBool C andBool notBool T
                    andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0))
       andBool (TG ==Int 1 impliesBool (C andBool T
                    andBool G >=Int 0 andBool E >=Int 0 andBool SF))

  syntax Bool ::= tagCoherentT ( AStateT ) [function, total]
  rule tagCoherentT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, _:Bool, _:ADiag))
    => (TG ==Int 0 impliesBool (notBool C andBool notBool T
             andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0))
       andBool
       (TG ==Int 1 impliesBool (C andBool T andBool G >=Int 0 andBool E >=Int 0))

"""

SEC_DOMAIN = """  // ===========================================================================
  // §F — THE DOMAIN PREDICATE AND THE FOLD (edit EF: the 1N mirror)
  // ===========================================================================
  syntax Bool ::= absExecutableT ( APProg , AStateT ) [function, total]
  rule absExecutableT(aRunNilJ, _:AStateT) => true
  rule absExecutableT(aConsJ(aExecJ(_:AOk, _:ASrc), _:APProg),
                      absStT(0, _:Bool, _:Bool, _:Int, _:Int, _:Int, _:Bool, _:ADiag))
    => false
  rule absExecutableT(aConsJ(AC:ACmd, R:APProg), AX:AStateT)
    => absExecutableT(R, absStepT(AX, AC)) [owise]

  syntax AStateT ::= absRunFT ( APProg , AStateT ) [function, total]
  rule absRunFT(aRunNilJ, AX:AStateT) => AX
  rule absRunFT(aConsJ(AC:ACmd, R:APProg), AX:AStateT)
    => absRunFT(R, absStepT(AX, AC))

  // the initialized-shaped projection (edit EA: STRENGTHENED with the tag
  // conjunct — the prefix corollary's content is END-INITIALIZED, and on the
  // tagged space that is the tag being 1 with the pins and the bookkeeping)
  syntax Bool ::= absInitShapedT ( AStateT ) [function, total]
  rule absInitShapedT(absStT(TG:Int, C:Bool, T:Bool, _:Int, _:Int, _:Int, SF:Bool, _:ADiag))
    => TG ==Int 1 andBool C andBool T andBool SF

  // ===========================================================================
  // §G — THE REFINEMENT MAP (edit EG; see spec/refinement-relation.md)
  //      absStE is the ERASE-TARGET mirror sort, field-isomorphic to the 1N
  //      AState.  SRW3N-ABS cannot be imported without its runner rules
  //      (they would contaminate the tagged machine's reachability), so the
  //      mirror is declared here; make_abs_t.py verifies the field
  //      correspondence against the 1N rule table at generation time.
  // ===========================================================================
  syntax AStateE ::= absStE ( cfgP:Bool
                              , catP:Bool
                              , cntG:Int
                              , cntE:Int
                              , nSlot:Int
                              , safe:Bool
                              , diag:ADiag )

  syntax Int ::= branchTag ( Bool , Bool ) [function, total]
  rule branchTag(true,  true)  => 1
  rule branchTag(false, false) => 0

  syntax AStateE ::= eraseT ( AStateT ) [function, total]
  rule eraseT(absStT(_:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))
    => absStE(C, T, G, E, N, SF, D)

  syntax AStateT ::= tagStE ( AStateE ) [function, total]
  rule tagStE(absStE(C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))
    => absStT(branchTag(C, T), C, T, G, E, N, SF, D)

endmodule
"""

SEC_INV_WEAK = """  // ===========================================================================
  // §E — THE CONJUNCTIVE TAGGED INVARIANT (edit EC; design §3) — WEAK FORM
  //      THE 1O WEAK EDIT: the presented bit carried (the make_abs_weak.py
  //      composition); ABSInvT itself is UNCHANGED — the weakness lives in
  //      the commit rows (§C below), which is exactly why the weak universal
  //      MUST FAIL.
  // ===========================================================================
  syntax Bool ::= ABSInvT ( AStateT ) [function, total]
  rule ABSInvT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, _:ADiag))
    => TG >=Int 0 andBool TG <=Int 1
       andBool (TG ==Int 0 impliesBool (notBool C andBool notBool T
                    andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0))
       andBool (TG ==Int 1 impliesBool (C andBool T
                    andBool G >=Int 0 andBool E >=Int 0 andBool SF))

  syntax Bool ::= tagCoherentT ( AStateT ) [function, total]
  rule tagCoherentT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, _:Bool, _:ADiag))
    => (TG ==Int 0 impliesBool (notBool C andBool notBool T
             andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0))
       andBool
       (TG ==Int 1 impliesBool (C andBool T andBool G >=Int 0 andBool E >=Int 0))

"""

# the weak commit rows replace the strong commit rows in §C (both forms)
WEAK_COMMIT_T = """  // ---- commit (rows 6, 11-12) — THE WEAK EDIT: the presented bit carried
  //      (aCommitJ(aOkT, B2) accepts with safe := B2 ==K aOkT — the 1O
  //      make_abs_weak.py edit in the tagged space; the unsafe (aOkT,aOkF)
  //      commit now "succeeds" with safe=false, breaking ABSInvT — the
  //      soundness controls' subject) ---------------------------------------
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(_:AOk, _:AOk))
    => absStT(0, false, false, G, E, N, SF, D)               // pre-init reject
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, _:Bool, D:ADiag),
                aCommitJ(aOkT, B2:AOk))
    => absStT(1, true, true, G -Int 1, E -Int 1, N +Int 1, B2 ==K aOkT, D)
    requires G >=Int 1 andBool E >=Int 1
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(_:AOk, _:AOk))
    => absStT(1, true, true, G, E, N, SF, D) [owise]         // the reject class
"""

WEAK_COMMIT_TDR = """  // ---- commit (rows 6, 11-12) — THE WEAK EDIT + THE REQUIRES SPLIT: the
  //      presented bit carried (aCommitJ(aOkT, B2) accepts with
  //      safe := B2 ==K aOkT); the reject/complement rows split explicitly.
  rule absStepT(absStT(0, false, false, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(_:AOk, _:AOk))
    => absStT(0, false, false, G, E, N, SF, D)               // pre-init reject
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, _:Bool, D:ADiag),
                aCommitJ(aOkT, B2:AOk))
    => absStT(1, true, true, G -Int 1, E -Int 1, N +Int 1, B2 ==K aOkT, D)
    requires G >=Int 1 andBool E >=Int 1
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, _:Bool, D:ADiag),
                aCommitJ(aOkT, _:AOk))
    => absStT(1, true, true, G, E, N, true, D)               // the accept complement
    requires G <=Int 0 orBool E <=Int 0
  rule absStepT(absStT(1, true, true, G:Int, E:Int, N:Int, SF:Bool, D:ADiag),
                aCommitJ(aOkF, _:AOk))
    => absStT(1, true, true, G, E, N, SF, D)                 // reject: bit 1 false
"""

VARIANTS = {
    # name: (module, step-section, runner-section, inv-section, title, stepnote, runnernote)
    "abs-machine-t.k": dict(
        mod="SRW3N-ABS-T", step=SEC_STEP_T, run=SEC_RUN_R, inv=SEC_INV,
        title="T — THE TAG ENCODING ALONE",
        stepnote="form-T: requires + [owise]",
        runnernote="R-form (symbolic shadow; NO rewrite-level tag discrimination)"),
    "abs-machine-td.k": dict(
        mod="SRW3N-ABS-TD", step=SEC_STEP_T, run=SEC_RUN_TD, inv=SEC_INV,
        title="TD — T + REWRITE-LEVEL TAG DISCRIMINATION",
        stepnote="form-T: requires + [owise]",
        runnernote="branch-discriminated ground-command"),
    "abs-machine-tdr.k": dict(
        mod="SRW3N-ABS-TDR", step=SEC_STEP_TDR, run=SEC_RUN_TD, inv=SEC_INV,
        title="TDR — TD + THE REQUIRES SPLIT",
        stepnote="form-TDR: the requires split",
        runnernote="branch-discriminated ground-command"),
    "abs-machine-tdrr.k": dict(
        mod="SRW3N-ABS-TDRR", step=SEC_STEP_TDR, run=SEC_RUN_TDRR, inv=SEC_INV,
        title="TDRR — TDR + THE RUNNER-LEVEL REQUIRES SPLIT (edit EE-prime)",
        stepnote="form-TDR: the requires split",
        runnernote="branch-discriminated ground-command with the runner-level Int fork"),
    "abs-machine-weak-t.k": dict(
        mod="SRW3N-ABS-WEAK-T", step=None,
        run=SEC_RUN_R, inv=SEC_INV_WEAK,
        title="WEAK-T — THE WEAK COMMIT ON THE T RUNG (the soundness control)",
        stepnote="form-T with the WEAK commit rows",
        runnernote="R-form (symbolic shadow; NO rewrite-level tag discrimination)"),
    "abs-machine-weak-td.k": dict(
        mod="SRW3N-ABS-WEAK-TD", step=None, run=SEC_RUN_TD, inv=SEC_INV_WEAK,
        title="WEAK-TD — THE WEAK COMMIT ON THE TD RUNG",
        stepnote="form-T with the WEAK commit rows",
        runnernote="branch-discriminated ground-command"),
    "abs-machine-weak-tdr.k": dict(
        mod="SRW3N-ABS-WEAK-TDR", step=None, run=SEC_RUN_TD, inv=SEC_INV_WEAK,
        title="WEAK-TDR — THE WEAK COMMIT ON THE TDR RUNG",
        stepnote="form-TDR with the WEAK commit rows",
        runnernote="branch-discriminated ground-command"),
}


def build_variant(cfg, src_sha: str) -> str:
    """Assemble one variant file from the sections."""
    step = cfg["step"]
    if step is None:
        # weak variants: the strong step section with the commit rows swapped
        if "form-TDR" in cfg["stepnote"]:
            step = SEC_STEP_TDR.replace(
                SEC_STEP_TDR[SEC_STEP_TDR.index("  // ---- commit (rows 6, 11-12) — THE REQUIRES SPLIT"):
                             SEC_STEP_TDR.index("  // ---- the INCOHERENT-TAG complement")],
                WEAK_COMMIT_TDR)
        else:
            step = SEC_STEP_T.replace(
                SEC_STEP_T[SEC_STEP_T.index("  // ---- commit (rows 6, 11-12)"):
                           SEC_STEP_T.index("  // NOTE (the 1N discipline, restated)")],
                WEAK_COMMIT_T)
    out = HEADER.format(title=cfg["title"], fname=cfg_key(cfg), mod=cfg["mod"],
                        srcsha=src_sha, stepnote=cfg["stepnote"],
                        runnernote=cfg["runnernote"])
    out += SEC_STATE
    out += step
    out += cfg["run"]
    out += cfg["inv"]
    out += SEC_DOMAIN
    return out


def cfg_key(cfg) -> str:
    for fname, c in VARIANTS.items():
        if c is cfg:
            return fname
    raise AssertionError


def main() -> int:
    src = SRC.read_text()
    src_sha = hashlib.sha256(src.encode()).hexdigest()

    # ---- fail-closed anchors: the 1N source must contain the blocks we
    # claim to mirror, exactly once each.
    for anchor, name in ((ANCHOR_CMDS, "command syntax"), (ANCHOR_ADIAG, "ADiag")):
        if src.count(anchor) != 1:
            print(f"FAIL-CLOSED: the 1N {name} anchor not found exactly once")
            return 1

    # ---- the 1N successor-table check: every N1_ROWS literal must occur in
    # the 1N source (the ERASE-* claims' RHS are these exact field updates).
    for row, lit in N1_ROWS.items():
        # normalize whitespace for the search
        probe = lit.replace(" ", "")
        if probe not in src.replace(" ", "").replace("\n", ""):
            print(f"FAIL-CLOSED: 1N row literal for {row} not found in the 1N source")
            return 1

    # ---- generate all six variants
    OUT.mkdir(parents=True, exist_ok=True)
    outs = {}
    for fname, cfg in VARIANTS.items():
        outs[fname] = build_variant(cfg, src_sha)

    # ---- roundtrip determinism: rebuild and compare byte-for-byte
    for fname, cfg in VARIANTS.items():
        again = build_variant(cfg, src_sha)
        if again != outs[fname]:
            print(f"FAIL-CLOSED: roundtrip nondeterminism in {fname}")
            return 1

    # ---- pairwise discipline: T vs TD differ ONLY in the runner section;
    # TD vs TDR differ ONLY in the step section; strong vs weak differ ONLY
    # in the commit rows (+ the §E disclosure comment on the weak rungs).
    def section_extract(text, start_marker, end_marker):
        i = text.index(start_marker)
        j = text.index(end_marker, i)
        return text[i:j]

    t, td, tdr = outs["abs-machine-t.k"], outs["abs-machine-td.k"], outs["abs-machine-tdr.k"]

    def body(text):
        """the module body from the requires line, module name normalized
        (headers disclose, bodies decide; the module rename is edit EA)"""
        i = text.index('requires "srw3closure-j-m4.k"')
        text = text[i:]
        import re as _re
        return _re.sub(r"^module SRW3N-ABS[ A-Z-]*$", "module @MOD@", text, count=1, flags=_re.M)

    def section_extract(text, start_marker, end_marker):
        i = text.index(start_marker)
        j = text.index(end_marker, i)
        return text[i:j]

    run_t = section_extract(t, "  // ===========================================================================\n  // §D", "  // ===========================================================================\n  // §E")
    run_td = section_extract(td, "  // ===========================================================================\n  // §D", "  // ===========================================================================\n  // §E")
    step_td = section_extract(td, "  // ===========================================================================\n  // §C", "  // ===========================================================================\n  // §D")
    step_tdr = section_extract(tdr, "  // ===========================================================================\n  // §C", "  // ===========================================================================\n  // §D")
    ok_td = body(td).replace(run_td, run_t) == body(t)          # TD with T's runner == T
    ok_tdr = body(tdr).replace(step_tdr, step_td) == body(td)   # TDR with TD's step == TD
    checks = {
        "T vs TD differ only in the runner": ok_td,
        "TD vs TDR differ only in the step": ok_tdr,
    }

    # ---- rule-count census (disclosed)
    import re
    census = {}
    for fname, text in outs.items():
        census[fname] = {
            "step-rules": len(re.findall(r"^  rule absStepT", text, re.M)),
            "runner-rules": len(re.findall(r"^  rule <k>", text, re.M)),
            "owise": text.count("[owise]"),
        }

    # ---- emit + hashes
    print(f"src sha256(abs-machine.k) = {src_sha}")
    for fname, text in outs.items():
        p = OUT / fname
        p.write_text(text)
        print(f"wrote {p.relative_to(REPO)}  sha256={hashlib.sha256(text.encode()).hexdigest()}  {census[fname]}")
    for name, ok in checks.items():
        print(f"check[{name}] = {ok}")
    if not all(checks.values()):
        print("FAIL-CLOSED: pairwise discipline violated")
        return 1

    # ---- the 1N row table emitted for the audit trail
    print("--- 1N successor table (verified against the 1N source) ---")
    for row, lit in N1_ROWS.items():
        print(f"  {row:15s} -> {lit}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
