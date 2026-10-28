# SRW3 Phase 1W — Independent Acceptance, Initialization-Boundary Closure, and Residual Proof Plan

**Final report — the fail-closed record.** Branch `phase1w-boundary-audit`,
built on the INDEPENDENTLY VERIFIED Phase 1V head. Every Phase 1V claim was
treated as a claim to check, not as proof: the branch bundle was verified
cryptographically and structurally (§0), the complete Phase 1V test
procedure was rerun twice in a fresh environment (§B), the reported
configuration-ownership changes were confirmed against the committed
objects (§A), the one open initialization affordance (R9) was demonstrated
on the pinned 1V model and closed structurally (§A), and every remaining
obligation was carried into a reconciled residual register with a concrete
next action (§E, `docs/research/residual-register-1w.md`).

**Verdict: PARTIALLY COMPLETE.** The between-transition initialization
affordance (the 1V register's R9 residual) is CLOSED with structural +
adversarial + positive-control evidence; the Phase 1V verification claims
are INDEPENDENTLY REPRODUCED; the gate/verifier tooling is demonstrated to
fail closed under 13 adversarial probes. The genesis TIMEOUT, GH-T,
the combined-batch tool boundary, the harness-honesty TCB, the examiner-
report archival, the crosswalk, and all Level-III boundaries remain exactly
as open as recorded. No completion tag.

**Result-status vocabulary used throughout this report:**
`VERIFIED` (independently checked in this phase against committed or
recomputed evidence), `FAILED` (a designed or discovered failure, retained),
`FAILED-STUCK` (a prover/proof-engineering failure retained distinctly),
`TIMEOUT` (never relabeled as either proof or disproof), `NOT RUN`
(out of scope this phase; carried), `BLOCKED` (an external dependency
prevents the work), `PASS`/`FAIL` (per-criterion acceptance in §F).

**Push status of record (2026-10-28):** no write credential is present in
this session's environment (no token, no `gh` CLI, no credential helper;
`git push github-origin phase1w-boundary-audit` fails at authentication —
"could not read Username for 'https://github.com'") — the push of the
Phase 1W branch is **BLOCKED**, exactly as in Phase 1V; the branch is
delivered as a verified transferable bundle (see the delivery note in
`STATE-OF-RECORD.md`). READ-ONLY remote metadata WAS verifiable this
session (no credential needed): `git ls-remote --symref github-origin
HEAD` → `ref: refs/heads/phase1u-model-hygiene HEAD` at
`8697bd744faee0b17156393fd8f57dd87e51598e` — the default branch and its
commit re-verified LIVE from THIS session, independently corroborating the
1V API check; the same listing shows `phase1v-configuration-ownership` is
NOT on the remote (consistent with the 1V BLOCKED record) and
`phase1t-c12-induction-validation` is at exactly the commit the regression
runners pin (`2247e68872d7a5f8bd8920db96db3ace290535b2`). Not claimed as
pushed; landing instructions in STATE-OF-RECORD.

---

## §0 — The starting point, independently established

The Phase 1V delivery reported: branch `phase1v-configuration-ownership`,
head `430f468`, base `8697bd7`, six commits, bundle
`srw3-phase1v-branch.bundle`, abbreviated sha256 `9c67aad4…1c85b7`, clean
worktree, push blocked (no credentials). Each item was verified from the
artifacts, not from the report:

