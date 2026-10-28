# SRW3 — Consolidated Residual Register (Phase 1V)

**Scope.** The cross-phase index of unresolved claims and registered
follow-ups, per the Phase 1V mandate (Workstream D item 2). The per-phase
ledgers (`phase1s/claims/claims.csv`, `phase1t/claims/claims-1t.csv`,
`phase1u/claims/claims-1u.csv`, `phase1v/claims/claims-1v.csv`) remain
APPEND-ONLY and authoritative for their own evidence; this register only
INDEXES what is still open and maps each item to its root-cause class,
attempted methods, and current status. Designed-failure controls (the
MUST-FAIL negative controls of 1S §7, the 1U falsity twins, the 1V
parse-rejection and designed-proof-failure controls) are NOT residuals —
they are working evidence and are excluded.

Established by Phase 1V; appended to per phase hereafter.

| # | ID(s) of record | Statement | Root-cause class | Attempted methods | Current status |
|---|---|---|---|---|---|
| R1 | `1S-C1.2-UNIV` | The K-native structural-induction route to C1.2 (`countToInt(P) >=Int 0` ∀P) does not close on the pinned toolchain | Prover-capability boundary (induction over constructor pools vs the Haskell backend's coverage) | 1S universal attempt (rc=1); 1T circularity forms `1T-C12-UNIV-CIRC`, `1T-C12-STEP-NZ-CIRC` (rc=1) | **FAILED-STUCK, superseded by route change**: C1.2 is PROVED in Lean 4.16.0 (`phase1t/audit/lean/c12_induction.lean`); the K-native route is closed with recorded negative evidence |
| R2 | `1S-MIGRATE-UNIV`; mechanism-A cells `1T-MIGRATE-UNIV-LEANC12`, `1T-CORR-*-UNCOND`, `1T-PRESV-INT-COMMIT-ACCEPT-LEANC12` | The unconditional migration/correspondence/preservation cells did not close unconditioned (1S) nor under the 1T mechanism-A harness | Proof-engineering: the 1T harness relied on an UNSOUND derived rule (removed in 1U) and on dropped conditions | 1S strengthened universal (rc=1); 1T mechanism A (rc=1 ×6) | **RESOLVED in 1U** under the corrected derived-rule harness (`1U-MIGRATE-UNIV-LEANC12-RULE` rc=0; nine cells rc=0) — the FAILED-STUCK rows remain in the 1S/1T ledgers as the historical record |
| R3 | `1T-MIGRATE-GENESIS-LEANC12(-RULE)`; `1U-MIGRATE-GENESIS-LEANC12-RULE` | The genesis-grounded run form of the migration theorem does not close within the 560s budget (empty log; the 1R TAG0-NF phenomenon) | Prover-capability boundary (goal size at the genesis form) | mechanism A (1T), corrected-rule harness (1U) — both rc=124 | **TIMEOUT — kept, never relabeled**; semantically subsumed by the closed universal |
| R4 | `1S-MIGRATE-DEST-NEG`, `1S-MIGRATE-DEST-NEG-CONCRETE`; `1U-WSA-CTRL-DEST-FALSE-RULE` | The destination-false controls under the symbolic harness time out instead of refuting | Prover-capability boundary (false-goal search explodes) | concrete-run variant (1S), decisive false-goal control `U-C15-COR-SYMB-GE2-TRUE` (1U, rc=1 4s) | **TIMEOUT — kept**; the computationally decisive control carries the refutation evidence |
| R5 | `ghost-GH-T` (every phase since 1L) | The minimal-destination probe of the ∀n theorem (a [circularity] variant) does not close | Proof-engineering (destination form resists the circularity's strengthening) | per-claim isolation every phase (1L…1V; rc=1 each time) | **FAILED-STUCK — the documented designed probe**; GH-T2/GH-M (the full theorem) PROVE |
| R6 | Combined `--spec-module SRW3-CLAIMS` batch on the ghost copy | The combined batch fails on unconstrained ghost cells | Pre-existing checker behavior (claim-pattern completion over the ghost cell) | reproduced IDENTICALLY on the 1T-tip artifact (1U) | **Documented tool boundary**; per-claim runs are the record |
| R7 | Examiner report archival | `SRW3-Independent-Examiner-Report-v1.2.md` absent from the repository | Traceability gap (document not supplied) | searched every commit of every branch, git grep, GitHub API (1U); filesystem + repo + API (1V) | **OPEN — BLOCKED on the document itself**; owner: author/examiner; byte-for-byte archival is ready to execute once supplied |
| R8 | Research-framework crosswalk (mechanized claims ↔ P1/P2/P3, A1–A4) | The mapping from the mechanized claims to the parent research framework's vocabulary is not established | Traceability gap (framework vocabulary document not in scope of the mechanization phases) | assumptions labeled A1–A7 in the sources (1U); P1–P6 mapped to the 1O spec layer | **OPEN — registered follow-up**; owner: a phase with research-framework access; verified-vs-interpretive labels must come from the framework document, not invention |
| R9 | Between-transition `init` state seeding (1V F2 residual) | `init` remains callable between transitions as a scenario-authoring affordance (disclosed); a real chain would not expose committed-state seeding to the transition program | Modeling-scope decision (deliberately retained affordance, not hidden) | mid-transition blocked (`blocked-init-open`, 1V); pre-begin availability kept for scenario compatibility | **DISCLOSED + registered follow-up**: move committed-state seeding to the trusted configuration boundary; owner: next phase |
| R10 | Harness-supplied configuration honesty | Policy, registry, authorities, resmap, and caps are trusted inputs of the harness; a hostile harness is outside the evaluated model | Trust-boundary definition (the TCB of record) | structural separation (1V); writer audit; unrepresentability controls | **OPEN by definition** — the TCB assumption is precise and recorded (A5/A7 of the sources) |
| R11 | Level-III boundaries | Full bidirectional state-representation equivalence/bisimulation; external transition-row generator completeness (TCB-2); concrete KEVM/protocol commitment-boundary safety; consensus integration | Scope boundary of the research program | not attempted (out of scope by every phase mandate) | **OPEN** — no claim of resolution may be made |
| R12 | Licence / tags / packaging | No licence file selected; tag-naming reconciliation across late-phase reports; no completion tag | Owner-authority items | disclosed in the 1U register; 1V creates no tag and chooses no licence | **OPEN** — owner: author (licence), maintainer (tag reconciliation at the next phase boundary) |

Cross-references: the per-phase verdicts live in the phase reports
(`phase1s/report/`, `phase1t/report/`, `phase1u/report/`,
`phase1v/report/`); the exit-code inventories are append-only
(`phase1v/claims/exit-codes-1v.csv` etc.). This register is updated
append-only at each phase boundary.
