# SRW3 Phase 1F — Authenticated Execution-Effect Binding and Commitment-Lineage Integration

**Status: PHASE 1F EXECUTED — the Level-3 research question is answered with a
qualified, boundary-honest result: the binding machinery is PROVED, the
execution-grounded closure is DEMONSTRATED, and the authenticity boundary of
the abstract layer is stated, not assumed away.** This report was produced
from the `phase1f` branch derived from the Phase 1E closure commit
(`8b26cb749...` = closure; scientific anchor `0d826c0f1...`), on a rebuilt
toolchain (K v7.1.337, Z3 4.13.3-1, clang/LLVM-15 15.0.6-4+b1, KEVM v1.0.921
source, blockchain-k-plugin @ 207ae512, krypto shim rebuilt from source with
the keccak-multiblock fix). The frozen layers were not modified: `git diff`
over `k/`, `python-gen/` and `phase1e/` against the Phase 1E closure state is
empty, and every Phase 1F extension is additive (`linCtxP` / `linRecE` /
`execCtx` discipline).

## 1. Research question and answer

**Question.** Can the SRW3 commitment gate bind its security decision to
authenticated evidence of EXECUTION-DERIVED effects — so that the lineage
records what a concrete execution actually produced (`PresentedEffects ==
TrueEffects(execution)`, Level 3) — rather than only (Level 1) a
self-consistent presentation or (Level 2) an anchored state representation?

**Answer: YES at Level 3 as a BINDING result, under explicitly stated
assumptions, with the three-level separation preserved — and the
authenticity boundary stated honestly.** The gate was extended (additively)
so that acceptance requires, on top of the full Phase 1D-R1 + 1E
certificate:

1. the declared effects to be byte-canonically EQUAL to the write
   projection of a digest-bound, order-preserving effect trace
   (`invalid-effdecl` — the Level-3 core check; effect equality becomes
   DECIDABLE rather than post-relative);
2. the effect trace to be bound into the record digest chain and coherent
   with an execution WITNESS (`invalid-efftrace`, `invalid-witness`);
3. the execution identity to be exactly the domain-separated recomputation
   over (parent state root, payload, chain config, environment)
   (`invalid-execid`, `invalid-execconfig`) — replaying the same payload
   against a different parent root, caller, or fork spec yields a different
   identity;
4. every presented read observation to be REPLAY-CONSISTENT and the trace's
   writes to compose exactly to the presented post (`invalid-effbind`) —
   this mechanizes the oracle-staleness class (false read observations are
   rejected even when every digest is coherently re-forged);
5. the whole presentation to respect explicit fragment bounds
   (`invalid-execbounds` — a model refuse, never silent).

What this result IS NOT, stated plainly: at the ABSTRACT layer the trace is
a presented input (A-F3). A producer able to forge ALL presented artifacts
consistently (trace + record + witness, co-signed) produces an internally
consistent Level-3 record — the same authorized-dishonest-producer boundary
as every prior phase, now WITH the boundary explicitly mechanized as a
negative-control-adjacent disclosure (mutation b02) rather than hidden.
Closing that boundary requires an execution-derived trace source: Phase 1F
DEMONSTRATES the closure at the instrumented-execution layer (KEVM), where
the trace is built by the semantics from real opcode execution and never
passes through producer hands; verifier re-execution remains REQUIRES
CLIENT/PROTOCOL SUPPORT.

## 2. Starting state and baseline regression

The handoff discipline mandated re-running the permanent suites before any
Phase 1F work (`transcripts/part0_baseline_k_composition.txt`):

| Suite | Result |
|---|---|
| L7 permanent adversarial suite (Python) | 10/10 PASS |
| Legacy hostile-mutation harness (21 classes) | 21/21 rejected |
| Comparison audit | 33/33 probes, zero deviations |
| Authorized-dishonest producer | REJECTED at L7-STATE |
| Phase 1E Python suite + mutations | 24/24 + 12/12 |
| K composition suite (fresh LLVM re-kompile) | pos=valid; neg1=neg2=neg3=invalid-state-composition |

Environment note, recorded honestly: this session began from a sandbox
reset. The remote `phase1e` branch was re-fetched from GitHub (the local
worktree and the local worklog had no Phase 1E state — a discrepancy with
the session-start expectation, recorded in the worklog); the toolchain was
rebuilt from the pinned recipe; the anchors `0d826c0f` (scientific) and
`8b26cb74` (closure) were verified on the fetched branch before `phase1f`
was derived.