| Reported | Independent finding | Status |
|---|---|---|
| Bundle `srw3-phase1v-branch.bundle` | Located at `download/srw3-phase1v-branch.bundle` (51,758,127 bytes) | VERIFIED |
| sha256 `9c67aad4…1c85b7` (abbreviated) | Computed FULL digest `9c67aad4527483879208aa3607d27b9106ee9736f5ff5b9be33c5a86da1c85b7`. The instruction supplies ONLY the abbreviated digest as the reference — no independent full digest exists in any artifact available to this session — so the equality check is necessarily an abbreviated-prefix/suffix match (`9c67aad4` … `1c85b7`), not a complete cryptographic equality against an authoritative full value. | VERIFIED against the available reference; the reference itself is abbreviated (disclosed limitation) |
| Bundle valid | `git bundle verify`: "bundle is okay"; advertised ref `430f46858168f0477c1296ba9cc895b3f44e89be refs/heads/phase1v-configuration-ownership`; **"The bundle records a complete history"** (self-contained, no prerequisites); hash algorithm sha1 | VERIFIED |
| Head `430f468` | Full SHA `430f46858168f0477c1296ba9cc895b3f44e89be` = the advertised ref = the clone's HEAD | VERIFIED |
| Base `8697bd7` | Full SHA `8697bd744faee0b17156393fd8f57dd87e51598e` resolves and is the DIRECT parent of the first 1V commit `f70353d` | VERIFIED |
| Six commits | `git rev-list --count 8697bd7..HEAD` = **6**; linear chain `8697bd7 → f70353d → 0c5a0fe → c7a0c7b → 91d5d0b → c790c8c → 430f468` | VERIFIED |
| Clean worktree | `git status --porcelain` = 0 entries in the verification clone | VERIFIED |
| Evidence exists in committed objects | All six commits inspected via `git diff-tree`: f70353d (2 files: both semantics), 0c5a0fe (192 files: tests/runner/ledgers/ghost), c7a0c7b (6 files: docs/register/report), 91d5d0b (4: clean-checkout transcripts), c790c8c (2: push-status note), 430f468 (2: head-reference docs). The residual register, both runners, all 44 control programs, all verdict ledgers and raw transcripts are present in the committed objects. | VERIFIED |
| Push blocked in 1V | Consistent with the 1V commit messages (recorded BLOCKED) and with this session's own credential-less environment | VERIFIED (as recorded) |

Import procedure (no history rewrite): `git clone <bundle>` into a fresh
verification repository; `git bundle verify` INSIDE the clone re-passed;
the local branch `phase1v-configuration-ownership` checked out at the
advertised head. All Phase 1W work grows from that verified head.

---

## §A — Workstream A: the between-transition initialization affordance

### A1. The exact residual (traced, then demonstrated)

The Phase 1V register's R9 entry names the residual: "`init` remains
callable between transitions as a scenario-authoring affordance
(disclosed)". Traced to the concrete model text (Phase 1V commit
`430f468`, sha-pinned by the 1W runner):

- **Command / grammar:** `syntax Srw3Cmd ::= "init" "(" app:AppId "," slot:Int "," v:Int ")"` (and `Srw3CmdG` in the generalized model) — `init` was STILL an untrusted-program command in 1V.
- **Rules:** the seeding rule `init(I,S,V) => .K` with `<committed> M => M[stK(I,S) <- V]` guarded ONLY by `<gateopen> false </gateopen>`; the mid-transition terminal block (`blocked-init-open`) guarded by `<gateopen> true </gateopen>`.
- **Configuration cells:** `<committed>` (the commitment boundary) and `<gateopen>` (the one-shot interval flag).
- **Boundary structure:** every gate outcome (accept / reject / reject-auth) and every blocking path closes the interval (`gateopen true => false`), so the seeding rule's guard `gateopen == false` is satisfied BEFORE the first `begin`, BETWEEN any two transitions, and AFTER any rejected or authorization-failed transition — i.e. in EVERY window the untrusted program controls.
- **Alternative routes to `<committed>`:** a full writer audit (repeated in 1W on both models) shows exactly TWO writers in 1V: the gate accept rule (the protocol path) and `init` (the disclosed affordance). `w`/`wH` write `<prospective>` only; no other production reaches `<committed>`. There is no second spelling of `init` and no indirect state-update path to `<committed>` in either grammar — the audit is structural (grep + module review), and the maximal IN-GRAMMAR attack control (`v1_atk_config_immutable` / its 1W translation) demonstrates that the in-grammar surface cannot reach `<committed>` outside the gate.
- **Phase 1V adversarial tests:** `v1_atk_init_mid` asserted the MID-transition block only; the pre-begin and between-transition windows were callable BY DESIGN and were not asserted as blocked.

