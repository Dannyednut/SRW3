# SRW3 Phase 1O — the Phase 1N evidence audit (reconciliation of record)

**Phase:** 1O — Source-Preserved Transitions and Universal Invariant
Preservation. **Audited object:** the complete Phase 1N claim set and its
retained evidence, at checkpoint `f2ee43dc57e879155b7de68399e09a3ca220333e`
(branch `phase1n-abstract-transition-simulation`).

**Method.** Every 1N claim was re-inventoried from RAW evidence only
(`phase1o/scripts/audit_1n_claims.py`, deterministic, re-runnable); the
retained logs were content-analyzed for proof terminals, trivial-proof
warnings, and residual shapes; five representative claims — including all
three universal claims, which the 1N runner never attempted — were
REPRODUCED LIVE on the pinned toolchain (K v7.1.337 + z3 4.13.3, the 1L
gate reproducing at 25.36s vs the recorded 25.6s). Nothing was taken from
the 1N classification CSVs on trust: the 1O recomputation is compared
against them and every disagreement is listed.

---

## 1. Baseline verification (mandate §2)

| Check | Result |
|---|---|
| Branch `phase1n-abstract-transition-simulation` at `f2ee43dc…` | VERIFIED (remote + local) |
| Checkpoint commit `000dc88` | VERIFIED (an ancestor of `f2ee43dc`) |
| Reported base `1200621e` (Phase 1M) | VERIFIED as the git parent ancestry root of the 1N work |
| Working tree at audit start | CLEAN |
| Frozen-tree integrity 1M→1N | **REPRODUCED CLEAN** (see §6) |

## 2. The five prior audit leads, rechecked (mandate §3)

| # | Lead | Disposition |
|---|---|---|
| L1 | `n_abs_proofs.k` declares `ABS-UNIV-STEP`, `ABS-UNIV-TAIL`, `ABS-PREFIX-SAFE` but the runner's claim list omits them | **CONFIRMED.** The retained `run_n_abs_proofs.sh` CLAIMS array contains `ABS-UNIV-BASE` (line 95) and none of the three universal labels. |
| L2 | No universal proof logs in the evidence bundle | **CONFIRMED.** Only `kprove_ABS-UNIV-BASE.log` exists. There is NO retained log for any of the three universal claims; no `.done_ABS-UNIV-STEP` marker exists either, so the runner never even started them. |
| L3 | `kprove_SIM-EXEC-MINT.log` empty though recorded as a timeout | **CONFIRMED, with the documented convention.** The log is 0 bytes and the ladder CSV records `FAILED(rc=124)`. Phase 1N retains `transcripts/k/README-0-size-logs.txt`, which lists all five 0-byte logs as timeouts of record (the 1M runner-discipline convention: kprove buffers stdout and `timeout` kills it before the flush). Conditionally acceptable: the raw result is the exit code only; no residual is retained. |
| L4 | `frozen-tree-verification.txt` empty | **CONFIRMED as an evidence defect.** The file is 0 bytes, while `PROVENANCE.md` cites it as the record of the frozen-tree check. The CHECK ITSELF is TRUE — this audit independently reproduced it (§6) — but the cited artifact is empty and cannot serve as evidence. |
| L5 | The summarizer may not validate proof terminals / trivial warnings | **CONFIRMED, with precision.** `summarize_1n.py` validates log existence, the empty-log+rc=124 convention, and unknown raw results, and it carries the `trivial` column — but (a) it has NO recognized-proof-terminal check at all, (b) it classifies every PROVED claim as `proved` regardless of the trivial flag, and (c) the runner's `PASS-EVAL` category accepts `WarnTrivialClaim` closures as `correct` by design (the `|| [ "$EXP" = "PASS-EVAL" ]` disjunct in the guard). See Finding 1O-A. |

## 3. Finding 1O-A — the trivial-closure scale (the most material finding)

**58 of the 83 claims classified `proved` by 1N closed with
`WarnTrivialClaim` / "Claim proven without rewriting"** — 49 on the ABS
ladder (the entire `ABS-PRES-*` successor-shape family, the `ABS-PRESV-*`
Bool forms, `ABS-INV-EXCL-*`, `ABS-RUN-*`, `ABS-INIT-BASE-INV`,
`ABS-UNIV-BASE`) and 9 on the SIM ladder (`SIM-ALG-*`).

This is NOT a repetition of the 1M misclassification, and the distinction
matters:

