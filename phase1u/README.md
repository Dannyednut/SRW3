# SRW3 Phase 1U — Model Hygiene, Proof Soundness, and Independent Revalidation

Branch `phase1u-model-hygiene` (base `2247e688`, the Phase 1T tip — verified
before branch creation). Pinned toolchain: K v7.1.337 + z3 4.13.3
(re-provisioned via `scripts/reinstall_toolchain_1m_r3.sh`; verified live).
Independent checker: Lean 4.16.0 (commit `128a1e6b0a82`; archive sha256
byte-verified at download).

## Layout

- `proofs/n_u_migrate_rule.k` — the CORRECTED derived-lemma rule module
  (the 1T unsound `>=Int I` generalization replaced by the exact-threshold
  rule; the 1T module `phase1t/proofs/n_t_migrate_rule.k` is left
  byte-frozen) + the full corrected battery.
- `proofs/n_u_c15_fixture.k` / `n_u_c15_mutant.k` / `n_u_c15_corrected.k` /
  `n_u_c15_liveness.k` / `n_u_c15_mutant_prio.k` — the isolated C1.5
  counterexample fixture: the deliberately-buggy mutant exhibit, the
  corrected exhibit, the rule-liveness probes, and the `[priority]`
  tool-boundary probe.
- `proofs/run_1u.sh` — the fail-closed runner (stages KD/UA2/WSA1/WSA4/
  UC1/UC1D/UC3/UC4/UC5).
- `tests/t1_harness.k` + `tests/demos/*.srw3` (14 programs) +
  `tests/run_1u_model_tests.sh` — the old-vs-fixed model matrix (T1/T2/T3
  execution evidence on BOTH the 1T-tip model and the fixed model, both
  layers, plus the kprove claims battery).
- `audit/lean/c12_helpers.lean` — the four helper lemmas (one per K rule),
  kernel-checked, axiom report `[propext, Quot.sound]`;
  `c12_helper_neg_controls.lean` — the falsity twins (rc=1 as designed).
- `transcripts/k/`, `transcripts/model/`, `transcripts/lean/` — every raw
  log (including failures, timeouts, and the old-model exhibits).
- `claims/claims-1u.csv` + `claims/exit-codes-1u.csv` — the append-only
  ledger (56 rows / 55 unique claims; superseded attempts retained) and the
  exit-code inventory (last-wins).
- `scripts/summarize_1u.py` — the fail-closed ledger gate (GATE GREEN).
- `report/phase1u-final-report.md` — the final report with the
  acceptance-criteria status table.

## Headline

- The invalid 1T rule `countToInt(succP(P)) >=Int I => true requires I >=Int 1`
  (false for P=zeroP, I=2) is REPLACED by the justified exact-threshold rule;
  every derived rule is audited (justification + admitted-substitution
  soundness), and the Lean helper lemmas give each rule a kernel-checked
  source.
- The corrected unconditional migration universal closes WITHOUT the C1.2
  assumption rules (rc=0, 14s; depth 1/2 fail, 3 closes); the decisive
  false-goal control refuses (rc=1, 4s — not a timeout).
- T1 (bareEdge obligation drop), T2 (re-entrant gate erasure), and T3
  (mid-transition policy/registry mutation) are REPRODUCED by execution on
  the unmodified 1T-tip model and FIXED, with permanent regression controls;
  the ghost-fidelity layer is regenerated from the corrected sources with
  every per-claim verdict identical to the historical record (GH-T2/GH-M
  still PROVED).
- The ledger count discrepancy (42 vs 40) is reconciled with the committed
  CSV as authoritative; the Task 11 contradiction is reconciled by an
  append-only erratum; `STATE-OF-RECORD.md` + the landing README are added.

Verdict: **PARTIALLY COMPLETE** — see the report for the acceptance table
and the disclosed residuals (genesis TIMEOUT; destination-false control
TIMEOUT, kept; the folded-rule liveness finding; the pre-existing
combined-batch checker behavior on the ghost copy).

Reproduce:
```
source /home/z/my-project/tools/env.sh
bash phase1u/proofs/run_1u.sh             # the corrected-rule battery
bash phase1u/tests/run_1u_model_tests.sh  # the old-vs-fixed model matrix
lean phase1u/audit/lean/c12_helpers.lean
python3 phase1u/scripts/summarize_1u.py
```
Level III only; no consensus-integration claim. No completion tag.