**Precondition → mutation → consequence (demonstrated, not hypothesized):**
precondition `gateopen == false` (untrusted-controlled window); mutation
arbitrary `<committed>[stK(I,S)] := V`; consequence — an ungated
committed-state mutation that (i) IS the final committed state when executed
after the last gate, and (ii) SURVIVES a subsequent gate rejection (the
reject discards `<prospective>`, not `<committed>`). Both are demonstrated
on the pinned 1V model (below). The 1V report had disclosed the affordance
but had not demonstrated the between-transition exploitation; the
hypothesized "corruption survives" behavior is now demonstrated fact.

**Demonstrations on the git-pinned OLD-1V model** (`phase1w/tests/
demos-aff/`, raw transcripts `krun_OLD1V-*.txt`, verdict rows in
`model-verdicts-1w.csv`; all VERIFIED this phase):

| Control | Lifecycle position | Demonstrated outcome on OLD-1V |
|---|---|---|
| `w1_aff_between_direct` | between two completed transitions | honest commit (appA=5,appB=2, head=commit(0)); then `init(appA,0,999)` — final committed appA=**999**, a value NO gate ever evaluated |
| `w1_aff_between_survives_reject` | between transitions | corruption to 999; the NEXT transition is correctly REJECTED (IAB violated on the seeded value) — and the seeded 999 REMAINS the committed state (lineageNext=1: the reject restored nothing) |
| `w1_aff_after_reject` | after a rejected transition | first gate rejects (5+9=14>10); `init` then re-seeds appA→999 ungated |
| `w1_aff_after_authfail` | after an authorization failure | `reject-auth`, then `init` re-seeds appA→999 ungated |
| `w1_aff_gen_between` | generalized model, between transitions | same shape on `srw3gen.k`: appA@7 → 999 ungated |
| `w1_aff_prebegin_by_design` | before the first begin | ACCEPTED (the disclosed 1V scenario-authoring affordance itself — the behavior 1W removes) |
| `w1_aff_mid_repro` | mid-transition | `blocked-init-open` reproduced on the pinned 1V model (the 1V control, unchanged) |

### A2. The intended trust boundary (and the smallest justified change)

The 1V architecture (structurally closed for policy/registry/authorities/
resmap/caps since T3-v2) left ONE item entering through the untrusted
language: the initial committed state, via the `init` command. The intended
boundary, now implemented:

| Item | Class | Enters via | Mutable during an accepted transition? | Mutable between transitions? |
|---|---|---|---|---|
| `<policy>` | trusted configuration | `$POLICY` (1V) | no (no writer) | no (no writer) |
| `<registry>` | trusted configuration | `$REGISTRY` kind (1V) | no | no |
| `<authorities>` | trusted configuration | `$AUTHORITIES` (1V) | no | no |
| `<resmap>` | trusted configuration | `$RESMAP` kind (1V) | no | no |
| `<cap>`/`<parent>` | trusted configuration | `$CAP`/`$PARENT` (1V) | no | no |
| `<committed>` INITIAL CONTENT | **trusted configuration (1W — was untrusted `init`)** | **`$INITSTATE` (1W)** | n/a (initial only) | **no writer except gate accept** |
| `<committed>` after initialization | legitimate mutable protocol state | gate accept ONLY (the commitment boundary) | via gate decision | via gate decision |
| `<prospective>`, footprints, usage-p | per-transition working state | transition execution | yes (discarded at every boundary) | n/a |
| `<usage-c>` | legitimate mutable protocol state | gate accept (gen model) | via gate decision | via gate decision |
| `<actor>` | per-transition declared identity | `as` PRE-BEGIN-ONLY (1V F3) | blocked mid-transition | re-declarable (re-checked by the gate at commit time — legitimate mutable protocol state, NOT frozen) |
| `<lineage>`, `<lineageNext>`, `<head>`, `<polver>` | protocol-owned ledger/constant | gate accept / fixed | via gate decision | immutable |