## 3. The minimal execution-effect model (FROZEN)

`phase1f/semantics/MODEL.md` is the normative specification. Design points:

- **Vocabulary (fragment).** `Read(1) / Write(2) / Call(3) / Return(4)`
  events `exEvt(op, app, a1, a2)` sourced from SLOAD / SSTORE / CALL /
  RETURN. LOGn, CREATE/CREATE2, CALLCODE, DELEGATECALL, STATICCALL,
  SELFDESTRUCT, gas and memory ops are OUTSIDE the fragment — a documented
  under-approximation matching the obligation surface the prior phases
  mechanized. Field bounds (`app < 2^32`, slot refinement for read/write,
  `a1,a2 < 2^64`) are explicit refuses (`invalid-execbounds`).
- **Order-preserving canonical encoding.** `TraceBytes = 0x03 ‖ n₄ ‖ (op₁ ‖
  app₄ ‖ a1₈ ‖ a2₈)*` in EXACT trace order — no sorting, no deduplication,
  no set semantics anywhere; two traces with the same multiset in different
  orders have different bytes and digests by construction (mechanized:
  EX3c/EX3d).
- **Execution identity.** `ExecutionId = H(0x1F ‖ parentStateRoot ‖
  PayloadDigest ‖ ConfigDigest ‖ EnvDigest)` with domain-separated component
  digests (`0x11` payload, `0x12` env, `0x13` config). Only fields with a
  demonstrated security role are included; the parent state root is the
  Phase 1E anchored root of the parent record, making
  `PreRoot + ExecutionId + TrueEffects + PostRoot` the binding chain.
- **Witness.** Eight fields (version, parentRoot, executionId, payloadD,
  declaredD, traceD, postRoot, configD), canon `0x57…`, digest checked by
  the gate with full coherence (each witness field pinned to the record or
  the recomputed context). **Signature ≠ authenticity** is explicit.
- **Trace semantics.** `ExecTraceWrites` (last-write-wins), `ExecReplayMap`
  / `ExecReadsOk` / `ExecReplayOk` (the verifier-side replay validating
  every read observation against the working state and the exact final
  composition), `ExecProj` (π_P — reads dropped, order preserved), and
  `ExecDeclaredOk` — the Level-3 core equality
  `H(canon(declared)) == H(canon(Writes(trace)))`.
- **Not an Ethereum trace format.** No RLP, no EIP-7685, no consensus
  structure is claimed; the model is minimal and fully mechanizable.

## 4. The additive record and gate

`LinRecF = (LinRecE, execId, effTraceDigest, execWDigest, execConfigDigest)`
with `CanonCoreF = CanonCoreE ‖ (new fields)` — CanonCoreE is a strict
PREFIX; the base `childE` is carried unchanged and the legacy chains run
unchanged on the projections. `VerifyLineageF` is a first-fail chain over
the unchanged Phase 1E chain, adding the six new verdicts above and
`valid-f`. The full accept condition is **14 atomic conjuncts** (legacy
chain ∧ corrected-composition ∧ capacity ∧ padkey ∧ state-root ∧ anchor ∧
childE ∧ execbounds ∧ execconfig ∧ execid ∧ efftrace ∧ effdecl ∧ witness ∧
effbind); the task brief's 12-candidate list is recorded as superseded by
the actual decomposition — not silently reconciled.

## 5. Mechanized proofs (Haskell backend, kprove)

`phase1f/proofs/` — 26 claims, one per file (`part3_k_proofs.txt`):

| Group | Claims | Outcome |
|---|---|---|
| Identity + canonical trace exactness | EX1, EX2a-c, EX3b-d | 7 PROVED |
| Trace replay semantics | EX4a-c | 3 PROVED |
| Record binding (prefix, childE invariance, childF, witness digest) | EX5a-c, EX5e | 4 PROVED |
| Branch-wise gate certificate + accept direction | EXB1-EXB6 (+EXB4b), EXBACC | 8 PROVED |
| Single-implication form | EXGATE | NOT PROVED at the simplification budget (disclosed; 1E GA1 precedent; content carried branch-wise) |
| Negative controls (designed fail) | NC1 (stuck — the A-F1 hash-injectivity boundary), NC2, NC3 | fail as designed |

