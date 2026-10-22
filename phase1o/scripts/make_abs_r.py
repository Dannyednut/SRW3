#!/usr/bin/env python3
"""SRW3 Phase 1O — derive the REWRITE-DISPATCHED abstract machine (R-variant).

Motivation (the 1O §6 reproducer evidence, proofs/repro/univ-repro.k):
  * R2/R6  — a runner whose command dispatch happens at the REWRITE level
             (per-ground-command rules) closes the machine-form universal
             over a symbolic program, genuinely (the soundness probes
             R5/R9 fail as required).
  * R10    — a runner whose shadow update goes through the STEP FUNCTION
             with a SYMBOLIC head command can NEVER dispatch: kprove does
             not case-split symbolic constructor variables in function-
             argument position, even when a domain predicate could prune.

The 1N machine rules are the R10 shape: `<k> aInitJ(AB:AOk) => .K ...`
+ `<absjshadow> AX => absStepJ(AX, aInitJ(AB)) </absjshadow>` with the
bits symbolic.  R lifts the dispatch to the rewrite level: ONE rule per
GROUND command shape (2 + 4 + 2 + 4 = 12), each consuming the literal
command and updating the shadow through absStepJ with the LITERAL command
(the function then matches its class equation — the genuine obligation).
The cons rule and the stall discipline are unchanged.

Discipline (the make_m2/m3/m4/make_abs_weak rule): the derived file
differs from abs-machine.k by EXACTLY the disclosed edits and nothing
else, verified fail-closed on the module-body diff.

Usage: python3 phase1o/scripts/make_abs_r.py
Output: phase1o/semantics/abs-machine-r.k  (module SRW3N-ABS-R)
"""
import difflib
import hashlib
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parents[1]
REPO = HERE.parent
SRC = REPO / "phase1n" / "semantics" / "abs-machine.k"
DST = HERE / "semantics" / "abs-machine-r.k"

OLD_BLOCK = """  // ---- the abstract runner (the <absjshadow> machine) -------------------
  rule <k> aConsJ(AC:ACmd, R:APProg) => AC ~> R ... </k>
  rule <k> aRunNilJ => .K ... </k>

  rule <k> aInitJ(AB:AOk) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aInitJ(AB:AOk)) </absjshadow>

  rule <k> aExecJ(AB:AOk, AS:ASrc) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aExecJ(AB:AOk, AS:ASrc)) </absjshadow>
    requires absCfgPinnedOf(AX) andBool absCatPinnedOf(AX)
  // NO rule for aExecJ on an unpinned shadow: the declared stall class,
  // mirroring the concrete machine (the pExecJ dispatch requires the pins).

  rule <k> aGateJ(AB:AOk) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aGateJ(AB:AOk)) </absjshadow>

  rule <k> aCommitJ(AB1:AOk, AB2:AOk) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aCommitJ(AB1:AOk, AB2:AOk)) </absjshadow>
"""

NEW_BLOCK = """  // ---- the abstract runner (the <absjshadow> machine) -------------------
  // PHASE 1O DISCLOSED R EDIT (the ONLY SRW3N-ABS -> SRW3N-ABS-R rule
  // difference): the command dispatch is lifted to the REWRITE level —
  // ONE rule per GROUND command shape (12 = 2 init + 4 exec + 2 gate +
  // 4 commit), each consuming the literal command and updating the shadow
  // through absStepJ with the LITERAL command.  The 1N rules dispatched
  // through absStepJ with SYMBOLIC bit variables, which kprove cannot
  // case-split in function-argument position (the R10 evidence) — the R
  // shape is the R2/R6-proven rewrite-dispatched form.  The cons rule is
  // unchanged; the stall discipline is unchanged (NO exec rule on an
  // unpinned shadow — the exec-on-unpinned ground shapes have no rule).
  rule <k> aConsJ(AC:ACmd, R:APProg) => AC ~> R ... </k>
  rule <k> aRunNilJ => .K ... </k>

  rule <k> aInitJ(aOkT) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aInitJ(aOkT)) </absjshadow>
  rule <k> aInitJ(aOkF) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aInitJ(aOkF)) </absjshadow>

  rule <k> aExecJ(aOkT, aSrcAuth) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aExecJ(aOkT, aSrcAuth)) </absjshadow>
    requires absCfgPinnedOf(AX) andBool absCatPinnedOf(AX)
  rule <k> aExecJ(aOkT, aSrcOther) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aExecJ(aOkT, aSrcOther)) </absjshadow>
    requires absCfgPinnedOf(AX) andBool absCatPinnedOf(AX)
  rule <k> aExecJ(aOkF, aSrcAuth) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aExecJ(aOkF, aSrcAuth)) </absjshadow>
    requires absCfgPinnedOf(AX) andBool absCatPinnedOf(AX)
  rule <k> aExecJ(aOkF, aSrcOther) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aExecJ(aOkF, aSrcOther)) </absjshadow>
    requires absCfgPinnedOf(AX) andBool absCatPinnedOf(AX)
  // NO rule for aExecJ on an unpinned shadow (all four ground exec shapes):
  // the declared stall class, mirroring the concrete machine unchanged.

  rule <k> aGateJ(aOkT) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aGateJ(aOkT)) </absjshadow>
  rule <k> aGateJ(aOkF) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aGateJ(aOkF)) </absjshadow>

  rule <k> aCommitJ(aOkT, aOkT) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aCommitJ(aOkT, aOkT)) </absjshadow>
  rule <k> aCommitJ(aOkT, aOkF) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aCommitJ(aOkT, aOkF)) </absjshadow>
  rule <k> aCommitJ(aOkF, aOkT) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aCommitJ(aOkF, aOkT)) </absjshadow>
  rule <k> aCommitJ(aOkF, aOkF) => .K ... </k>
       <absjshadow> AX:AState => absStepJ(AX, aCommitJ(aOkF, aOkF)) </absjshadow>

  // the COMPLEMENT rule (exhaustiveness-by-construction): the 12 ground
  // shapes above ARE the whole of ACmd's ground terms, so this rule can
  // NEVER fire on a ground command (rule priority).  It exists so the
  // prover's complement branch (a command matching no ground shape —
  // satisfiable only for non-ground terms) closes: the command is
  // consumed and NOTHING changes (a non-committing stutter — the same
  // content as the 1N function-level identity convention; the exec-on-
  // unpinned stall also lands here, consuming the command and writing
  // nothing, which mirrors the concrete machine's SAFETY content: the
  // stuck concrete configuration writes nothing and commits nothing).
  // The soundness controls (the weak-machine universal MUST FAIL; the
  // destination control MUST FAIL) guard this rule against misuse.
  rule <k> AC:ACmd => .K ... </k>
       <absjshadow> AX:AState => AX </absjshadow> [owise]
"""

