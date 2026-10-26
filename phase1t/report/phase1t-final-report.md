# SRW3 Phase 1T — C1.2 Structural Induction and Migration-Proof Validation

**Final report — the fail-closed record.** Branch `phase1t-c12-induction-validation`,
base commit `7a8118f37550b6050b105ab856e0030d2b700e81` (the Phase 1S freeze,
`phase1s-refinement-coverage`). Toolchain: the rebuilt pinned pair **K v7.1.337**
(jammy deb) + **Z3 4.13.3** (verified live: `kprove --version`, `z3 --version`).
Independent checker (fallback route): **Lean 4.16.0** (commit `128a1e6b0a82`,
Release; archive `lean-4.16.0-linux.zip` sha256
`54d6cba24417d97d928cd8dc0b79e74fedcf8ad92ba4b69850b319785b81c80c`).

**Verdict: PARTIALLY COMPLETE — with one major upgrade.** C1.2 is now
**PROVED** (independent-kernel structural induction; the K-native route
remains closed — three fresh probes recorded). The migration theorem is
**PROVED with a disclosed derived-lemma dependency** (the unconditional
universal closes without the C1.2 *assumption* rules — the only C1.2 use is
rules derived from the checked theorem). The genesis-grounded form remains
TIMEOUT (the recorded 1R phenomenon). No completion tag. Scope: Level III
only; no consensus-integration claim.

---

## 1. Starting state (verified, not assumed)

The sandbox was reset before this phase; recovery preceded all work:

| Item | Value |
|---|---|
| Repo | `Dannyednut/SRW3`, cloned fresh; all 24 branches present |
| Baseline | `7a8118f37550b6050b105ab856e0030d2b700e81` verified with `git rev-parse` before branch creation |
| Branch | `phase1t-c12-induction-validation` created from the exact baseline commit |
| Toolchain | `scripts/reinstall_toolchain_1m_r3.sh` (the reset-#7 recipe), rebuilt under `/home/z/my-project/tools`; K v7.1.337 + z3 4.13.3 verified live |
| Definition | `phase1s/semantics/rel-machine.k` → `SRW3N-REL-S`, haskell backend, **kompile rc=0 in 31s** (`/tmp/p1s-rel-def`) |

The Phase 1S files of record were verified at their expected paths before any
run: `phase1s/proofs/n_s_count_semantics.k`, `n_s_migrate.k`,
`n_s_migrate_c12.k`, `phase1s/semantics/rel-machine.k`,
`phase1s/claims/claims.csv` (104 lines incl. header — 103 claims),
`phase1s/proofs/run_1s.sh` (the runner whose command shapes this phase reuses
verbatim). The C1.2 definitions of record were traced through the import
chain to the frozen module `phase1q/semantics/abs-machine-q.k` lines 31–32
(the two `[constructor]` declarations) and lines 400–402 (the two
`countToInt` equations; no `[owise]`, no requires, no overlap).

## 2. Workstream B — C1.2 without the assumption (the new result)

**The goal (C1.2):** `forall P : PoolCount, countToInt(P) >=Int 0` — the
Phase 1S attempt `1S-C1.2-UNIV` was FAILED-STUCK (rc=1, 10s) and the
conditional migration ran under the disclosed simplification rules
`1S-C12-SIMPL-ASSUMED[+SHIFT]` (ledger row `1S-C12-NONNEG-ASSUMED`: *never
proved*).

### 2.1 The K-native route — three fresh probes, all negative

1. **`1T-C12-ATTR-PROBE` (rc=113, 6s).** The `[induction]` claim attribute —
   kore's structural-induction strategy, **never attempted on this toolchain
   by any prior phase** (grepped all 1L–1S proof trees) — is **rejected by
   the pinned compiler**: `Unrecognized attributes: [induction]`, 4
   structural errors. The route does not exist on K v7.1.337
   (`kprove --help` offers no induction strategy flag; only `--trusted`).
2. **`1T-C12-UNIV-CIRC` (rc=1, 10s, FAILED-STUCK).** The
   `[circularity]`-marked universal — also never before attempted for C1.2
   (1S's `1S-C1.2-UNIV` was a plain claim) — self-applies (the compiler
   warns `Variable 'P' defined but not used` on the goal) and dies on the
   stuck leaf *"backend terminated because the configuration cannot be
   rewritten further"*. The falsity twin `1T-C12-NEG-GE5-CIRC` also fails
   (rc=1): the mechanism is **incomplete, not unsound**.
3. **`1T-C12-STEP-NZ-CIRC` (rc=1, 10s).** The constructor-discriminated
   circular form (`requires P =/=K zeroP`): FAILED-STUCK, same signature.

The 1O boundary statement ("no structural induction over function-argument
constructor variables") is thereby **re-established with fresh, stronger
evidence**: neither the attribute (rejected), nor circularity
(self-application without discharge), nor constructor discrimination
(undecidable inner requires) closes the universal on this toolchain.

### 2.2 The fallback route — Lean 4.16.0, kernel-checked structural induction

Per the mission's fallback provision, C1.2 was proved by an independent
proof checker. Artifact: `phase1t/audit/lean/c12_induction.lean`
(sha256 `ca8b909014890fbb413fc353fae040c10f26abd47df218030671036e1ddf2a49`),
run `lean phase1t/audit/lean/c12_induction.lean` → **rc=0, no errors**,
axiom report **`'c12_nonneg' depends on axioms: [propext, Quot.sound]`** —
Lean's two standard logical axioms, **no `sorryAx`** (no unproved
placeholders). The proof is a genuine structural induction over the free
algebra: base case by the defining equation (`rfl`) + linear arithmetic;
step case by the defining equation + the induction hypothesis + linear
arithmetic (`omega`). Transcript retained:
`phase1t/audit/lean/transcript_c12_induction.txt` (sha256 `66398e35...`).

**The exact correspondence argument** (full text in the .lean header,
clauses (C-a)–(C-f)):
- **(C-a) constructors:** the K category `PoolCount` has exactly two
  `[constructor]` productions, `zeroP`/0 and `succP`/1, no other production
  targets it — a free algebra; the Lean `inductive PoolCount` is the same
  free algebra up to identity renaming.
- **(C-b) the function:** the K `countToInt` is defined by exactly the two
  constructor-complete, left-linear, non-overlapping equations (lines
  400–402) — the unique function satisfying them; the Lean `def` by pattern
  match defines the same function (both defining equations are `rfl`-provable
  in the artifact, checked by the kernel).
- **(C-c) the predicate:** K `>=Int` on the builtin `Int` (SMT unbounded
  integer `>=`) ≡ Lean `≥` on `Int` (arbitrary-precision).
- **(C-d) the claim:** under (C-a)+(C-b), the Lean theorem
  `c12_nonneg : ∀ p : PoolCount, countToInt p ≥ 0` is **literally C1.2**.
- **(C-f) trust base (disclosed):** the Lean kernel + core, the
  correspondence clauses (source-inspection, retained), the tool pin. This
  is an **independent-checker proof — NOT a K-native derivation**; the
  K-side boundary stands exactly as recorded.

**Falsity controls of the route (both MUST-FAIL rows failed correctly):**
`1T-LEAN-NEG-GE5` (threshold 5 — omega refuses `0 ≥ 5`) and `1T-LEAN-NEG-ODD`
(zeroP interprets to 0, even) — elaboration errors, rc=1, transcript
`transcript_c12_neg.txt` (sha256 `2ab1f267...`). The checker discriminates
truth from falsehood; the route is genuine.

**Classification: `1T-C12-UNIV-LEAN` = PROVED-EXTERNAL.** C1.2 is **proved**
in the mission's acceptance sense ("a genuine universal induction proof or
a verified equivalent"): a kernel-checked universal structural induction of
the literal statement, with the correspondence disclosed. The K-side ledger
rows `1S-C1.2-UNIV` (FAILED-STUCK) keep their historical classifications —
never relabeled.

## 3. Workstream A — the conditional result is genuine

All rows on the rebuilt pinned toolchain, same harness as 1S
(`/tmp/p1s-rel-def`, module `S-MIGRATE-C12-PROOFS` with the two disclosed
simplification rules):

| Row | Result | Reading |
|---|---|---|
| `1S-MIGRATE-UNIV-C12ASSUMED` | **rc=0, 12s** | exact reproduction (1S: 12s) |
| depth d=1 / d=2 | rc=1 (11s/12s) | must-FAIL probes fail — real unrolling |
| depth d=3 | **rc=0, 12s** | the closure needs exactly 3 unrollings |
| `1T-WSA-CTRL-DEST-FALSE` | rc=124 TIMEOUT (150s) | falsehood NOT proven |
| `1T-WSA-CTRL-SAFETY-FALSE` | rc=1, 11s | falsehood NOT proven |
| `1S-NEG-WEAK-UNIV-Q` (weak machine) | rc=1, 12s | must-FAIL control fails correctly |
| `1S-NEG-OMIT-GATEMINT` (mutant) | rc=1, 11s | omission detected |

**Genuineness verdict: PASSED.** No false goal closes under the assumption
harness; the depth ladder shows the closure is earned by unrolling (fails at
d=1,2; closes at d=3); both mutated-transition controls behave as designed.
The conditional result keeps its classification
**PROVED-UNDER-C1.2-ASSUMPTION** — and additionally earns *validated under
the disclosed assumption* in the mission's sense (genuineness probes and
negative controls all pass, freshly).

