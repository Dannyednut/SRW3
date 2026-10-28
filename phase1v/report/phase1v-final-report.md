# SRW3 Phase 1V — Configuration Ownership and Reproducible Verification

**Final report — the fail-closed record.** Branch `phase1v-configuration-ownership`,
base commit `8697bd744faee0b17156393fd8f57dd87e51598e` (the Phase 1U tip,
branch `phase1u-model-hygiene`, verified with `git rev-parse` before branch
creation; the remote branch head was confirmed in sync). Live repository
metadata verified BEFORE any documentation edit: the GitHub API reports
`default_branch: phase1u-model-hygiene` — the owner's default-branch action
has SUCCEEDED (the Phase 1U report recorded it as BLOCKED at its writing
time; that historical record is preserved and a dated follow-up note is
appended, not rewritten).

Toolchain: the sandbox was fresh; the pinned toolchain was re-provisioned
from the recorded recipe **minus the KEVM / blockchain-k-plugin / krypto-shim
pieces** (Phase 1V exercises only the abstract models and kprove, which need
K + z3 + flex + libsecp256k1 + libLLVM-15 only): **K v7.1.337** (jammy deb,
`kompile --version` verified in every stage log) + **Z3 4.13.3** (trixie
package, exact recorded pin). The toolchain root moved from `tools/` to
`tools1v/` (the reset left the old root root-owned); documented deviation,
same pins. Lean 4.16.0 is NOT exercised: no Lean artifact changed in 1V; the
1U Lean certificates (C1.2 + helpers, axiom reports `[propext, Quot.sound]`)
stand unchanged.

**Verdict: PARTIALLY COMPLETE.** The configuration-ownership gap of record
(T3) is closed structurally; three configuration-mutation paths BEYOND the
examiner's lead were discovered and closed (F1a/F1b/F2, plus the F3
hardening); the old-vs-fixed evidence is complete in both directions; the
regression runner is reproducible from a clean checkout and fail-closed; the
state-of-record is corrected for the default-branch change. The Level-III
boundaries, the genesis TIMEOUT, and the earlier FAILED-STUCK residuals
remain exactly as open as recorded. No completion tag.

**Disclosed limitation of record:** the examiner document
`SRW3-Independent-Examiner-Report-v1.2.md` was NOT supplied to the Phase 1V
session (not present on the session filesystem and not in the repository) —
Workstream D item 1 is therefore dispositioned as "cannot archive: the
document itself is required"; the registration stays open with owner
author/examiner. No byte-for-byte archival was possible without the file.

---

## §A — Workstream A: the configuration-ownership boundary

### A1. The residual confirmed (before-evidence, on the pinned 1U model)

The Phase 1U disposition (setup-phase discipline: `setPolicy`/`useRegistry`
blocked only while `<gateopen>` is true) leaves the mutation windows OPEN
whenever no gate interval is open — before the first `begin` and between
transitions. Source inspection of `k/srw3.k` (1U tip) confirms the guarded
rules require `<gateopen> false </gateopen>` — i.e. they PERMIT exactly in
the attack windows. Executed against the git-pinned 1U model
(`git show 8697bd7:k/srw3.k`, sha-pinned in the runner) — raw transcripts
under `phase1v/transcripts/model/krun_OLD1U-*.txt`:

| Control | Window | Recorded outcome on OLD-1U |
|---|---|---|
| `p1u_policy_prebegin` | before first begin | `setPolicy(trust)` accepted; hidden write `wH(appC,0,11)` COMMITTED (appC→11) |
| `p1u_policy_between` | between transitions | honest commit, then `setPolicy(trust)` accepted; second transition COMMITTED appC→11 |
| `p1u_registry_prebegin` | before first begin | `useRegistry(negative)` accepted; IAB violation (10+10=20) COMMITTED |
| `p1u_registry_between` | between transitions | honest commit, then `useRegistry(negative)`; IAB violation COMMITTED |
| `p1u_init_mid` (F2) | mid-transition | unguarded `init` writes committed appA 7→999; the gate then REJECTS the violating transition but the corruption SURVIVES (never gated) |

### A2. New findings beyond the examiner lead (F1a/F1b/F3)