**Total: 22 PROVED.** Disclosed not-mechanized attempts (kept verbatim in
`proofs/not_mechanized/` with reasons): EX3a (symbolic order-preservation
induction), EX4d (cross-slot map commutativity), EX5w (the replay-writes
lemma — the gate does not depend on it), EX5d/f/g/h (honest-construction
coherence over fully symbolic maps — the AuthRootOf path; content pinned
concretely by the LLVM demo + the cross-layer bytes). Non-vacuity: the
accept premise is satisfiable — `valid-f` is a permanent demo case on the
LLVM backend with real keccak + secp256k1, mirrored by the Python suite;
NC3 (the vacuity probe) fails as designed.

## 6. The abstract demonstration suite (LLVM, real krypto)

`srw3exec-demo.k` — the Oracle → Lending → Liquidator case study as a
three-record `LinRecF` chain with execution-identity and parent-root
threading (`part4_k_demo_suite.txt`; the concatenated suite exceeds the 3 GB
sandbox as ONE term, so the SAME cases run as partitioned programs — none
skipped, documented):

| Case | Construction | Verdict |
|---|---|---|
| pos0/1/2 | honest chain (oracle update; borrow reading the price; liquidation with an intermediate same-slot write corrected by the final write) | valid-f ×3 |
| f8a/f8b/f8diff | equal final state, divergent traces (trailing redundant read): BOTH accepted, digests differ | valid-f; trace-digests differ |
| neg1 (F1) | hidden write in the trace, declared unchanged | invalid-effdecl |
| neg2 (F2) | read suppressed from the presented trace, digest covers the full trace | invalid-efftrace |
| neg3 (F4) | same-slot reorder with changed value, fully re-forged presentation | invalid-anchor (Level 2 catches first — recorded at its actual layer) |
| neg3x (F4 boundary) | cross-slot reorder, same final map, re-bound trace | valid-f BY DESIGN (fragment: cross-slot order is not security-relevant; the trace digest still binds it — neg3xdiff=true) |
| neg4 (F5) | stale parent-root replay | invalid-execid |
| neg5 (F6) | fork-spec replacement | invalid-execconfig |
| neg6 (F7) | witness bound to a foreign trace digest | invalid-witness |
| neg7 | bounds refuse (app = 2^32) | invalid-execbounds |
| neg8 (F2 residual) | FALSE READ OBSERVATION, every digest coherently re-bound, all legacy+L2 green | invalid-effbind |

F8's demonstration is the standing discipline made concrete: the model never
infers trace equality from post-state equality nor the converse.

## 7. Python mirror and mutation harness

`phase1f/python/` mirrors the K semantics exactly (`exec_model.py` — canon,
identity, witness, replay, gate) and re-runs the full case table
(`test_exec_verify.py`: **16/16** verdict cases + 3/3 byte checks against the
K values) plus a hostile-mutation harness (`exec_mutations.py`: **15/15** as
expected — the producer re-signs and re-digests everything forgeable;
rejections at the documented first-fail layers, including m01-m02 digest
flips, m03-m06 witness mutations, m07-m09 declared/trace tampering,
m10-m12 context substitutions, m13 stale anchor; b01/b02 are DOCUMENTED
BOUNDARIES: the cross-slot order swap is accepted by design, and the fully
consistent hidden-write forgery is caught by the Level-2 anchor — the
A-F3 boundary at the abstract layer, closed at the KEVM layer).

## 8. The instrumented-execution layer (KEVM) — the Level-3 closure demonstration

`k/kevm/srw3-exec-evm.k` (+ demos; `part5_kevm_binding.txt`):

- **Execution-derived traces.** Additive `#next [OP]` interception rules
  (priority 20, the frozen loop untouched) log the four fragment opcodes
  into a RESERVED TRACE ACCOUNT (4096, outside the observed state) with a
  (last-run, last-pc) guard so multi-run traces record exactly one event per
  execution step, in actual execution order, with the actual operands. The
  trace never passes through producer hands.
- **`#w3GateF(anchor, payload, declared, presented)`.** The record binds the
  PRESENTED artifacts (abstract-layer discipline); `VerifyLineageF` runs on
  the presented trace; on top of valid-f, the LEVEL-3 EXECUTION CHECK
  confronts the declared effects with the write projection of the
  EXECUTION-DERIVED trace.