The 1W model change (the smallest justified change, mirroring the audited
1V T3-v2 pattern): **remove `init` from both untrusted grammars; retire both
1V init rules with their syntax; declare `<committed> $INITSTATE:Map </committed>`
in both initial configurations; add assumptions A8/A9** recording the
harness-trust dependency on the initial state. NO guard flags are
introduced — the boundary is structural (unrepresentability), not a flag
the untrusted path could influence. Consequences documented for both
semantics: the 1V demos' pre-begin `init` seeds move into the trusted
invocation (`-cINITSTATE`); the blocked-init-open rule disappears with the
command (the attack class it guarded is unrepresentable); the no-hidden-
axiom contract comment ("the ONLY rule that ever updates `<committed>` is
the gate accept rule") is now literally true. Application data is NOT
indiscriminately frozen: committed state remains legitimately mutable —
but only through gate-accepted transitions (the two-transition positive
control `w1_pos_two_transitions` demonstrates exactly this flow).

### A3. Adversarial tests on the closed boundary (NEW-1W)

All asserted by `phase1w/tests/run_1w_model_tests.sh` (raw transcripts
`krun_NEW1W-*.txt`):

1. **Before the first begin:** the attack program (init seeds pre-begin, verbatim) → **rc=113, parse error "unexpected token 'init'"** (`NEW1W-w1_atk_init_between` runs the same program shape; the pre-begin variant is the same parse rejection — the command does not exist).
2. **While a transition is open:** verbatim mid-transition program → **rc=113** (`NEW1W-w1_atk_init_mid`).
3. **Between two completed transitions:** verbatim `w1_aff_between_survives_reject` program → **rc=113** (`NEW1W-w1_atk_init_between`).
4. **After a rejected transition / after authorization failure:** verbatim programs → **rc=113** (`NEW1W-w1_atk_init_afterauthfail`; the after-reject variant is the same unrepresentable command).
5. **Alternative spellings / indirect paths:** `init` has no alias production; the writer audit (structural) + the maximal in-grammar attack control (`NEW1W-w1_atk_config_immutable` → `blocked-effect-incomplete`, protected cells asserted unchanged) demonstrate the in-grammar surface cannot reach `<committed>` outside the gate.
6. **Generalized model:** the gen-model between-transition attack → rc=113 (`NEW1W-v1_atk_gen_useResMap_mid`/`grant` carried controls also re-asserted).
7. **Resource-map/alias and capability mutation paths:** carried 1V controls re-run on NEW-1W (`useResMap`/`grant`/`setPolicy`/`useRegistry` all rc=113 — still removed).

**A parse-time rejection evidences that the command is unavailable in that
grammar**; the FULL mutation-boundary claim rests on the trio: (a) the
writer audit (no non-gate writer of `<committed>` exists in either
semantics), (b) the parse rejections (the untrusted program cannot name the
former writer), and (c) the positive controls (legitimate flows still
commit). All three are in evidence.

**Positive controls (authorized configuration accepted; valid transitions
work):** `w1_pos_initstate_seed` (trusted seeding + commit, seeded value
preserved as legitimate committed state), `w1_pos_empty_seed` (empty seed =
zeroed storage analogue), `w1_pos_two_transitions` (legitimate
between-transition flow with lineage advancing twice — NO seeding command),
`w1_pos_reject_then_recover` (post-reject lifecycle intact), plus the full
T1/T2/GEN translated batteries (23 controls, 1V-record outcomes).

**The TCB boundary control:** `w1_pos_bad_baseline_rejected` — a VIOLATING
harness-supplied baseline (appA=999) is VISIBLE and FAILS CLOSED: the gate
evaluates IAB over the seeded baseline and rejects; nothing commits; the
violating value stays where the trusted caller put it (asserted). The
honesty dependency is therefore PRECISE: the model fail-closes on a bad
baseline's consequences; what it cannot do is refuse a bad baseline that
the harness itself supplies — that is the recorded trust assumption, not a
theorem.

### A4. Closure status

**R9 disposition: CLOSED** — the claim "the untrusted transition program
cannot seed or mutate committed state at any lifecycle position" is
supported by (i) the structural change (command removed, single non-gate
writer eliminated), (ii) the adversarial battery at every lifecycle
position + alternative-route + gen-model controls (parse rejections /
blocks asserted), and (iii) the positive controls (legitimate flows work).
**Necessary trusted-harness assumptions, stated explicitly (NOT converted
into a theorem):** the harness-supplied `$INITSTATE` is honest protocol
configuration (A8/A9; R10 extended); a hostile harness is outside the
evaluated model, as in 1V. The prior 1V evidence (the OLD-1V demonstrations
in §A1) is preserved unchanged and cross-referenced; nothing was rewritten.
T3 (the 1V T3-v2 configuration-ownership closure) is thereby extended to
full lifecycle coverage of the configuration surface INCLUDING the initial
committed state; the residual that remains is the harness-honesty TCB
(R10) — open by definition, precisely recorded.

---

## §B — Workstream B: independent reproduction of the Phase 1V claims

**Environment:** fresh clones of the verified bundle (two independent
clones `runA`/`runB`, each checked out at the verified head, each with
worktree clean at start); the pinned toolchain K v7.1.337 + Z3 4.13.3
verified live (`kompile --version`, `z3 --version`); NO leftover `/tmp`
artifacts of the 1V session existed in this fresh sandbox (the reset had
removed them) — the only inputs were the bundle and the pinned toolchain.

**Disclosed environment deviations (process-level, semantics-neutral):**
(i) the toolchain root is the reset-surviving `/tmp/my-project/tools`
extraction (same pins, verified live) instead of the 1V session's
`tools1v/`; (ii) on this sandbox the `/tmp` medium is slow and the
interactive tool-call budget is 10 minutes, so the runners' SUPPORTED
staged mode (`RUN_WS_DIR` + `RUN_APPEND=1`) was used, and two long stages
(GEN in both runs) were re-invoked after mid-stage tool-call kills — each
re-invocation re-runs the whole stage and overwrites its transcripts; the
final ledgers were deduplicated LAST-WINS (each control appears exactly
once, with the outcome of its final execution; every final execution's
transcript is the retained one). The comparison key is the LOGICAL verdict
per control (the 1V determinism discipline: wall times excluded). (iii)
One interrupted attempt briefly ran with a workspace on `/dev/shm` (64MB —
too small; aborted, disclosed, no evidence produced by it is relied upon).

**Run A and Run B, per reported claim:**

| Phase 1V claim | Reproduction result | Status |
|---|---|---|
| B4 two-run clean-worktree comparison; 44/44 controls each; logical verdicts identical | Run A: 44/44 OK. Run B: 44/44 OK. `diff` of (tag, verdict) columns: RunA≡RunB≡committed historical ledger | **VERIFIED** |
| Claims 1–4 (rc=0 #Top) + negative control (rc=1) on the fixed model | Run A: rc=0 #Top (7s) / rc=1 (6s). Run B: rc=0 #Top / rc=1 | **VERIFIED** |
| The documented 1U command via the compatibility wrapper | Reproduced end-to-end from a clean checkout: harness transformation asserted (only the require line), all five kompiles rc=0, OLD legs byte-comparable to the 1U record (pairwise improper commit lending→90; empty-map double-gate and gate-no-begin commits; mid-transition exploits), claims rc=0 #Top, negative control rc=1, NEW legs' `?` cells = the by-design removed-command difference. `phase1u/claims/exit-codes-1u.csv` restored BIT-IDENTICALLY after the demonstration (sha256 `ef10f58f…710` before = after) | **VERIFIED** |
| 48 ghost per-claim verdicts vs historical counterparts | Run A: 48/48 rc-identical. Run B: 48/48 rc-identical. GH-T2/GH-M PROVED; GH-T/GH-T2-NEG and generalized NEGs FAILED as designed | **VERIFIED** |
| Byte-fidelity checks | `audit_ghost_exact.py verify` PASS in both runs (fidelity row rc=0); the regenerated `induction_ghost.k` is byte-identical to the committed one (manifest sha256 fields equal; only environment-absolute `path` fields differ) | **VERIFIED** |
| Summarizer gate GATE GREEN + 92-row register | `build_ledgers_1v.py` → 92 rows both runs; `summarize_1v.py` → **GATE GREEN (0 alarms)** on the FRESH ledgers of both runs | **VERIFIED** |

Raw artifacts: `phase1w/transcripts/repro/run{A,B}-model-verdicts.csv`,
`run{A,B}-ghost-verdicts.csv`, `negprobe-d.log`,
`compat-1u-run-exitcodes.csv`, `1u-exitcodes-preserved.sha`.

**The checks were audited, not trusted (Workstream D):** the runner's
fail-closed claims were exercised with 13 negative controls
(`scripts/p1w_negprobe.sh`, log `transcripts/repro/negprobe-d.log`) — see
§D. A displayed `44/44` was NOT accepted at face value: the verifier
(`verify_1v_out.py`, read line-by-line) asserts exactly ONE final
configuration block, no stuck-function warning, no backend `[Error]`, the
exact `<result>` cell, and per-cell substrings; the parse-rejection checks
assert the nonzero rc AND the offending token; the negative controls
assert rc=1 explicitly; the runner exits nonzero on any deviation. The one
structural gap found (claim-count pinning inside the ghost batch, R13) is
registered with a concrete follow-up; the count invariant is currently
enforced one layer up (the summarizer's row-count class + the cross-phase
48/48 comparison, probe D6).

**Deviation policy:** no historical evidence was changed to make the rerun
pass; where the environment differs, BOTH the deviation and its
neutrality argument are disclosed above. All rerun results agree with
history; there is no discrepancy to investigate.

---

## §D — Workstream D: ghost-batch boundary, harness-honesty TCB, negative controls

**What establishes what (the evidence-layer map):**
- **K kernel + prover artifacts (trusted tools, pinned):** each ghost
  per-claim verdict is an isolated `kprove` run against the regenerated
  slice — the PROOF obligations (GH-BASE/A/R/SOUND-I/SOUND-F/GATE-AGREE/
  ISO/T1/T2/M PROVED; GH-T, GH-T2-NEG, *NEG designed-FAILED) are kernel
  facts, not script outputs.
- **Batch scripts (auditable):** `run_1w_ghost.sh` regenerates the slice,
  refreezes + verifies the manifest (exact byte-faithfulness), splits the
  claims, and asserts EACH claim's expected verdict (rc and, for PROVED
  rows, #Top presence) — a wrong verdict FAILS the batch (nonzero exit);
  it cannot suppress a failure or relabel one.
- **Boundary finding (R13, new):** the batch derives its claim LIST from
  the splitter without pinning the expected count INSIDE the batch — a
  splitter regression dropping a claim would shorten the battery while the
  batch still exits green. The invariant IS enforced one layer up
  (`summarize_1w.py` row-count class {46,48,94}; the 48/48 cross-phase
  comparison; negative control D6 demonstrates a short ledger is
  REJECTED). Registered as R13 with the smallest fix (assert the expected
  label list in the ghost runner; owner: next phase touching the ghost
  tooling).
- **External interpretation (minimized):** verdict/exit-code ledgers are
  machine-written by the runners; the summarizer cross-checks them
  fail-closed; the human-readable report cites ledger rows. No verdict in
  the ledger depends on eyeballing raw output.

**Negative controls (13/13 PASS — `transcripts/repro/negprobe-d.log`):**
D1 baseline-green accepted; D2 duplicated claim row → REJECTED; D3 missing
transcript → REJECTED; D4 exit-code mismatch + unrecognized rc=7 →
REJECTED; D5 missing expected result → REJECTED; D6 count mismatch →
REJECTED; D7 designed-failure relabeled rc 1→0 (GH-T) → **RELABELING ALARM
+ GATE RED**; D8 non-OK verdict row → REJECTED; D9 wrong expected result
cell → REJECTED; D10 correct expectation → accepted; D11 nondeterministic
two-block output → REJECTED; D12 stuck-function warning → REJECTED; D13
duplicate verdict row in the builder → FATAL. The batch mechanism is
demonstrated UNABLE to pass malformed, missing, duplicated, mismatched, or
relabeled evidence.

**The harness-honesty TCB (components assumed when interpreting a run as
evidence about the model):** (1) the pinned K distribution (kompile/krun/
kprove/kast) and its Haskell backend + Z3 4.13.3 — assumed to implement
the K semantics faithfully (kernel-checked claims mitigate prover-side
assumptions); (2) the harness INVOCATION inputs (`$POLICY/$REGISTRY/
$AUTHORITIES/$RESMAP/$CAP/$PARENT` and now `$INITSTATE`) — assumed honest
protocol configuration (A5/A7/A8/A9; R10); (3) the byte-pinned model
sources and their sha assertions in the runners; (4) the
verifier/summarizer scripts themselves — mitigated THIS phase by the 13
negative controls (the scripts' rejection behavior is now demonstrated,
not merely claimed); (5) the ghost dynamic-slice tooling (the slice's
byte-faithfulness is machine-verified per run — `audit_ghost_exact.py`).
A hostile toolchain or hostile harness is outside the evaluated model;
this is the recorded TCB boundary, unchanged in kind from 1V and narrowed
in degree by the negative controls.

---

## §E — Residual obligations (reconciled register)

The full reconciled register R1–R14 with per-item status, evidence,
assumptions, impact, 1W change, next action, and objective acceptance
criterion: **`docs/research/residual-register-1w.md`**. Summary of the
items the 1W mandate listed explicitly:

| Item | Status after 1W | Next action (objective acceptance criterion) |
|---|---|---|
| Genesis-form proof | TIMEOUT (R3; unchanged — the 1U proof modules are dependency-independent of the 1V/1W model changes, verified by their distinct require set) | re-attempt only with a toolchain/strategy change; a close requires rc=0 on the genesis spec within a recorded budget; never relabel a timeout |
| `GH-T` | FAILED-STUCK (R5; re-confirmed rc=1 on the regenerated 1W artifact) | keep per-phase per-claim isolation; a close requires the minimal-destination probe to close without weakening the theorem statement |
| Combined ghost-batch tool boundary | Documented tool boundary (R6) + NEW defense-in-depth gap R13 | R13: assert the expected label list inside the ghost runner; criterion: the batch fails when any expected claim is missing from the splitter output |
| Harness-honesty TCB | OPEN by definition (R10, extended to `$INITSTATE` via A8/A9; the bad-baseline fail-closed control documents the assumption's exact coverage) | remains a recorded trust boundary; any narrowing requires a mechanism outside the evaluated model |
| Between-transition initialization affordance | **CLOSED (R9)** — structural removal + adversarial battery + positive controls | none (closed); the residual trust dependency lives in R10 |
| Examiner-report archival | BLOCKED (R7; the document was re-searched in the working tree and all six 1V commits — absent) | owner/examiner supplies `SRW3-Independent-Examiner-Report-v1.2.md`; archival = byte-for-byte copy + sha256 + origin record committed by the next phase |
| Research terminology crosswalk | OPEN (R8; A8 added to the source assumptions; no labels invented) | a phase with research-framework access maps mechanized claims ↔ P1/P2/P3, A1–A4, labeling each mapping verified or interpretive FROM the framework document |
| T4 granularity | UNCHANGED (app-granular vs storage-key-granular documented; no equivalence claimed) | closure requires an independently supported equivalence proof at a single granularity |
| Level-III boundaries | OPEN (R11) | each requires its own evidence program (bisimulation, generator completeness, concrete correspondence, consensus integration) |

## §F — Acceptance criteria (per-criterion status)

| # | Criterion (mandate §7) | Evidence | Status |
|---|---|---|---|
| 1 | The starting Phase 1V commit and ancestry independently verified | §0 table (bundle sha, verify, clone, full SHAs, parent chain, count=6, clean tree, per-commit diffs) | **PASS** |
| 2 | The Phase 1V reproduction procedure audited and rerun, deviations disclosed | §B (two fresh runs 44/44 + 48/48 each, identical to each other and to history; compat wrapper; gate GREEN ×2; deviations (i)–(iii) disclosed) | **PASS** |
| 3 | The between-transition initialization affordance closed with adequate evidence OR retained as a bounded explicit issue | §A (demonstrated on pinned 1V in 5 windows + gen + characterization; closed structurally; 7 parse-rejection/runtime controls + writer audit + positive controls) | **PASS (CLOSED)** |
| 4 | Trusted configuration clearly distinguished from untrusted commands and legitimate mutable protocol state | §A2 table (trusted config / mutable protocol state / per-transition working state; `as` and post-initialization `<committed>` deliberately NOT frozen) | **PASS** |
| 5 | The runner detects the negative and failure conditions it claims to detect | §D (13/13 negative controls; boundary finding R13 registered with the layer-up enforcement demonstrated by D6) | **PASS** |
| 6 | Historical verdicts and evidence preserved | 1V commit objects untouched (append-only branch); OLD-1V demonstrations run against the git-pinned 1V model; 1U exit-code ledger restored bit-identically (sha256-verified); no relabeling anywhere | **PASS** |
| 7 | Every residual obligation traceable with an objective next step | §E + `docs/research/residual-register-1w.md` (R1–R14, each with next action + acceptance criterion) | **PASS** |
| 8 | Repository documentation accurately reflects the verified state | STATE-OF-RECORD + README updates (§G); the 1V historical narrative preserved verbatim; live metadata NOT re-claimable this session (no credential) — the default-branch statement carries the 1V live verification date and the 1W branch makes no new default-branch claim | **PASS** (with the no-credential disclosure) |

**Carried item statuses (unchanged, per mandate §8):** genesis TIMEOUT;
GH-T FAILED-STUCK; combined-batch boundary documented (+R13 new); T4
granularity documented; examiner archival BLOCKED; crosswalk OPEN;
harness-honesty TCB OPEN by definition; Level-III boundaries OPEN.

## §G — What this phase did NOT do (scope discipline)

No new general proof campaign; no universal/production-security claim; no
Ethereum-deployment, consensus-integration, bisimulation, or
generator-completeness claim; no completion tag; no licence choice; no
default-branch change; no rewriting of any historical report; no widening
of any proof's assumptions; no timeout relabeled; no FAILED-STUCK merged
into FAILED.

## §H — The explicit open-obligation list (final)

1. R3 genesis-form proof — TIMEOUT (kept).
2. R4 destination-false TIMEOUT control (kept; decisive control stands).
3. R5 GH-T — FAILED-STUCK (kept).
4. R6 combined-batch checker boundary — documented tool boundary.
5. R7 examiner-report archival — BLOCKED on the document itself.
6. R8 research-framework crosswalk — registered follow-up.
7. R10 harness-honesty TCB (incl. `$INITSTATE`, A8/A9) — open by definition.
8. R11 all Level-III boundaries — open.
9. R12 licence / tag reconciliation — owner authority.
10. R13 ghost-batch claim-count pinning — new, smallest fix registered.
11. R14 sandbox durability process note — new, procedural.

Scope: Level III only. Verdict: **PARTIALLY COMPLETE**.
