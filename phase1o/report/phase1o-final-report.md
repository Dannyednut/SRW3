# SRW3 Phase 1O — Final Report: Source-Preserved Transitions and Universal Invariant Preservation

**Verdict: `PARTIALLY COMPLETE`.** The phase's audit, model, and
investigation deliverables are complete and reproducible; the universal
transition-preservation theorem is **NOT MECHANIZED** — and for the first
time the obstruction is located with a ten-probe minimal reproducer, a
residual-level characterization of the exact tool limitation, and a
soundness-controlled proof architecture that gets within one checker
capability of the theorem. No completion tag exists. Level III only; no
consensus-integration claim is made or implied anywhere.

---

## 1. Exact repository state

| Item | Value |
|---|---|
| Base (verified Phase 1N checkpoint) | `f2ee43dc57e879155b7de68399e09a3ca220333e` on `origin/phase1n-abstract-transition-simulation` |
| 1N checkpoint commit | `000dc88` (verified an ancestor of the checkpoint) |
| 1N reported base | `1200621e9bec096a13f3703862205a383dbc458b` (Phase 1M; verified ancestor) |
| 1O branch | `phase1o-source-preserved-transitions` (created from `f2ee43dc`) |
| Working tree at phase start | CLEAN |
| Toolchain | K v7.1.337 + z3 4.13.3, the pinned recipe (`scripts/reinstall_toolchain_1m_r3.sh`); the 1L validation gate reproduces at 25.36s vs the recorded 25.6s |
| Frozen-tree integrity | `git diff --name-status 1200621e f2ee43dc` = 193 additions under `phase1n/` + `scripts/make_m4.py`; ZERO modifications to any frozen tree (`phase1o/audit/frozen-tree-verification-1n.txt`); the same check is re-run at 1O commit time |

## 2. Changes made (file-level inventory)

All new work is under `phase1o/`; the only outside-directory additions are
none (no shared file was modified). Highlights:

* `phase1o/audit/` — the 1N evidence audit, the reproduced frozen-tree
  record, source hashes, environment of record.
* `phase1o/spec/` — the foundational model and the transition contract.
* `phase1o/claims/` — the 1N machine-readable inventory (86 claims, 22
  fields), the 1O inventory (41 claims), reclassification and summaries.
* `phase1o/semantics/` — three GENERATED machines (`abs-machine-r.k`,
  `abs-machine-weak.k`, `abs-machine-weak-r.k`), each produced by a
  fail-closed roundtrip-verified derivation script
  (`scripts/make_abs_r.py`, `make_abs_weak.py`, `make_abs_weak_r.py`).
* `phase1o/proofs/` — the universal-attempt ladders
  (`n_o_univ.k`, `n_o_univ_r.k`, `n_o_univ_weak.k`, `n_o_univ_weak_r.k`),
  the generated lemma module (`n_o_lemmas.k`, byte-identical to the 1N
  PRESV family), the ten-probe minimal reproducer
  (`repro/univ-repro.k`), and the formal runner (`run_o_univ.sh`).
* `phase1o/scripts/` — `audit_1n_claims.py` (the 1N auditor),
  `summarize_1o.py` (the fail-closed summarizer with negative
  self-tests), the three derivation generators, `make_o_lemmas.py`.
* `phase1o/transcripts/` — every raw kprove log (including the first
  retained logs of the 1N universal claims), the canonical CSV, the
  score, the mirror sweep.

## 3. Baseline audit: the Phase 1N discrepancies and their disposition

Full detail in `phase1o/audit/phase1n-evidence-audit.md`; the findings:

* **1O-A (material).** 58 of the 83 claims 1N classified `proved` close
  with `WarnTrivialClaim` / "Claim proven without rewriting" — evaluation
  closures, non-vacuous at the definition level (the negative controls
  fail as designed; the harness is sensitive), but bounded to the pinned
  branch or concrete pipeline, NOT universal theorems. The 1N CSVs
  flattened this distinction into "proved". 1O re-classifies:
  `proved-by-evaluation` (58) vs `proved-nontrivial` (16).
* **1O-B.** The three 1N universal claims (`ABS-UNIV-STEP`, `ABS-UNIV-TAIL`,
  `ABS-PREFIX-SAFE`) were declared but never in the runner's claim list;
  no logs existed. 1O ran all three live (rc=1, ~12s each) and retains the
  first logs of record. The 1N "NOT MECHANIZED" verdict stands a fortiori.