## 4. Workstream C — the dependency removal (measured, not assumed)

C1.2 is proved; the mission permits the downstream re-runs. **Two hand-off
mechanisms were compared, and the comparison is itself a finding:**

### 4.1 Mechanism A — the `--trusted` claim hand-off: does NOT work (recorded)

`1T-MIGRATE-UNIV-LEANC12` (the unconditional universal with
`--trusted 1T-C12-UNIV-LEAN`): **rc=1, 13s, residual UNCHANGED** —
`#Not(countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0)` at the commit-accept
strip state. The trusted claim's rewrite fires (compiler warning `Variable
'P' defined but not used`) but its ensures-condition `?N >=Int 0` remains a
fresh-variable obligation — **the trusted-claim mechanism conveys no fact
content** about symbolic `countToInt` values. All six dropped-condition
correspondence cells fail identically (10–11s each); the COMMIT-ACCEPT
preservation cell fails (rc=1); only the two C1.2-independent preservation
cells close (EXE-MINT, GATE-MINT — rc=0). The genesis form under mechanism A
was run to its 560s budget (see §4.3). **Precise negative finding, retained:
the pure-K lemma hand-off cannot express "this predicate holds of all
constructor terms".**

### 4.2 Mechanism B — the derived-lemma rules: the universal CLOSES

The rules (bodies verbatim from the 1S disclosed simplifications; **labels
and justification changed**):

```k
rule countToInt(P:PoolCount) >=Int 0 => true
  [simplification, label(1T-C12-LEAN-RULE)]                    // Lean-checked
rule countToInt(P:PoolCount) +Int I:Int >=Int 0 => true requires I >=Int 0
  [simplification, label(1T-C12-LEAN-RULE-SHIFT)]              // C1.2 + monotonicity
rule countToInt(succP(P:PoolCount)) >=Int I:Int => true requires I >=Int 1
  [simplification, label(1T-C1.5-PROVED-RULE)]                 // 1S-C1.5-BWD-COND (K-proved) + C1.2
rule countToInt(P:PoolCount) +Int I:Int >=Int 1 => true requires I >=Int 1
  [simplification, label(1T-C12-LEAN-RULE-SHIFT1)]             // C1.2 + monotonicity
