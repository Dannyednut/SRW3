# SRW3 Phase 1X — Ghost-Runner Integrity, Proof-Status Fidelity, and State-of-Record Repair

**Final report — the fail-closed record.** Branch `phase1x-ghost-runner-hardening`,
cut from the verified Phase 1W head `34ef232` (the documentation-only landing
commit; the delivered 1W review state `19990a5` is its parent). Phase 1X closed
the registered tooling residual **R13** at the source, restored per-claim
**status fidelity** to the ghost evidence pipeline, and hardened the ledger
gate; this follow-up (2026-10-30) closes the Phase 1X mandate's verification
workstreams: the gate now re-derives every claim's status from the RAW
transcripts (WS-A), the adversarial regression suite was EXECUTED for real
with per-case records (WS-B), the full battery was re-run in an independent
clean environment and compared logically (WS-C), the complete sequence was
executed in a clean checkout with a full SHA-256 evidence manifest (WS-D), and
the documentation surfaces were brought to the current state (WS-E/F/G).

**Verdict: PARTIALLY COMPLETE.** A tooling-integrity phase and its follow-up
close tooling defects and evidence-classification gaps; they do not close
theorems. GH-T remains FAILED-STUCK (the designed probe of the ∀n theorem
form), the genesis form remains TIMEOUT, and all Level-III boundaries remain
open exactly as registered. No completion tag.

**Result-status vocabulary used throughout:** `VERIFIED` (independently
checked in this phase against committed or recomputed evidence), `FAILED` /
`FAILED-STUCK` (designed or discovered prover failures, retained distinctly),
`TIMEOUT` (never relabeled), `NOT RUN` (out of scope this phase; carried),
`BLOCKED` (an external dependency prevents the work), `PASS`/`FAIL`
(per-criterion acceptance in §F).

**Push status of record (2026-10-30):** the Phase 1X branch and this
follow-up are delivered by APPEND-ONLY commits pushed to GitHub with the
owner-supplied credential (the same channel the 1W landing used, on the
owner's standing instruction to continue using it); pushes are
create/fast-forward only, no force, no history rewrite; the remote head is
verified EXACT-equal by credential-free `git ls-remote` after the push, and
the verified heads are recorded in the dated delivery note at the end of
`STATE-OF-RECORD.md`. The branch head is always authoritative
(`git rev-parse phase1x-ghost-runner-hardening`).

---

## §0 — The starting point, independently established

The follow-up mandate named branch `phase1x-ghost-runner-hardening` at head
`e70e863` (parent `34ef232`). Each item was verified from the artifacts at
session start, not from the mandate:

| Reported | Independent finding (2026-10-30) | Status |
|---|---|---|
| Remote head `e70e8634badd0ee5b7de87994751b8e052a3e879` | `git ls-remote` (credential-free, pre-clone): `refs/heads/phase1x-ghost-runner-hardening` → `e70e8634…` — EXACT match; the branch had NOT moved | VERIFIED |
| Default branch unchanged | same ls-remote: `phase1u-model-hygiene` → `8697bd744f…` — unchanged | VERIFIED |
| 1V/1W not rewritten | same ls-remote: `phase1v-configuration-ownership` → `430f46858168f…`, `phase1w-boundary-audit` → `34ef2321f2…` — exactly the delivered heads | VERIFIED |
| Ancestry chain | fresh clone: `8697bd7` ⊂ `430f468` ⊂ `19990a5` ⊂ `34ef232` ⊂ `e70e863` (`git merge-base --is-ancestor`, all four OK) | VERIFIED |
| Clean worktree | fresh clone checks out clean (`git status` empty); `git diff 34ef232 e70e863` = the committed 1X implementation + Run A (73 files, +9670/−2) | VERIFIED |
| Run A evidence in tree | 48-row ghost ledger + full `kpg_1x_*` transcript set + repro digests, all at the committed content | VERIFIED |
| Toolchain | K v7.1.337 + Z3 4.13.3 re-verified live this session (`kompile --version`, `z3 --version`); the sandbox recycle had destroyed the working clones AND the `/home/z/my-project/tools` symlink — the toolchain store survived under `/tmp/my-project/tools` and was re-linked | VERIFIED |

**Session-infrastructure disclosure (register R14, realized again).** Between
the Phase 1X implementation session and this follow-up, the sandbox was
recycled: BOTH working clones were destroyed (their directories survived
empty), while the pushed remote state and the `/tmp` toolchain store survived.
Recovery: fresh `git clone` of the pushed branch (everything needed was
committed — the R14 lesson that working state must be committed early), plus
re-creation of the tools symlink. No evidence was lost: Run A and the 1X
implementation were already at `e70e863` on GitHub.

## §A — R13: the ghost-batch claim-count defect, closed and now adversarially verified

**Root cause (registered at 1W).** `run_1v_ghost.sh`/`run_1w_ghost.sh`
derived the per-claim battery from `split_ghost_claims.py` output without
pinning the expectation inside the batch layer: a splitter regression that
dropped a claim shortened the battery while the batch still exited green.

**Closure at the source (committed at `e70e863`).** The expected label sets
are PINNED in a reviewed data file
(`phase1x/claims/expected-ghost-inventory.json`: 12 / 12 / 12 / 11 labels —
`gen_full` deliberately has NO A1 claim — with per-claim expected statuses
and design roles; ledger arithmetic 47 + 1 = 48 DERIVED from the inventory),
derived from the COMMITTED claim artifacts at `34ef232`, never from splitter
runtime output or row counts (derivation record:
`phase1x/claims/INVENTORY-DERIVATION.md`). The runner asserts the splitter
output against the inventory BEFORE any `kprove` invocation
(`check_labels_1x.py`: missing / extra / duplicate / empty / malformed all
rejected by named reason; `SPEC-FILES-COMPLETE` + `SPEC-FILES-EXACT`).

**This follow-up's additions (WS-A).** The pinning was verified to survive
the WHOLE pipeline, not just the batch layer:

1. The GATE re-derives every claim's status from the raw evidence (§B/§C:
   checks S6–S9), so a ledger row can no longer stand behind evidence that
   does not support it.
