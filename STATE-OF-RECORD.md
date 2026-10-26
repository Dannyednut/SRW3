# SRW3 — State of Record

**This file is the authoritative landing pointer for the SRW3 research and
mechanization project.** It exists because the repository's GitHub *default*
branch has historically pointed at an early phase (`phase1b`), which made the
current state of the research undiscoverable (independent-examiner finding
S1, remediated by Phase 1U workstream D1).

---

## Current accepted state

| Field | Value |
|---|---|
| Current phase | **Phase 1U — Model Hygiene, Proof Soundness, and Independent Revalidation** |
| Branch of record | `phase1u-model-hygiene` |
| Head commit | see `git rev-parse phase1u-model-hygiene` (the branch head is always authoritative; this file is updated per phase) |
| Base | Phase 1T tip `2247e68872d7a5f8bd8920db96db3ace290535b2` (branch `phase1t-c12-induction-validation`) |
| Verdict | **PARTIALLY COMPLETE** (see below — the project is never declared complete by a green gate) |
| Scope | Level III only — the abstract K models and their mechanized proofs. **No** consensus-integration, concrete-Ethereum, or protocol-commitment-boundary claim is made. |

## Phase-branch topology

The research proceeds in append-only phase branches; each phase branch is
frozen at its final commit and never rewritten:

```
main (archive: divergent early line, ends at an early phase — kept for
      provenance, NOT the state of record)
 └─ phase1b (historical GitHub default branch — STALE as a pointer)
     └─ phase1c → phase1d-r1-complete → phase1e → … → phase1n → phase1o
        → phase1p → phase1q → phase1r → phase1s-refinement-coverage
        → phase1t-c12-induction-validation → phase1u-model-hygiene  ← CURRENT
```

Every phase directory (`phase1n/` … `phase1u/`) carries its own README,
final report, claim ledger, exit-code inventory, and raw transcripts.

## Toolchain pins

| Tool | Version | Verification |
|---|---|---|
| K framework | v7.1.337 (jammy deb) | `kompile --version` in every phase transcript |
| Z3 | 4.13.3 | `z3 --version` in every phase transcript |
| Lean | 4.16.0 (commit `128a1e6b0a82`, Release; archive sha256 `54d6cba2…b81c80c`) | `lean --version`; the C1.2 + helper-lemma axiom reports are `[propext, Quot.sound]` — no `sorryAx` |

Rebuild recipe: `scripts/reinstall_toolchain_1m_r3.sh` (idempotent;
re-provisions everything under `/home/z/my-project/tools`).

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
- **Ghost-fidelity layer**: regenerated from the corrected sources; all
  per-claim verdicts identical to the historical record (incl. the ∀n
  theorem GH-T2/GH-M PROVED and the designed failures).

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
6. T3 is implemented as a setup-phase discipline **plus the documented
   assumption A5/A7** (policy/registry are protocol-authored); removing the
   setup commands entirely is a deliberate design decision left open.
7. T4: the abstract layers claim effect-completeness at DIFFERENT
   granularities (app-granular vs storage-key-granular) — documented in
   `docs/research/t4-footprint-granularity.md`; no cross-layer equivalence
   is claimed at the differing granularity.
8. All Level-III boundaries remain open: full bidirectional representation
   equivalence/bisimulation, external transition-row generator completeness
   (TCB-2), concrete KEVM/protocol commitment-boundary safety, actual
   protocol security, consensus integration.
9. FAILED-STUCK residuals from earlier phases are consolidated in each
   phase's ledger; the 1S/1T/1U ledgers are append-only.

## Reproduce

```sh
source /home/z/my-project/tools/env.sh
bash phase1u/proofs/run_1u.sh              # the corrected-rule proof battery
bash phase1u/tests/run_1u_model_tests.sh   # the old-vs-fixed model matrix
lean phase1u/audit/lean/c12_helpers.lean   # the helper-lemma development
python3 phase1u/scripts/summarize_1u.py    # the fail-closed ledger gate
```

No completion tag exists and none may be created while any central
proof, safety, or fidelity obligation remains unresolved.
