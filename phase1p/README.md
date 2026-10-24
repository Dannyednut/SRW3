# SRW3 Phase 1P — Branch-Tagged Invariants and Universal Transition Preservation

**Status: RECONSTRUCTION r2 — COMPLETE AS AN EXPERIMENT; the universal
theorem's disposition is whatever `transcripts/k/score-p.txt` says (the raw
results decide, never the gate color).**

The r1 tree was lost to a sandbox reset before any commit (see
`spec/branch-tag-design.md` §0 and `audit/baseline-1p.txt` §0).  This tree
re-derives the phase from the recorded design and re-executes everything
fresh under the pinned toolchain (K v7.1.337 + z3 4.13.3) on the fresh clone
at the 1O freeze (cdb5556).

## The experiment in one paragraph

Phase 1O located the exact blocker of the machine-form universal theorem
(kprove case-splits rewrite-position constructor variables, never
function-argument ones, and its implication checker cannot evaluate a
pattern-matched function under a disjunctive state constraint).  Phase 1P
makes the invariant's two branches an EXPLICIT, SOLVABLE component of the
state — an integer branch tag — so the invariant becomes CONJUNCTIVE and the
branch becomes a first-class value the rewrite engine can select on.  The
ladder T → TD → TDR adds exactly one mechanism per rung:

| rung | module | mechanism | runner |
|------|--------|-----------|--------|
| T    | `SRW3N-ABS-T`    | the conjunctive tagged invariant alone | R-form (symbolic shadow) |
| TD   | `SRW3N-ABS-TD`   | + rewrite-level tag discrimination | branch-discriminated ground commands |
| TDR  | `SRW3N-ABS-TDR`  | + the requires split (explicit Int complements) | branch-discriminated ground commands |

The weak variants (`SRW3N-ABS-WEAK-{T,TD,TDR}`) carry the 1O weak-commit
edit (the presented bit carried) — the soundness controls' subject: the
weak universal MUST FAIL.

## Layout

    spec/branch-tag-design.md      the design + the r1 expectations
    spec/refinement-relation.md    eraseT/tagStE/branchTag + the CORR families
    scripts/make_abs_t.py          the fail-closed generator (edits EA-EH,
                                   roundtrip-deterministic; pairwise discipline)
    scripts/make_mutants_1p.py     the two mutants (one per kompile target)
    semantics/abs-machine-*.k      the six tagged variants (GENERATED — do not edit)
    tests/abs-machine-mut-*.k      the mutants (GENERATED — do not edit)
    proofs/n_p_univ_{t,td,tdr}.k   the ladder attempts + DEST/run/unsafe controls
    proofs/n_p_lemmas_tdr.k        P1(3) + PRESV(21) + COH(14) + CORR(14) + TLR
    proofs/n_p_lemmas_t.k          the 5-claim T-machine smoke subset
    proofs/n_p_univ_weak_t.k       the weak-machine soundness controls
    proofs/n_p_diag_tdr.k          the NIL/CONS budget diagnostics
    proofs/n_p_neg_mut_{stale,flip}.k  the mutation controls (MUST FAIL)
    proofs/n_p_neg_self.k          the PASS-EVAL guard-hole probe (on purpose)
    proofs/repro/univ-repro-t.k    the tagged toy (T1-T4 + T4b) — the r1
                                   session's UNREAD result, produced here
    proofs/run_p_univ.sh           the fail-closed runner (stages K/B/R/L/U/D/N/P)
    transcripts/k/                 raw per-claim logs + claims-status-p.csv + score-p.txt
    claims/claims.csv              the curated claim inventory (r2 results)
    audit/baseline-1p.txt          the reconstruction + baseline audit record
    report/phase1p-final-report.md the phase report

## Reproduce

    source /home/z/my-project/tools/env.sh
    export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
    python3 phase1p/scripts/make_abs_t.py && python3 phase1p/scripts/make_mutants_1p.py
    bash phase1p/proofs/run_p_univ.sh

Level III only; no consensus-integration claim.