The configuration audit (A3 below) found two UNguarded mutation commands in
the 1U GENERALIZED model — worse than the guarded `setPolicy`/`useRegistryG`:

- **F1a — `useResMap`:** no `gateopen` guard of any kind. Executed on the
  pinned 1U gen model: mid-transition `useResMap(rmNone)` wipes the alias
  table; the resource obligation IRP becomes inapplicable; the violation
  6+9=15>10 COMMITS (`krun_OLD1U-p1u_resmap_mid.txt`). The same exploit
  works before the first begin (`p1u_resmap_prebegin`).
- **F1b — `grant`:** no guard of any kind. Executed: mid-transition
  `grant(appB,appB,1000000)` + `grant(appC,appB,1000000)` raise the
  delegation bounds; `consume(appC,1000)` COMMITS against the
  protocol-authored budget of 6/10 (`krun_OLD1U-p1u_grant_mid.txt`); the
  between-transitions variant commits usage 1001 (`p1u_grant_between`).
- **F3 — `as` (not exploitable on 1U, load-bearing on 1V):** on the 1U model
  the authority set was always reset to ALL apps by `useRegistry`, so no
  restricted-authority exploit is demonstrable there (disclosed). Once
  authorities become genuinely configurable (1V), a mid-transition `as`
  would switch to an authorized identity at gate time — forging the
  authorization evidence. The 1V model blocks it.

### A3. The whole-boundary ownership audit

For each configurable item: who supplies the initial value, where it enters
the K configuration, whether untrusted commands can change it, stability
during/between transitions, and what stays outside the model.

| Item | Supplied by | Enters via | Untrusted mutation (1U) | Untrusted mutation (1V) | Between transitions | Outside the model |
|---|---|---|---|---|---|---|
| `<policy>` | protocol (trusted harness) | `$POLICY` initial configuration | `setPolicy` pre-begin/between (demonstrated); BLOCKED mid-transition (1U) | **none — command removed; no rule writes the cell** | **immutable** | a wrong harness-supplied policy (TCB) |
| `<registry>` | protocol | `$REGISTRY` kind → `pickRegistry` (equations in SRW3-CLOSURE) | `useRegistry` pre-begin/between (demonstrated) | **none — command removed** | **immutable** | an incomplete harness-supplied registry (TCB) |
| `<authorities>` | protocol | `$AUTHORITIES` initial configuration | reset by `useRegistry` (indirect) | **none — no writer** | **immutable** | membership discipline (A3 of record) |
| `<resmap>` | protocol | `$RESMAP` kind → `pickResMap` | `useResMap` ANY time — no guard (F1a, demonstrated) | **none — command removed** | **immutable** | alias-relation completeness (A5, ASSUMED) |
| `<cap>`/`<parent>` | protocol | `$CAP`/`$PARENT` initial configuration | `grant` ANY time — no guard (F1b, demonstrated) | **none — command removed** | **immutable** | delegation-topology realism (A6) |
| `<polver>` | protocol constant | fixed `1` in the initial configuration | none (grep-audited: zero writers) | none | immutable | — |
| `<committed>` (state seeding) | scenario prelude | `init` command | mid-transition init (F2, demonstrated corruption) | PRE-BEGIN-ONLY (`blocked-init-open`); between-transition availability DISCLOSED as scenario authoring | init callable (disclosed; follow-up registered) | real-chain state provisioning (Level-III boundary) |
| actor identity | scenario prelude | `as` command | mid-transition switch possible (F3) | PRE-BEGIN-ONLY (`blocked-actor-switch-open`) | callable (the modeled multi-actor scenario discipline) | authenticated identity (A3 of record: membership evidence only) |

Writer audit (grep + semantics review, reproduced in the runner's
`NEW1V-v1_atk_config_immutable` control): after the refactor, NO rule in
`k/srw3.k` or `k/srw3gen.k` writes `<policy>`, `<registry>`,
`<authorities>`, `<resmap>`, `<cap>`, or `<parent>`. The remaining
configuration assumptions (harness-supplied policy/registry/authorities/
resmap/caps are honest) are precise and recorded in A5/A7 of the sources
and in the TCB inventory of the 1U report, now updated in
`STATE-OF-RECORD.md`.

