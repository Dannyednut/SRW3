# SRW3 — State of Record

**This file is the authoritative landing pointer for the SRW3 research and
mechanization project.** It exists because the repository's GitHub *default*
branch has historically pointed at an early phase (`phase1b`), which made the
current state of the research undiscoverable (independent-examiner finding
S1). **S1 status after Phase 1U: the landing surfaces are delivered on the
branch of record; the DEFAULT-BRANCH SWITCH itself is BLOCKED** — the API
attempt with the provided token returned "Resource not accessible by
personal access token" (Administration write permission missing) and the
default branch remains `phase1b`. **Manual action required (repo owner):**
GitHub → Settings → Branches → default branch → `phase1u-model-hygiene`.

> **[1V FOLLOW-UP, 2026-10-28 — the default-branch action has SUCCEEDED.**
> Verified live via `GET /repos/Dannyednut/SRW3` at the start of Phase 1V:
> `default_branch: phase1u-model-hygiene`. The BLOCKED paragraph above is
> the historically accurate record of the Phase 1U time point and is
> preserved verbatim; as of this date the default branch IS the Phase 1U
> branch and the stale-`phase1b` caveat applies to history only. The
> Phase 1V working branch is deliberately NOT set as default — the owner
> selects the default after reviewing Phase 1V.]
>
> **[1W FOLLOW-UP, 2026-10-28 — default branch RE-VERIFIED LIVE without a
> credential.** The Phase 1W session has no GitHub API credential, but
> `git ls-remote --symref github-origin HEAD` (read-only git protocol)
> returned `ref: refs/heads/phase1u-model-hygiene HEAD` with HEAD →
> `8697bd744faee0b17156393fd8f57dd87e51598e`: the default branch IS the
> Phase 1U branch at the verified 1U tip — independently corroborating the
> 1V API check from THIS session. The same ls-remote shows
> `phase1v-configuration-ownership` is NOT on the remote (consistent with
> the 1V push-BLOCKED record) and `phase1t-c12-induction-validation` is at
> `2247e68872d7a5f8bd8920db96db3ace290535b2` — the exact OLD-1T commit the
> regression runners pin. The Phase 1W push remains BLOCKED (authentication:
> no credential); the branch is delivered as a verified transferable
> bundle and the owner (or a credentialed session) lands it verbatim with
> `git push origin phase1w-boundary-audit` — see the delivery note at the
> end of this file.]

---

## Current accepted state

| Field | Value |
|---|---|
| GitHub default branch (LIVE, verified 2026-10-28 by BOTH 1V via the API and 1W via `git ls-remote --symref`; re-verified live 2026-10-30 by the Phase 1X follow-up via credential-free `git ls-remote`) | **`phase1u-model-hygiene`** at `8697bd744faee0b17156393fd8f57dd87e51598e` |
| Current accepted phase | **Phase 1U — Model Hygiene, Proof Soundness, and Independent Revalidation** (the default branch carries its completed state) |
| Working phase under development | **Phase 1X — Ghost-Runner Integrity, Proof-Status Fidelity, and State-of-Record Repair** (branch below; NOT the default until the owner chooses) — including its 2026-10-30 verification follow-up (the per-claim status-fidelity gate, the executed 31-case regression suite, the independent Run B, and the evidence manifest; see the dated note at the end of this file) |
| Branch of record (working) | `phase1x-ghost-runner-hardening` — ON THE REMOTE at `e70e8634badd0ee5b7de87994751b8e052a3e879` (the 1X implementation + Run A; pushed 2026-10-29 after the 1V/1W landing), with the append-only follow-up commits on top (WS-A…WS-G; the branch head is always authoritative via `git rev-parse`; the verified post-push head is recorded in the Phase 1X delivery note below) |
| Head commit | see `git rev-parse phase1x-ghost-runner-hardening` (the branch head is always authoritative; this file is updated per phase) |
| Base | Phase 1V head `430f46858168f0477c1296ba9cc895b3f44e89be` (branch `phase1v-configuration-ownership`; INDEPENDENTLY VERIFIED in 1W: bundle sha256 `9c67aad4527483879208aa3607d27b9106ee9736f5ff5b9be33c5a86da1c85b7`, `git bundle verify` OK, complete history, six commits on the 1U tip `8697bd744faee0b17156393fd8f57dd87e51598e`) |
| Verdict | **PARTIALLY COMPLETE** (see below — the project is never declared complete by a green gate) |
| Scope | Level III only — the abstract K models and their mechanized proofs. **No** consensus-integration, concrete-Ethereum, or protocol-commitment-boundary claim is made. |