* **1O-C.** The two SIM negative controls timed out (rc=124, empty logs)
  but were classified `refuted`. Corrected to `timed-out-expected-fail`:
  the design expectation is met, no counterexample was constructed.
* **1O-D.** The 1N ladder CSVs are a palimpsest (a row whose `correct`
  value the retained runner cannot produce). The `raw_result` column
  matches the logs; the 1O inventory is recomputed from raw evidence.
* **1O-E.** The runner's `PASS-EVAL` category re-admitted trivial
  closures as `correct` (the 1M lesson incompletely generalized). The 1O
  runner closes the hole; the summarizer validates proof terminals and
  demonstrates its rejection rules by negative self-tests.

Dispositions: the 1N evidence is preserved unmodified; the corrections
live in the 1O inventory; nothing was relabeled inside the frozen trees.

## 4. Formal model (summary)

`spec/foundational-model.md` defines, over the frozen 1N abstract machine
(unchanged) and the frozen M3 concrete machine:

* \(S\): the `absSt` state space (decidable skeleton); \(S_0\): the
  genesis.
* \(F\): the foundational specification — FIXED by the frozen artifacts
  (the `ABSInv`/`JInvPlusJ` invariant pair, the M3 class partition, the
  R3 authority model); no rule can write it.
* \(Safe_F\): `ABSInv` — the two-branch disjunction; the `sf` bit is set
  only by the computed init guard and carried only by the computed
  commit guard; SafeJ-conformance remains the declared per-execution
  obligation (the 1L stuck-symbolic class, unchanged).
* \(T_F\): the responded-transition relation over the twelve ground
  command shapes with the declared stall class.
* \(Auth_F\): unauthorized specification change is UNEXPRESSIBLE in the
  model (P4 holds by construction — the honest strength limit, not a
  theorem about implementations).
* \(Commit_F\): the accept-commit class, the machine's own guard.
* The six predicate classes of mandate §4 are separated explicitly;
  assumptions A-EV, A-FRAG, A-R3, A-IMPL are inherited unchanged; 1O
  introduces no new assumption.
* The specialization relation (\`spec/transition-contract.md` §4) is
  DEFINITIONAL (what an application may vary), not a monotonicity
  theorem — the mandate's warning is honored.

## 5. Proof ledger (the 1O claims; full inventory in `claims/claims.csv`)

| Classification | Count | Claims |
|---|---|---|
| proved-nontrivial | 4 | `R3-UNIV-CONS`, `R6-DOMAIN-RESTRICTED`, `1O-RUN-HONEST-R`, `1O-RUN-INIT-EXEC-R` |
| proved-by-evaluation | 23 | the 21 trusted-lemma PRESV family + `R4B-EVAL-CONTROL` + `R7-DOMAIN-CONTROL` |
| refuted-by-proof-failure | 5 | `1O-NEG-DEST-R`, `1O-NEG-DEST-RL`, `1O-NEG-WEAK-UNIV-R`, `R5-SOUNDNESS-MUST-FAIL`, `R9-FUNC-DISPATCH-MUST-FAIL` |
| failed-budget | 6 | `1O-UNIV-MACHINE-R`, `1O-UNIV-PREFIX-R`, `1O-UNIV-MACHINE-RL`, `1O-UNIV-PREFIX-RL`, `R1-UNIV-FOLD`, `R10-FUNC-DISPATCH-DOMAIN` |
| timed-out-expected-fail | 1 | `1O-NEG-UNSAFE-COMMIT-R` |
| failed | 2 | `R4-CMD-SPLIT`, `R2-UNIV-MACHINE` |

Every claim: raw log retained, exit code recorded, terminal analyzed,
classification fail-closed (`scripts/summarize_1o.py`, self-test PASS).
The gate is GREEN (zero ALARMS) — no claim's outcome contradicts its
declared expectation — while the universal attempts are recorded as the
failures they are.

## 6. The §6 investigation: the exact obstruction (the phase's central finding)

**Method.** A stall-free ten-probe toy model mirroring the abstract
machine's shape (`proofs/repro/univ-repro.k`); every probe run with
retained logs; the real machine attempted in three architectures.

**The results of record (all in `transcripts/k/`):**