- **Demos** (all with real keccak + secp256k1, obligations green, commit/
  lineage atomicity preserved — rejects restore all storages and append no
  lineage record):
  - `evm_exec_commit` — honest: **valid-f → COMMIT**;
  - `evm_exec_hidden` — the state-invisible hidden write (SSTORE of a slot's
    own value; L1, L2 and every abstract layer are BLIND to it; the
    presentation is fully coherent): **invalid-declared-exec → REJECT +
    RESTORE** — the execution-derived evidence is the ONLY layer that sees
    it; this is the phase's headline demonstration;
  - `evm_exec_tamper` — tampered presented trace: **invalid-effdecl →
    REJECT + RESTORE**.
- Multi-gate executability required additive carrier/run hoisting rules
  (1E recorded single-gate-per-run only) — disclosed as new additive rules,
  frozen files untouched.

## 9. Cross-layer byte consistency

`scripts/phase1f/part6_crosslayer.py` (`part6_crosslayer_bytes.txt`):
**9/9 byte-equality checks MATCH** across Python ↔ K-abstract (llvm, real
krypto) ↔ KEVM instrumented run: trace canon bytes, execId, childF
(abstract case), and for the KEVM commit record: config digest, execution
id, trace digest, witness digest, the anchored state root (embedded from
the Python reference — acceptance certifies root equality by construction),
and the executed-trace canon bytes decoded from the tracer storage of the
real run.

## 10. Countermodels CM-F1..F9 (all demonstrated; expectations recorded)

| ID | Construction | Rejected at |
|---|---|---|
| F1 | hidden write | invalid-effdecl (abstract); invalid-declared-exec when state-invisible (KEVM) |
| F2 | suppressed read | invalid-efftrace (suppression); false observation → invalid-effbind (neg8) |
| F3 | declared-but-never-executed effect | invalid-effdecl (declared ≠ Writes(trace)) |
| F4 | fake order | same-slot value change → invalid-anchor (L2; the honest anchor pins the post); cross-slot → accepted BY DESIGN with trace-digest distinctness (fragment boundary) |
| F5 | context replacement (stale parent root) | invalid-execid |
| F6 | fork-spec replacement | invalid-execconfig |
| F7 | producer-signed fake effects (fully coherent forgery) | abstract layer: the binding holds by construction (the honest disclosure — A-F3); the same construction is REJECTED where the trace source is execution-derived (KEVM hidden demo); anchor-visible variants are caught at L2 |
| F8 | equal final state, trace divergence | NOT an attack: both records accepted, digests distinct — the model does not assume same-state ⇒ same-trace (nor the converse) |
| F9 | hidden cross-application interaction | the interaction's write is an effect: declared ≠ Writes(trace) → invalid-effdecl; if also state-hidden → invalid-declared-exec (KEVM) / L2 anchor for state-visible variants |

## 11. Prior-art positioning (targeted; `part7_prior_art.txt`)

| Technique | The distinction |
|---|---|
| EIP-8025 (execution/state witnesses over RPC) | authenticates STATE pieces to clients from a serving node; no K semantics, no obligation gate, no lineage threading, no ordered effect trace |
| zkEVM provers | prove GENERIC execution validity — the frozen standing distinction (generic validity ≠ SRW3 security validity) applies verbatim; the obligation surface, lineage, and anchoring are absent; complementary as a future witness SOURCE |
| Stateless-Ethereum / Verkle witness formats | authenticate the state TOUCHED, not the ordered effect stream; no execution identity, no read-observation binding (the oracle-staleness class), no lineage |
| Attested execution receipts (TEE/quorum) | trust replaces verification; SRW3 recomputes everything mechanized and states signature ≠ authenticity explicitly |
| Fraud-proof / evidence systems | retroactive and challenge-gated; SRW3's gate is commit-time with lineage atomicity |
| KEVM contract verification | proves properties of programs; 1F proves properties of a GATE over records/traces/identities/anchors — a different artifact class on the same engine |

No technique surveyed combines: order-preserving digest-bound effect traces,
a domain-separated execution identity over (parent root, payload, config,
env), witness-coherent lineage records, replay-validated read observations,
and a commit-time security-obligation gate over real EVM execution. The
comparison upgrades no evidence tier.

## PHASE 1F RESULTS

