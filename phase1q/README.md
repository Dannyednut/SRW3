# SRW3 Phase 1Q — Constructor-Based Pool Counts and Universal Preservation

**Phase:** 1Q — the controlled proof experiment on whether exact
constructor-valued pool counts (`PoolCount ::= zeroP | succP(PoolCount)`)
eliminate the Phase 1P compound-integer-guard obstruction, allowing the
pinned toolchain (K v7.1.337 + z3 4.13.3) to mechanize universal transition
preservation without weakening the invariant or changing the behavior.

**Start:** the verified Phase 1P commit `83dd01571adccb77e51adcf5499c9a2480caaeaf`
(parent = the 1O freeze `cdb5556…`), branch `phase1q-constructor-pools`.

## Layout

| path | content |
|---|---|
| `spec/count-representation.md` | the PoolCount encoding, the row-for-row transition translation, the honesty boundaries |
| `spec/refinement-relation.md` | the erasure map, the coupling, the C1–C5 obligations and their declared proof vehicles |
| `scripts/make_abs_q.py` | the fail-closed generator (roundtrip-verified; source-verified against the frozen 1P TDRR artifact) |
| `scripts/abs-machine-q.tpl` | the reviewed machine template (every line part of the disclosed edit set EQ-A..EQ-H + EQ-F′) |
| `scripts/summarize_1q.py` | the fail-closed summarizer (terminal-aware; the HOLE/UNSOUND-CLOSURE class) |
| `semantics/abs-machine-q.k` | the constructor-count machine of record (GENERATED — do not edit) |
| `semantics/abs-machine-weak-q.k` | the weak variant (W1 presented-bit + W2 empty-pool accept; the soundness battery's subject) |
| `proofs/n_q_univ_q.k` | the universal attempts + the ground executions + the commit controls + the PREFIX corollary of record |
| `proofs/n_q_lemmas_q.k` | P1 / C1 / PRESV(14) / COH(6) / C2(14) / C3 / C4 / C5 / the self-assumption probe |
| `proofs/n_q_neg_weak_q.k` | the weak-machine battery |
| `proofs/n_q_neg_mut_{stale,flip,omit}_q.k` | the mutant battery (one mutant per kompile target — the 1P lesson) |
| `proofs/n_q_diag_eqform.k` | the ==K claim-form vacuity pair + the false-hypothesis probe |
| `proofs/n_q_univ_prefix_unpatched.k` | the circularity-hole exhibit (rc=0 on a semantically false claim; UNSOUND-CLOSURE) |
| `proofs/repro/univ-repro-q.k` | the DIRECT toy (the unforked diagnostic) |
| `proofs/repro/univ-repro-qf.k` | the FORKED toy (the architecture of record at toy scale) |
| `proofs/run_q_univ.sh` | the fail-closed runner (stages K/B/A/L/U/N/M/D/S) |
| `claims/claims.csv` | the complete claim inventory (81 claims; expectation/class/exit-code/note) |
| `transcripts/k/` | the raw per-claim logs + the toolchain rebuild record |
| `audit/baseline-1q.txt` | provenance: repo state, frozen-artifact integrity, the residual reproduction, the disclosed mid-phase corrections |
| `report/phase1q-final-report.md` | the findings and the verdict |

## Reproduce

```
python3 phase1q/scripts/make_abs_q.py
bash phase1q/proofs/run_q_univ.sh K B A L U N M D
python3 phase1q/scripts/summarize_1q.py
```
(The universal claim's full-budget attempt of record ran detached at 3600s;
see the report and `claims/claims.csv` for its exact disposition.)

Level III only; no consensus-integration claim.
