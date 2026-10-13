# SRW3 Phase 1J — Security Closure Report

**Reachability Safety Closure & Execution-Evidence Completeness**
Branch `phase1j-security-closure` · additive tree `phase1j/` · frozen base
`8a520fd8a3d4651b0884a59e8db8aec1d3eb7670` (`phase1i-r3-complete`)

---

## 1. Objective and outcome

Phase 1J advances SRW3 from the verified configuration commitment (1I-R3) to
an explicit **reachable-committed-state safety theorem** over a new isolated
transition system `M_J`.  The theorem target — `J-REACHABLE-COMMITTED-SAFE`
(every committed prefix of every reachable finite execution satisfies the
independently defined safety predicate `Safe_P`) — is decomposed per the
handoff §3 into base, execution/evidence, effect closure, catalog integrity,
interaction closure, preservation, gate/commit bridge, and induction
obligations.

**Outcome (Level III, conditional): CLOSED FOR THE DECLARED FINITE
FRAGMENT, conditional on the listed anchor/source assumptions — with four
retained not-mechanized items whose concrete substitutes are delivered.**
The K ladder is **38 PROVED / 4 retained** over a 42-claim inventory; the
Python adversarial suite is **48/48 PASS** over all 24 normative attack
classes plus honest pipelines, determinism, and golden vectors; the LLVM
suite (real Ethereum Keccak-256 via the Phase-1C shim) is **14 executed
demos + 5 kparse ill-formedness rejections**; the cross-layer conformance is
**22/22 byte-identical** fields; all frozen regression suites reproduce
exactly and the frozen trees are byte-identical to the R3 base.

The four retained items are the honest Haskell-boundary outcomes, each with
its failed log retained and its concrete substitute delivered
(`claim-classification.csv`): `J-EVIDENCE-STATE-CORRESPONDENCE` and the two
pipeline claims (the keccak hook has no evaluator on the hs backend — the
documented R3 `PIPELINE-HONEST` class; demonstrated on LLVM T1/T2/T3/T6 and
checked in Python), and `J-REACHABLE-COMMITTED-SAFE` (the kore
stuck-configuration/circularity blocker — the frozen `PI7-ALL` class; the
closure evidence is the proved component lemmas, the Python exhaustive
sequence enumeration — 3474 committed prefixes, 386 unsafe derived states
caught by `Safe_P`, zero committed unsafe — and the LLVM two-block pipeline).

## 2. What was built

`phase1j/semantics/srw3closure-j.k` — the ISOLATED J machine (module
`SRW3CLOSURE-J`, 2069 lines), importing ONLY the frozen Phase 1G gate:

- **The concrete policy catalog** (handoff §5.1): registered applications,
  resources (the flat 64-bit 1E key space, 8-byte canonical encoding), n-ary
  hyperedges, and a DECLARED finite typed invariant fragment (local bounds;
  sum over a key set; equality over a key set) organized as local /
  hyperedge / global classes.  Canonical encoding with a new domain
  (`"SRW3/PolicyCat/J"||0x00`, versioned, length-delimited, deterministic
  order) and three content-class sub-roots (0xB1/0xB2/0xB3) that the pin
  binds to the R3-rooted configuration fields 3/4/5 — **catalog CONTENTS are
  authenticated by the same R3 anchor** (the digest-without-contents and
  contents-without-digest refusals both fail closed).
- **The closed execution fragment `EVM_F`** (Option A, handoff §4.1): a
  four-op interpreter (Read/Write/Call/Return — the frozen 1F vocabulary)
  that DERIVES the ordered event trace, the effective write-delta, and the
  post-state from the current abstract state.  Excluded effect classes and
  out-of-range operands produce EXPLICIT refusals (`jExecUnsupported`/
  `jExecBounds`) — never skipped, never silent no-ops.  The trace is emitted
  by the semantics (the only trace producers are the interpreter rules);
  the footprint is the first-occurrence projection of the trace.
- **The J state root** (`StateRootJ`, tag 0xB4 over the frozen ascending
  map canon) and the **evidence identity** (`EvidenceIDJ`, new domain
  `"SRW3/Evidence/J"`, binding config root, catalog root, chain/fork,
  parent/post state roots, payload digest, execution-source identity,
  trace digest, footprint digest, policy-context digest).
- **Two receipt kinds**: the exec receipt (minted ONLY by `pExecJ`, all
  fields machine-derived) and the gate receipt (minted ONLY by
  `pGateEvalJ`, verdict COMPUTED by the frozen 21-conjunct gate over the
  machine-constructed context, embedding the exec receipt it was derived
  from).  Both consumed exactly once by the commit.
- **The bounded hypergraph closure** (handoff §5.2): the least closure of
  the touched keys plus every incident hyperedge plus the additional nodes
  needed to evaluate each incident invariant, under an explicit fuel bound;
  exhaustion refuses (never "no more interactions"); unregistered touched
  keys refuse.