```

Results (module `T-MIGRATE-RULE-PROOFS`, **no assumption rules anywhere**;
the file requires only the rel-machine of record):

| Row | Result |
|---|---|
| **`1T-MIGRATE-UNIV-LEANC12-RULE`** — the unconditional strengthened universal | **rc=0, 13s — PROVED** |
| genuineness d=1 / d=2 | rc=1 / rc=1 — real unrolling, non-vacuous |
| `1T-WSA-CTRL-DEST-FALSE-RULE` (false goal, same harness) | rc=124 TIMEOUT — falsehood not proven; mechanism sound |
| `1T-CORR-GATE-MINT/REFUSE-RULE`, `1T-CORR-COMMIT-ACCEPT/C/D-RULE` (conditions dropped) | **rc=0** ×5 (10–12s) — the five C12-COND cells are now unconditional |
| **`1T-CORR-NODEP-RULE`** — the strip-state probe | **rc=0, 10s — the 1S residual of record `countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0` is DISCHARGED** |
| `1T-PRESV-INT-EXE-MINT/GATE-MINT/COMMIT-ACCEPT-RULE` | rc=0 ×3 — the full ABSInvE preservation chain unconditional (COMMIT-ACCEPT was the C1.2 spot) |

The SHIFT1 row was required by a measured detail: simplification unfolds
`countToInt(succP(E0))` to `countToInt(E0) +Int 1` before the succP-headed
C1.5 rule can match, so the mirror guards (`… ≥Int 1`) need the unfolded
shape. The first attempt without it failed (six rows rc=1, retained in the
ledger); with it, all six close.

**Classification upgrade (the mission's promotion test, passed):** the
unconditional migration theorem is **PROVED (derived-lemma dependency
disclosed)** — the proof contains **no C1.2 assumption rules**; the only
C1.2 use is rules whose justification is a kernel-checked proof artifact.
The historical rows keep their classifications: `1S-MIGRATE-UNIV`
(FAILED-STUCK, its residual now discharged at the cell level by
`1T-CORR-NODEP-RULE`) and `1S-MIGRATE-UNIV-C12ASSUMED`
(PROVED-UNDER-C1.2-ASSUMPTION, freshly reproduced and validated) are
untouched history; the 1T rows are new claims.

### 4.3 The genesis-grounded form: TIMEOUT (unchanged phenomenon)

`1T-MIGRATE-GENESIS-LEANC12-RULE`: **rc=124 at the 560s budget** — exactly
the 1S record (`1S-MIGRATE-GENESIS-C12ASSUMED` rc=124, 560s, twice): the
genesis-pinned LHS cannot re-apply circularly at the re-tagged tail (the
`1R-UNIV-TAG0-NF-QS` phenomenon). Semantically subsumed by the closed
universal (the genesis is an invariant state; `1S-INIT-CORR-*` gives its
integer safety by evaluation). Recorded as TIMEOUT — never a refutation,
never relabeled.

## 5. Evidence and accounting (§5 of the mission)

- **Commands and versions:** every row was run through
  `phase1t/proofs/run_1t.sh` (the fail-closed runner; command shapes
  identical to `run_1s.sh`: `kprove <spec> $INC -d <def> --spec-module <M>
  --claims <C> [--trusted <L>] [--depth <N>]`), with `K v7.1.337` +
  `z3 4.13.3` verified live at session start. Lean: `lean
  phase1t/audit/lean/c12_induction.lean` on the pinned 4.16.0 binary.
- **Raw logs:** `phase1t/transcripts/k/kprove_<CLAIM>[-D<d>].log` (one per
  row, including the failures and the two parse-failure exhibits) and
  `phase1t/audit/lean/transcript_*.txt`.
- **Exit codes:** `phase1t/claims/exit-codes-1t.csv` (last-wins, as 1S).
- **Ledger:** `phase1t/claims/claims-1t.csv` — **42 rows**: 12 PROVED or
  PROVED-derived-lemma closures, 2 PROVED-EXTERNAL (Lean) + 1
  reproduced-under-assumption + 1 depth-closure, 10 FAILED-STUCK attempts
  (incl. the two mechanism-A batteries and the three K-native induction
  probes), 1 tool-boundary (the attribute rejection), 3 TIMEOUT
  (destination-false controls ×2 under their harnesses + the genesis form),
  6 must-FAIL controls that failed correctly, 7 further controls/probes.
  Same-attempt re-runs are last-wins single rows (the ledger never counts
  retries as independent theorems).
- **Assumptions and trust dependencies (complete list):** (i) the K
  toolchain v7.1.337 + Z3 4.13.3 (kore checker, SMT ground decisions); (ii)
  the Lean 4.16.0 kernel + core (`propext`, `Quot.sound` only, disclosed by
  `#print axioms`); (iii) the correspondence clauses (C-a)–(C-d) — a
  source-inspection argument, retained verbatim in the .lean header; (iv)
  the derived-rule provenance: the 1T simplification rules carry no
  independent epistemic weight — rejecting the Lean certificate rejects
  every row that used them (all such rows are labeled
  `proved-derived-lemma`); (v) the frozen machine of record
  (`SRW3N-ABS-QS` chain) exactly as in 1Q–1S.

