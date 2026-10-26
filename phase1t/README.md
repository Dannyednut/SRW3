# SRW3 Phase 1T — C1.2 Structural Induction and Migration-Proof Validation

Branch `phase1t-c12-induction-validation` (base `7a8118f`, the Phase 1S freeze).
Pinned toolchain: K v7.1.337 + z3 4.13.3 (rebuilt from
`scripts/reinstall_toolchain_1m_r3.sh` after the sandbox reset; verified live).
Independent checker: Lean 4.16.0 (pinned, sha256 in the report).

## Layout

- `proofs/n_t_c12_attr.k` — the `[induction]`-attribute probe module (the
  parse-failure exhibit; the pinned compiler rejects the attribute).
- `proofs/n_t_c12_circ.k` — the `[circularity]`-route probes (universal,
  falsity twin, constructor-discriminated form) — all FAILED-STUCK.
- `proofs/n_t_wsa_controls.k` — Workstream A false-goal controls inside the
  C12-assumption harness (must fail; they fail).
- `proofs/n_t_migrate_uncond.k` — Workstream C mechanism A: the unconditional
  migration under the `--trusted` Lean-checked C1.2 claim (recorded: the
  mechanism conveys no fact content — residual unchanged).
- `proofs/n_t_corr_uncond.k` — mechanism A cells (recorded outcomes).
- `proofs/n_t_migrate_rule.k` — Workstream C mechanism B: the derived-lemma
  rules (projections of the Lean-checked C1.2 / K-proved C1.5, provenance
  disclosed) + the unconditional universal (CLOSES, rc=0, 13s) + the dropped-
  condition correspondence cells (all close) + the strip-state NODEP probe
  (the 1S residual DISCHARGED) + the preservation chain + the rule-harness
  falsity control (does not close).
- `proofs/run_1t.sh` — the fail-closed runner (stages KD/WSA1-4/WC1-4C).
- `transcripts/k/` — one raw log per row (including failures).
- `audit/lean/` — the Lean development: `c12_induction.lean` (the structural
  induction; rc=0; axioms [propext, Quot.sound]), `c12_neg_controls.lean`
  (the falsity controls; rc=1 as designed), both transcripts, sources hashed
  in the report.
- `claims/claims-1t.csv` — the 1T ledger (**40 unique claim rows** — 34 `1T-`
  IDs + 6 reproduced `1S-` rows; **51 attempt rows** in
  `claims/exit-codes-1t.csv`, last-wins; historical rows never relabeled).
  *[Count corrected by Phase 1U workstream D2: this README previously said
  "42 rows"; the committed ledger is authoritative — see
  `phase1u/report/phase1u-final-report.md` §D2.]*
- `claims/exit-codes-1t.csv` — raw exit codes (last-wins).
- `report/phase1t-final-report.md` — the final report with the five verdicts.

## Headline

- C1.2 (`forall P : PoolCount, countToInt(P) >=Int 0`): **PROVED** by
  kernel-checked structural induction (Lean 4.16.0); the K-native route is
  exhausted with fresh negative evidence (`[induction]` rejected; two
  circularity forms stuck).
- The unconditional migration universal **closes without the C1.2 assumption
  rules** (`1T-MIGRATE-UNIV-LEANC12-RULE`, rc=0, 13s; depth 1/2 fail) — the
  only C1.2 use is derived rules whose justification is the checked theorem.
- The commit-accept strip-state residual of record
  (`countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0`) is **discharged**.
- The genesis-grounded form remains TIMEOUT (the recorded 1R phenomenon).

Verdict: **PARTIALLY COMPLETE** — see the report for the five verdicts and
the disclosed trust base.

Reproduce:
```
source /home/z/my-project/tools/env.sh
bash phase1t/proofs/run_1t.sh            # the full battery (stages as in run_1s.sh)
lean phase1t/audit/lean/c12_induction.lean
```
Level III only; no consensus-integration claim. No completion tag.