- **`Safe_P` computed, independent of the gate** (handoff §3/§6): `SafeJ`
  evaluates every registered invariant on a state — used at the pin (the
  genesis must be safe: `J-INIT-SAFE` enforced at init) and at the commit
  boundary on the DERIVED post-state.
- **One chain-extending rule** (`pCommitJ`, handoff §7) with the nine
  requirement classes in the R3 guard order (decidable conjuncts first, the
  computed policy result, the hash-class conjuncts last); rejections leave
  every cell unchanged.

`phase1j/semantics/srw3closure-j-demo.k` — the fixture suite: the 3-app
countermodel catalog (oracle/lending/vault with the 3-app solvency
hyperedge `he1={k1,k2,k3}` and the pairwise edge `he2={k2,k4}`), the honest
evidence chain BUILT FROM the derived artifacts (the correspondence is
structural), the mutation/malformation fixtures, and the cross-layer byte
certificate (`xCertJ`).

`phase1j/proofs/` — the 42-claim ladder (`j_proofs.k`), the runner
(`run_j_proofs.sh`, resumable, per-claim exit codes + retained logs), the
all-literal fixtures (`j_fixtures.k`), and the LLVM build script
(`j_build_llvm.sh`).

`phase1j/python/` — the executable mirror (`j_model.py`: catalog canon +
roots, fragment interpreter, footprint, state roots, evidence identity,
invariant evaluation, bounded closure, the full machine driving the REAL
frozen gate via the unchanged Phase-1G model) and the adversarial runner
(`run_j_attacks.py`: J-A01..J-A24 + honest pipelines + determinism + golden
vectors + the reachability sequence enumeration).

`phase1j/tests/`, `phase1j/vectors/`, `phase1j/transcripts/{k,llvm,attacks,
regression}/`, `phase1j/audit/`, `phase1j/report/`, `phase1j/provenance/` —
per the handoff §11 layout.

## 3. The theorem, honestly stated

For the declared fragment and the fixture catalog, the following are
MECHANIZED (hs backend, logs retained):

- **Base.** `J-INIT-SAFE-BASE`: the registered invariants hold on the
  genesis state; an unsafe genesis is REFUSED at the pin
  (`J-INIT-REFUSES-UNSAFE-GENESIS`).
- **Origin/correspondence structure.** The trace is emitted by the
  semantics (`J-FRAG-TRACE-WRITE/ORDER/READ-AFTER-WRITE`); the footprint is
  the derived projection (`J-FOOTPRINT-PROJECTION`); the candidate identity
  fields equal the derived values (the mint's binding conjuncts —
  demonstrated concretely on LLVM where the mints fire, and in Python).
- **Effect closure.** Every excluded class refuses
  (`J-FRAG-UNSUPPORTED/-MIDPROGRAM/-BOUNDS`); nothing outside the fragment
  can silently affect the state.
- **Catalog integrity.** The canonical preimage is pinned byte-for-byte
  (`J-CATALOG-CANON-FIXTURE`, the golden vector); each content class binds
  (`J-CATALOG-BINDS-APPS/RESOURCES/GRAPH/POLICY`); well-formedness is
  total and fail-closed (`J-CATALOG-WF-*`); the missing 3-app hyperedge
  changes the preimage and refuses the pin
  (`J-CATALOG-BINDS-GRAPH`, `J-INIT-REFUSES-GRAPH-MISMATCH`).
- **Interaction closure.** `J-CLOSURE-FIXTURE` (the fixed point pulls in
  the pairwise edge via the 3-app edge) and `J-CLOSURE-EXHAUSTED`
  (bounded exhaustion refuses); unknown touched keys refuse
  (`J-FOOTPRINT-REGISTERED-UNKNOWN`).
- **Safety decomposition.** `J-SAFE-HONEST`; the 3-app countermodel
  `J-SAFE-UNSAFE-COMPOSITION` (locals pass, the pairwise invariant passes,
  the 3-app hyperedge invariant FAILS, `SafeJ` false); the global class
  `J-SAFE-GLOBAL-FAIL`; `J-FRAME-PRESERVATION`.
- **Gate/commit bridge.** `J-GATELINK-VALID` (the derived-decision link),
  `J-DECISION-BOUND` (only "valid-g" is protocol-valid),
  `J-FORGED-VERDICT-REJECT` (a non-valid-g computed verdict cannot commit),
  `J-COMMIT-NO-RECEIPT-REJECTS`; the anchor discipline
  (`J-INIT-PINS-AUTHORIZED`, `J-INIT-ROOT-MISMATCH-REJECTS`).

