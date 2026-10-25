# SRW3 Phase 1S — Final Report: Constructor-Count Refinement and Transition Coverage

Date of record: 2026-10-25. Branch **`phase1s-refinement-coverage`**,
created from the verified Phase 1R commit. Toolchain **K v7.1.337 +
z3 4.13.3** (the pinned recipe, rebuilt after the ninth sandbox reset).
Ledger: **103 claims, GATE GREEN (zero alarms)** — 73 PROVED-EVAL,
1 PROVED-UNDER-C1.2-ASSUMPTION, 1 ASSUMPTION, 23 FAILED-STUCK,
4 TIMEOUT, 1 SELF-ASSUMED, plus the ASSUMPTION row's declaration.

## 1. Verdict

**PARTIALLY COMPLETE.**

The Phase 1R universal safety theorem over the constructor-count machine
has been MIGRATED to the integer model's actual safety predicate
(`ABSInvE` — the 1P `ABSInvT` meaning verbatim, including its tag-1
nonnegativity conjuncts) as a mechanized closure — **under the explicitly
disclosed C1.2 nonnegativity assumption**. Unconditionally, the migration
fails at exactly ONE mechanized residual: the commit-accept strip state's
`countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0` — the structural
induction over function-argument constructor variables that the pinned
toolchain has not provided since 1O. That residual was isolated
mechanically, measured at every dependent cell, and disclosed — it is
never labeled unconditional and never hidden. A positive integer-model
theorem under a disclosed assumption is an honest PARTIAL result; the
mission's acceptance criterion ("a positive integer-model theorem is not
a necessary condition of honest reporting") is satisfied with the
strongest positive content the toolchain supports.

## 2. Exact repository, branch, commit, working tree (§11.1)

