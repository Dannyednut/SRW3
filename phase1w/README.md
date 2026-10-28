# SRW3 Phase 1W — Independent Acceptance, Initialization-Boundary Closure, and Residual Proof Plan

Branch `phase1w-boundary-audit`, created from the INDEPENDENTLY VERIFIED
Phase 1V head `430f46858168f0477c1296ba9cc895b3f44e89be` (branch
`phase1v-configuration-ownership`, imported via
`git bundle verify` + clone from `download/srw3-phase1v-branch.bundle`,
sha256 `9c67aad4527483879208aa3607d27b9106ee9736f5ff5b9be33c5a86da1c85b7` —
"records a complete history"; base `8697bd744faee0b17156393fd8f57dd87e51598e`
re-verified as the direct parent; six 1V commits inspected; worktree clean).
Pinned toolchain: **K v7.1.337** + **Z3 4.13.3** (verified live in-session;
`kompile --version` and `z3 --version` in the reproducible-env recipe).
Lean is NOT exercised (no Lean artifact changed; the 1U certificates stand).

## Layout

- `k/srw3.k`, `k/srw3gen.k` — the corrected models (the initialization-
  boundary closure; see below).
- `tests/demos-aff/*.srw3` (6 programs) — the BEFORE-evidence battery: the
  between-transition `init` affordance DEMONSTRATED on the git-pinned 1V
  model (direct corruption; corruption surviving a reject; after-reject;
  after-authfail; generalized model; pre-begin characterization).
- `tests/demos/*.srw3` (29 programs) — the 1W battery: verbatim attack
  programs (parse-rejected on 1W), translated 1V regression programs (seeds
  via `$INITSTATE`), and the trusted-seeding/TCB-boundary positive controls.
- `tests/run_1w_model_tests.sh` — the fail-closed runner (stages KOM AFF
  OWN1 OWN2 T1 T2 GEN1 GEN2 CLM; every input from committed repository
  objects incl. the git-pinned OLD-1V/OLD-1T models sha-asserted; unique
  mktemp workspace + cleanup trap; compile failures fatal; every expected
  outcome asserted via `tests/verify_1w_out.py` — a byte-identical copy of
  the audited 1V verifier, sha256 `ebc40c84…13866a`).
- `proofs/run_1w_ghost.sh` — the ghost regeneration + per-claim battery (a
  path-adjusted derivative of the audited 1V runner; every check
  byte-identical, evidence relocated to `phase1w/`).
- `claims/claims-1w.csv` (94 rows) + `claims/exit-codes-1w.csv` (94 rows) +
  `claims/model-verdicts-1w.csv` (46 rows) + `claims/ghost-verdicts-1w.csv`
  (48 rows) — the ledgers; `scripts/build_ledgers_1w.py`,
  `scripts/summarize_1w.py` — the ledger builder and the fail-closed gate
  (GATE GREEN, 0 alarms).
- `transcripts/model/`, `transcripts/ghost/`, `transcripts/repro/` — every
  raw log, plus the fresh-environment reproduction artifacts (Workstream B:
  two independent clean runs, the 1U compat run, and the 13-probe negative-
  control log for the summarizer/verifier gate).
- `report/phase1w-final-report.md` — the final report (verified findings,
  assumptions, blockers, unverified claims; the acceptance table; the
  residual crosswalk).

## Headline

- **R9 CLOSED (the 1V residual: between-transition `init` seeding):** the
  affordance is first DEMONSTRATED on the pinned 1V model in every open
  window (between two completed transitions — direct and
  survive-a-reject variants; after a rejected transition; after an
  authorization failure; in the generalized model; pre-begin, the
  by-design case), then CLOSED STRUCTURALLY: `init` is REMOVED from both
  untrusted transition-program grammars (both 1V rules retired with their
  syntax), and the initial committed state enters ONLY through the trusted
  harness invocation (`-cINITSTATE="stK(appA,0) |-> 5 …"`), exactly like
  `$POLICY/$REGISTRY/$AUTHORITIES` in 1V. NO rule in either semantics
  writes `<committed>` except the gate accept rule — the no-hidden-axiom
  contract statement is now literally true. Committed-state mutation by the
  untrusted program is UNREPRESENTABLE (parse-time rejection) at every
  lifecycle position.
- **Trust assumption recorded, not hidden (A8/A9):** the harness-supplied
  INITIAL STATE is trusted input (the same TCB of record as every other
  configuration item — R10 extended). A VIOLATING baseline is demonstrably
  VISIBLE and FAILS CLOSED: the gate evaluates every applicable obligation
  over the seeded baseline and rejects (`w1_pos_bad_baseline_rejected`) —
  a bad baseline cannot be laundered silently through the gate; what the
  assumption covers is the baseline itself.
- **Independent acceptance (Workstream B):** the complete Phase 1V test
  procedure reran TWICE from fresh clones of the verified bundle in a
  clean environment — 44/44 model controls and 48/48 ghost per-claim
  verdicts in EACH run, logically identical to each other and to the
  committed historical record; the documented 1U command reproduced through
  the compatibility wrapper (OLD legs byte-comparable; the 1U exit-code
  ledger restored bit-identically, sha256-verified); `summarize_1v.py`
  GATE GREEN on the fresh ledgers of both runs.
- **The gate genuinely fails closed (Workstream D):** 13/13 negative
  controls — duplicated claim rows, missing transcripts, exit-code
  mismatches, unrecognized terminal states, missing expectations, count
  mismatches, designed-failure relabeling (RELABELING ALARM + GATE RED),
  non-OK verdict rows, wrong expectations, nondeterministic two-block
  outputs, stuck-function warnings, and duplicate verdict rows in the
  builder — every probe REJECTED; the positive baseline accepted.
- **Regression continuity:** Claims 1–4 rc=0 #Top and the negative control
  rc=1 on the NEW model (1U/1V-record parity); the T1/T2/GEN matrices
  re-established on the translated programs with the 1V-record outcomes;
  the ghost artifacts REGENERATED from the 1W sources with exact
  byte-faithfulness PASS and ALL 48 per-claim verdicts identical to the
  historical record.

Reproduce:
```
source <pinned toolchain env.sh>            # K v7.1.337 + z3 4.13.3
bash phase1v/tests/run_1v_model_tests.sh    # the 1V battery (unchanged, on the 1V commit)
bash phase1w/tests/run_1w_model_tests.sh    # the 1W initialization-boundary battery (fail-closed)
bash phase1w/proofs/run_1w_ghost.sh         # ghost regeneration + per-claim battery
python3 phase1w/scripts/build_ledgers_1w.py
python3 phase1w/scripts/summarize_1w.py     # GATE GREEN expected
```

Verdict: **PARTIALLY COMPLETE** — see the report for the acceptance table,
the disclosed assumptions, and the residual register
(`docs/research/residual-register-1w.md`). Level III only; no
consensus-integration claim. No completion tag.
