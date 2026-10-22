# SRW3 Phase 1O — Source-Preserved Transitions and Universal Invariant Preservation

**Branch:** `phase1o-source-preserved-transitions` (from the verified
Phase 1N checkpoint `f2ee43dc57e879155b7de68399e09a3ca220333e`).
**Verdict of record:** `PARTIALLY COMPLETE — UNIVERSAL THEOREM NOT
MECHANIZED (with the obstruction re-located and precisely characterized)`.
No completion tag exists. Level III only; no consensus-integration claim.

## Scope

The research direction (Source-Preserved Transitions): an application may
specialize its behavior and produce changing states, but every accepted
transition must preserve foundational security properties defined
independently of the application. Phase 1O (i) audited the Phase 1N
evidence, (ii) formalized the foundational model, (iii) investigated the
exact tool boundary that blocked the 1N universal proofs, (iv) re-attempted
the universal theorem in stronger formulations with soundness controls,
and (v) recorded every result with raw, reproducible evidence.

## Layout

| Path | Content |
|---|---|
| `spec/foundational-model.md` | S, S₀, F, Safe_F, T_F, Auth_F, Commit_F; the six predicate classes; P1–P6 |
| `spec/transition-contract.md` | the twelve-class partition, invariants, refusals, the specialization relation |
| `audit/phase1n-evidence-audit.md` | the 1N evidence reconciliation (findings 1O-A..1O-E) |
| `audit/frozen-tree-verification-1n.txt` | the reproduced frozen-tree check (1M→1N: zero modifications) |
| `audit/source-hashes.txt`, `audit/env.txt` | provenance |
| `claims/phase1n-claim-inventory.csv` (+ reclassification + summary) | the machine-readable 1N inventory |
| `claims/claims.csv`, `claims/claim-classification.csv` | the 1O claim inventory (41 claims) |
| `semantics/abs-machine-r.k`, `abs-machine-weak.k`, `abs-machine-weak-r.k` | the GENERATED machines (each by a roundtrip-verified script) |
| `proofs/n_o_univ.k`, `n_o_univ_r.k`, `n_o_univ_weak.k`, `n_o_univ_weak_r.k`, `n_o_lemmas.k`, `repro/univ-repro.k` | the proof ladders and the minimal reproducer |
| `proofs/run_o_univ.sh` | the formal runner (fail-closed; every listed claim is attempted) |
| `scripts/` | the derivation generators + the auditors + the summarizer |
| `transcripts/k/` | every raw kprove log, the CSV, the score |
| `transcripts/attacks/` | the Python mirror sweep |
| `report/phase1o-final-report.md` | the final report |

## Commands

```
bash scripts/reinstall_toolchain_1m_r3.sh            # the pinned toolchain
python3 phase1o/scripts/audit_1n_claims.py           # the 1N claim auditor
bash phase1o/proofs/run_o_univ.sh                    # the full 1O K suite
python3 phase1o/scripts/summarize_1o.py              # the fail-closed inventory
python3 phase1o/scripts/summarize_1o.py --self-test  # its negative tests
python3 phase1n/python/abs_mirror.py                 # the exhaustive mirror sweep
```

## Status (the one-paragraph version)

The 1N audit confirmed every prior lead: the three universal claims were
never attempted by the 1N runner and had no retained logs (1O now retains
the live logs); 58 of the 1N "proved" claims close by evaluation (honest,
non-vacuous at the definition level, but not universal theorems); two SIM
controls timed out rather than refuted; the frozen-tree record file was
empty while the claim itself was true (reproduced here). The §6
investigation produced a ten-probe minimal reproducer that locates the
tool boundary precisely: kprove dispatches rewrite-position constructor
variables but never case-splits function-argument constructor variables,
and the implication checker cannot evaluate a pattern-matched function
under a disjunctive state constraint. The universal theorem was then
re-attempted in the strongest available formulations (the rewrite-level
R machine, with and without the branch-complete preservation family as
trusted lemmas): both attempts FAIL with retained residuals; the
soundness controls (the weak machine, the destination sanity) all behave
as designed, and the trusted-lemma trust chain is independently re-proven.
The universal theorem is therefore NOT MECHANIZED — with the obstruction,
its reproducer, and the exact residual obligation on record.
