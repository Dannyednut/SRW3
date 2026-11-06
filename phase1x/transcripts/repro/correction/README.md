# Phase 1X correction — clean-checkout verification sequence (Run C, 2026-11-06)

The WS-N sequence of record, executed in a FRESH clone (`srw3-1x-verify`,
cloned --no-hardlinks from the correction worktree) at the correction docs
head `50af992e43eacd01240391fc0e63dd3f994f12db`, worktree clean at start.
Toolchain: K v7.1.337, Z3 4.13.3 (toolchain-versions.txt).

## What ran (all ten sequence steps; staging disclosed in SEQUENCE.log)

1. Full label/inventory checks — runner stage LABELCHECK: all four suites
   (12/12/12/11) match the pinned inventory (runner-fresh/labelcheck-gen.log).
2. Ghost runner execution on K v7.1.337 + Z3 4.13.3 — stages GEN, KOM, MAIN,
   GENSPEC (cm2_alias / cm3_auth / gen_full): 48/48 rows as expected, ALL
   GHOST VERDICTS AS EXPECTED (runner-fresh/*.log; fresh per-claim transcripts
   under runner-fresh/transcripts/ — 47 kpg logs + the fidelity certificate,
   byte-identical to Run A's).
3. Ledger construction — build_ledgers_1x.py: 94 rows (46 fixture + 48 fresh).
4. Enhanced summarizer — GATE GREEN (0 alarms) with S1–S11 live on the FRESH
   ledgers (gate-clean-checkout.txt).
5. Full adversarial suite R1–R40c — 46 PASS / 0 FAIL / 1 SKIP (disclosed:
   R39b needs the final manifest, added by a later commit of this same
   sequence; executed at the final head — see the delivery note)
   (regressions-clean-checkout.log).
6. Run A preservation — git diff 229e066..50af992 EMPTY for
   phase1x/transcripts/ghost + phase1x/claims; runA-sha256.txt re-verified
   anchored at phase1x/: 65/69 OK, the 4 mismatches are exactly the tooling
   files legitimately evolved by reviewed commits AFTER Run A (summarize_1x,
   build_ledgers_1x, run_1x_regressions, phase1x README) — every EVIDENCE
   file matches. (SEQUENCE.log)
7. Run B preservation — runB/sha256.txt re-verified: 61/61 OK. (SEQUENCE.log)
8. Logical comparison — Run A vs Run B vs Run C: all pairs RUNS LOGICALLY
   IDENTICAL (COMPARISON-runC-vs-runA-runB.txt; rc+expected+observed status
   per claim; wall-clock/paths excluded by design).
9. Final SHA-256 manifest — generated and verified AFTER all other Phase 1X
   files were finalized (the ordering requirement); see
   `../evidence-manifest-1x-final.txt` and the delivery note.
10. Clean-worktree verification — 0 dirty files at clone start; the runner
    intentionally wrote fresh evidence into the throwaway clone only; the
    repository's committed evidence paths are not modified by any correction
    commit (verified by the diff checks recorded in the delivery note).

## Staging disclosures (R14 discipline)

- The first LABELCHECK+GEN invocation completed its work (log) but the
  tool-call wrapper hit its ceiling after the runner finished.
- The KOM invocation omitted RUN_APPEND=1 and truncated the ledger (the same
  slip class as Run B's first staging, disclosed in the 1X report §D).
- The recovery call first re-invoked GEN without RUN_APPEND (operator slip)
  before the correct RUN_APPEND=1 re-run; recovered by re-running MAIN with
  RUN_APPEND=1.
- Every GENSPEC invocation carried RUN_APPEND=1; the completed ledger has
  exactly 48 rows; the fresh per-claim transcripts are each claim's final
  execution, consistent with its ledger row (last-wins).

Run C is a THIRD independent execution identified separately (this
directory); Run A and Run B evidence is preserved untouched.