```
Research question:               can the gate bind its security decision to
                                 authenticated evidence of execution-derived
                                 effects (PresentedEffects == TrueEffects-
                                 (execution), Level 3)?
Status:                          ANSWERED — qualified positive at Level 3 as a
                                 BINDING result under stated assumptions;
                                 three-level separation preserved; the
                                 authenticity boundary stated, not assumed away
Effect-trace fragment:           Read/Write/Call/Return over SLOAD/SSTORE/CALL/
                                 RETURN; order-preserving canonical encoding
                                 (no sorting/dedup/set semantics); explicit
                                 bounds refuses; NOT an Ethereum trace format
Execution identity:              H(0x1F ‖ parentRoot ‖ payloadD ‖ configD ‖
                                 envD) — domain-separated components; parent
                                 root = the 1E anchored root (PreRoot +
                                 ExecutionId + TrueEffects + PostRoot chain)
Witness:                         8-field canon + full gate coherence; signature
                                 ≠ authenticity explicit
Record:                          LinRecF additive; CanonCoreE strict prefix of
                                 CanonCoreF; childE carried unchanged
Gate_F:                          first-fail; 14 atomic conjuncts (the brief's
                                 12-candidate list recorded as superseded);
                                 new verdicts: invalid-execbounds/execconfig/
                                 execid/efftrace/effdecl/witness/effbind;
                                 effdecl = the LEVEL-3 CORE CHECK (declared
                                 effects == Writes(trace), decidable, not
                                 post-relative)
Mechanized:                      22 kprove claims PROVED (identity/canon
                                 exactness, replay, record binding, branch-wise
                                 EXEC-EFFECT-BINDING certificate + accept
                                 direction); EXGATE single form BLOCKED
                                 (budget, disclosed); NC1-3 designed-fail;
                                 7 disclosed not-mechanized attempts (kept)
Demonstrated (abstract):         3-record Oracle->Lending->Liquidator chain
                                 (valid-f x3), F1-F9 classes, F8 trace-
                                 sensitivity, cross-slot order boundary —
                                 LLVM, real krypto, partitioned programs
Demonstrated (KEVM):             EXECUTION-DERIVED traces via additive #next-
                                 interception; honest -> valid-f COMMIT;
                                 state-invisible hidden write -> invalid-
                                 declared-exec REJECT+RESTORE (the headline:
                                 only the execution evidence sees it);
                                 tampered trace -> invalid-effdecl REJECT
Cross-layer bytes:               9/9 MATCH (P <-> K-abstract <-> KEVM)
Python mirror:                   16/16 cases + 15/15 mutations (2 documented
                                 boundaries)
Zero regression:                 frozen 1D/1E surface untouched; baseline
                                 re-verified at start (L7 10/10, mutations
                                 21/21, comparisons 33/33, 1E suites, K
                                 composition suite)
Assumptions:                     A-F1 keccak collision resistance (REQUIRES
                                 CRYPTOGRAPHIC ASSUMPTION); A-F2 structural
                                 injectivity; A-F3 trace authenticity =
                                 verifier-domain boundary at the abstract
                                 layer, CLOSED by construction at the KEVM
                                 layer, else REQUIRES CLIENT/PROTOCOL SUPPORT
                                 (re-execution); A-F4 explicit bounds refuses;
                                 A-F5 parent-root threading (inherits A-E3)
Level 1 (Phase 1D-R1):           unchanged — presented-record internal
                                 self-consistency (frozen surface, zero
                                 regression)
Level 2 (Phase 1E):              unchanged — anchored state commitment
                                 (Merkle root == anchor); anchor provenance
                                 still REQUIRES CLIENT/PROTOCOL SUPPORT
Level 3 (Phase 1F):              binding PROVED BY K (branch-wise certificate
                                 + accept direction); execution-grounded
                                 closure DEMONSTRATED BY KEVM (instrumented
                                 real execution); general historical-truth
                                 authentication REQUIRES CLIENT/PROTOCOL
                                 SUPPORT (re-execution) — recorded, not
                                 silently closed
Anti-vacuity:                    pos=valid-f permanent demos (abstract + KEVM)
                                 + Python E0-style witness; NC3 fails as
                                 designed
Honest disclosures:              EXGATE single-form BLOCKED; 7 not-mechanized
                                 attempts kept; sandbox-reset recovery
                                 recorded; 3 GB sandbox memory constraint
                                 documented (partitioned demo programs); the
                                 abstract-layer consistent-forgery boundary
                                 (b02) stated as the A-F3 boundary, closed at
                                 the KEVM layer only by demonstration
Git:                             branch phase1f derived from phase1e closure
                                 8b26cb74 (scientific anchor 0d826c0f);
                                 no history rewrite of any milestone branch
Artifact bundle:                 SRW3-Phase1F-Artifact-Bundle.zip + .sha256
                                 sidecar (MANIFEST 422 entries, round-trip
                                 ALL OK; cumulative 0-D..1F)
Completion verdict:              COMPLETE — all completion criteria evaluated
                                 below; no criterion silently waived
```