## 6. What this phase does NOT establish (unchanged boundaries)

The five-state separation is maintained verbatim: state 2 (the Level-III
integer-model universal over the in-repo image) is strengthened from
"under the disclosed C1.2 assumption" to "with a kernel-checked C1.2
dependency". NOT established: full bidirectional representation equivalence
or bisimulation (the correspondence remains the one-directional image with
the bounded-only converse; tag-blindness by design); the external
transition-row generator's completeness (TCB-2); the concrete Ethereum
deployment correspondence; actual protocol safety; consensus integration.
The K prover itself remains unable to internalize the structural induction —
that boundary is a permanent, recorded property of the pinned toolchain.

## 7. The five mission verdicts

1. **C1.2 universal:** **PROVED** — `1T-C12-UNIV-LEAN`, kernel-checked
   structural induction (Lean 4.16.0, no `sorryAx`, falsity controls fail
   correctly), literal-statement correspondence disclosed. K-native main
   route: exhausted with fresh negative evidence (attribute rejected;
   two circularity forms FAILED-STUCK).
2. **Conditional-migration genuineness:** **VALIDATED UNDER THE DISCLOSED
   ASSUMPTION** — reproduced (rc=0, 12s), depth ladder d=1/2 fail + d=3
   closes, both false-goal controls refuse, weak-machine and OMIT-mutant
   controls fail as designed. Classification kept
   PROVED-UNDER-C1.2-ASSUMPTION (and now *validated*, not merely disclosed).
3. **Unconditional migration theorem:** **PROVED (derived-lemma dependency
   disclosed)** — `1T-MIGRATE-UNIV-LEANC12-RULE` rc=0 13s with no assumption
   rules; depth 1/2 fail; destination-false control under the same harness
   does not close. Mechanism A (`--trusted`) recorded as unable to convey
   the fact content (residual unchanged) — the mechanism finding is part of
   the deliverable.
4. **Dependent obligations and genesis:** the five C12-COND correspondence
   cells are **unconditional closures** (conditions dropped, discharged by
   the checked lemma); the **commit-accept strip-state residual of record
   (`countToInt(G0) >=Int 0 ∧ countToInt(E0) >=Int 0`) is DISCHARGED**
   (`1T-CORR-NODEP-RULE` rc=0); the preservation chain is unconditional;
   the genesis-grounded form **remains TIMEOUT** (560s, the recorded 1R
   phenomenon, semantically subsumed) — the one dependent obligation that
   did NOT upgrade.
5. **Remaining trust dependencies:** the five disclosed in §5 (K checker;
   Lean kernel; correspondence clauses; derived-rule provenance; the frozen
   machine of record). Nothing undisclosed; no assumption of record was
   reclassified — the assumption was *replaced by a proof*, which was the
   phase's purpose.

**PARTIALLY COMPLETE** — C1.2 and the migration core upgrade to proved /
proved-with-disclosed-dependency; the genesis run-form and the §6 boundaries
remain open exactly as recorded.
