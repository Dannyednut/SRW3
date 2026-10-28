# SRW3 — Symbolic Rewrite Verification of Commitment-Gated Composition

A research and mechanization project: commitment-gated composition semantics
(the SRW3 model family) formalized in the **K framework**, with mechanized
proofs on a pinned toolchain (K v7.1.337 + Z3 4.13.3) and an independent
Lean 4.16.0 kernel check for the constructor-count induction.

> **START HERE: [`STATE-OF-RECORD.md`](STATE-OF-RECORD.md)** — the current
> accepted phase, branch, toolchain pins, verdict, and open residuals.

## What this repository is

The GitHub **default branch** historically pointed at an early phase
(`phase1b`) — a stale pointer (independent-examiner finding S1). **The owner
has since switched the default branch to `phase1u-model-hygiene` (verified
live 2026-10-28)** — the stale-pointer problem is RESOLVED; the note below
is retained for the historical record. The research lives on the
append-only phase-branch chain ending at **`phase1u-model-hygiene`**
(default) with **`phase1v-configuration-ownership`** as the working branch
under review. `main` is a divergent early-phase archive kept for
provenance; `phase1b` remains an early-phase snapshot.

## Phase topology (chronological)

| Phase | Branch | One-line outcome |
|---|---|---|
| 0D–1L | `phase1b` … `phase1l-universal-induction` | abstract model, KEVM binding, crypto lineage, ghost-state ∀n theorem |
| 1M | `phase1m-proof-backend-closure` | proof-backend closure pass |
| 1N–1R | `phase1n-…` → `phase1r-fold-decomposition` | abstract transition simulation; the K-native induction boundary established |
| 1S | `phase1s-refinement-coverage` | constructor-count refinement + coverage battery; conditional migration |
| 1T | `phase1t-c12-induction-validation` | C1.2 proved (Lean structural induction); conditional migration validated; unconditional migration closes via disclosed derived rules |
| 1U | `phase1u-model-hygiene` | proof-rule soundness remediation (the invalid C1.5 generalization), T1/T2/T3 model defects reproduced and fixed, ledger/erratum reconciliation, state-of-record — **the GitHub default branch since the owner's switch (verified live 2026-10-28)** |
| **1V** | **`phase1v-configuration-ownership`** | **configuration ownership (T3-v2: trusted model configuration, mutation commands removed from the untrusted grammars; F1a/F1b/F2/F3 findings closed), reproducible fail-closed regression runner, state-of-record correction for the default-branch change** |

Each `phase1X/` directory contains that phase's README, final report
(fail-closed verdict), claim ledger + exit-code inventory, raw transcripts,
and the Lean audit where applicable.

## Verdict discipline

The project verdict is **PARTIALLY COMPLETE** and stays that way while any
central proof, safety, or fidelity obligation is unresolved. A green
regression gate never implies completeness; timeouts are never relabeled;
historical attempt rows are never deleted; no completion tag is created.
See `STATE-OF-RECORD.md` §Open residuals.

## Licence

No licence file has been selected yet — this is a tracked packaging item
(Phase 1U report §E, "Packaging and traceability register"); adding one
requires the author's explicit choice and is **deferred with owner/action**
recorded rather than silently chosen.
