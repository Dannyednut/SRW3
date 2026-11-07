# Phase 1X — Minor Validator Hardening (findings of the 2026-11-06 review; executed 2026-11-07)

**Character of this document.** This is a concise correction note for a minor
validator-hardening pass — NOT a new mathematical proof phase, NOT a new
theorem, and NOT a change to any proof outcome. The overall project verdict
remains `PARTIALLY COMPLETE`. The Phase 1X evidence-integrity correction of
2026-11-06 (commits `c26b6db` → `e2722be`) remains the correction of record;
this pass hardens two minor validator weaknesses that review identified as
remaining, plus the evidence-packaging obligations that follow from changing
any Phase 1X file.

## Findings addressed

| Finding | Weakness (as reviewed) | Correction | Executed evidence |
|---|---|---|---|
| **A** (register R18) | The S11 model-fixture byte-identity check ran only when BOTH `phase1x/claims/model-verdicts-1x.csv` and `phase1w/claims/model-verdicts-1w.csv` existed — a missing original 1W fixture silently skipped the comparison. The consolidated model provenance was validated with `startswith()` instead of exact equality. | The ORIGINAL immutable 1W fixture is a mandatory gate dependency: a missing Phase 1X copy or a missing original fixture is a named GATE RED alarm; the byte-identity comparison is unconditional whenever both files exist. Model provenance is compared by EXACT equality against the builder's canonical `MODEL_SOURCE` constant (`fixture:phase1w/claims/model-verdicts-1w.csv (1W evidence, immutable)`), which strictly subsumes the prefix check: correct-prefix-with-trailing-text, truncated provenance and fresh-1X values are all rejected. | R41: original fixture removed → GATE RED `phase1w/claims/model-verdicts-1w.csv MISSING — the ORIGINAL immutable Phase 1W model fixture is a mandatory gate dependency…`; R42: original fixture modified, 1X copy retained → GATE RED `model-verdicts-1x.csv is NOT byte-identical to the immutable 1W fixture…`; R43: provenance + ` UNEXPECTED-TRAILING` → GATE RED `!= the exact MODEL_SOURCE…`. All three PASS in the suite. |
| **B** (register R19) | The S8 check accepted any line containing `[HOLDS]` — it did not establish that the expected fidelity equation is the equation being affirmed. | `[HOLDS]` is bound to the ACTUAL fidelity equation: exactly one `equation:` confirmation whose whitespace-normalized text (canonical two-line format rejoined) equals the exact emission of `scripts/audit_ghost_exact.py verify` — `baseline_semantics + exactly_declared_ghost_additions = ghost_instrumented_semantics [HOLDS]` — and exactly one `[HOLDS]` line in the whole certificate, attached inside that equation. Missing, duplicated, truncated or substituted equations and stray `[HOLDS]` lines all fail closed with named alarms. Whitespace normalization affects parsing only, never the semantic comparison. | R44: the genuine two-line equation replaced by unrelated text carrying `[HOLDS]` (seven named [PASS] assertions and the terminal `VERDICT: PASS` preserved) → GATE RED `EQUATION CONFIRMATION MISMATCH…`. PASS in the suite. Manual adversarial probes (stray `[HOLDS]` line; duplicated equation; removed equation) all GATE RED by named alarm. |

Positive control: R38b (the pristine certificate on a fresh sandbox copy of
the genuine committed evidence) remains GATE GREEN under the strengthened
validator — the genuine two-line equation confirmation parses and passes.

## What did and did not change

- Changed (commit `383e7d4`): `phase1x/scripts/summarize_1x.py` (S11
  mandatory fixture + exact provenance; S8++ equation binding) and
  `phase1x/tests/run_1x_regressions.sh` (mkroot stages the original 1W
  fixture unconditionally into every sandbox; R41–R44 added after R40c;
  R1–R40c untouched).
- Changed (commit `ad9e927`): ONLY
  `phase1x/transcripts/repro/evidence-manifest-1x-final.txt`, regenerated
  over the committed code-and-test tree (header Source commit/tree =
  `383e7d4d7c7b06a84cdb70e46e8344cdb30e4a66`; 215 covered paths = every
  tracked `phase1x/` file except the manifest itself; MANIFEST OK). The
  WS-U two-commit ordering requirement is satisfied by construction.
- NOT changed: any theorem, proof outcome, verdict row, ledger, transcript,
  certificate, Run A/B/C evidence, expected result, or historical artifact
  (including the original 138-entry manifest and the 2026-11-06 registers
  and reports, preserved verbatim).
- Execution-environment adaptations (disclosed, semantics-preserving): in
  the 2026-11-07 execution sandbox, symlink creation is policy-blocked, so
  the regression sandboxes stage the 1W transcripts as plain copies of the
  same committed files (the gate checks presence and content, never inode
  type); and the sandbox staging is one multi-argument `cp` per target
  directory because a sourced K toolchain environment makes every forked
  process pay a dynamic-linker `LD_LIBRARY_PATH` scan (~0.3 s/exec), which
  made the previous per-file staging loop ~30 s per sandbox. Neither
  adaptation changes any expected result, alarm name, or case meaning.

## Verification results (at the manifest commit `ad9e927`)

- Enhanced gate on the genuine committed Run A evidence: **GATE GREEN
  (0 alarms)** — 48 ghost + 46 model rows accepted; the genuine Phase 1W
  fixture present and byte-identical (`sha256 a91f059f…` for both copies).
- Full regression suite R1–R44: **51 PASS / 0 FAIL / 0 disclosed SKIP**
  (was 47; the four new cases R41–R44 all pass with their named expected
  outcomes), including R39b (the committed final manifest: MANIFEST OK —
  215 paths, exactly-once coverage, all digests match, self-exclusion
  enforced) and R12 (the live reproduction of the historical runner
  defect; R12b the new-runner refusal).
- Toolchain: K v7.1.337, Z3 4.13.3 (pinned).
- Residual register: R18/R19 CLOSED (this note + the register rows);
  R1–R17 preserved unchanged (R13 stays CLOSED). GH-T remains
  FAILED-STUCK; the genesis-grounded form remains TIMEOUT; the
  destination-false control remains TIMEOUT with its decisive control
  preserved.

## Non-claims

A green gate asserts that the evidence matches the expected verdict
inventory; it is NOT a completeness claim. Parsing a retained certificate
does not re-execute the verifier nor re-establish the source-byte-fidelity
property — those distinctions (retained-certificate check vs afresh
verifier execution vs the property itself) are unchanged. No production
Ethereum security, consensus integration, bisimulation, or full
protocol commitment-boundary safety is claimed. **Verdict:
PARTIALLY COMPLETE.**
