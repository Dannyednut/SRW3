# Phase 1R — the soundness controls (index)

The 1R soundness controls are K reachability claims and live with the
proof modules (K has no separate test runner in this stack); this file is
the index required by the mission's deliverables layout.

| control (mission §9) | claim(s) | module | logs |
|---|---|---|---|
| 1 weak machine breaks | 1Q-NEG-WEAK-UNIV-Q, 1Q-WEAK-BREAKING-RUN-Q, 1Q-NEG-WEAK-INV-Q | phase1q/proofs/n_q_neg_weak_q.k over the weak definition | transcripts/k/ |
| 2 false goals fail | 1Q-DIAG-EQFORM-FALSE, 1Q-DIAG-FALSE-HYP, 1Q-NEG-DEST-Q, QT-UNIV-UNRESTRICTED, QT-BOUND-1-UNRESTRICTED, 1R-BOUND-1-DEST-Q | n_q_diag_eqform.k / n_q_univ_q.k / n_r_toy_threaded.k / n_r_bound_ladder.k | transcripts/k/ |
| 3 checked equality forms | the arrow-form discipline; the EQFORM pair | n_q_diag_eqform.k | transcripts/k/ |
| 4 constraining circular premises | 1Q-UNIV-PREFIX-UNPATCHED-Q (the UNSOUND-CLOSURE exhibit) + 1Q-NEG-PREFIX-CEX-Q (the falsity witness) | n_q_univ_prefix_unpatched.k / n_q_univ_q.k | transcripts/k/ |
| 5 refusal keeps the pre-init state | 1Q-NEG-PREFIX-CEX-Q | n_q_univ_q.k | transcripts/k/ |
| 6 init-accept the only re-tag | verify_grid_1r.py G3 + 1R-BOUND-1-Q (the covered fork) + the 1Q PRESV family of record | scripts/verify_grid_1r.py | audit/grid-verification-1r.txt |
| 7 empty/single-pool commit semantics | 1Q-STRONG-EMPTY-REJECT-STEP-Q, 1R-QS-EMPTY-REJECT-STEP-Q | n_q_univ_q.k / n_r_qs_battery.k | transcripts/k/ |
| 8 every case represented | make_tag0_family_1r.py F2 (the 12 shapes), verify_grid_1r.py G5 (the fork cover), the OMIT mutant battery (1Q-NEG-MUT-OMIT-GATEMINT/-C2) | scripts/ + phase1q/proofs/n_q_neg_mut_omit_q.k | audit/ + transcripts/k/ |
| 9 timeouts never refutations | the ledger's TIMEOUT rows (9) with budgets | claims/claims.csv | transcripts/k/*.rc |
| 10 bounded ≠ universal | the summarizer's BOUNDED-PROVED class (7 claims) vs PROVED (11) | scripts/summarize_1r.py | audit/summarizer-gate-1r.txt |

The QS semantics-preservation battery (the ER-1 variant's own controls):
1R-QS-STALL-STEP-Q, 1R-QS-STALL-NONEXEC-Q, 1R-QS-EMPTY-REJECT-STEP-Q,
1R-QS-RUN-INIT-EXEC-Q, 1R-QS-RUN-HONEST-Q (phase1r/proofs/n_r_qs_battery.k).