2. The regression suite EXECUTED the adversarial cases for real (§D):
   the unmodified historical runner `run_1w_ghost.sh` at `34ef232`, run on
   its own commit with a stub splitter dropping GH-M, wrote exactly **11/12**
   main claims and still exited **0** with `ALL GHOST VERDICTS AS EXPECTED`
   (case R12: `rc=0 rows=11 green=1`) — the defect demonstrated live; the
   NEW runner on the SAME stub refuses with
   `EXACT-SET-EQUALITY: MISSING ['GH-M']` (rc=4) BEFORE any K proof
   (case R12b).

**R13 closure conditions (the mandate's 8-condition gate) — all satisfied:**

| # | Condition | Evidence |
|---|---|---|
| 1 | Inventory pinned | `expected-ghost-inventory.json` + derivation record (data file, reviewed commits only) |
| 2 | Full-suite check BEFORE any K | runner stage LABELCHECK + re-assertion inside MAIN/GENSPEC (R14: runner refuses pre-K, rc=4) |
| 3 | Missing/extra/duplicate/malformed rejected | named reasons (R2–R5, R7, R12b, R13, R14 all PASS) |
| 4 | Exact counts + exact IDs | gate S1 (per-ledger constants 48/46/94/94) + S2 (exact ID sets, duplicates rejected); runner per-stage row-count pins (R15–R18 PASS) |
| 5 | Per-claim status comparison | gate S6 triple + S7 four-way, 48/48 rows (R22–R26 PASS) |
| 6 | Transcript re-verification | S7 recompute + S8 certificate + S9 identity (R27–R30 PASS) |
| 7 | Regressions pass | 31/31 PASS, twice (main clone and runB clean checkout) |
| 8 | Gate rejects downgrade/relabel | R19 (rc relabel → RELABELING ALARM), R22–R26 (FAILED-STUCK→FAILED downgrades → STATUS TRIPLE + FOUR-WAY alarms) |

R13 is therefore CLOSED in `docs/research/residual-register-1x.md` — the
closure covers the TOOLING defect (batch-layer pinning + pipeline-wide
status fidelity). The proof obligations themselves (e.g. GH-T) remain open
exactly as registered.

## §B — Proof-status fidelity: the four-way consistency requirement

The 1W runner/ledger recorded the designed prover failures with the coarse
label `FAILED`, while the report/register recorded `FAILED-STUCK` from the
transcript diagnostics — a status-fidelity gap between ledger and evidence.
Phase 1X closed this with ONE classifier shared by runner and tests
(`classify_1x.py`: PROVED = rc=0 + ≥1 `#Top` + no `[Error]` + no
`WarnStuckClaimState`; FAILED-STUCK = rc=1 + `WarnStuckClaimState` +
`backend terminated`; FAILED = rc=1 without the signature; TIMEOUT = rc=124;
NOT-RUN / INVALID-SUCCESS / UNKNOWN fail closed).

This follow-up enforces status fidelity per claim, per row, from the RAW
evidence (gate additions S6–S9, strictly additive over S1–S5):

- **S6 — the per-claim STATUS TRIPLE.** For every ghost row:
  inventory-expected == ledger-expected-column == observed `status=` field,
  plus exit-code compatibility (PROVED⇒0, FAILED/FAILED-STUCK⇒1,
  TIMEOUT⇒124) and diagnostic evidence IN the observed field itself
  (FAILED-STUCK needs stuck≥1 AND backenderr≥1; PROVED kprove rows need
  #Top≥1).
- **S7 — the FOUR-WAY RECOMPUTE.** Every ghost kprove transcript is
  re-classified with the shared classifier at the ledger's rc; the
  recomputed status must equal the recorded status. A transcript whose
  stuck diagnostics were stripped, whose `#Top` was removed, or into which
  `[Error]` was injected no longer supports its row and the gate goes RED.
- **S8 — the fidelity certificate check.** The `ghost-exact-fidelity` row is
  not a kprove row; its certificate (`ghost_manifest_verify_1x.txt`) must
  itself carry `VERDICT: PASS`, zero `[FAIL]` lines, and the full `[PASS]`
  battery — checked independently of the prover classifier.
- **S9 — CLAIM↔TRANSCRIPT IDENTITY.** Every kprove transcript must mention
  its OWN per-claim spec filename (`c_<L>.k` / `<PRE>_<L>.k` — verified
  present in all 47 committed Run A transcripts): a transcript belonging to
  a different claim cannot stand as this claim's evidence even if its
  classification would match (demonstrated by R30: swapped transcripts →
  2 identity alarms while both classifications would still have matched).

Nothing in S1–S5 (exact per-ledger counts, exact claim-ID inventories,
status vocabulary, non-relabelling, last-wins, transcript presence, headline
invariants) was relaxed; the pre-existing mutation cases R15–R22 still go
RED with their original named reasons (verified in the executed suite log).

## §C — The gate: what GATE GREEN now means

`summarize_1x.py` (strict, fail-closed) asserts, on sandbox copies for
negative controls only:

- S1 exact per-ledger row counts, each its OWN constant: ghost 48
  (= 47 claims + 1 fidelity, DERIVED from the pinned inventory), model 46,
  claims 94, exit-codes 94 — the 1W shared-set acceptance is gone;
- S2 exact claim-ID inventories (set equality both ledgers; duplicates
  rejected; claims = union of model + ghost inventories exactly);
- S3 closed status vocabulary + the GH-T specific preservation
  (FAILED-STUCK, per the 1W report's R5, without rewriting any 1W file);
- S4 non-relabelling (designed-failure rows never rc=0/PROVED; rc=0 kprove
  rows carry `#Top=`);
- S5 carried 1W checks (unique IDs, no empty fields, expectation
  vocabulary, class vocabulary, last-wins exit-code consistency,
  transcript presence incl. the 1W fixture aliases, terminal-rc vocabulary
  {0,1,113,124}, headline invariants);
- **NEW S6–S9 (§B).**

**GATE GREEN (0 alarms) was obtained twice this follow-up:** once over the
committed Run A evidence (main clone) and once over Run B's fresh ledgers in
the runB clean checkout — with the hardened S6–S9 checks live in both.
GATE GREEN asserts the EVIDENCE matches the expected verdict inventory; it
is NOT a completeness claim.

## §D — Execution evidence (provenance distinguished)

| Evidence | Provenance | Where |
|---|---|---|
| **Run A** (the 1X implementation's battery: 48/48 ghost rows, GATE GREEN) | EXECUTED in the Phase 1X session on the pinned toolchain; COMMITTED at `e70e863`; preserved IN SITU — untouched by this follow-up | `phase1x/transcripts/ghost/`, `phase1x/claims/*.csv`, `repro/runA-sha256.txt` |
| **Run B** (independent clean environment) | EXECUTED 2026-10-30 in a FRESH `git clone` of this branch at the follow-up head `9e8e5ad` (clean checkout, fresh mktemp workspaces); all five stages live: LABELCHECK+GEN (regen-immutability OK, path-only manifest drift), KOM, MAIN (12), GENSPEC cm2_alias/cm3_auth/gen_full (12/12/11) — 48/48 rows as expected | `repro/runB/` (full raw evidence: 48 kpg logs, 4 kompile logs, GEN certificates, fresh ledgers, toolchain versions, digests) |
| **Run A vs Run B comparison** | COMPUTED with the committed tool `phase1x/scripts/compare_runs_1x.py` — logical verdicts only (rc + expected + observed STATUS per claim; wall-clock and environment paths excluded by the disclosed path-only drift allowance) | `repro/runB/COMPARISON-runA-vs-runB.txt`: **RUNS LOGICALLY IDENTICAL**, 48/48 tags, census 12/12/12/11 + 1 fidelity, zero mismatches |
| **Regression suite** | EXECUTED for real, TWICE: in the main clone (31 PASS / 0 FAIL) and again in the runB clean checkout as the final WS-D sequence step (31 PASS / 0 FAIL) | `repro/regressions-1x-followup.log`, `repro/runB/regressions-from-runB-checkout.log` |
| **Model verdict ledger** | NOT re-executed — the DISCLOSED immutable 1W fixture (byte-identical copy of `phase1w/claims/model-verdicts-1w.csv`, sha256 `a91f059f…`, per-row `fixture:` provenance in claims-1x.csv), used to exercise the combined-ledger gate | `phase1x/claims/model-verdicts-1x.csv` |
| **Evidence manifest** | GENERATED 2026-10-30: SHA-256 over every file under `phase1x/` (138 digests) with the SOURCE-COMMIT IDENTITY in the header | `repro/evidence-manifest-1x.txt` |

**Staging disclosures (R14 discipline — honest record of deviations):**

1. Run B's first staged invocations were launched WITHOUT `RUN_APPEND=1`, so
   each invocation truncated the ledger at start and only the last suite's
   11 rows survived. Recovery: the missing stages were re-run with
   `RUN_APPEND=1`; the runner's designed last-wins dedup retained each
   claim's FINAL execution; the completed ledger has exactly 48 rows and the
   gate is GREEN. The exported runB transcripts are each claim's final
   execution, consistent with its ledger row.
2. The executed suite exposed two test-harness defects IN THE SUITE ITSELF,
   both fixed by making the demonstrations MORE faithful (commit `9e8e5ad`):
   R12 must replicate the 1W-session invocation conditions (the historical
   34ef232 runner predates the 1X `LD_LIBRARY_PATH` set-u guard — without
   the pre-source it dies at the env.sh source, an environment artifact, not
   the defect under demonstration; and the historical runner has NO
   per-invocation ledger truncation, so the committed 1W ledger must be
   removed in the sandbox first — otherwise the appended battery is
   indistinguishable from history, which is itself further evidence of the
   1X C4 hardening), and R17's alarm-shape expectation was corrected to
   MISSING + DUPLICATE (a count-preserving substitution with a REAL tag
   produces exactly those two named alarms).

## §E — Residuals (R1–R14)

Carried forward with NO drops, merges, or downgrades; indexed in
`docs/research/residual-register-1x.md` (the 1W register remains as the
historical record). Changes this phase: **R13 CLOSED** (§A — all eight
closure conditions satisfied with executed evidence); **R14 updated** (the
sandbox recycle realized AGAIN — this follow-up's recovery by fresh clone
re-execution, plus the RUN_APPEND staging disclosure above); every other
item unchanged, in particular R3 (genesis TIMEOUT), R4 (destination-false
TIMEOUT; decisive control stands), R5 (GH-T FAILED-STUCK — re-confirmed
by the four-way recompute in BOTH runs), R6 (combined-batch tool boundary),
R7 (examiner archival BLOCKED), R8 (crosswalk OPEN), R10 (harness-honesty
TCB open by definition), R11 (Level-III boundaries OPEN), R12 (licence/tag
owner authority).

## §F — Acceptance criteria (per-criterion status)

| # | Criterion (Phase 1X follow-up mandate) | Evidence | Status |
|---|---|---|---|
| 1 | Entry gate: actual remote head confirmed, ancestry + 1V/1W non-rewrite verified, clean worktree | §0 table (ls-remote exact, four merge-base checks, fresh clone) | **PASS** |
| 2 | Gate enforces the per-claim STATUS TRIPLE (inventory == ledger-expected == observed), all 48 rows | S6; GATE GREEN ×2 with the checks live | **PASS** |
| 3 | Gate enforces exit-code compatibility per expected status | S6b (PROVED⇒0, FAILED/FAILED-STUCK⇒1, TIMEOUT⇒124) | **PASS** |
| 4 | Gate enforces diagnostic-evidence support in the observed fields | S6c (stuck/backenderr for FAILED-STUCK; #Top≥1 for PROVED) | **PASS** |
| 5 | Four-way consistency (inventory / runner / recomputed / rc) via the shared classifier on raw transcripts | S7; all 47 kprove rows recomputed GREEN in both runs | **PASS** |
| 6 | Fidelity row backed by an independently checked certificate | S8 (VERDICT: PASS, 0 [FAIL], full battery) | **PASS** |
| 7 | Claim↔transcript identity binding | S9 (per-claim spec token in all transcripts); R30 (swap → ≥2 alarms) | **PASS** |
| 8 | New regression controls recorded: per-claim downgrades (GH-T2-NEG, GH2/GH3/GH4-NEG), stripped stuck diagnostics, removed #Top, injected [Error], identity mismatch | R23–R30, all PASS in both executed suite runs | **PASS** |
| 9 | NO relaxation of the existing inventory/count checks | S1–S5 unchanged; R15–R22 still RED with original reasons (suite log) | **PASS** |
| 10 | Regression suite EXECUTED for real with per-case expected/actual/exit/reason | `repro/regressions-1x-followup.log` (31 cases) + runB re-run | **PASS** |
| 11 | Old-runner defect reproduced on the TRUE historical runner; new runner refuses the same input | R12 (`rc=0 rows=11 green=1` on `run_1w_ghost.sh@34ef232`) + R12b (rc=4 MISSING GH-M) | **PASS** |
| 12 | Run B completed in an independent clean environment, all stages | §D Run B row; 48/48 rows; toolchain versions captured | **PASS** |
| 13 | Run A preserved in situ; runA/runB layout created | §D; main-clone transcripts untouched (git-clean); `repro/runA/` + `repro/runB/` | **PASS** |
| 14 | Four-suite logical verdict comparison Run A == Run B | `COMPARISON-runA-vs-runB.txt`: RUNS LOGICALLY IDENTICAL | **PASS** |
| 15 | Clean-checkout FULL sequence (runner → build → gate → regressions) executed | §D runB sequence; gate GREEN; suite 31/31 in the clean checkout | **PASS** |
| 16 | Full SHA-256 evidence manifest with source-commit identity | `repro/evidence-manifest-1x.txt` (138 digests, commit header) | **PASS** |
| 17 | Final report with §0–§G distinguishing evidence provenance (Run A = committed, Run B = new, regressions = real executions, model = 1W fixture) | this report §D table | **PASS** |
| 18 | README + STATE-OF-RECORD current (1V/1W landed, 1X the newest working branch at its actual head; 2026-10-28 BLOCKED and 2026-10-29 landing history preserved; dated 1X follow-up note) | WS-F updates; historical notes preserved verbatim | **PASS** |
| 19 | Delivery discipline: append-only reviewable commits, push WITHOUT force, remote head verified, no completion tag, verdict PARTIALLY COMPLETE | dated delivery note in STATE-OF-RECORD (verified heads recorded after the push); no tag; verdict unchanged | **PASS** |

## §G — Limitations (what this phase does NOT claim)

1. **No new theorems.** GH-T stays FAILED-STUCK (the minimal-destination
   probe of the ∀n theorem form); the genesis form stays TIMEOUT; the
   destination-false control stays TIMEOUT; nothing was relabeled.
2. **The model ledger is a disclosed fixture.** The 46-row model verdict
   ledger is the immutable 1W evidence copy, exercised through the combined
   gate; no model-level proof was re-executed in 1X (the 1W two-run model
   reproduction stands as its record).
3. **Logical comparison only.** Run A vs Run B compares rc + expected +
   observed status per claim; wall-clock timings and environment-absolute
   paths are excluded (the disclosed path-only drift allowance). No
   performance claim is made.
4. **Toolchain-bound classifications.** The status vocabulary's
   machine-checkable signature (stuck tokens, #Top, [Error]) is defined on
   the pinned toolchain (K v7.1.337, Z3 4.13.3); a generic rc=1 without the
   signature is recorded as FAILED and the runner fails closed on anything
   unrecognized.
5. **Staged execution.** The sandbox kills background processes between
   tool calls (R14); both runs used staged foreground execution with
   last-wins dedup. Run B's first staging slip (missing RUN_APPEND) is
   disclosed in §D with its recovery.
6. **Level III only.** No consensus-integration, concrete-Ethereum,
   protocol-commitment-boundary, bisimulation, or generator-completeness
   claim is made.
7. **A green gate/runner is not completeness.** The verdict remains
   **PARTIALLY COMPLETE**; the open-obligation list lives in the residual
   register (`docs/research/residual-register-1x.md`).

## §H — Evidence-integrity correction addendum (2026-11-06) — append-only

The independent review of this follow-up (delivered 2026-10-30) confirmed
that the delivery substantially improved the proof-status pipeline and
closed the original R13 defect, and identified four remaining integrity
issues. This addendum is APPENDED; §0–§G and their acceptance table are the
historical record of the 2026-10-30 delivery and are not rewritten. No
proof outcome, expected theorem status, or historical phase evidence was
changed by this correction — the verdict remains **PARTIALLY COMPLETE**.

### H.1 — The review findings

| # | Finding | Verdict on investigation |
|---|---|---|
| F1 | The consolidated 94-row claim ledger was not fully checked against its source verdict ledgers; a claim's exit code could be altered in BOTH consolidated files (mutually consistent) while the source row and transcript stay untouched, evading the checks | **Confirmed** — implemented as S10/S11 below; the evasion shape is now a named gate alarm and a rejected regression case (R31–R34b) |
| F2 | The S8 fidelity-certificate check counted markers (≥5 `[PASS]`, `VERDICT: PASS`, 0 `[FAIL]`) instead of validating the complete required named-check set — a certificate retaining five arbitrary passes plus the verdict text while omitting a required named assertion would pass | **Confirmed** — implemented as S8+ below; now a named-alarm rejection (R35–R38b) |
| F3 | The SHA-256 manifest `evidence-manifest-1x.txt` (138 digests) omits the final report added after its generation | **Confirmed, and BROADER than reported**: the phase README `phase1x/README.md` was also updated after manifest generation (commit `dff34c4`), so the manifest was stale for TWO files, not one — the checker (`check_manifest_1x.py --check` against the current tree) names both |
| F4 | `STATE-OF-RECORD.md` still identifies `dff34c4` as the delivered branch head while the branch pointed to `229e066` | **Confirmed** — corrected by the dated append-only note (H.6) |

### H.2 — Source→consolidated ledger consistency (S10/S11, commit `c26b6db`)

The projection rules a source verdict row obeys on its way into the
consolidated ledgers are CENTRALIZED in `build_ledgers_1x.py`
(`classify`, the new `expectation_for`, the source labels) and IMPORTED by
`summarize_1x.py`, so the builder and the validator cannot silently
diverge. The gate then re-derives every consolidated value FROM THE SOURCE
ROW at gate time:

- **S10, all 48 ghost rows**: exactly one consolidated claim row per source
  ID (missing/duplicate/substituted/unexpected IDs never accepted);
  consolidated `exit_code` == source rc; `expectation` ==
  `expectation_for(source verdict)`; `class` == `builder_classify(source
  tag, source vclass)`; the exit-code inventory row == the claim row == the
  source rc; the provenance field identifies the ghost runner.
- **S11, all 46 model rows**: the same join against
  `model-verdicts-1x.csv` (the DISCLOSED immutable 1W fixture — never
  treated as a fresh Phase 1X execution); the provenance field must
  preserve `fixture:phase1w/claims/model-verdicts-1w.csv`; and when the
  immutable fixture file is present the copy must be BYTE-IDENTICAL to it
  (sha256).

**Shared logic vs independent checking.** The shared functions keep the
RULES in one place; the validator nevertheless recomputes each projected
value from the SOURCE row and compares — and the mutation tests R31–R34b
demonstrate empirically that a consolidated-only mutation (source rows and
transcripts untouched, the two consolidated files mutually consistent) is
rejected BY NAME. The gate result on all three evidence sets (Run A
committed, Run B, the fresh Run C) is GATE GREEN (0 alarms) with S10/S11
live.

### H.3 — Fidelity-certificate validation (S8+, commit `c26b6db`)

S8 now validates the REQUIRED NAMED-CHECK SET of the canonical full-mode
output of `scripts/audit_ghost_exact.py verify` — the generator of the
certificate — rather than counting markers: the seven named assertions
(baseline slice unchanged; artifact byte-identity; header region;
extension region; baseline ⊕ declared insertions = copied body; no
undeclared executable addition; marker accounting), each appearing EXACTLY
ONCE as `[PASS]`; missing, duplicated, failed-present, and unexpected named
assertions each produce a named alarm; zero `[FAIL]`; exactly one terminal
`VERDICT:` line equal to the canonical success text; the `[HOLDS]`
equation confirmation required. The three distinctions, documented in the
gate source and respected by the implementation:

1. **Checking a retained certificate** — what S8+ does: a strict parse of
   the committed transcript against the canonical check set.
2. **Executing the verifier afresh** — what the runner's GEN stage did at
   run time to PRODUCE the certificate (and only for the artifact state it
   then verified). The gate deliberately does not re-execute it.
3. **Source-byte fidelity** — the PROPERTY the verifier establishes via the
   frozen SHA-256s. S8+ establishes that the retained certificate says so,
   completely; the verifier's own frozen checks establish that it WAS so.

### H.4 — The adversarial battery R31–R40c and its execution

16 new cases (unique IDs; R1–R30 untouched, all 31 originals still PASS
with their original meanings); every mutation on sandbox copies only; every
case records expected / actual / exit code / named reason. Executed TWICE:
pre-commit in the correction worktree and in the clean-checkout sequence of
record (commit `a68407a`, log
`transcripts/repro/correction/regressions-clean-checkout.log`): **46 PASS /
0 FAIL / 1 disclosed SKIP** both times.

| Case | Mutation | Required | Actual |
|---|---|---|---|
| R31 | ghost consolidated rc changed in claims+exit-codes TOGETHER, source untouched | GATE RED | GATE RED (S10 rc join, named) |
| R32 / R32b | ghost consolidated class / expectation changed | GATE RED | GATE RED (S10 class/expectation joins) |
| R33 / R34 / R34b | model-fixture consolidated rc / class / expectation changed | GATE RED | GATE RED (S11 joins + fixture rules) |
| R35 | required named certificate `[PASS]` removed, ≥5 other markers + verdict kept | GATE RED | GATE RED (REQUIRED named check MISSING) |
| R36 | a required assertion duplicated | GATE RED | GATE RED (DUPLICATED 2x) |
| R37 | a `[FAIL]` assertion injected | GATE RED | GATE RED ([FAIL] line + NOT PASSING) |
| R38 | terminal VERDICT removed | GATE RED | GATE RED (found 0) |
| R38b | pristine certificate/ledgers control (restore-to-genuine) | GATE GREEN | GATE GREEN (0 alarms) |
| R39a / R40 / R40b / R40c | fixture-tree manifest: coverage / mutated file / added file / duplicated line | PASS / RED / RED / RED | PASS / RED / RED / RED (checker named alarms) |
| R39b | committed final manifest verified vs `git ls-files` | PASS | SKIP-disclosed at this commit (the manifest is added by a LATER commit of this same sequence — the WS-J ordering requirement forbids generating it earlier); executed at the final head, recorded in the delivery note |

Three suite defects were found BY execution and fixed in the same commit,
each making the demonstration MORE faithful: R37's expected alarm name, the
pristine-control sandbox (mkroot now stages the 1W fixture ledger + the 1W
alias transcripts so R38b is genuinely GREEN), and R40c's in-place append.

### H.5 — The final evidence manifest (WS-J)

`transcripts/repro/evidence-manifest-1x-final.txt` covers EVERY tracked
file under `phase1x/` — all source scripts, the runner, ledgers,
certificates, Run A evidence, Run B evidence, the Run C correction
evidence, regression output, READMEs, and the final report — excluding
ONLY itself (a file cannot contain its own digest; the self-exclusion is
documented in the manifest header and ENFORCED by the checker, which
rejects self-inclusion). Each path exactly once, one SHA-256 per path,
with the source commit/tree, generation date, and pinned toolchain in the
header. It is generated LAST (after the report, READMEs, ledgers and all
evidence are frozen) and committed together with the frozen tree; NO
Phase 1X file is modified after generation (the correction's only
subsequent commit touches root-level files outside the phase1x/ scope).
The original 138-entry `evidence-manifest-1x.txt` is PRESERVED verbatim as
historical evidence; the final manifest supersedes it in coverage only.
Verification is programmatic (`check_manifest_1x.py --check` against
`git ls-files`): missing/unexpected/duplicate paths, incorrect digests,
and self-inclusion are all rejected; the verification results are recorded
in the delivery note and are re-executable by anyone with one command.

### H.6 — The state-of-record correction (WS-K)

`STATE-OF-RECORD.md` gained the dated append-only note "Phase 1X
delivery-pointer correction (2026-11-06)": `229e066` identified as the
previously verified delivery head (matching the uploaded delivery record);
the 2026-10-30 note's `dff34c4` explained as the HISTORICAL
pre-delivery-note head (the delivery-note commit was appended after the
push it records, then pushed itself as the next fast-forward); the general
self-referential-hash limitation recorded (a documentation commit cannot
contain its own final SHA — the branch ref is the pointer of record, and
post-push `git ls-remote` is the verification); every historical narrative
(2026-10-28 BLOCKED, 2026-10-29 landing, 2026-10-30 follow-up and delivery
notes) preserved verbatim. Nothing was rewritten.

### H.7 — Residual register (WS-L)

`docs/research/residual-register-1x.md` carries R1–R17 with no drops,
merges, or downgrades. **R13 remains CLOSED** for the original ghost-batch
claim-count tooling defect under its recorded 8-condition closure — this
correction does not reopen or downgrade it. New rows, appended 2026-11-06:
**R15 CLOSED** (per-claim source→consolidated joins + executed mutation
battery R31–R34b); **R16 CLOSED** (exact named-check validation + executed
battery R35–R38b); **R17 CLOSED** (programmatic full-tree manifest
generation and verification — closed at the manifest commit with the
verification record in the delivery note). GH-T stays FAILED-STUCK; the
genesis form stays TIMEOUT; the destination-false control stays TIMEOUT
with its decisive control preserved; R3/R4/R6/R7/R8/R10/R11/R12 unchanged.

### H.8 — Correction acceptance table (22 criteria)

| # | Acceptance criterion | Evidence | Status at this commit |
|---|---|---|---|
| 1 | Correct starting branch/head independently verified | entry gate: credential-free ls-remote = `229e066…` (40-char server value; the task text's inline hash dropped one character, same 229e066 abbreviation); worklog part 1 | **PASS** |
| 2 | Append-only ancestry preserved | merge-base checks (8697bd7→430f468→34ef232→229e066) + the correction commits are descendants; no force/rebase | **PASS** |
| 3 | All 48 ghost claims joined to source verdict rows | S10 live; GATE GREEN on Run A, Run B, Run C ledgers | **PASS** |
| 4 | All 46 model fixture claims joined to source verdict rows | S11 live (incl. fixture byte-identity + provenance) | **PASS** |
| 5 | Consolidated exit-code rows checked against source and claim rows | S10/S11 exit-code joins + last-wins check | **PASS** |
| 6 | Ghost source/consolidated mutation tests reject altered exit codes | R31 GATE RED by named alarm | **PASS** |
| 7 | Ghost source/consolidated mutation tests reject altered expectation/class | R32/R32b GATE RED | **PASS** |
| 8 | Model source/consolidated mutation tests reject altered exit codes | R33 GATE RED | **PASS** |
| 9 | Model source/consolidated mutation tests reject altered expectation/class | R34/R34b GATE RED | **PASS** |
| 10 | S8 validates every required named certificate assertion | S8+ (7 named checks, exactly-once, all-PASS); H.3 | **PASS** |
| 11 | All certificate mutation controls reject malformed/incomplete certificates | R35/R36/R37/R38 GATE RED + R38b GATE GREEN | **PASS** |
| 12 | Original R1–R30 controls remain intact and meaningful | suite logs: all 31 originals PASS with original IDs/meanings (both executions) | **PASS** |
| 13 | New regression controls R31–R40 execute successfully | 46 PASS / 0 FAIL / 1 disclosed SKIP (R39b at final head), twice | **PASS** |
| 14 | Original Run A evidence remains preserved | git diff EMPTY for Run A paths; runA-sha256 re-verified (65/69, 4 = reviewed tooling evolution, all EVIDENCE files match) | **PASS** |
| 15 | Original Run B evidence remains preserved | runB/sha256.txt 61/61 OK; untouched | **PASS** |
| 16 | Full verification sequence executes in a clean checkout | Run C sequence (commit `a68407a`): steps 1–8+10 in one clean clone, step 9 staged per the WS-J ordering (disclosed) | **PASS** |
| 17 | Final manifest covers all tracked Phase 1X files except itself | the manifest + checker; header records the exact count | **PASS** |
| 18 | Manifest mutation and digest checks behave correctly | R40/R40b/R40c GATE RED by named alarms; R39a PASS; R39b at final head | **PASS** |
| 19 | State-of-record accurately distinguishes historical and current references | the 2026-11-06 correction note (H.6) | **PASS** |
| 20 | Residual register carries R1–R17 without silent drops or downgrades | register rows R15–R17 added; R13 stays CLOSED; others unchanged | **PASS** |
| 21 | Final report documents the corrections and their actual evidence | this addendum §H | **PASS** |
| 22 | Final branch push is fast-forward only and independently verified | the push executes immediately after this commit (the last step); the verified remote head is recorded in the delivery note | **NOT RUN at this commit — executed as the delivery step; verified post-push** |

### H.9 — What this correction does NOT claim

A green evidence gate means the retained evidence matches the expected
evidence inventory and resists the adversarial mutations tested. It does
NOT discharge any proof obligation: GH-T remains FAILED-STUCK, the
genesis-grounded form remains TIMEOUT, the destination-false control
remains TIMEOUT with its decisive control preserved, the combined-batch
tool boundary / harness-honesty TCB / examiner-report archival /
research-framework crosswalk / Level-III boundaries / licence-and-tag
owner-authority items remain open (register R1–R14). No Ethereum/KEVM
production-security, consensus-integration, bisimulation, or
protocol-commitment-boundary claim is made. The verdict remains
**PARTIALLY COMPLETE**.