### A4. Adversarial controls (after-evidence, on the 1V model)

All asserted by the runner (raw transcripts `krun_NEW1V-*.txt`, verdict
ledger `model-verdicts-1v.csv`):

1. **Policy mutation before the first transition** — `v1_atk_policy_prebegin`
   (program = the OLD exploit program verbatim): rc=113 parse rejection
   naming `setPolicy`. The attack is UNREPRESENTABLE.
2. **Registry mutation before the first transition** —
   `v1_atk_registry_prebegin`: rc=113 naming `useRegistry`.
3. **Policy mutation between transitions** — `v1_atk_policy_between`: rc=113
   naming `setPolicy`.
4. **Registry mutation between transitions** — `v1_atk_registry_between`:
   rc=113 naming `useRegistry`.
5. **Gen-model F1a/F1b attacks** — `v1_atk_gen_useResMap_mid` /
   `v1_atk_gen_grant_mid` / `v1_atk_gen_setPolicy_mid`: rc=113 each.
6. **Ordinary valid transition** — `v1_t2_valid_begin_gate` (and the full
   T1/T2/GEN batteries): COMMIT with the correct committed state, head,
   lineageNext, gateopen, and policy cells asserted. Existing flows work
   through the trusted boundary.
7. **Unauthorized configuration changes** — all five removed commands are
   parse-rejected (1–5 above); the alternative-route control
   `v1_atk_config_immutable` executes a maximal IN-GRAMMAR attack (hidden
   write): the hidden write is BLOCKED by `enforce` (`blocked-effect-
   incomplete`), the violation is not committed, and the final policy,
   registry, authorities, and committed cells are asserted unchanged.
8. **F2/F3 runtime blocks** — `v1_atk_init_mid` → `blocked-init-open` with
   committed state intact (no 999 corruption); `v1_atk_as_mid` →
   `blocked-actor-switch-open` (run with authorities={appA} to show the
   would-be identity swap is refused).
9. **Authority configuration honored** — `v1_auth_valid` (authorities=
   {appB}) commits; `v1_auth_reject` (authorities={appA}, actor appB) →
   `reject-auth`. The trusted authority boundary is enforced.

### A5. Existing results preserved and rerun