## Phase-branch topology

The research proceeds in append-only phase branches; each phase branch is
frozen at its final commit and never rewritten:

```
main (archive: divergent early line, ends at an early phase — kept for
      provenance, NOT the state of record)
 └─ phase1b (historical GitHub default branch — STALE as a pointer, historical only)
     └─ phase1c → phase1d-r1-complete → phase1e → … → phase1n → phase1o
        → phase1p → phase1q → phase1r → phase1s-refinement-coverage
        → phase1t-c12-induction-validation → phase1u-model-hygiene  ← DEFAULT (verified live 2026-10-28 by 1V; re-verified 2026-10-30 by 1X follow-up)
           └─ phase1v-configuration-ownership  ← ON GITHUB (landed 2026-10-29 from the verified bundle)
              └─ phase1w-boundary-audit  ← ON GITHUB (landed 2026-10-29; landing-note commit 34ef232 on top)
                 └─ phase1x-ghost-runner-hardening  ← WORKING (implementation + Run A at e70e863; follow-up commits appended — see the dated notes)
```

Every phase directory (`phase1n/` … `phase1w/`) carries its own README,
final report, claim ledger, exit-code inventory, and raw transcripts.

## Toolchain pins

| Tool | Version | Verification |
|---|---|---|
| K framework | v7.1.337 (jammy deb) | `kompile --version` in every phase transcript |
| Z3 | 4.13.3 | `z3 --version` in every phase transcript |
| Lean | 4.16.0 (commit `128a1e6b0a82`, Release; archive sha256 `54d6cba2…b81c80c`) | `lean --version`; the C1.2 + helper-lemma axiom reports are `[propext, Quot.sound]` — no `sorryAx`. NOT exercised in 1V (no Lean artifact changed); the 1U certificates stand. |

Rebuild recipe: `scripts/reinstall_toolchain_1m_r3.sh` (idempotent;
re-provisions everything under the toolchain root). Phase 1V note: after
the 2026-10-28 sandbox reset the toolchain was re-provisioned at
`tools1v/` (the 1V recipe, `scripts/rebuild_toolchain_1v.sh`, minus the
KEVM/plugin pieces that 1V does not exercise) with the SAME pins verified
live.

## What is actually proved (and how it is classified)

- **C1.2** (`forall P : PoolCount, countToInt(P) >=Int 0`): **PROVED** by
  kernel-checked structural induction in Lean 4.16.0
  (`phase1t/audit/lean/c12_induction.lean`), with 1U helper lemmas for every
  K derived rule (`phase1u/audit/lean/c12_helpers.lean`). The K-native
  induction route is CLOSED on this toolchain (recorded negative evidence).
- **The unconditional migration theorem**: closes **without** any C1.2
  *assumption* rule; its only C1.2 dependence is the audited derived-rule
  set (`phase1u/proofs/n_u_migrate_rule.k`), whose bodies are exact
  projections of the checked theorems. Classification:
  PROVED with a disclosed cross-language trust dependency (K checker + Lean
  kernel + the source-correspondence argument).
- **The conditional (C1.2-assumed) migration**: PROVED-UNDER-C1.2-ASSUMPTION,
  validated under the disclosed assumption.
- **Model soundness (1U)**: the T1 obligation-drop, T2 re-entrant gate
  erasure, and T3 mid-transition mutation defects are REPRODUCED by
  execution on the pre-1U model and FIXED, with permanent regression
  controls (`phase1u/tests/`).
- **Configuration ownership (1V)**: policy, registry, authorities, the
  alias table, and the capability configuration are TRUSTED MODEL
  CONFIGURATION entering only through the initial configuration; the
  mutation commands are REMOVED from the untrusted grammars (T3-v2);
  the 1U-model exploit windows (pre-begin / between transitions) and the
  unguarded `useResMap`/`grant` paths (F1a/F1b) are demonstrated on the
  pinned 1U model and closed on 1V, with asserted adversarial controls
  (`phase1v/tests/`).
- **Initialization-boundary closure (1W)**: the 1V between-transition
  `init` seeding affordance (R9) is DEMONSTRATED on the pinned 1V model in
  every open window and CLOSED STRUCTURALLY — `init` removed from both
  untrusted grammars; the initial committed state is trusted configuration
  `$INITSTATE` (A8/A9); NO rule writes `<committed>` except the gate accept
  rule; a violating harness-supplied baseline is demonstrably VISIBLE and
  FAILS CLOSED (`phase1w/tests/`).