* The 1M vacuous claims had **destination = source** structurally (the
  safety conclusion already inside the hypothesis; zero content). The 1N
  trivial closures are **evaluation closures**: the claim pins the branch
  (the state constructor / the command bits / a concrete pipeline) and the
  checker discharges the obligation by evaluating the defined functions —
  the machine's equations actually run. The negative controls
  (`ABS-NEG-UNSAFE-ACCEPT`, `ABS-NEG-REFUSE-ON-MINT`) FAILED as designed
  (rc=1), which is a live harness-sensitivity witness absent in 1M.
* The 1O live reproduction confirms the signatures: `ABS-INIT-BASE`
  rc=0 with NO trivial marker (genuine rewriting); `ABS-PRESV-I-EXEC-MINT`
  rc=0 WITH `WarnTrivialClaim` + "without rewriting" (evaluation);
  `ABS-NEG-UNSAFE-ACCEPT` rc=1 (designed failure); `ABS-UNIV-BASE` rc=0
  trivial (the base case of the induction, legitimately the identity).
* BUT the 1N classification flattened the distinction: all 58 are
  recorded `proved`, indistinguishable from the 16 genuinely-rewritten
  claims (`ABS-INIT-BASE`, the 10 `ABS-STEP-*`, and 5 SIM shape claims)
  and from the universal theorem that was never attempted. The runner's
  own score files were honest ("PASS-expected proved (non-trivial): 1")
  but the CSVs and the commit message's "74 proved" absorbed the
  distinction.

**1O disposition.** The 1O inventory re-classifies the 58 as
`proved-by-evaluation`: mechanized, non-vacuous *as far as the definition's
own output*, bounded to the pinned branch or the concrete pipeline, and NOT
universal theorems over runs. The 16 rewritten claims are `proved-nontrivial`.
The 1N evidence itself is not repudiated — it is RELABELED precisely.

## 4. Finding 1O-B — the universal theorem was never mechanically attempted in the retained evidence

