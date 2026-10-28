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

---

## Current accepted state

| Field | Value |
|---|---|
| GitHub default branch (live, verified 2026-10-28) | **`phase1u-model-hygiene`** (the owner's switch succeeded) |
| Current accepted phase | **Phase 1U — Model Hygiene, Proof Soundness, and Independent Revalidation** (the default branch carries its completed state) |
| Working phase under development | **Phase 1V — Configuration Ownership and Reproducible Verification** (branch below; NOT the default until the owner chooses) |
| Branch of record (working) | `phase1v-configuration-ownership` (base = the 1U tip) |
| Head commit | see `git rev-parse phase1v-configuration-ownership` (the branch head is always authoritative; this file is updated per phase) |
| Base | Phase 1U tip `8697bd744faee0b17156393fd8f57dd87e51598e` (branch `phase1u-model-hygiene`) |
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
        → phase1t-c12-induction-validation → phase1u-model-hygiene  ← DEFAULT (verified live 2026-10-28)
           └─ phase1v-configuration-ownership  ← WORKING (under review)
```

Every phase directory (`phase1n/` … `phase1v/`) carries its own README,
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
   (a hostile harness is outside the evaluated model) and the disclosed
   between-transition `init` seeding affordance (follow-up registered).
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
   index lives at `docs/research/residual-register-1v.md`.
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
bash phase1v/proofs/run_1v_ghost.sh         # ghost regeneration + per-claim battery
lean phase1u/audit/lean/c12_helpers.lean    # the helper-lemma development (unchanged)
python3 phase1v/scripts/build_ledgers_1v.py
python3 phase1v/scripts/summarize_1v.py     # the fail-closed ledger gate (1V)
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