- **Independent acceptance (1W)**: the complete Phase 1V test procedure
  reran TWICE from fresh clones of the verified bundle — 44/44 model
  controls and 48/48 ghost verdicts per run, identical to each other and
  to history; the gate/verifier tooling demonstrated to fail closed under
  13 adversarial negative controls; the 1U compat command reproduced with
  the 1U exit-code ledger restored bit-identically.
- **Ghost-fidelity layer**: regenerated from the corrected sources (1U and
  again from the 1V sources); all per-claim verdicts identical to the
  historical record (incl. the ∀n theorem GH-T2/GH-M PROVED and the
  designed failures).

## Open residuals (fail-closed register)

1. Genesis-grounded run form: **TIMEOUT** (the 1R TAG0-NF phenomenon) —
   subsumed semantically by the closed universal; never relabeled.
2. The destination-false control under the derived-rule harness: **TIMEOUT**
   (kept as a timeout; the computationally decisive false-goal control is
   `U-C15-COR-SYMB-GE2-TRUE`).
3. The folded C1.5 simplification rule is **inert at claim-goal level** on
   the pinned toolchain (evaluation-order masking — disclosed; the rule is
   sound and retained as the documented Lean projection).
4. GH-T remains FAILED-STUCK (the documented minimal-destination probe).
5. The combined `SRW3-CLAIMS` batch run on the ghost copy exhibits a
   pre-existing checker behavior on unconstrained ghost cells (also fails on
   the 1T-tip artifact; per-claim runs are the record).
6. T3 (1U) was the setup-phase discipline plus the documented assumption
   A5/A7. **Closed by Phase 1V (T3-v2)**: the mutation commands are removed
   and the configuration is protocol-owned (see the 1V report §A); the
   residual that REMAINS is the honesty of the trusted harness itself
   (a hostile harness is outside the evaluated model). **The disclosed
   between-transition `init` seeding affordance was CLOSED by Phase 1W
   (R9)**: `init` removed from the grammars, the initial committed state
   protocol-owned via `$INITSTATE` (A8/A9); the remaining harness-honesty
   dependency is R10, now covering the initial state as well.
7. T4: the abstract layers claim effect-completeness at DIFFERENT
   granularities (app-granular vs storage-key-granular) — documented in
   `docs/research/t4-footprint-granularity.md`; no cross-layer equivalence
   is claimed at the differing granularity.
8. All Level-III boundaries remain open: full bidirectional representation
   equivalence/bisimulation, external transition-row generator completeness
   (TCB-2), concrete KEVM/protocol commitment-boundary safety, actual
   protocol security, consensus integration.
9. FAILED-STUCK residuals from earlier phases are consolidated in each
   phase's ledger; the 1S/1T/1U/1V ledgers are append-only. The cross-phase
   index lives at `docs/research/residual-register-1w.md` (carries R1–R14;
   the 1V index remains as the historical record).
10. The examiner report file `SRW3-Independent-Examiner-Report-v1.2.md` is
   still absent from the repository; Phase 1V could not archive it because
   the document was not supplied to the session (registered, owner
   author/examiner).
11. The research-framework crosswalk (mechanized claims ↔ P1/P2/P3,
    A1–A4) remains a registered follow-up (needs the framework vocabulary
    document; owner: a phase with research-framework access).

## Reproduce

```sh
source <toolchain root>/env.sh               # K v7.1.337 + z3 4.13.3 (pinned)
bash phase1u/proofs/run_1u.sh               # the corrected-rule proof battery (1U; unchanged)
bash phase1v/tests/run_1v_model_tests.sh    # the 1V old-vs-fixed model matrix (fail-closed)
bash phase1v/tests/run_1u_model_tests_compat.sh   # the 1U runner from a clean checkout
bash phase1v/proofs/run_1v_ghost.sh         # ghost regeneration + per-claim battery (1V)
bash phase1w/tests/run_1w_model_tests.sh    # the 1W initialization-boundary battery (fail-closed)
bash phase1w/proofs/run_1w_ghost.sh         # ghost regeneration + per-claim battery (1W)
bash phase1x/proofs/run_1x_ghost.sh         # the HARDENED ghost runner (1X: label pinning + status-aware classification)
python3 phase1x/scripts/build_ledgers_1x.py
python3 phase1x/scripts/summarize_1x.py     # the strictest gate (1X: S1-S9 incl. the four-way per-claim recompute)
bash phase1x/tests/run_1x_regressions.sh    # the 31-case adversarial suite (1X, executed 2026-10-30: 31/31)
python3 phase1x/scripts/compare_runs_1x.py --a <runA.csv> --b <runB.csv>   # the run-pair logical comparison
lean phase1u/audit/lean/c12_helpers.lean    # the helper-lemma development (unchanged)
python3 phase1v/scripts/build_ledgers_1v.py
python3 phase1v/scripts/summarize_1v.py     # the fail-closed ledger gate (1V)
python3 phase1w/scripts/build_ledgers_1w.py
python3 phase1w/scripts/summarize_1w.py     # the fail-closed ledger gate (1W)
python3 phase1u/scripts/summarize_1u.py     # the 1U gate (unchanged)
```