- Both models recompiled from clean output directories (six definitions in
  the runner's isolated workspace; kompile failures fatal).
- T1 matrix: NEW harness probes (`"false"`/`"true"`), mixed-registry and
  pairwise violation rejections, honest commits — all asserted; the
  OLD-1T-tip defect reproductions match the recorded 1U outcomes
  (mixed probe decomposition-masked → reject; pairwise → IMPROPER COMMIT
  lending→90; probe-only on OLD → `false` = masked, per the 1U record).
- T2 battery: double-gate/gate-no-begin/reject-then-gate/double-begin all
  fail closed with state intact; OLD-1T double-gate and gate-no-begin
  reproduce the empty-map commits.
- GEN battery: valid commit, alias-resource violation REJECTED (IRP
  enforced under the protocol-owned resmap), cap valid/violation
  commit/reject, T2 analogues — all asserted.
- Claims 1–4 battery: `kprove --spec-module SRW3-CLAIMS` rc=0 with #Top,
  wall 7s — IDENTICAL to the Phase 1U record (rc=0, 7s). Negative control
  rc=1 (refuted), wall 6s (1U: rc=1, 5s). No claim relied on
  transition-controlled policy/registry selection: every claim pins the
  registry/policy cells explicitly, so the trusted-harness refactor does
  not weaken any premise — nothing needed reformulation, and no previous
  result had a stronger configuration assumption than the model enforced
  (the claims quantified over `<policy>` and pinned `<registry>
  completeRegistry()` — both now harness-supplied, exactly as the claims
  always assumed them fixed).
- Ghost-fidelity layer: REGENERATED (the pinned slice changed); exact
  byte-faithfulness PASSES; all 48 per-claim verdicts identical to the
  historical record (see §C).
- The 1U proof-rule battery (`phase1u/proofs/*`) requires
  `phase1s/semantics/rel-machine.k`, NOT `k/srw3.k` (dependency-verified) —
  the 1V semantic change cannot affect it; the 1U scoping-disclosure
  precedent applies and it is not rerun.
- The classic 0D demo suite (`k/demos`, 13 programs) is byte-frozen
  historical evidence written against the pre-1U grammar that still contains
  the removed commands; it cannot parse against the 1V model BY DESIGN. Its
  scenarios are superseded by the asserted 1V battery (`v1_*`), which covers
  the same commit/reject shapes with explicit outcome assertions. The frozen
  files are retained verbatim.

**Workstream A verdict: the configuration-ownership gap is structurally
closed** — untrusted transitions cannot select or change policy, registry,
authorities, the alias table, or the capability configuration before the
first transition, during one, or between transitions; the equivalent paths
are audited; the adversarial controls fail to change protected configuration
and demonstrate the expected enforcement; the remaining assumptions are
precise and disclosed.

---

## §B — Workstream B: the reproducible, fail-closed runner

### B1. The old-model dependency is gone

The 1U runner relied on `/tmp/p1u-old-srw3.k`,
`/tmp/p1u-old-harness/srw3.k`, and `/tmp/p1u-old-harness/t1_harness_old.k`
— the last never generated by that runner (the B1 finding of record). The
1V runner (`phase1v/tests/run_1v_model_tests.sh`) generates EVERY input from
committed repository objects: the historical models via `git show <pinned
sha>:k/srw3.k` (sha256-asserted: OLD-1T `da4a895b…`), the T1 harness by
copying the committed harness byte-identically into a miniature of the repo
layout (`<ws>/h1t/phase1v/tests/t1_harness.k` beside `<ws>/h1t/k/srw3.k`) so
the relative `requires "../../k/srw3.k"` resolves to the pinned OLD model —
NO source transformation, layout + sha asserted before any compile. The
workspace is a unique `mktemp -d` with a cleanup trap; durable logs and
verdicts are written under `phase1v/transcripts/` and `phase1v/claims/`.

### B2. Fail-closed execution

- Compile failures are FATAL (`die`); every compiled definition is checked
  to exist; toolchain tools are checked.
- Every positive control asserts: exactly ONE final configuration block
  (multi-branch output = nondeterminism = failure — this class was observed
  live during bring-up when the `pickResMap` expansion lacked an equation:
  `WarnFunctionWithoutEvaluators` + a two-branch commit/reject output; the
  verifier now fails on both), no `WarnFunctionWithoutEvaluators`, no
  backend `[Error]`, the exact `<result>` cell, and per-cell assertions
  (committed state, head, lineageNext, gateopen, policy).
- Deliberately-negative controls are handled EXPLICITLY: parse rejections
  assert the nonzero rc AND the offending token; designed proof failures
  assert rc=1; timeouts would be recorded as rc=124 and never relabeled.
- The runner exits nonzero on any deviation (the failure count is printed).
- No blind `set -e`: negative controls use explicit rc comparisons.

### B3. The T1 regression is truly adversarial

The mixed-registry probe (ONE real edge + ONE bareEdge over the same
dependency set) and the pairwise-registry violation are both kept. On the
OLD-1T model the recorded outcomes are reproduced exactly (mixed probe
decomposition-masked → reject; pairwise → improper commit) and RETAINED per
registry shape — no buggy-model scenario is forced to commit. On the fixed
model BOTH shapes reject the violation. K `Set` ordering is not assumed:
the fixed model's `applicable` is order-independent by construction
(the footprint is preserved across every decomposition), and the probe
demonstrates the engine's actual decision rather than asserting an
order-independence property beyond it.

### B4. Clean-checkout acceptance

- Two isolated runs of the complete model regression script from separate
  fresh workspaces (empty temp state, no shared outputs): **44/44 controls
  each, logical verdicts IDENTICAL** (`determinism-1v-report.txt`; the only
  differences are wall-time notes, excluded from the comparison key).
- The exact documented Phase 1U command reproduces from a clean checkout via
  `phase1v/tests/run_1u_model_tests_compat.sh` (B4 wrapper): it provisions
  the missing `/tmp/p1u-old-harness` inputs from committed objects with ONE
  documented transformation (the harness require path; diff-asserted to
  touch only that line) and execs the byte-frozen 1U runner. The compat run
  reproduced: all five kompiles rc=0; every OLD-model leg byte-comparable to
  the 1U record (pairwise improper commit, empty-map double-gate commit,
  mid-transition exploits); the claims battery rc=0 #Top and the negative
  control rc=1 against the 1V model. The NEW-model legs of the 1U runner
  record `?` cells because the 1U demo programs use the removed commands —
  the by-design 1V difference (the 1V runner is the battery of record for
  the new model). The 1U evidence files are byte-frozen: the appended
  compat-run rows were preserved to `phase1v/transcripts/model/compat_1u_run.log`
  and `compat-exit-codes-1u-run.csv`, and `phase1u/claims/exit-codes-1u.csv`
  was restored bit-identically (sha256-verified) after the demonstration.

---

## §C — Ghost-fidelity regeneration and per-claim battery

`proofs/induction_ghost.k`, `proofs/ghost_manifest.json`,
`proofs/gen/{cm2_alias,cm3_auth,gen_full}.k`, and
`proofs/gen/ghost_manifest_gen.json` were REGENERATED from the corrected
sources via the dynamic-slice tooling (now repo-relative — the old absolute
tooling paths died with the sandbox reset; a documented tooling maintenance
change). `audit_ghost_exact.py verify` → **PASS (exact byte-faithfulness)**;
14 `//GHOST:` lines, all declared. The per-claim battery (isolated kprove
runs): GH-BASE/A/R/SOUND-I/SOUND-F/GATE-AGREE/ISO/T1 **PROVED**; **GH-T2
(the full ∀n theorem) PROVED; GH-M PROVED**; GH-T FAILED (the documented
stuck probe) and GH-T2-NEG FAILED (non-vacuity) — designed failures, never
relabeled; the generalized batteries: 32 PROVED + 3 NEG FAILED (CM2 layer
12, CM3 layer 12, generalized 11 — gen_full has no A1 claim, matching the
historical shape). **Every verdict identical to the Phase 1U record.** The
combined `--spec-module SRW3-CLAIMS` batch on the ghost copy remains a
pre-existing checker behavior (unconstrained ghost cells) and is NOT the
record — the 1U classification precedent is preserved.

---

## §D — Workstream C: the state-of-record after the default-branch change

Verified LIVE first: `GET /repos/Dannyednut/SRW3` →
`default_branch: phase1u-model-hygiene` (2026-10-28). The Phase 1U report's
D1 narrative (API attempt BLOCKED; default still `phase1b` at that time) is
HISTORICALLY TRUE and is preserved verbatim; `STATE-OF-RECORD.md` and
`README.md` now carry a dated follow-up note (2026-10-28): the owner's
manual action has succeeded, the default branch IS the Phase 1U branch, and
the stale-`phase1b` caveat applies to history only. The updated
STATE-OF-RECORD distinguishes: GitHub default branch (`phase1u-model-
hygiene`, owner-selected), current accepted phase (1U), working phase under
development (1V, this branch — NOT set as default; the owner chooses after
review), the exact verified commit, the verdict, the toolchain pins, and the
open residuals.

## §E — Workstream D: traceability and remaining examiner findings

| Item | Disposition |
|---|---|
| Examiner report archival | CANNOT ARCHIVE: the v1.2 document was not supplied to this session (searched filesystem + repo + API); the registration stays OPEN with owner author/examiner — the file itself is required for a byte-for-byte archival. |
| Consolidated residual register | DELIVERED: `docs/research/residual-register-1v.md` — the cross-phase index of unresolved claim IDs (statement, root-cause class, attempted methods, current status), pointing at the append-only per-phase ledgers as the authoritative evidence. |
| Research crosswalk (P1/P2/P3, A1–A4) | PRESERVED as the registered follow-up (owner: a phase with research-framework access); no crosswalk entries were invented this phase — inventing verified-vs-interpretive labels without the framework document would be fabrication. |
| T4 granularity | UNCHANGED (correct): `docs/research/t4-footprint-granularity.md` still documents app-granular vs storage-key-granular effect completeness; no projection/refinement equivalence is claimed. |
| Licence / tags / packaging | UNCHANGED from the 1U register: no licence chosen (author's decision), no completion tag created, tag-naming reconciliation stays a registered follow-up. |

## §F — Acceptance criteria — status table

| # | Criterion | Evidence path | Status |
|---|---|---|---|
| 1 | Policy ownership (before/during/between) | §A4 controls 1/3/7; grammar removal; zero-writer audit | **VERIFIED** |
| 2 | Registry ownership at every boundary | §A4 controls 2/4/7; same | **VERIFIED** |
| 3 | Related configuration audited | §A3 ownership table (resmap/caps/authorities/polver/init/as) | **VERIFIED** (init's between-transition seeding DISCLOSED + follow-up registered — the one deliberately retained affordance) |
| 4 | Adversarial controls with actual state assertions | `model-verdicts-1v.csv` (44 rows, every row cell-asserted); §A4 | **VERIFIED** |
| 5 | Compatibility of existing flows | T1/T2/GEN batteries + Claims 1–4 rc=0 + negative control rc=1 + ghost verdict parity | **VERIFIED** |
| 6 | Runner isolation (clean checkout, no hidden temp artifacts) | §B1/B4; committed-input generation; unique workspaces | **VERIFIED** |
| 7 | Runner determinism (two isolated runs agree) | `determinism-1v-report.txt` (44/44 identical) | **VERIFIED** |
| 8 | Fail-closed behavior | §B2; the bring-up incident (missing-equation nondeterminism) is now a detected failure class | **VERIFIED** |
| 9 | Repository state matches live metadata | §D; live API check 2026-10-28 | **VERIFIED** |
| 10 | Residual management | `docs/research/residual-register-1v.md` + §E table | **VERIFIED** (examiner-report archival BLOCKED on the document) |
| 11 | Reproducibility (raw evidence, commands, pins, ledger, summarizer consistent) | `summarize_1v.py` GATE GREEN (0 alarms) over 92 ledger rows; toolchain pins verified live | **VERIFIED** |
| 12 | Genesis-grounded run form | unchanged from 1U (rc=124, kept TIMEOUT; the 1U proof modules are dependency-independent of the 1V change) | **TIMEOUT** (unchanged classification) |
| 13 | GH-T minimal-destination probe | rc=1 FAILED (designed), per-claim log retained | **FAILED** (as designed; never relabeled) |
| 14 | Level-III boundaries (bisimulation, generator completeness, concrete correspondence, consensus) | `STATE-OF-RECORD.md` §Open residuals | **NOT RUN** (out of scope; remain open) |

**Verdict policy honored:** nothing was made green by weakening a property,
broadening an assumption, relabeling a timeout, or deleting a failed
attempt. The one NEW disclosure (init's between-transition availability) is
a classification of an EXISTING affordance, registered with a follow-up —
not a new trust path.

## §G — What remains open (the explicit list)

1. Genesis-grounded run form — TIMEOUT (1U classification unchanged).
2. GH-T — FAILED-STUCK (the documented minimal-destination probe).
3. The combined ghost-batch checker behavior — pre-existing, per-claim runs
   are the record.
4. T4 granularity — documented, no cross-layer equivalence.
5. Examiner report archival — BLOCKED on the document itself.
6. The research-framework crosswalk — registered follow-up (needs the
   framework vocabulary document).
7. Between-transition `init` state seeding — disclosed scenario-authoring
   affordance; follow-up: move committed-state seeding to the trusted
   boundary (owner: next phase).
8. Harness-supplied configuration honesty (policy/registry/authorities/
   resmap/caps are trusted inputs) — the TCB boundary of record; a hostile
   harness is outside the evaluated model.
9. All Level-III boundaries (full bidirectional representation
   equivalence/bisimulation, external transition-row generator completeness
   TCB-2, concrete KEVM/protocol commitment-boundary safety, consensus
   integration).
10. The consolidated FAILED-STUCK residuals of earlier phases — indexed in
    `docs/research/residual-register-1v.md`; the per-phase ledgers remain
    append-only and authoritative.

Scope: Level III only. No concrete-Ethereum deployment equivalence, no
actual protocol commitment-boundary safety, no consensus integration, no
full bisimulation, no generator-completeness claim, no resolution of earlier
FAILED-STUCK claims is asserted. No completion tag exists.