The three universal claims exist only as declaration text and as narrative
in the 1N report §4 ("genuine residuals of record", "the residuals
reproduce in ~11s"). The bundle retains NO log, NO exit code, and NO
`.done` marker for any of them. The 1N commit message's "genuine residuals
of record" is therefore not independently evidenced by the artifact bundle.

**1O live reproduction (this audit runs them, logs retained):**

| Claim | Result | Time | Residual of record |
|---|---|---|---|
| `ABS-UNIV-STEP` | FAILED(rc=1) | 12s | "configuration's term unifies with the destination's term, but the implication check between the conditions has failed" — the fold stuck on the symbolic `RUN`; the state expanded to `absSt(AX0..AX6)`; no `WarnTrivialClaim` (0 occurrences) |
| `ABS-UNIV-TAIL` | FAILED(rc=1) | 13s | same boundary |
| `ABS-PREFIX-SAFE` | FAILED(rc=1) | 12s | same boundary |

The 1N report's ~11s reproduction claim is consistent with these timings —
the attempts were apparently real; only the evidence was never retained.
The 1O verdict on the 1N universal disposition ("NOT MECHANIZED") STANDS,
now with the raw logs of record in `phase1o/transcripts/k/repro/`.

## 5. Finding 1O-C — timeout misclassified as refutation (the SIM controls)

`SIM-NEG-MINT-ON-FORBIDDEN-SOURCE` and `SIM-NEG-COMMIT-ON-STALE-SLOT` are
FAIL-expected controls whose runs TIMED OUT (rc=124, 0-byte logs) — yet the
1N classification records `refuted`. A budget exhaustion is not a
counterexample: the prover neither discharged the claim nor constructed a
model. The 1O classification is `timed-out-expected-fail` (the design
expectation "must not prove" is met; the refutation is NOT established).
By contrast the ABS controls genuinely failed with rc=1 and residuals —
`refuted-by-proof-failure` (kprove discharged the search without proving;
still not a constructed countermodel, and labeled accordingly).

## 6. Finding 1O-D — the ladder CSVs are a palimpsest; the frozen-tree record is empty but true

* The retained `claims-status-sim.csv` contains a row (`SIM-EXEC-SOURCE`,
  `correct=INCORRECT`) that the retained runner code cannot produce
  (ATTEMPT rows are always `recorded`): the CSV is a composite of multiple
  invocations and runner versions. The `raw_result` column matches the
  logs; the `correct` column is unreliable. The 1O inventory is recomputed
  from raw evidence only.
* The frozen-tree check (mandate §2): `git diff --name-status 1200621e
  f2ee43dc` shows EXACTLY 194 paths — 193 additions under `phase1n/` plus
  `scripts/make_m4.py`. **Zero modifications** to `phase1e`–`phase1m`,
  `k/`, `proofs/`, `python-gen/`, or `docs/`. The 1N provenance claim is
  TRUE; its cited evidence artifact was left empty (Finding from L4). The
  populated record now lives at `phase1o/audit/frozen-tree-verification-1n.txt`.

## 7. Finding 1O-E — the runner's PASS-EVAL guard hole (the 1M lesson incompletely learned)

The 1N runner's stated discipline — "ANY log containing WarnTrivialClaim
is marked TRIVIAL — a trivially closing PASS/ATTEMPT claim is an ALARM,
never a pass" — is enforced ONLY for strict-`PASS` claims. The guard's
second disjunct (`|| [ "$EXP" = "PASS-EVAL" ]`) re-admits trivial closures
for every `PASS-EVAL` claim, and `summarize_1n.py` then classifies them
`proved` unconditionally. The vacuity-detection lesson of 1M
(audit/1m-misclassification-finding.md) was implemented at the ABS-UNIV
level (correctly — `ABS-UNIV-BASE` is trivial-by-evaluation and honestly
flagged) but not across the preservation family. The 1O runner
(`phase1o/proofs/run_o_univ.sh`) closes this hole for its own claims and
its summarizer validates proof terminals explicitly (Finding 1O-F's
remedy; see `phase1o/scripts/summarize_1o.py` and its negative self-tests).

## 8. The reproduction matrix (live, this phase)

| Claim (1N) | 1N record | 1O reproduction | Signature |
|---|---|---|---|
| `ABS-INIT-BASE` | PROVED | rc=0 | no trivial marker — genuine rewrite |
| `ABS-PRESV-I-EXEC-MINT` | PROVED (trivial=YES) | rc=0 | WarnTrivialClaim + "without rewriting" |
| `ABS-NEG-UNSAFE-ACCEPT` | FAILED (designed) | rc=1 | designed control failure |
| `ABS-UNIV-BASE` | PROVED (trivial=YES) | rc=0 | WarnTrivialClaim + "without rewriting" |
| `ABS-UNIV-STEP` | *(no record)* | rc=1, 12s | the composition boundary residual |
| `ABS-UNIV-TAIL` | *(no record)* | rc=1, 13s | same |
| `ABS-PREFIX-SAFE` | *(no record)* | rc=1, 12s | same |

All reproduction logs: `phase1o/transcripts/k/repro/`. The toolchain gate
(the frozen 1L kompile) reproduces at 25.36s vs the recorded 25.6s.

## 9. The claim inventory and reclassification artifacts

* `phase1o/claims/phase1n-claim-inventory.csv` — all 86 1N claims (83
  ladder rows + 3 declared-but-unattempted universals), 22 fields each:
  source location, intended proposition, kind, runner coverage, expected
  outcome, timeout budget, raw result, log existence/size, terminal
  markers, trivial warnings, vacuity assessment, exact command, 1O
  classification, rationale.
* `phase1o/claims/phase1n-reclassification.csv` — the 5 disagreements
  between the 1N classification and the 1O recomputation (the 2 SIM-NEG
  timeouts and the 3 unattempted universals).
* `phase1o/claims/phase1n-audit-summary.txt` — the counts.

## 10. Dispositions (final)

1. **The 1N universal disposition ("NOT MECHANIZED") stands a fortiori** —
   now with retained raw logs of the three attempts (Finding 1O-B).
2. **The 1N "74 proved" splits into 16 non-trivial + 58 by-evaluation**
   (Finding 1O-A); the 1O ladder and report use the finer vocabulary
   everywhere.
3. **The SIM-NEG `refuted` classifications are corrected** to
   `timed-out-expected-fail` (Finding 1O-C).
4. **The frozen-tree verification is reproduced and now on record** with
   the empty-file defect noted (Finding 1O-D).
5. **The 0-byte timeout convention is accepted** as documented (L3), with
   the standing caveat that such claims' raw evidence is the exit code
   only.
6. **The evidence defects (L2, L4, 1O-D, 1O-E) are remediation
   requirements carried into the 1O deliverables**, not merely recorded:
   the 1O runner attempts every claim it lists, the summarizer validates
   proof terminals and trivial warnings, and the frozen-tree file is
   populated.