* Remote `github.com/Dannyednut/SRW3`; branch of record
  `phase1s-refinement-coverage`, created from the verified Phase 1R commit
  **`29e7cee92acf572fb1094e2db5289dc3f65794d3`** (the remote
  `phase1r-fold-decomposition` verified at exactly that hash before any
  work; ancestry verified: 1Q `f6c5106…` and 1P `83dd015…` are ancestors;
  1P's parent is the 1O freeze `cdb5556…`).
* Working tree at phase start: a fresh detached worktree at the 1R commit —
  clean. The 1N–1R trees are UNTOUCHED by this phase (verified: `git
  status` shows only `phase1s/` additions; the generators' roundtrip over
  the frozen sources is byte-identical). The only shared-file change is
  the root `worklog.md` entry, per the established protocol.

## 3. Phase 1R reproduction results (§11.2; mission §1)

All on the rebuilt pinned toolchain (kompile rc=0 for both definitions of
record; raw logs in `transcripts/1r-repro/`):

| item | result |
|---|---|
| `1R-UNIV-COMPOSED-QS` (standalone, budget 560 s) | **rc=0, wall 12 s** (record: 12 s) |
| depth-1 probe | rc=1 FAIL, 10 s (cannot close at depth 1 — genuine unrolling required) |
| depth-2 probe | rc=1 FAIL, 11 s |
| depth-3 probe | rc=0 close, 12 s |
| the 1R summarizer gate over the frozen ledger | GATE GREEN, 53 claims, rc=0 |
| `verify_grid_1r.py` | ALL CHECKS PASS (G1–G6) |
| `make_abs_qs.py` / `make_tag0_family_1r.py` | roundtrip BYTE-IDENTICAL |
| the 1P TDRR anchor | `448db6a4…` matches the of-record sha256 |
| source hashes of record | `audit/source-hashes-1r.txt` (QS machine `b526e299…`, generator `78e4049a…`, univ spec `528f1bcc…`) |

The depth-probe logs are NEW retained evidence (the 1R session ran the
probes but did not retain separate transcripts; `audit/baseline-1s.md` §3
documents this). The reproduction-instruction reconciliation: the report
§10 sequence of record executes as written; the one-command form for the
central theorem + gate is in `audit/baseline-1s.md` §5.

## 4. CountRel / StateRel — the formal correspondence (§11.3; mission §2)

Defined mechanically in the GENERATED additive module
`semantics/rel-machine.k` (fail-closed, roundtrip-verified, sha-anchored
to the three frozen sources):

* **`CountRel(p, n) ⇔ n ==Int countToInt(p)`** — the exact interpretation;
  no slack, no bounds; the integer side's own nonnegativity stays INSIDE
  `ABSInvE` (the integer model's actual predicate) and the constructor
  side's is obligation C1.2 — never silently added or dropped.
* **`StateRel(absStQ(TG,C,T,G,E,N,SF,D), absStQE(C,T,G2,E2,N,SF,D))`** —
  the shared config/auth bits (C, T), the slot counter (N), the safety
  flag (SF, identity mapping), and the diagnostic (D, identity mapping,
  all four constructors) are enforced at MATCH time by shared pattern
  variables (the reliable KORE route); both pools related by CountRel; the
  branch tag required legal (`TG ∈ {0,1}` — an incoherent tag such as 7 is
  refused explicitly, not vacuously) and consistent with the init-state
  bits on BOTH sides (one conjunct set governs both, since the mirror's
  bits ARE the shared C, T). No silent field drops; no weakened safety
  predicates.
* **`qToQE`** — the definitional image; **`1S-INIT-CORR-*`** — the genesis
  is related and safe on BOTH sides by evaluation (`InitialSafeInt` of
  record).
* **Integer-model side of record**: the in-repo verbatim mirror
  (`absStQE`/`absStepE`/`ABSInvE`) declared inside the frozen QS module.
  A direct dual import of the two frozen modules is INFEASIBLE on the
  pinned frontend (token ambiguities — `audit/frontend-probes-1s.md`
  Probe A, rc=113); the mirror↔1P provenance is carried by the generator's
  verbatim transcription + the sha anchors + the static row witness
  (`scripts/verify_rows_1s.py`: 17 step rows multiset-equal under the
  documented renames; `ABSInvE` ≡ `ABSInvT`; W1–W4 ALL PASS) — **TCB-1,
  disclosed**.
* A frontend soundness-adjacent finding recorded en route: `==Bool`
  equality CONJUNCTIONS over shared symbolic variables inside a function
  RHS leave polluted bindings on this toolchain (single equalities close,
  two-member conjunctions do not — the probe logs `transcripts/probes/`);
  the relation was redesigned onto the matcher route, which the probes
  showed to be reliable.

## 5. C1 results (§11.4; mission §3)

| obligation | disposition |
|---|---|
| C1.1 elimination equations | **PROVED** (`1S-C1.1-EQ0/EQ1`, rc=0) — evaluation on constructor-headed arguments, symbolic tails |
| C1.2 universal | **ATTEMPTED, FAILED-STUCK** (rc=1, 10 s) — the residual of record; the structural-induction boundary confirmed live |
| C1.2 zero case | **PROVED** (evaluation) |
| C1.2 succ case (the conditional induction step) | **PROVED** (evaluation + arithmetic; the IH in the requires — a lemma about the step, NOT the universal) |
| C1.2 slack propagation | **PROVED** (`1S-C1.2-SLACK`) — the mint-class discharger needing NO induction |
| C1.2 depth family d=0..5 | **PROVED** each (BOUNDED-PROVED; generated; never relabeled to the universal) |
| C1.2 no-counterexample experiment | the conditional step + the depth chain + the generator's canonical sweep (every PoolCount shape ≤ depth 5 interprets nonneg — no counterexample in the bounded space) + the SORT argument (no negative inhabitants) — the residual is a proof-engineering boundary, not a semantic doubt |
| C1.3 exact increment (exec-mint) | **PROVED** (rc=0; no C1.2 dependence) |
| C1.3 gate-mint / gate-refuse | **PROVED** in the C12-COND form (rc=0); the unconditional NODEP probe records the requires-fire dependence (rc=1) |
| C1.4 exact decrement (commit-accept) | **PROVED** in the C12-COND form (rc=0); post nonnegativity follows from the wrapped `>=Int 1` hypothesis by arithmetic WITHOUT the universal |
| C1.4 size-one boundary | **PROVED** (`1S-COV-E-COMMIT-B-AT11`, rc=0): (1,1) → (0,0) on BOTH sides |
| C1.4 NODEP probe | **FAILED-STUCK** (rc=1) — the divergence cell (Q strips vs the mirror row-A stutter) is refuted only by C1.2 — measured |
| C1.5 empty-pool correspondence | **PROVED** (`1S-CORR-GATE-EMPTY`, rc=0): Q row A-Z (`zeroP`) ↔ mirror row A (`E' <= 0` fires by evaluation); the backward direction closes conditionally (`1S-C1.5-BWD-COND`, rc=0) |

The dependence ledger (measured, not assumed): every class closes WITHOUT
C1.2 except the commit-accept strip cells and the gate/commit
requires-fires — exactly the spots the migration residual names.

## 6. C5 results and the trust boundary (§11.5; mission §5)

* **Mechanized (K)**: all 17 declared step cells + the 4 complement-
  inertness cells as ground evaluation claims (rc=0, 21/21); the mirror
  guard grid (7/7 rc=0, including the exact boundaries E'=0, E'=1, (G',E')=
  (1,1)); the exclusivity pairs (3/3 rc=0); the executable-domain anchors
  (3/3 rc=0). The battery is GENERATED from the frozen machine source by
  `scripts/make_coverage_1s.py` (C1: 18 step heads + 36+1 shadow rows
  verified fail-closed; C2: all 17 declared heads found verbatim; C4:
  roundtrip byte-identical).
* **The mutant control**: the OMIT mutant (the machine of record minus the
  gate-mint row, generated, roundtrip-verified, confined to tests/) — the
  coverage battery's gate-mint cell against it **FAILS (rc=1, 10 s)**: the
  omission is DETECTED.
* **TCB-2 (disclosed)**: the ENUMERATION itself — that the generated
  battery's cell list is exactly the declared-rule list — is an external
  (Python-side, fail-closed, roundtrip-verified) check, NOT a mechanized
  theorem. A green generator run is not a proof; everything downstream of
  the enumeration (each cell's post-state equality, exclusivity,
  inertness) IS a K-proved claim. Single deterministic source: machine,
  battery, and mutant are generated from the same frozen source.

## 7. Per-class transition correspondence (§11.6; mission §4)

The functional forward-simulation cell of record:
`eraseQ(absStepQ(SQ, c)) ==K absStepE(eraseQ(SQ), c)`, per declared class,
constructor-pinned, COHERENT-FRAGMENT RESTRICTED. Results (all rc=0 unless
stated):

* init-accept / init-refuse / re-init / stall / exec-mint / exec-source-
  refuse / exec-unsupported / gate-pre / gate-empty / commit-pre /
  commit-G-empty / commit-E-empty: **PROVED UNCONDITIONALLY** (12 classes).
* gate-mint, gate-refuse, commit-accept, commit-C, commit-D: **PROVED in
  the C12-COND form** (the mirror requires carried explicitly on the
  wrapped count); the unconditional NODEP probes for gate-mint and
  commit-accept **FAIL as designed** — the measured dependence.
* The invariant-preservation cells (`1S-PRESV-INT-*`): exec-mint and
  gate-mint preserve `ABSInvE` on the image UNCONDITIONALLY (the slack
  arithmetic); commit-accept conditionally (C12-COND); the NODEP form
  fails as designed.
* **Converse direction**: discharged on the BOUNDED fragment only (the
  depth-family witnesses; `1S-NEG-CONV-NEG-INT` shows no witness exists
  for a negative-count mirror state). The general converse requires the
  rebuild `Int → PoolCount` (integer induction) — deliberately NOT
  defined (the 1Q design boundary); recorded OPEN with the exact reason.
* **Domain restrictions stated precisely**: the correspondence holds on
  the coherent fragment only; on incoherent tags the Q machine stutters
  (the `[owise]` complement) while the mirror is STUCK on mixed bits —
  the models differ BY DESIGN there, and the separation witness
  (`1S-SEP-INCOHERENT-NOT-RELATED`, rc=1 as designed) pins it.
* **NOT a bisimulation**: the results are a one-directional (functional,
  deterministic) forward simulation restricted to the coherent fragment;
  the converse holds only on the evaluated fragment. The word
  "bisimulation" is never used of them.
* **The erasure-blindness finding** (§7): the eraseQ image equality is
  blind to the branch tag BY DESIGN (the mirror has no tag field) — the
  tag discipline is carried by StateRel's consistency conjuncts and
  `tagCoherentQ` (the tag-break StateRel control FAILS as designed).

## 8. The migration theorem — exact status (§11.7; mission §6)

* **`1S-MIGRATE-UNIV`** (the strengthened universal `ABSInvQ(AX) ∧
  ABSInvE(eraseQ(AX)) ∧ tagCoherentQ(AX) ∧ absExecutableQ(RUN, AX) →
  ABSInvQ(end) ∧ ABSInvE(eraseQ(end))`, UNCONDITIONED): **FAILED-STUCK,
  rc=1 in 13 s**. The residual of record (retained verbatim):
  `#Not({true #Equals countToInt(E0) >=Int 0} #And {true #Equals
  countToInt(G0) >=Int 0})` at the state
  `absStQ(tg:1, cfgP:true, catP:true, cntG:G0, cntE:E0, nSlot:+1,
  safe:true)` — THE COMMIT-ACCEPT STRIP STATE. The mission's
  nonnegativity obligation is thereby mechanically isolated, not assumed
  away. 12 unexplored command branches (the 1Q-attempt1-style signature).
* **`1S-MIGRATE-UNIV-C12ASSUMED`** (the same claim under the DISCLOSED C1.2
  simplification — `countToInt(P) >=Int 0 => true` plus its arithmetic
  closure, labeled `1S-C12-SIMPL-ASSUMED[+SHIFT]`): **CLOSED, rc=0 in
  12 s** — classified **PROVED-UNDER-C1.2-ASSUMPTION**. The first
  trusted-cell-claim form of the axiom could not discharge pure conditions
  (identical residual retained); the simplification form is the honest
  carrier.
* **`1S-MIGRATE-GENESIS-C12ASSUMED`** (the genesis-grounded run form —
  the mission's `InitialSafeInt(s0) ∧ ReachableInt(s0,s) → SafeInt(s)`
  shape): **TIMEOUT (rc=124, 560 s; twice — direct and with the closed
  universal trusted)** — the same phenomenon as 1R-UNIV-TAG0-NF-QS: a
  genesis-pinned LHS pattern cannot re-apply circularly at the re-tagged
  tail. The general universal SUBSUMES it semantically: the genesis is an
  invariant state and `1S-INIT-CORR-*` establishes its integer safety by
  evaluation — the corollary follows by instantiation, and this is
  documented rather than claimed as a separate mechanized theorem.
* **The proof's explicit use of the mission's five required ingredients**:
  the initial correspondence (`1S-INIT-CORR-*`), the per-class transition
  correspondence (`1S-CORR-*`), the Phase 1R universal preservation method
  (the [circularity] architecture of `1R-UNIV-COMPOSED-QS` — the 1R
  theorem of record is retained as a NAMED DEPENDENCY, never copied into
  the ledger as a new integer-model theorem), the count nonnegativity and
  precise update correspondences (C1.2 as the disclosed assumption + the
  C1.3/C1.4 exact correspondences), and the integer model's actual safety
  predicate (`ABSInvE` itself).
* **Five-state separation (maintained)**: the closure establishes state 2
  ONLY (the 1P integer-model universal over the in-repo image, under the
  disclosed assumption). States 3 (full representation equivalence), 4
  (concrete-implementation correspondence), and 5 (actual protocol-
  commitment-boundary safety) are established by NO claim in this phase
  and are never stated. The separation witness (`1S-SEP-INCOHERENT-NOT-
  RELATED`) demonstrates one structural reason state 3 fails.
* The destination falsity controls: the symbolic form TIMES OUT (rc=124);
  the concrete-run form TIMES OUT (rc=124); the STEP-level witness FAILS
  as designed (rc=1, 10 s: the init-accept re-tag post ≠ genesis). All
  recorded, never relabeled.

## 9. Negative-control results (§11.8; mission §7)

18 negative rows (see `tests/README.md` for the full table). Highlights:

* negative-integer pool counts: refused by `ABSInvE` (rc=1 as designed) —
  no legal natural-number representation (负整数 pool count);
* stale/wrong count mapping: the stale map cannot reproduce the exact
  increment (rc=1) (过期/错误计数映射);
* decrement from zero / below-guard on the Int side: both refused (rc=1)
  (从零递减、从一递减);
* empty-pool commit-accept: refused (rc=1) (空池 commit);
* invalid-auth-bits commit from nonempty pools: refused (rc=1) (双池非空
  但授权位无效);
* the OMIT mutant: the missing row is DETECTED (rc=1 in 10 s) (缺失转移行);
* the branch-tag break: refused at the StateRel level (rc=1) (破坏分支
  tag 的转移) — with the erasure-blindness finding documented;
* the 1R weak machine: its breaking accept is `ABSInvE`-unsafe (rc=1) and
  its universal fails (rc=1) — the guard structure is load-bearing on
  BOTH models;
* the fake universal correspondence (per-class conditions removed): fails
  (rc=1) (假对应定理);
* the conclusion-in-hypothesis probe: closes trivially, classified
  SELF-ASSUMED-NOT-A-PROOF (结论含于假设的定理);
* the timeout-discipline control: the 1Q machine-of-record universal
  re-run live — rc=124, 560 s, EMPTY log — the exact TIMEOUT disposition
  of record (超时永不归类为反例).

Classification discipline held throughout: proof / evaluation / bounded
test / demonstrated-refusal / proof-failure / timeout / assumption /
self-assumed are DISTINCT ledger classes; nothing was relabeled.

## 10. Remaining concrete-implementation and protocol-boundary obligations (§11.9)

Unchanged by this phase, and still open exactly as recorded in 1N–1R:
the C1.2 universal (structural induction), the general converse direction
(`Int → PoolCount` rebuild), the Level-IV concrete-boundary obligations
(the KEVM binding, the on-chain anchoring, the resmap/cap derivation), and
the consensus-integration boundary (never claimed at Level III).

## 11. Reproduction commands (§11.10)

```
source /home/z/my-project/tools/env.sh
cd <repo-root>
# §1 baseline (raw logs retained in phase1s/transcripts/1r-repro/):
bash phase1s/proofs/run_1r_repro.sh 2>/dev/null || true   # see audit/baseline-1s.md §5
# the 1S battery (all stages, ~35 min):
bash phase1s/proofs/run_1s.sh GEN KD CS CF CO CV MG1 MG2 MG3 MG3B MG4 NG NM NT S
# the gate:
python3 phase1s/scripts/summarize_1s.py    # GATE GREEN, 103 claims
```

Per-claim budgets and the fixed order are in `proofs/run_1s.sh`; the raw
logs land in `transcripts/k/`; the exit/wall records in
`claims/exit-codes-1s.csv` (last-wins); the ledger reconciliation is
`scripts/build_claims_1s.py` (fail-closed).

## 12. The minimal defensible next steps (§11.12)

1. **C1.2 on an induction-capable backend**: the residual is a single
   structural induction over `PoolCount` (two constructor cases, both
   already mechanized conditionally); any backend with structural
   induction over function-argument constructor variables discharges it
   and upgrades `1S-MIGRATE-UNIV-C12ASSUMED` to an unconditional theorem
   with NO other changes.
2. **The genesis corollary as a mechanized claim**: the general universal
   subsumes it; a backend able to instantiate the circularity at the
   re-tagged tail (or a two-claim composition whose trusted form carries
   an EVALUATED executable-domain predicate) closes `1S-MIGRATE-GENESIS`.
3. **The converse direction** (`Int → PoolCount` rebuild + integer
   induction) — upgrades the correspondence toward the bisimulation the
   results currently are not.
4. Level IV: the concrete-boundary obligations (KEVM binding, on-chain
   anchoring) — untouched, as recorded since 1N.

Level III only; no consensus-integration claim.
