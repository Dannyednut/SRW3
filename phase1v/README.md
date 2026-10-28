# SRW3 Phase 1V — Configuration Ownership and Reproducible Verification

Branch `phase1v-configuration-ownership` (base `8697bd7`, the Phase 1U tip
`phase1u-model-hygiene` — verified with `git rev-parse` before branch
creation; the remote branch head was confirmed in sync; the GitHub default
branch was confirmed LIVE as `phase1u-model-hygiene` via the API before any
documentation edit). Pinned toolchain: **K v7.1.337** + **Z3 4.13.3**
(re-provisioned after the sandbox reset from the recorded recipe minus the
KEVM/plugin pieces, which Phase 1V does not exercise; verified live in every
transcript header). Lean is NOT exercised this phase (no Lean artifact
changes; the 1U Lean certificates stand unchanged).

## Layout

- `k/srw3.k`, `k/srw3gen.k` — the corrected models (the trusted-configuration
  boundary; see below).
- `tests/t1_harness.k` — the T1 order-independence harness (behaviorally
  identical to the 1U harness; the registry KIND is now selected by the
  trusted harness via the initial configuration instead of an in-program
  command).
- `tests/demos/*.srw3` (30 programs) — the 1V scenario battery; configuration
  enters ONLY through `krun -c` (trusted harness invocation).
- `tests/demos-old/*.srw3` (9 programs) — the OLD-1U exploit programs
  (before-evidence; old grammar, run against the git-pinned 1U model).
- `tests/run_1v_model_tests.sh` — the fail-closed old-vs-fixed runner
  (Workstream B; unique mktemp workspace + cleanup trap; every input from
  committed repository objects; compile failures fatal; every expected
  outcome ASSERTED via `tests/verify_1v_out.py`; stuck-function warnings and
  nondeterministic multi-branch outputs are always failures; nonzero exit on
  any deviation).
- `tests/run_1u_model_tests_compat.sh` — the Workstream B4 compatibility
  wrapper: makes the EXACT documented Phase 1U command self-contained from a
  clean checkout (provisions `/tmp/p1u-old-harness/{srw3.k,t1_harness_old.k}`
  from committed objects with ONE documented require-path transformation,
  asserted); the 1U runner itself is byte-frozen.
- `proofs/run_1v_ghost.sh` — the ghost-fidelity regeneration + per-claim
  battery (staged; expected verdicts asserted).
- `claims/claims-1v.csv` (92 rows) + `claims/exit-codes-1v.csv` (92 rows) —
  the append-only ledgers; `claims/model-verdicts-1v.csv` (44 rows) +
  `claims/ghost-verdicts-1v.csv` (48 rows) — the machine-readable per-run
  verdict ledgers.
- `scripts/build_ledgers_1v.py`, `scripts/summarize_1v.py` — the ledger
  builder and the fail-closed consistency gate (GATE GREEN, 0 alarms).
- `report/phase1v-final-report.md` — the final report with the acceptance
  table, the configuration-ownership audit table, and the residual register.
- `transcripts/model/`, `transcripts/ghost/` — every raw log (including the
  OLD-model exploit exhibits and the two clean-run ledgers).

## Headline

- **T3-v2 (configuration ownership):** `setPolicy`, `useRegistry`,
  `useRegistryG`, `useResMap`, and `grant` are REMOVED from the untrusted
  transition-program grammars. Policy, registry, authorities, the alias
  table, and the capability configuration enter the models ONLY through the
  initial configuration (`$POLICY/$REGISTRY/$AUTHORITIES`,
  `$POLICY/$REGISTRYG/$AUTHORITIES/$RESMAP/$CAP/$PARENT`) supplied by the
  trusted harness invocation; NO rule in either semantics writes those
  cells. Configuration mutation is now UNREPRESENTABLE (parse-time
  rejection) before the first transition, during one, and between
  transitions.
- **F1a/F1b (new findings, beyond the examiner lead):** the 1U model's
  `useResMap` and `grant` had NO guard at all — reachable mid-transition.
  Both exploits are demonstrated on the pinned 1U model (alias-wipe commits
  an IRP violation 6+9=15>10; self-granted caps commit usage 1000 against a
  protocol budget of 6/10) and are closed by the removal.
- **F2/F3 (new hardening):** `init` (committed-state seeding) and `as`
  (actor identity) are now PRE-BEGIN-ONLY — the 1U model's mid-transition
  `init` corrupts committed state on the reject path (demonstrated:
  appA 7→999 never gated) and is now BLOCKED (`blocked-init-open`);
  mid-transition `as` would forge authorization evidence against 1V's
  configurable authority sets and is BLOCKED (`blocked-actor-switch-open`).
- **T1/T2 regression continuity:** the bareEdge order-independence matrix and
  the gate re-entrancy battery are verdict-identical to the 1U record on
  both the pinned 1T-tip model (defects) and the fixed model (rejections).
- **Ghost fidelity:** the byte-pinned core changed, so
  `proofs/induction_ghost.k` + `ghost_manifest.json` + `proofs/gen/*` were
  REGENERATED from the corrected sources; `audit_ghost_exact.py verify`
  PASSES (exact byte-faithfulness); every one of the 48 per-claim ghost
  verdicts is identical to the historical record (GH-T2/GH-M PROVED;
  GH-T/GH2-NEG and the generalized NEG rows FAILED as designed).
- **Reproducibility:** the old-vs-fixed matrix runs from committed inputs in
  a unique temp workspace; TWO isolated clean runs produce IDENTICAL logical
  verdicts (44/44 controls each; `determinism-1v-report.txt`); the exact
  documented Phase 1U command reproduces from a clean checkout via the
  compatibility wrapper (OLD-model legs byte-comparable; the 1U ledger
  byte-frozen).

Reproduce:
```
source <pinned toolchain env.sh>          # K v7.1.337 + z3 4.13.3
bash phase1v/tests/run_1v_model_tests.sh  # the old-vs-fixed model matrix (fail-closed)
bash phase1v/proofs/run_1v_ghost.sh       # ghost regeneration + per-claim battery
python3 phase1v/scripts/build_ledgers_1v.py
python3 phase1v/scripts/summarize_1v.py   # GATE GREEN expected
```

Verdict: **PARTIALLY COMPLETE** — see the report for the acceptance table
and the disclosed residuals. Level III only; no consensus-integration claim.
No completion tag.