## 12. Completion criteria evaluation

| # | Criterion | Verdict |
|---|---|---|
| 1 | TrueEffects vocabulary + documented fragment | SATISFIED (MODEL.md §2 frozen; bounds explicit) |
| 2 | Execution identity binding (parent root, payload, config, env) | SATISFIED (recomputation layer; F5/F6 negative controls) |
| 3 | Canonical, deterministic, independently recomputable EffectDigest | SATISFIED (order-preserving canon; 9/9 cross-layer bytes) |
| 4 | ExecWitness + coherence; signature ≠ authenticity | SATISFIED (8-field witness; gate layer L21) |
| 5 | Non-trivial theorem (strongest provable form) | SATISFIED branch-wise (8 gate claims + accept direction); single form BLOCKED and disclosed |
| 6 | Negative controls with expected verdicts | SATISFIED (NC1-3 + CM-F1..F9 + 15 mutations) |
| 7 | Level-2 preserved | SATISFIED (frozen diff empty; baselines green) |
| 8 | Three-level separation preserved | SATISFIED (§11 verdicts stated per level; no merging) |
| 9 | Prior-art comparison incl. the standing distinction | SATISFIED (part7; scoped, tier-neutral) |
| 10 | Independently reproducible | SATISFIED (transcripts + pinned recipes + per-claim raw outputs) |
| 11 | Honest witness accepted / forgery rejected / fake effects fail | SATISFIED (commit/hidden/tamper demos; b02 boundary disclosed and closed at KEVM) |
| 12 | Packaging: report, bundle, provenance, git | SATISFIED by this closure |

## 13. What is proved, demonstrated, and open

- **PROVED BY K (22 claims).** Identity and canonical-trace exactness; the
  replay semantics; the record binding (prefix + childE invariance + childF
  + witness digest); the branch-wise EXEC-EFFECT-BINDING certificate (every
  extension verdict characterized exactly) and the accept direction
  (all-14 ⟹ valid-f). No claim consumes hash evaluation; injectivity stays
  pinned to A-E1/A-F1 (NC1 stuck by design).
- **DEMONSTRATED BY KEVM.** The execution-derived trace construction over
  real opcode execution; honest → valid-f COMMIT; the state-invisible hidden
  write → invalid-declared-exec REJECT+RESTORE; the tampered presentation →
  invalid-effdecl REJECT+RESTORE; 9/9 cross-layer bytes.
- **NOT YET MECHANIZED (disclosed).** EXGATE's single-implication form
  (content carried branch-wise); the replay-writes lemma (the gate does not
  depend on it); cross-slot map commutativity; symbolic-universe coherence
  pins (concretely pinned by demos + bytes).
- **REQUIRES CLIENT/PROTOCOL SUPPORT.** Trace authenticity for abstract-layer
  records (re-execution or an attested execution-derived source); anchor
  provenance (inherited from 1E, untouched — no circular strengthening).
- **Standing open items (unchanged).** Tier-3 universal reconciliation;
  the general cryptographic theorem form; the result remains a concrete
  demonstration within the modeled verifier domain.

Phase 1G remains out of scope and is not entered by this closure.

## 14. Artifact index

| Artifact | Path |
|---|---|
| Model spec (FROZEN) | `phase1f/semantics/MODEL.md` |
| K semantics (additive) | `phase1f/semantics/srw3exec.k` + demo `srw3exec-demo.k` |
| K proofs + negative controls | `phase1f/proofs/*.k`, `proofs/not_mechanized/` |
| Python reference + suites | `phase1f/python/{exec_model,test_exec_verify,exec_mutations}.py` |
| KEVM binding + demos | `k/kevm/srw3-exec-evm.k`, `srw3-exec-evm-demos.k`, `k/kevm/demos/evm_exec_*.srw3evm` |
| Transcripts (Parts 0-7) | `phase1f/transcripts/` (+ `part3_per_claim/` raw outputs) |
| Cross-layer + prior-art scripts | `scripts/phase1f/` |
| Report | `phase1f/report/SRW3-Phase1F-Execution-Binding-Report.{md,pdf}` |
| Provenance | `phase1f/provenance/PROVENANCE.md` |