| Probe | Question | Result |
|---|---|---|
| R1 fold form | the 1N `ABS-UNIV-STEP` shape, minimized | FAIL — the 1N residual signature reproduced ("implication check between the conditions has failed") |
| R2 machine form, unrestricted | rewrite-level dispatch | FAIL (after `bad`/`dec2` entered the toy) — correctly: an unrestricted universal over a breaking command fails |
| R3 cons-pinned + domain | circularity self-application | **PROVES non-trivially** |
| R4 symbolic constructor in function-argument position | case-splitting? | FAIL — kprove does NOT case-split function arguments |
| R4b evaluation control | the same over constructors | PROVES (trivial) — isolating R4's boundary |
| R5 unrestricted with a breaking command | soundness of the approach | FAILS as required — no stutter artifact |
| R6 domain-restricted universal | the responded-command discipline | **PROVES non-trivially** |
| R7 domain evaluation control | okRun by matching | PROVES (trivial) |
| R9 function-dispatched runner, unrestricted | false-proof check | FAILS as required — no artifact proof |
| R10 function-dispatched + domain | the 1N runner shape | FAIL — the domain predicate cannot prune a stuck function evaluation |

**The characterized boundary.** kprove (K v7.1.337 Haskell backend):
(1) REWRITE-position constructor variables ARE case-split (the engine
branches on rule-pattern unification — R3/R6's first step); (2)
FUNCTION-argument constructor variables are NEVER case-split (R4, R10);
(3) the implication checker cannot evaluate a pattern-matched function on
a state constrained only by a DISJUNCTION (`ABSInv`) — it needs the branch
literals in the matching, not in the constraint store (the
`1O-UNIV-MACHINE-R` residual); (4) trusted branch-pinned lemmas do not
help: their LHS patterns need the same case-split
(`1O-UNIV-MACHINE-RL`'s residual is the identical obligation).

**The three universal-attempt architectures (all on the real machine,
all retained):**

| Architecture | Claim | Result | Residual of record |
|---|---|---|---|
| 1N fold form (reproduced) | `ABS-UNIV-STEP` | rc=1 | the symbolic `RUN` fold cannot dispatch |
| R machine (rewrite-level dispatch, 12 ground rules + `[owise]` complement that cannot fire on ground commands) | `1O-UNIV-MACHINE-R` | rc=1, 11s | the ground branches ARE genuinely explored (18 branches); the stuck leaf is the implication check `ABSInv(absStepJ(absSt(AX0..AX6), aInitJ(aOkT)))` over the disjunction-constrained state |
| R machine + the 21-claim preservation family as `--trusted` lemmas (each independently re-proven first) | `1O-UNIV-MACHINE-RL` | rc=1, 14s | the identical leaf — the checker does not unify the branch-pinned lemma patterns with the constrained state |

**The one-checker-capability statement.** The theorem is blocked by ONE
identifiable capability: case-splitting a constructor-constrained
symbolic state inside the implication check (equivalently, evaluating a
pattern-matched function under a disjunctive constraint, or unifying
branch-pinned lemma patterns against the constrained state). Every other
ingredient — the per-class content (the 21 lemmas, re-proven), the
composition mechanism (the machine circularity, proven at toy scale), the
dispatch (the R rewrite-level partition), the soundness controls — is in
place and mechanized.

## 7. Universal theorem status

**NOT MECHANIZED.** Neither refuted nor abandoned: the strongest
mechanized fragments are on record — the branch-complete per-class
preservation family (21 claims, independently re-proven in 1O), the
concrete-pipeline machine-level compositions (`1O-RUN-HONEST-R`,
`1O-RUN-INIT-EXEC-R` — real multi-step rewriting on the R machine), the
toy-scale composition theorems (R3, R6), and the exhaustive Python sweep
(864 states × 12 commands; S4 weak-machine control: 48 breaking accepts).
The P1–P6 standing table is in `spec/foundational-model.md` §7.

## 8. Counterexamples and negative controls (all classified)

| Control | Expected | Actual | Classification |
|---|---|---|---|
| `ABS-NEG-UNSAFE-ACCEPT` (1N, reproduced) | fail | rc=1 | refuted-by-proof-failure |
| `1O-NEG-WEAK-UNIV-R` (the weak+R machine universal) | fail | rc=1 | refuted-by-proof-failure — the R dispatch genuinely evaluates the weak accept; the architecture is guard-sensitive |
| `1O-NEG-DEST-R` / `1O-NEG-DEST-RL` (destination sanity) | fail | rc=1 | refuted-by-proof-failure |
| `R5-SOUNDNESS-MUST-FAIL` (toy: a breaking command in scope) | fail | rc=1 | refuted-by-proof-failure — no stutter artifact |
| `R9-FUNC-DISPATCH-MUST-FAIL` (toy: the 1N runner shape) | fail | rc=1 | refuted-by-proof-failure — no false proof |
| `1O-NEG-UNSAFE-COMMIT-R` (ground unsafe commit on R) | fail | rc=124 | timed-out-expected-fail (the reject path's `[owise]` expansion grinds; retained) |
| Python S4 weak-machine control | >0 breaks | 48 breaks | demonstrated (exhaustive finite model) |

## 9. Implementation correspondence

Established: the counting-algebra correspondence (the 1N `SIM-ALG-*`
family, re-verified by the audit), the class-wise simulation shapes with
hash equalities as hypotheses (1N), and the R machine's class-faithfulness
(its twelve rules call the UNCHANGED `absStepJ` with literal commands —
the derivation is roundtrip-verified). Remaining assumptions: the SafeJ
conformance (per-execution), the concrete-layer implementation agreement
(A-IMPL — the LLVM/Python layers are 1M-era evidence, not re-run here),
cryptography (A-EV), the execution fragment (A-FRAG), consensus (none —
Level III). The krun configuration-injection limitation for
abstract-program configurations is recorded (the `$PGM` sort is the
concrete `PProgJI`; `--term` rejects cell syntax in the term parser); the
multi-step runtime evidence is therefore mechanized as ground execution
claims instead.

## 10. Known limitations

1. The universal theorem over symbolic programs is not mechanized (§7).
2. The trusted-lemma mechanism (`kprove --trusted`) rests on the
   independently-retained proof runs of the trusted claims (all 21
   re-proven in the 1O bundle); K has no cryptographic proof-object
   checking, so the trust is procedural, not mechanical.
3. P4 holds by construction inside the model; no claim is made about any
   implementation outside the modeled fragment.
4. The 0-byte timeout convention (inherited from 1M) means timed-out
   claims' raw evidence is the exit code only.
5. The toy reproducer's R2 result changed when the toy's command
   alphabet gained `bad`/`dec2` (the unrestricted universal became
   honestly false); the investigation's intermediate PASS logs are
   retained under `transcripts/k/repro/` and the final probe suite is
   exactly scoped — the evolution is documented, not hidden.

## 11. Reproduction instructions

```
bash scripts/reinstall_toolchain_1m_r3.sh              # K v7.1.337 + z3 4.13.3
source /home/z/my-project/tools/env.sh
export LIBRARY_PATH="$TOOLS/extract/syslibs:$LIBRARY_PATH"
python3 phase1o/scripts/audit_1n_claims.py             # the 1N inventory (re-runnable)
bash phase1o/proofs/run_o_univ.sh                      # the full 1O suite (~15 min)
python3 phase1o/scripts/summarize_1o.py                # the fail-closed inventory
python3 phase1o/scripts/summarize_1o.py --self-test    # its negative tests
python3 phase1n/python/abs_mirror.py                   # the exhaustive sweep
git diff --name-status 1200621e9bec096a13f3703862205a383dbc458b f2ee43dc57e879155b7de68399e09a3ca220333e
                                                       # the frozen-tree check (expect: phase1n/ + make_m4.py additions only)
```

Expected outcomes: the 1L gate ~25s; the universal attempts rc=1 with the
recorded residuals; the controls fail as designed; the mirror sweep PASS.

## 12. Next smallest research step

The single obligation that most directly blocks the theorem: **teach the
proof to case-split the `ABSInv`-constrained symbolic state inside the
implication check.** Concretely, one of:

1. a kprove formulation whose requires pins the ABSInv branch WITHOUT a
   disjunction (e.g., two claims sharing one circularity is not expressible
   in one run — the backend feature needed is exactly "disjunctive-require
   case-splitting in the implication check");
2. a backend capability: constrained constructor case-splitting for
   function-argument positions (the R4/R10 gap);
3. an encoding route: restate `ABSInv` as an EQUALITY against a branch
   tag carried in the state (making the branch a first-class Int with
   z3-decidable constraints, which the checker already splits) — the
   smallest change that stays inside the current toolchain.

Option 3 is the recommended next experiment; the R machine and the
trusted-lemma chain are already in place to receive it.