No completion tag exists and none may be created while any central
proof, safety, or fidelity obligation remains unresolved.

## Phase 1V delivery note (2026-10-28)

The Phase 1V branch `phase1v-configuration-ownership` is committed locally
(four reviewable work commits `f70353d` / `0c5a0fe` / `c7a0c7b` / `91d5d0b`
on the verified base `8697bd7`, plus the delivery-documentation commits;
the branch head is always authoritative; worktree clean; ancestry verified;
no history rewrite; no force-push). The push to GitHub is BLOCKED in the
Phase 1V session (the sandbox reset removed the credential; authentication
fails) — recorded, not claimed as pushed. The branch head of record is
delivered as a verified transferable bundle at
`download/srw3-phase1v-branch.bundle` (the sha256 of record is printed at
bundle creation and re-verified below); the owner (or any session holding
the token) can land it verbatim with
`git push origin phase1v-configuration-ownership`. The GitHub default
branch remains the owner-selected `phase1u-model-hygiene`.

## Phase 1W delivery note (2026-10-28)

The Phase 1W branch `phase1w-boundary-audit` is committed locally on the
INDEPENDENTLY VERIFIED Phase 1V head `430f46858168f0477c1296ba9cc895b3f44e89be`
(three reviewable work commits — the initialization-boundary closure with its
adversarial battery and the regenerated ghost layer; the independent-acceptance
evidence including the two-run reproduction and the 13 negative controls; the
reconciled register, the phase report, and the documentation — plus this
delivery-documentation commit; the branch head is always authoritative —
`git rev-parse phase1w-boundary-audit`; worktree clean; ancestry verified; no
history rewrite; no force-push; no completion tag). The `git push` to GitHub is
**BLOCKED in this session** (no credential; authentication fails — recorded,
not claimed as pushed). The branch of record is delivered as a verified
transferable bundle at `download/srw3-phase1w-branch.bundle` (the sha256 of
record is printed at bundle creation in the transfer summary); the owner (or
any session holding the token) can land BOTH undelivered phase branches
verbatim:

```sh
git clone /path/to/srw3-phase1v-branch.bundle /tmp/land-1v && cd /tmp/land-1v
git push origin phase1v-configuration-ownership        # lands the 1V branch
git fetch /path/to/srw3-phase1w-branch.bundle phase1w-boundary-audit:phase1w-boundary-audit
git push origin phase1w-boundary-audit                  # lands the 1W branch
```

The GitHub default branch remains the owner-selected `phase1u-model-hygiene`
(re-verified live this session via `git ls-remote --symref`); no default-branch
change is requested by Phase 1W.

## Phase 1W push-landing note (2026-10-29)

The BLOCKED push status above is superseded, not rewritten: on 2026-10-29 an
owner-supplied credential landed BOTH undelivered phase branches on GitHub
exactly as the delivery note instructed. Per-branch evidence (full detail in
`phase1w/report/push-landing-record.md`):

- Both transferable bundles were re-verified from scratch in the landing
  session BEFORE any push: sha256 `9c67aad4527483879208aa3607d27b9106ee9736f5ff5b9be33c5a86da1c85b7`
  (1V) and `2cee9b02a92316d490ada96741359e9ca5df354e71e7147899fb06267394eba9`
  (1W) — both EXACTLY the digests of record; `git bundle verify` OK (complete
  history); round-trip clones clean.
- Pre-push remote state (credential-free `git ls-remote`): default branch
  `phase1u-model-hygiene` at `8697bd744faee0b17156393fd8f57dd87e51598e`;
  BOTH phase branches ABSENT — consistent with the BLOCKED record.