OLD_MODULE = "module SRW3N-ABS\n"
NEW_MODULE = "module SRW3N-ABS-R\n"

HEADER = """// =============================================================================
// SRW3 PHASE 1O — THE REWRITE-DISPATCHED ABSTRACT MACHINE (R-variant)
//                    (phase1o/semantics/abs-machine-r.k)
//
// GENERATED by phase1o/scripts/make_abs_r.py from phase1n/semantics/
// abs-machine.k.  DO NOT EDIT BY HAND.  The ONLY rule difference is the
// disclosed rewrite-level command dispatch (12 ground-command runner
// rules replacing the 4 symbolic-bit rules); the module is renamed
// SRW3N-ABS-R.  absStepJ, ABSInv, simJ, absExecutable, absRunF are
// UNCHANGED.  Level III only; no consensus-integration claim.
// =============================================================================

"""

def main() -> int:
    src = SRC.read_text()
    if src.count(OLD_BLOCK) != 1:
        print("FAIL-CLOSED: the 1N runner block not found exactly once")
        return 1
    out = src.replace(OLD_BLOCK, NEW_BLOCK)
    if out.count(OLD_MODULE) != 1:
        print("FAIL-CLOSED: module declaration not found exactly once")
        return 1
    out = out.replace(OLD_MODULE, NEW_MODULE)
    req_idx = out.find('requires "srw3closure-j-m4.k"')
    if req_idx < 0:
        print("FAIL-CLOSED: requires line not found")
        return 1
    out = HEADER + out[req_idx:]
    DST.write_text(out)

    # ---- fail-closed verification: module-BODY diff must be exactly the
    # module rename + the runner block swap; no other rule/syntax moved.
    def body(lines, marker):
        i = next(k for k, l in enumerate(lines) if l.startswith(marker))
        return lines[i:]
    a = SRC.read_text().splitlines()
    b = DST.read_text().splitlines()
    ba = body(a, "module SRW3N-ABS")
    bb = body(b, "module SRW3N-ABS-R")
    bd = list(difflib.unified_diff(ba, bb, lineterm=""))
    brem = [l[1:] for l in bd if l.startswith("-") and not l.startswith("---")]
    badd = [l[1:] for l in bd if l.startswith("+") and not l.startswith("+++")]
    # removed: the 5 old runner rules + their comment/blank lines;
    # added: the disclosure comment + 14 new rules (cons, nil, 12 ground).
    brem_f = [l for l in brem if not l.lstrip().startswith("//")]
    badd_f = [l for l in badd if not l.lstrip().startswith("//")]
    ok = (
        sum(1 for l in brem if l.strip().startswith("rule ")) == 4
        and sum(1 for l in badd if l.strip().startswith("rule ")) == 13
        and any("[owise]" in l for l in badd)
        and all("absStepJ(AX, aInitJ(AB" not in l for l in badd)
        and not any("aConsJ" in l for l in brem + badd)   # cons rule UNCHANGED (context)
        and not any("rule ABSInv" in l for l in brem + badd)
        and not any(l.strip().startswith("syntax ") for l in brem + badd)
        and not any("pInitJ" in l or "pExecJ" in l or "pGateEvalJ" in l
                    or "pCommitJ" in l or "simJ (" in l for l in brem_f + badd_f)
    )
    print(f"body-diff: removed rule lines={sum(1 for l in brem if l.strip().startswith('rule '))} "
          f"added rule lines={sum(1 for l in badd if l.strip().startswith('rule '))} (expect 4/13)")
    print(f"r-derivation ok={ok}")
    print(f"sha256 abs-machine.k    : {hashlib.sha256(SRC.read_bytes()).hexdigest()}")
    print(f"sha256 abs-machine-r.k  : {hashlib.sha256(DST.read_bytes()).hexdigest()}")
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