**Not mechanized (retained, with substitutes):** the record/digest-level
correspondence and the two full-pipeline one-step claims (hs keccak
boundary — demonstrated on LLVM T1/T2/T3/T6, checked in Python), and the
universal reachability induction (the kore circularity class — the closure
evidence is the component lemmas above plus the Python exhaustive sequence
enumeration over the closed fragment: 3474 committed prefixes checked, 386
unsafe derived states caught by `Safe_P`, zero committed unsafe, plus the
LLVM two-block honest pipeline).  Per the handoff §10, a failed universal
theorem accurately recorded is not a project failure; relabeling it would be.

## 4. The cross-layer evidence

- **22/22 byte-identical** conformance fields between the K LLVM
  certificate (real Keccak-256) and the Python mirror: catalog canon bytes
  and length, catalog root, three sub-roots, config root, three state
  roots, trace digest, footprint digest + canon, payload digest,
  policy-context digest, evidence identity, block commitment, certificate
  id — plus the computed verdicts (verdict0/verdict1 "valid-g") and the
  SafeJ evaluations, with the disclosed verdict-surface normalization (the
  R2/R3 mirror artifact: the Python gate emits layer-coded verdicts;
  `verdict_k` normalizes; only "valid-g" maps to the valid decision on both
  sides).
- The machine's honest pipeline executes END-TO-END on LLVM with REAL
  keccak: init (anchor check) → exec (derived receipt) → gate (computed
  verdict) → commit (state moves to the derived post-state) — twice
  (T2), with the unsafe third block REJECTED (T6: state, head, and counter
  unchanged; the receipts stay unconsumed).
- The Python mirror drives the REAL frozen gate (`verify_lineage_g`
  imported unchanged from the Phase-1G model) — including the demonstrative
  fact that the gate ACCEPTS the unsafe record (`J-A13`: "valid-g"): the
  authority layer and the policy layer are DISTINCT, and the commit
  boundary composes them fail-closed.

## 5. Assumptions, exclusions, and costs

(See `audit/SECURITY-CLOSURE-AUDIT.md` §E for the full register.)

- **ASSUMED**: the authenticated anchor; Keccak-256 collision resistance;
  the frozen gate's soundness as used; the invariant language IS the
  intended policy (the typed fragment); the declared execution source's
  integrity; the 1F/1G input-side authenticity boundary.
- **EXCLUDED and fail-closed**: LOGn, CREATE/CREATE2, CALLCODE,
  DELEGATECALL, STATICCALL, SELFDESTRUCT, gas accounting, memory
  operations, precompile/system effects — each is an explicit refusal
  (`jUnsupported`), never a silent no-op.  Option B (full-EVM evidence)
  remains OPEN and is not claimed.
- **Liveness cost**: fail-closed availability — unavailable evidence,
  catalog, or closure data means the commit never fires (a non-committing
  defer); unavailability is never interpreted as acceptance.
- **No consensus-integration claim** (Level III model; the 1H Geth adapter
  was a shadow boundary and remains one).  The disposition is: **closed for
  the declared finite effect/policy fragment, conditional on the listed
  anchor/source assumptions** — NOT "end-to-end security closed".

## 6. Regression and provenance

- Frozen trees byte-identical to `8a520fd` (git diff over everything except
  `phase1j/` is empty).
- Frozen suites reproduce exactly: 1E baseline OK; 1F 16/16; 1G 25/25;
  R1 48/48; R2 87/87; R3 181/181.
- 1J Python: 48/48 adversarial checks; 27/27 unittests.
- `provenance/MANIFEST.txt` + `provenance/provenance-hashes.txt` record the
  phase1j tree (107 files hashed at packaging time).

## 7. Artifact index

```
phase1j/
  semantics/srw3closure-j.k            the isolated J machine
  semantics/srw3closure-j-demo.k       fixtures + the cross-layer certificate
  proofs/j_fixtures.k                  proof-definition fixtures (inert)
  proofs/j_proofs.k                    the 42-claim ladder
  proofs/run_j_proofs.sh               the resumable runner (score 1:1)
  proofs/j_build_llvm.sh               the LLVM + krypto-shim build
  python/j_model.py                    the executable mirror (real keccak)
  python/run_j_attacks.py              J-A01..A24 + pipelines + vectors
  python/pack_cfg_shim.py              the 13-field config builder shim
  tests/test_security_closure.py       27 unittests
  vectors/j_golden.json                the cross-layer conformance vectors
  transcripts/k/                       the K ladder: logs + claims-status.csv
                                       + claim-classification.csv + score.txt
  transcripts/llvm/                    T0-T15 (14 executed + 5 kparse rejects)
  transcripts/attacks/run_j_attacks.txt
  transcripts/regression/regression.txt
  audit/SECURITY-CLOSURE-AUDIT.md
  report/SRW3-Phase1J-Security-Closure-Report.{md,pdf}
  provenance/MANIFEST.txt + provenance-hashes.txt
```