- `git push` (create-only, no `--force`): `phase1v-configuration-ownership`
  → `[new branch]`, exit 0; `phase1w-boundary-audit` → `[new branch]`, exit 0.
- Post-push `git ls-remote`: remote heads `430f46858168f0477c1296ba9cc895b3f44e89be`
  and `19990a53f6d249871509d0a9875a1ac85c3d2b98` — EXACT equality with the
  delivered heads (the commit ID covers the full object DAG); a fresh GitHub
  clone checks out both branches clean with identical ancestry
  (`8697bd7..19990a5` = 10 commits); exactly the two branch refs were added;
  the default branch was NOT changed.
- A dated landing-note commit (documentation only: this note, the README
  follow-up, `phase1w/report/push-landing-record.md`, the worklog entry) was
  appended on the owner's instruction ("continue using the same PAT for
  pushes"); the delivered review state `19990a5` remains verbatim-reviewable
  (`git diff 19990a5..HEAD` is docs-only); no history rewrite; no force-push;
  no completion tag. The branch head is always authoritative
  (`git rev-parse phase1w-boundary-audit`).

The verdict remains **PARTIALLY COMPLETE**; the residual register R1–R14 is
unchanged by the landing. The GitHub default branch remains
`phase1u-model-hygiene` — selecting the post-review default is the owner's
call, as before.

## Phase 1X follow-up note (2026-10-30)

The Phase 1X branch `phase1x-ghost-runner-hardening` (implementation +
Run A committed at `e70e8634badd0ee5b7de87994751b8e052a3e879`, pushed
2026-10-29 after the 1V/1W landing) received an append-only verification
follow-up this date, closing the phase mandate's verification workstreams.
Full record: `phase1x/report/phase1x-final-report.md` (§0–§G, 19-item
acceptance table) and the worklog. Summary:

- **WS-A** — the gate `summarize_1x.py` now re-derives every ghost claim's
  status from the RAW evidence: the per-claim STATUS TRIPLE (pinned
  inventory == ledger expected == observed), exit-code compatibility,
  diagnostic-evidence support, the FOUR-WAY recompute of every kprove
  transcript with the shared classifier, an independent fidelity-certificate
  check, and CLAIM↔TRANSCRIPT IDENTITY binding (per-claim spec filename
  present in each transcript). S1–S5 (counts, inventories, vocabulary,
  non-relabelling, last-wins) are NOT relaxed — strictly additive.
- **WS-B** — the adversarial regression suite EXECUTED for real: 31 PASS /
  0 FAIL, including the defect reproduced live on the TRUE historical
  runner (`run_1w_ghost.sh@34ef232` exits 0 with 11/12 claims) and the 1X
  runner refusing the same input before any K proof. Execution log:
  `phase1x/transcripts/repro/regressions-1x-followup.log`.
- **WS-C** — Run B executed 2026-10-30 in an independent clean clone (fresh
  checkout of the follow-up head): all stages, 48/48 rows; the Run A vs Run
  B comparison (`phase1x/scripts/compare_runs_1x.py`) is RUNS LOGICALLY
  IDENTICAL (wall-clock and environment paths excluded by the disclosed
  path-only drift allowance). Run A preserved in situ; layout
  `phase1x/transcripts/repro/runA/` and `runB/`.
- **WS-D** — the FULL sequence (runner → build → gate → regressions)
  executed in the runB clean checkout; gate GREEN with the hardened checks;
  full SHA-256 evidence manifest with source-commit identity:
  `phase1x/transcripts/repro/evidence-manifest-1x.txt` (138 digests).
- **WS-G** — `docs/research/residual-register-1x.md` carries R1–R14 with no
  drops/merges/downgrades; **R13 CLOSED** under its 8-condition gate (all
  satisfied by executed evidence); R14 updated; GH-T remains FAILED-STUCK;
  the genesis form remains TIMEOUT; Level-III boundaries remain open.

Staging disclosures (R14 discipline): a sandbox recycle destroyed both
working clones before this follow-up (recovered by fresh clone of the
pushed branch — working state had been committed); Run B's first staged
invocations omitted `RUN_APPEND=1` and were recovered by re-running the
missing stages with the designed last-wins dedup. Both disclosed in the
report §D. The verdict remains **PARTIALLY COMPLETE**; no completion tag.

The pushes execute immediately after the follow-up commits (append-only,
fast-forward, no force); the verified remote head is recorded in the Phase
1X delivery note below.
