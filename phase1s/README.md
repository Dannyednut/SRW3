# SRW3 Phase 1S — Constructor-Count Refinement and Transition Coverage

**Branch:** `phase1s-refinement-coverage` (from the verified Phase 1R
commit `29e7cee92acf572fb1094e2db5289dc3f65794d3`).
**Toolchain:** K v7.1.337 + z3 4.13.3 (the pinned recipe, rebuilt after the
ninth sandbox reset; see `audit/baseline-1s.md`).
**Question of record:** can the Phase 1R universal safety theorem over the
constructor-count machine be MIGRATED to the original integer-count model
by mechanized, honestly-classified state and transition correspondences —
or does the abstract result rest on properties not yet connected to the
integer model?

**Verdict of record:** **PARTIALLY COMPLETE.** The migration theorem is
MECHANIZED (`1S-MIGRATE-UNIV-C12ASSUMED`, rc=0 in 12 s) under the
explicitly disclosed C1.2 nonnegativity assumption; unconditionally it
fails at exactly one mechanized residual — the commit-accept strip state's
`countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0` — the structural
induction boundary recorded since 1O. Everything else the migration needs
(the relations, the count eliminations, the exact increment/decrement/
empty correspondences, the per-class transition correspondence, the
coverage partition, the mutant detection) closes on the pinned toolchain.
Five-state separation maintained throughout.

## Layout

| path | content |
|---|---|
| `spec/state-correspondence.md` | §2: CountRel, qToQE, StateRel; the field-by-field disclosure; the TCB-1 statement; not-a-bisimulation discipline |
| `spec/count-semantics.md` | §3: the C1.1–C1.5 statements, dispositions, and the measured dependence ledger |
| `spec/transition-coverage.md` | §5: the cell table, the guard grid, the exclusivity pairs, the TCB-2 boundary, the mutant control |
| `semantics/rel-machine.k` | the ADDITIVE relation module (GENERATED — do not edit): CountRel, qToQE, StateRel |
| `proofs/n_s_count_semantics.k` | §3 battery: C1.1, the C1.2 attempt + cases + slack, the image/genesis lemmas |
| `proofs/n_s_c12_family.k` | the GENERATED bounded C1.2 depth family d=0..5 |
| `proofs/n_s_correspondence.k` | §4 battery: the per-class image correspondences + the invariant-preservation cells + the NODEP probes |
| `proofs/n_s_coverage.k` | §5 battery (GENERATED): the ground cells, the guard grid, the exclusivity pairs, the domain anchors |
| `proofs/n_s_migrate.k` | §6: the UNCONDITIONED migration attempt (the C1.2 residual of record), the destination falsity controls, the separation witness |
| `proofs/n_s_migrate_c12.k` | §6: the migration under the DISCLOSED C1.2 simplification — THE CLOSURE |
| `proofs/run_1s.sh` | the fail-closed runner (stages GEN/KD/CS/CF/CO/CV/MG1–MG4/NG/NM/NT/S) |
| `tests/` | §7: the negative battery, the weak-machine control, the OMIT mutant (generated) |
| `scripts/` | the generators (rel, c12-family, coverage, mutant — all fail-closed, roundtrip-verified), the static row witness, the summarizer, the ledger builder |
| `claims/claims.csv` | the 103-row ledger (stable ids, exact propositions, budgets, exit codes, classifications) |
| `claims/exit-codes-1s.csv` | the runner's raw exit/wall records (last-wins) |
| `transcripts/k/` | every raw kprove log (102 files) |
| `transcripts/probes/` | the frontend probes (dual-import infeasibility; the StateRel design-space bisection) |
| `transcripts/1r-repro/` | the §1 baseline reproduction logs (the central theorem + the depth probes) |
| `audit/` | baseline verification, source hashes, the row witness, the coverage table, the frontend probes |
| `report/phase1s-final-report.md` | the 12-element final report |

## The one-command reproduction sequence

```
source /home/z/my-project/tools/env.sh
bash phase1s/proofs/run_1s.sh GEN KD CS CF CO CV MG1 MG2 MG3 MG3B MG4 NG NM NT S
```

(the baseline §1 items additionally:
`phase1s/transcripts/1r-repro/` — see `audit/baseline-1s.md` §2–§3.)

Level III only; no consensus-integration claim.
