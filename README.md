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
live 2026-10-28; re-verified live 2026-10-30)** — the stale-pointer problem
is RESOLVED; the note below is retained for the historical record. The
research lives on the append-only phase-branch chain ending at
**`phase1u-model-hygiene`** (default), with **`phase1v-configuration-ownership`**
and **`phase1w-boundary-audit`** landed on GitHub (2026-10-29, verbatim from
the verified bundles) and **`phase1x-ghost-runner-hardening`** as the newest
working branch (implementation + Run A at `e70e863`, follow-up commits on
top). `main` is a divergent early-phase archive kept for provenance;
`phase1b` remains an early-phase snapshot.

> **[Push-landing follow-up, 2026-10-29.]** Both delivered branches are NOW
> ON GITHUB, landed verbatim from the verified bundles with an
> owner-supplied credential: `phase1v-configuration-ownership` at
> `430f46858168f0477c1296ba9cc895b3f44e89be` and `phase1w-boundary-audit` at
> `19990a53f6d249871509d0a9875a1ac85c3d2b98` (create-only pushes, remote
> heads verified equal, default branch unchanged). The "push blocked" wording
> above is the dated 2026-10-28 record and is superseded, not rewritten —
> full evidence in `phase1w/report/push-landing-record.md` and the dated
> notes at the end of `STATE-OF-RECORD.md`. A documentation-only landing-note
> commit sits on top of `19990a5` (`git diff 19990a5..HEAD` is docs-only).

> **[Phase 1X follow-up, 2026-10-30.]** The Phase 1X branch's verification
> workstreams are closed with executed evidence: the ledger gate now
> re-derives every ghost claim's status from the RAW transcripts (status
> triple + four-way recompute + identity binding + independent fidelity
> certificate — strictly additive over the exact count/inventory checks);
> the 31-case adversarial regression suite was EXECUTED (31/31, including
> the R13 defect reproduced live on the true historical 1W runner); the
> battery was re-run in an independent clean environment (Run B) and is
> RUNS LOGICALLY IDENTICAL to Run A; the full sequence ran in a clean
> checkout with a 138-digest SHA-256 evidence manifest. R13 is CLOSED under
> its 8-condition gate; GH-T stays FAILED-STUCK; the genesis form stays
> TIMEOUT; verdict **PARTIALLY COMPLETE**. See
> `phase1x/report/phase1x-final-report.md` and
> `docs/research/residual-register-1x.md`.

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
| **1W** | **`phase1w-boundary-audit`** | **independent acceptance (the 1V bundle verified, the full 1V test procedure rerun twice from fresh clones — 44/44 + 48/48 identical to history; 13/13 tool negative controls), initialization-boundary closure (the between-transition `init` affordance demonstrated on the pinned 1V model and closed structurally via `$INITSTATE`), reconciled residual register R1–R14** |
| **1X** | **`phase1x-ghost-runner-hardening`** | **ghost-runner integrity (R13 closed: the expected label sets pinned and asserted BEFORE any kprove; the defect demonstrated live on the historical runner), proof-status fidelity (the FAILED-STUCK signature enforced per claim; the gate re-derives every status from the raw transcripts — S1–S9), the executed 31-case adversarial suite, the independent Run B (logically identical to Run A), the full evidence manifest** |

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
