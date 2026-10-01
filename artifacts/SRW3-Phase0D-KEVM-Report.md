# SRW3 Phase 0-D — KEVM External Agent Handoff: Research Report

**Phase:** 0-D — Executable Semantics + KEVM Binding
**Status:** Abstract-layer proofs COMPLETE (Claims 1, 2, 3, 4a, 4b PROVED). KEVM binding OPERATIONAL. Baseline v1.0 INGESTED VERBATIM and VERIFIED — 15/15 via canonical Makefile, run before any KEVM-side change (§C). **Reconciliation & audit program COMPLETE (§F–§L). Round-2 theorem-boundary audit COMPLETE (§Q). Theorem-closure pass COMPLETE (§R): the full lineage-length safety theorem `InitialSafe(P,σ₀) ∧ SecurityClosed(P) → ∀n. Safe(P,σₙ)` is now MECHANIZED over the ghost-instrumented semantics (GH-T2/GH-M reach #Top via [circularity]; GhostMatches base, accept/reject preservation, certificate-to-real-state soundness, and gate agreement all machine-checked; encoding faithfulness mechanically certified byte-identical, 507/507 lines; non-vacuity negative control correctly fails) — §R.1; the tier-3 universal reconciliation is STATEMENT FORMALIZED; NOT YET MECHANIZED with three verbatim prover boundaries (§R.2); the four-level enforcement taxonomy A–D is adopted with per-level trust assumptions and the theorem bound to its level (§R.3); the prior-art conjunction hypothesis survived the freeze check and is frozen (§R.4); full regression matrix v3 confirms zero change (§R.6).**
**Deliverables:** `k/srw3.k` (abstract semantics + claims), `k/kevm/srw3-kevm.k` (KEVM binding), `k/compat/srw3-bridge.k` (reconciliation), `proofs/safe_form_audit.k` (4a/4b premise-form audit), `proofs/generalized_bridge.k` (wfCoverage + state-generalized agreement), `proofs/induction_ghost.k` (ghost-state ∀n theorem — theorem-closure pass), `proofs/tier3_universal.k` (tier-3 universal statement), `proofs/defects/phantom_reject.k` (defect reconstruction), `proofs/induction_full.k` + `proofs/induction_record.k` (superseded induction attempts, kept as the recorded blocker evidence), 13 abstract demos + 4 EVM demos, audit transcripts under `transcripts/audit/`, this report (MD + PDF).

---

## A. Environment

| Component | Version | Source / Method |
|---|---|---|
| K Framework | **v7.1.337** (build Jun 18 2026) | GitHub release `.deb` (ubuntu-jammy build), extracted with `dpkg -x` (no root) |
| KEVM | **v1.0.921** | Source (`evm-semantics` tag; no binary release assets published); K pinned by `deps/k_release` = `7.1.337` (exact match) |
| blockchain-k-plugin | **207ae5121e5178a09742ed746f2d15e34b1750cc** | Cloned at the submodule SHA pinned by KEVM v1.0.921; K sources (`plugin/krypto.md`) restored into the kproj include path after the container restore; C library (libkrypto) NOT built — no keccak-dependent opcodes are exercised (§O) |
| Z3 | 4.13.3 | Debian trixie package, extracted without root |
| flex / libfl2 | 2.6.4 | Debian packages, extracted (K scanner generation) |
| LLVM runtime | 15.0.6 | Debian bookworm pool packages (needed by `kore-expand-macros`) |
| libsecp256k1 | 0.5.0 | Extracted; required by `kore-exec` |
| Java / Python | OpenJDK 21.0.12 / 3.12.14 | Host, preinstalled |
| OS | Debian trixie container, unprivileged user `z`, 2 cores, 4.1 GiB RAM | |

All installation steps are recorded in `tools/env.sh`. kup/Nix are unusable (no `/nix` write); the release-`.deb` route is functionally equivalent and fully pinned. The KEVM LLVM backend link step requires building `libkrypto.a` (cryptopp/libff submodules, multi-GB) — skipped; per the audit directive the LLVM retarget is explicitly deferred (§P).

**Audit-period environment note.** The blockchain-k-plugin K sources were lost in a container restore and were re-fetched from GitHub at the pinned SHA and restored to `kproj/plugin/` before any audit work was run. All kompilations in this audit used the restored, pinned sources; the pre-existing compiled definitions (`hs-out`, `kevm-hs-out`) were reused where sources were unchanged.

---

## B. Commands

```bash
source /home/z/my-project/tools/env.sh          # K v7.1.337, z3 4.13.3, LLVM-15 libs, flex

# abstract SRW3 layer
kompile srw3.k --backend haskell --main-module SRW3-GATE --syntax-module SRW3-GATE -o hs-out
krun  demos/demo1_min_reject.srw3 -d hs-out            # + 12 more (run_demos.sh)
kprove srw3.k -d hs-out --spec-module SRW3-CLAIMS      # Claims 1,2,3,4a,4b -> #Top
kprove proofs/negative_control.k -d hs-out -I .. -I . --spec-module SRW3-NEGCONTROL   # fails as designed

# reconciliation bridge (Priority 1)
kompile k/compat/srw3-bridge.k --backend haskell --main-module SRW3-BRIDGE \
  --syntax-module SRW3-BRIDGE -I k -o k/compat/bridge-out
kprove k/compat/srw3-bridge.k -d k/compat/bridge-out -I k --spec-module SRW3-BRIDGE-CLAIMS

# defect reconstruction (Priority 3)
kompile proofs/defects/phantom_reject.k --backend haskell --main-module SRW3-PHANTOM \
  --syntax-module SRW3-PHANTOM -I k -o proofs/defects/defects-out
krun  /tmp/honest.srw3 -d proofs/defects/defects-search-out --search   # 2 outcomes (defect)
krun  /tmp/honest.srw3 -d k/hs-search-out --search                     # 1 outcome (corrected)

# induction attempts (Priority 2)
kprove proofs/induction_full.k   -d proofs/inductB-out -I k --spec-module SRW3-INDUCT-FULL
kprove proofs/induction_record.k -d proofs/inductC-out -I k --spec-module SRW3-RECORD-CLAIMS-PROVED --claims record-4a
kprove proofs/induction_record.k -d proofs/inductC-out -I k --spec-module SRW3-RECORD-CLAIM-ATTEMPT

# KEVM binding (haskell backend; config vars required by evm.md)
KPROJ=/home/z/my-project/tools/evm-semantics-1.0.921/kevm-pyk/src/kevm_pyk/kproj
krun k/kevm/demos/evm_negative_stale.srw3evm -d k/kevm/kevm-hs-out \
  -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false -cCHAINID=1
```

All commands are wrapped by the reproducible audit scripts in `/home/z/my-project/scripts/` (`audit_bridge.sh`, `audit_defect.sh`, `audit_defect_search.sh`, `audit_induction.sh`, `audit_boundary.sh`, `audit_evm_trace.sh`, `audit_matrix.sh`); every transcript cited below is verbatim command output under `srw3-kevm/transcripts/audit/`.

---

## C. Existing scaffold result — baseline v1.0 **VERIFIED — 15/15 tests pass**

The authoritative Phase 0-D baseline (`SRW3_Phase_0D_Implementation_v1.0.zip`, sha256
`2db8669f8aeddc5bceff762bfd4a4901ddc9cb3f3e6387364e0abe2ac8e62955`) was ingested verbatim — never reconstructed or modified. The original is
preserved twice: a read-only pristine copy (`srw3-baseline/`) and a self-contained
git work repo (`srw3-work/`) whose `main` branch initial commit is byte-identical
to the zip contents; all KEVM-side work happens on branch `kevm-changes`, so every
subsequent change diffs against the authoritative baseline via
`cd srw3-work && git diff main`.

The baseline's own test suite was executed FIRST, before any KEVM-side work, using
its canonical Makefile invocation (`make test` → `python3 -m unittest discover
-s tests -v`), with the verbatim transcript below. The K scaffold was compiled
UNMODIFIED with its canonical Makefile flags; findings are recorded verbatim
(including any toolchain compatibility issues — fixes, if needed, are applied only
on the `kevm-changes` branch with a recorded diff, never in the pristine copy).

```text
# Section C — Baseline ingest evidence (generated 2026-09-28T06:19:34+00:00)
## Provenance
- zip: `/home/z/my-project/upload/SRW3_Phase_0D_Implementation_v1.0.zip`
- size: 18984 bytes
- sha256: `2db8669f8aeddc5bceff762bfd4a4901ddc9cb3f3e6387364e0abe2ac8e62955`
- integrity: OK (25 entries tested OK)

- note: single top-level dir 'SRW3_Phase_0D_Implementation_v1.0' flattened to baseline root
## Content inventory (verbatim zip listing)
./Makefile
./PHASE_0D_STATUS.md
./README.md
./demo.py
./k/claims/srw3-closed-composition.k
./k/countermodels/README.md
./k/countermodels/cm01-local-vs-global.srw3
./k/srw3.k
./pyproject.toml
./srw3/__init__.py
./srw3/closure.py
./srw3/examples.py
./srw3/model.py
./srw3/proof.py
./tests/test_closure.py
./tests/test_core.py
./tests/test_countermodels.py
./tests/test_proof.py

## Baseline Python test suite (run FIRST, before any KEVM change)
--- canonical: make test (from work repo root)
python3 -m unittest discover -s tests -v
test_closed_counterexample_has_complete_interaction_contract (test_closure.ClosureTests.test_closed_counterexample_has_complete_interaction_contract) ... ok
test_hidden_dependency_breaks_effect_completeness (test_closure.ClosureTests.test_hidden_dependency_breaks_effect_completeness) ... ok
test_local_only_composition_is_not_interaction_complete_when_edge_required (test_closure.ClosureTests.test_local_only_composition_is_not_interaction_complete_when_edge_required) ... ok
test_hidden_dependency_is_detectable_as_effect_underapproximation (test_core.Phase0DTests.test_hidden_dependency_is_detectable_as_effect_underapproximation) ... ok
test_local_invariants_can_miss_global_interaction_invariant (test_core.Phase0DTests.test_local_invariants_can_miss_global_interaction_invariant) ... ok
test_oracle_lending_liquidator_interaction_contract_is_represented (test_core.Phase0DTests.test_oracle_lending_liquidator_interaction_contract_is_represented) ... ok
test_refinement_is_monotone_in_finite_fragment (test_core.Phase0DTests.test_refinement_is_monotone_in_finite_fragment) ... ok
test_authority_aggregation_pattern (test_countermodels.CountermodelTests.test_authority_aggregation_pattern) ... ok
test_global_countermodel (test_countermodels.CountermodelTests.test_global_countermodel) ... ok
test_resource_aliasing_pattern (test_countermodels.CountermodelTests.test_resource_aliasing_pattern) ... ok
test_three_way_interaction_pattern (test_countermodels.CountermodelTests.test_three_way_interaction_pattern) ... ok
test_closed_composition_gate_rejects_bad_noop (test_proof.ProofTests.test_closed_composition_gate_rejects_bad_noop) ... ok
test_interaction_aware_model_proves_finite_safety (test_proof.ProofTests.test_interaction_aware_model_proves_finite_safety) ... ok
test_local_only_model_cannot_claim_closed_composition (test_proof.ProofTests.test_local_only_model_cannot_claim_closed_composition) ... ok
test_oracle_lending_liquidator_finite_safe_step (test_proof.ProofTests.test_oracle_lending_liquidator_finite_safe_step) ... ok

----------------------------------------------------------------------
Ran 15 tests in 0.008s

OK
--- make test exit code: 0

### Verdict: PASSED=15 FAILED=0 (expected 15/15)
BASELINE 15/15 CONFIRMED — authoritative baseline accepted; KEVM changes may proceed on top of it.

## K scaffold compile (UNMODIFIED, canonical flags): k/srw3.k
[Error] Compiler: Could not find module: SET-SYNTAX
        Source(/home/z/my-project/srw3-work/k/srw3.k)
        Location(6,3,6,21)
        6 |       imports SET-SYNTAX
          .       ^~~~~~~~~~~~~~~~~~
- kompile exit: 113

## K overlay compile (UNMODIFIED, with -I k): k/claims/srw3-closed-composition.k
[Error] Compiler: Could not find module: SRW3-SEMANTICS
        Source(/home/z/my-project/srw3-work/k/claims/srw3-closed-composition.k)
        Location(2,3,2,25)
        2 |       imports SRW3-SEMANTICS
          .       ^~~~~~~~~~~~~~~~~~~~~~
- kompile exit: 113

## Recorded compatibility patch (branch kevm-changes ONLY; pristine untouched)
- patch applied + committed on kevm-changes
- recorded diff vs pristine main:
diff --git a/k/claims/srw3-closed-composition.k b/k/claims/srw3-closed-composition.k
index 8bf0c98..8c647ee 100644
--- a/k/claims/srw3-closed-composition.k
+++ b/k/claims/srw3-closed-composition.k
@@ -1,3 +1,6 @@
+// Compatibility (recorded): added requires so the claims overlay can resolve
+// SRW3-SEMANTICS from k/srw3.k; kompile with -I k. No semantic content changed.
+requires "srw3.k"
 module SRW3-CLOSED-COMPOSITION
   imports SRW3-SEMANTICS
 
diff --git a/k/srw3.k b/k/srw3.k
index c035499..383b596 100644
--- a/k/srw3.k
+++ b/k/srw3.k
@@ -2,9 +2,9 @@ module SRW3-SYNTAX
   imports INT-SYNTAX
   imports STRING-SYNTAX
   imports BOOL-SYNTAX
-  imports MAP-SYNTAX
-  imports SET-SYNTAX
-  imports LIST-SYNTAX
+  imports MAP
+  imports SET
+  imports LIST
 
   syntax AppId
   syntax RootId

## K scaffold compile AFTER recorded patch
[Warning] Compiler: Variable 'L' defined but not used. Prefix variable name
with underscore if this is intentional.
        Source(/home/z/my-project/srw3-work/k/srw3.k)
        Location(79,20,79,21)
        79 |             <lineage> L </lineage>
           .                       ^
- kompile k/srw3.k exit: 0
        Source(/home/z/my-project/srw3-work/k/srw3.k)
        Location(79,20,79,21)
        79 |             <lineage> L </lineage>
           .                       ^
- kompile claims exit: 0

## Makefile k-tests note (recorded)
Makefile k-tests references k/tests/cm01-local-vs-global.srw3; the zip ships k/countermodels/cm01-local-vs-global.srw3, which is COMMENT-ONLY documentation of the intended countermodel (executable countermodels live in the Python suite, e.g. test_local_invariants_can_miss_global_interaction_invariant). krun therefore not applicable to this artifact as shipped.

## Baseline suite re-run on patched branch (sanity)
----------------------------------------------------------------------
Ran 15 tests in 0.008s

OK
- exit: 0
```


---

## D. KEVM binding

### D.1 Files

| File | Purpose |
|---|---|
| `k/srw3.k` | Abstract SRW3 semantics (6 modules: SYNTAX, STATE, INVAR, CLOSURE, GATE, CLAIMS) — commitment gate, obligation evaluation, hypergraph closure, lineage, the five formalized claims |
| `k/kevm/srw3-kevm.k` | **KEVM binding**: SRW3 commands as `EthereumSimulation` extensions over `module EVM` (evm.md) + the real assembler (`asm.md`); mini-driver replicating `loadCallState`/`start`/`flush` mechanics via KEVM's own `#loadProgram`/`#initVM`/`#execute` items |
| `k/compat/srw3-bridge.k` | **Reconciliation bridge** (§F): signature-faithful `gateOk`/`rootOk` instantiations + gate-decision extraction + 9 ground agreement/disagreement claims |
| `proofs/defects/phantom_reject.k` | **Defect reconstruction** (§G): the phantom-reject rule, demonstration claims, corrected-side controls |
| `proofs/induction_full.k`, `proofs/induction_record.k` | **Induction attempts** (§F.4/full-theorem): Map-encoded circularity attempt, record-encoded attempts + proved step claims |
| `k/run_demos.sh`, `k/demos/*.srw3` | 13 abstract-layer demos (one command each, self-verifying) |
| `k/kevm/demos/evm_*.srw3evm` | 4 EVM-layer demos (positive, stale-price negative, single-segment gate, setup-only) |
| `proofs/negative_control.k` | Deliberately false claim — prover sanity check |
| `patches/baseline-k-compat.patch` | Recorded compatibility patch for the baseline K scaffold (branch `kevm-changes` only) |

### D.2 Semantic design (no hidden axioms)

- **Commitment boundary.** `<committed>` and `<prospective>` are distinct cells. `begin` copies committed → prospective (σ → σ̂ over committed σ). Apart from the state-initialization command `init` (which establishes σ₀ before any transition executes), the **only rule in the entire semantics that updates `<committed>`** is the gate's ACCEPT rule — verified by rule census (`transcripts/audit/boundary_census.txt`, item [3]). REJECT discards the prospective state; the committed cell is untouched.
- **Obligations are equations, not axioms.** Every invariant is an evaluated function `evalInv(InvId, State)`. There is no `gateOk(_) => true` anywhere. Gate acceptance = `allHold(applicable(registry, declaredFootprint), prospective) ∧ member(actor, authorities)`.
- **Hypergraph (§17).** The registry is a set of `edge(InvId, AppSet)` hyperedges (plus `bareEdge(AppSet)` — a known dependency with **no** contract, used for CM6). `Affected(τ) = applicable(registry, Foot(τ))` is computed per handoff §19.
- **Effect completeness (§12, §19).** Transitions record a **true footprint** (`<footprint-t>`) and a **declared footprint** (`<footprint-d>`). Under policy `enforce`, `wfCheck` refuses to gate any transition with `¬(Γ* ⊆ Γ̂)` (result `blocked-effect-incomplete`); under policy `trust` the gate reasons over the declared footprint alone — deliberately unsound, used to mechanize §13.
- **Security closure (§12).** `securityClosed(R, policy)` = `interactionComplete(R, universe) ∧ contractComplete(R)` ∧ EffectComplete(= policy `enforce`) ∧ LineageComplete/GateComplete (**structural** — the single guarded commit path; proved as Claims 2/3, not assumed). The obligation **universe is a parameter** (`securityClosedUniv`), so the minimal model is closed over *its* universe without vacuous premises (§E).
- **Lineage (§14).** Λ = ⟨ParentCommitment, TransitionId, AuthorizationEvidence(auth(actor)), PolicyVersion, ChildCommitment⟩, appended **only** by the commit path, parent = current chain head, child = `commit(next)`. InputEvidence/ProofEvidence are threaded symbolically at this layer and realized as concrete prospective storage values in the KEVM layer (documented abstraction A3; cryptographic status audited in §J).
- **KEVM layer.** Real SSTORE/SLOAD/CALL/RETURN/MSTORE/MLOAD/PUSH/STOP execute through genuine KEVM rules; the SRW3 gate evaluates IOL/ILD/IOLD **over the real `<accounts>` storage**; commit re-snapshots; **reject restores account storages from the snapshot** — the commitment boundary expressed on EVM state itself (audited in §H–§I).

### D.3 "Important semantic changes" — deviations forced by the toolchain

1. No `driver.md`/`optimizations.md` in the binding's kompile scope (kompile budget); the binding reproduces the needed driver mechanics minimally. *Consequence:* none for the demos; recorded for future re-integration.
2. KEVM configuration used **unmodified** (the SRW3 state is threaded through `<k>` as `#w3State(...)` carriers) — nested-cell extension of the `<kevm>` root is blocked by cell-map unit regeneration (`too many top cells` / `Multiple <k>` / `.AccountCellMap is not unique`). Documented as a K-v7.1.337 extension-mechanics finding.
3. Contracts placed at 0x1001–0x1003 (precompiles occupy 1..0x11 in CANCUN — an instructive collision caught during bring-up).

---

## E. Proof results

Environment for proofs: K v7.1.337 Haskell backend + Z3 4.13.3. Every claim below was re-verified in the post-reconciliation matrix run (`transcripts/audit/full_matrix.txt`, item [3]) with **no vacuity warnings** (`WarnTrivialClaim` absent), and the prover is validated by a **negative control** (a deliberately false claim that kprove correctly fails, exit 113).

| # | Claim | Status | Evidence |
|---|---|---|---|
| 1 | **Local preservation** — in a single-app universe (registry = {IA}), a locally valid transition that the gate accepts produces a committed state satisfying the declared local invariant, with lineage appended | **PROVED** | `SRW3-CLAIMS` claim 1 |
| 2 | **Gate coverage** — under the complete registry, a transition whose prospective state violates an applicable invariant (x_A + x_B > 10) cannot produce a committed state: committed cell unchanged, prospective discarded, result = reject | **PROVED** | claim 2 |
| 3 | **Lineage append** — a valid accepted transition yields child commitment `commit(N)`, lineage record `lin(parent=CH, tid=N, auth(actor), polver, child=commit(N))`, head := commit(N), next := N+1 | **PROVED** | claim 3 |
| 4a | **Admissible one-step transition preserves safety** — under Safe(X,Y,X+Y) (the evaluated predecessor-state safety premise, verified as such in §Q.1) ∧ SecurityClosedUniv(completeRegistry, enforce, minInvs), a transition the gate accepts commits a state satisfying Safe(IA ∧ IB ∧ IAB) | **PROVED** | claim 4a; premise-form audit `proofs/safe_form_audit.k` (§Q.1) |
| 4b | **Inadmissible one-step transition cannot commit** — under the same premises, a transition violating an applicable obligation leaves the committed state unchanged with result reject (σ_{n+1} = σ_n) | **PROVED** | claim 4b; premise-form audit `proofs/safe_form_audit.k` (§Q.1) |
| — | **Full theorem (target):** `Reach_committed(A) ⊆ Safe(P)` — i.e. `∀n. Safe(P, σ_n)` given `InitialSafe_P` ∧ `SecurityClosed(P)`, by induction over committed lineage length with 4a ∧ 4b as the step and the structural uniqueness of the commit path | **Hand proof valid; steps machine-checked; the induction itself NOT YET MECHANIZED** — three precise prover-level blockers captured verbatim (§F.4) | `proofs/induction_full.k`, `proofs/induction_record.k`, `transcripts/audit/induction_attempt.txt` |
| NC | **Negative control** — the false claim "a transition with x_A + x_B > 10 commits" | **correctly FAILS** (WarnStuckClaimState; the prover is checking, not rubber-stamping) | `proofs/negative_control.k` |

**Claim 4 is deliberately NOT overstated.** What is PROVED BY K is exactly 4a ∧ 4b: the induction *step*, split by gate outcome, over the minimal model. The full theorem requires iterating that step along the committed lineage — see §F.4 for the hand induction, the machine-checked counterparts, and the verbatim record of where and why the K prover cannot currently close the packaging.

**Assumptions (explicit, per §23; none hidden):**
- **A1.** `trueDeps(·)` is a manual read-set derivation from the `evalInv` equations (auditable; the KEVM analogue derives from real storage accesses).
- **A2.** Commitments are opaque `commit(Int)` terms; no hash function is modeled at this layer (cryptographic status: §J).
- **A3.** InputEvidence/ProofEvidence of Λ are symbolic; authorization evidence = authority-closure membership (checked, with a `reject-auth` outcome).
- **A4.** Claim-level closure premises are **evaluated against the concrete registry term** in each claim — non-vacuous: kore evaluates `securityClosedUniv(...)` to true/false; for the negative registry it evaluates FALSE, so no vacuous proof of the full theorem over the negative model is possible (and none is claimed; the negative model is demonstrated by concrete counterexample, §N/CM1).

**Demo verification matrix** (all concrete, all as-expected; re-run verbatim in `transcripts/audit/full_matrix.txt`):

| Demo | Setup | Expected | Observed |
|---|---|---|---|
| D1 | complete registry; (7,3) → write B=7 | reject; committed (7,3); no lineage | ✓ |
| D2 | **negative registry (IAB missing)** — CM1 | accept; committed (7,7); lineage rec 0 | ✓ |
| D2b | D2 + second in-bounds step | commit (7,2); lineage chain 0→1 | ✓ |
| D3 | **hidden write to appC outside declared foot + trust** — CM7 | commit of violation (appC=11) | ✓ |
| D3b | hidden write to appA (co-edge with appB) + trust | reject via IAB (defense-in-depth) | ✓ |
| D4 | D3 under `enforce` | `blocked-effect-incomplete`, committed unchanged | ✓ |
| D5 | no actor (unauthorized) | `reject-auth`, committed unchanged | ✓ |
| D6 | honest chain: lending CALLs oracle; liq CALLs lending | 2 commits; lineage chain | ✓ |
| D7 | undeclared cross-read (rdH) under `enforce` | `blocked-effect-incomplete` (Γ* ⊄ Γ̂) | ✓ |
| D7b | declared read, stale price write 90 | reject via IOL | ✓ |
| D8/D9 | settlement at price ≠ lending price, wrong lineage | reject via IOLD (three-way) | ✓ |
| D10 | **pairwise-only registry, three-way edge missing** — CM6 | accept; violation committed | ✓ |

**EVM-layer verification** (real KEVM execution; stage-by-stage traces in §I; transcripts `evm_positive_final.txt`, `evm_negative_stale_final.txt`, `audit/evm_trace_stale.txt`):

| Demo | Expected | Observed |
|---|---|---|
| `evm_positive` | oracle SSTOREs price=100/auth=1; lending **CALLs oracle** (real CALL/RETURN) and SSTOREs the returned price + debt=5; liq **CALLs lending**, stores transfer=4 and priceLineage=MLOAD(...)=100; IOL/ILD/IOLD hold on real storage | **COMMIT**: snapshot = {oracle:{0:100,1:1}, lending:{0:100,1:5}, liq:{0:4,1:100}}; lineage `w3lin(parent=-1, tid=0, price=100)` |
| `evm_negative_stale` | lending SSTOREs 90 instead of the CALL-returned 100 | **REJECT + restore**: all three storages restored to pre-bundle snapshot (empty); no lineage; head = -1 |
| `evm_min2` | single oracle segment + gate (bundle incomplete → IOL fails) | **REJECT + restore** — demonstrates mid-bundle gating granularity |

---

## F. Reconciliation of the original scaffold (Priority 1)

The original Phase 0-D scaffold (`srw3-work/k/srw3.k`, the authoritative baseline) declares two placeholder predicates **with no defining equations**:

```k
syntax Bool ::= gateOk(Map, Map, List, Set, Set, Map) [function]
syntax Bool ::= rootOk(Set, String, String)           [function]
```

and a transition skeleton whose two `tau` rules are guarded by `gateOk(C, S, TR, R, H, M)` / `notBool gateOk(...)`. The implemented evaluated-obligation semantics (`srw3-kevm/k/srw3.k`) did **not** delete or rename these placeholders — it **realizes** them. This section establishes precisely how, and whether the result is a refinement or a replacement.

### F.1 The original scaffold is a specification, not an implementation

Mechanical evidence (`transcripts/audit/original_scaffold_probe.txt`):

1. **The scaffold admits no programs.** `Tau ::= tau(AppId, TransitionId)` exists, but `AppId` and `TransitionId` have **no productions** — no term of sort Tau can even be written. There are no edge/event constructors for `HyperGraph`, no contract schema for `ContractRegistry`.
2. **Even with an inhabitable tau, no transition executes.** A probe module supplying the missing tokens still ends with `tau(appA, t1) ~> .K` unconsumed: `gateOk` has no equations, so the accept rule's `requires gateOk(...)` is a stuck function application and **neither** tau rule can fire.
3. **The skeleton has no commitment semantics.** Its rules keep `<committed> C => C` and `<shadow> S => S` — nothing ever copies shadow into committed, and there is no reject/restore path; the `<gate>` boolean flag is the only observable.
4. **`rootOk` is dead.** It is declared but referenced by no rule.
5. **The signature is underspecified for its own purpose.** `gateOk`'s six arguments do not include the actor/authority and do not include the transition's footprint — so the accept condition could not express authorization (that is what `rootOk` was presumably for, but it is never called), nor compute `Affected(τ)` (which needs `Foot(τ)`). Any realization must add plumbing the original signature does not have.

**Conclusion:** the original predicates were underspecified — a specification sketch. The implemented semantics is not a replacement model but a **realization** of that sketch, with the missing structure added explicitly and the realization itself mechanically checked (F.3).

### F.2 The component mapping

| Original predicate/component | ↓ | New semantic predicate/rules | ↓ | Meaning |
|---|---|---|---|---|
| `C : Map` (committed cell) | ↓ | `<committed> : Map StKey→Int` | ↓ | committed state σ (unchanged role) |
| `S : Map` (shadow cell) | ↓ | `<prospective> : Map StKey→Int` | ↓ | prospective state σ̂ — renamed from "shadow" because `begin` (σ → σ̂), gate evaluation **on σ̂**, and commit (σ := σ̂) give it an active role the skeleton never specified |
| `TR : List` (event trace) | ↓ | `<lineage> : Map tid→Λ` + `<footprint-t>/<footprint-d>` | ↓ | the event list is subsumed by Λ lineage records (one per accepted transition, with authorization evidence and commitments); footprints are **added** because Affected(τ) needs Foot(τ), which no `gateOk` argument supplies |
| `R : Set` (roots) + `rootOk(R, s₁, s₂)` | ↓ | `<authorities> : Set` + `<head>` root-anchoring; accept requires `member(Ac, As)`; lineage `parent = head` | ↓ | root-anchored authorization: the actor must be inside the root-derived authority closure (checked, `reject-auth` outcome), and every commitment chains to the root via the head link |
| `H : Set` (hypergraph) | ↓ | `<registry> : Set` of `edge(InvId, AppSet)` (+ `bareEdge`) | ↓ | same shape (a set of hyperedges), now with obligation identity and app sets expressed |
| `M : Map` (contracts) | ↓ | fused into the edges: `edge(InvId, AppSet)` | ↓ | the original separated contracts from the hypergraph with no link between them; the realization fuses them — a dependency edge **carries** its contract |
| `gateOk(C,S,TR,R,H,M)` | ↓ | `allHold(applicable(REG, FD), P)` — the obligation conjunct of the ACCEPT rule's `requires` | ↓ | "every obligation applicable to this transition holds on the prospective state" |
| skeleton accept/reject (`<gate> _ => true/false`) | ↓ | gate ACCEPT / REJECT / REJECT-auth rules | ↓ | accept commits σ̂ and appends Λ; reject discards σ̂ (and restore, at the KEVM layer) |

### F.3 Signature-faithful instantiations, checked by evaluation

`k/compat/srw3-bridge.k` defines both placeholders **with the exact original signatures** over the implemented semantics:

```k
rule gateOk(_C:Map, S:Map, _TR:List, _R:Set, H:Set, _M:Map)
  => allHold(universeObls(H), S)          // ALL obligations carried by the hypergraph
rule rootOk(R:Set, ActorName:String, _Tid:String) => memberName(ActorName, R)
```

`gateOk_faithful` is the strongest accept condition expressible **within the original six-argument signature**: since no footprint argument exists, the only signature-faithful reading checks *every* obligation in the hypergraph on the prospective state. The implemented gate is more permissive: it checks only the **applicable** obligations (`applicable(REG, FD)`). The refinement statement is therefore precise and was verified claim-by-claim (`transcripts/audit/bridge_reconciliation.txt`, kprove exit 0, `#Top`; the claims are pure ground evaluations, so `WarnTrivialClaim` there means *checked by evaluation*, the strongest form for ground decisions — a disagreement would have evaluated to `false` and failed):

| Claim | State (from the demo suite) | Faithful `gateOk ∧ rootOk` | Implemented `gateAccept` | Verdict |
|---|---|---|---|---|
| G1 (D1) | complete registry, (7,3)→(7,7) violating IAB | false | false | **AGREE** (both reject) |
| G2 (D6 step 1) | chain registry, honest lending commit | true | true | **AGREE** (both accept) |
| G3 (D7b) | chain registry, stale price 90 | false | false | **AGREE** (both reject) |
| G4 (D8) | settlement at 90 (IOLD) | false | false | **AGREE** (both reject) |
| G5 (D2/CM1) | negative registry, (7,3)→(7,7) | true | true | **AGREE** (both accept — the CM1 defect is in the *registry*, not the gate) |
| G6 (D10/CM6) | pairwise-only, three-way hole | true | true | **AGREE** (both accept — same lesson) |
| G7 | complete registry, honest (7,2) | true | true | **AGREE** |
| **X1 (D3, trust)** | hidden write appC:=11, declared foot {appB} | **false** | **true** | **DISAGREE** — claim `notBool(≈)` PROVED: the divergence is pinned to effect incompleteness (CM7) |
| X2 (D4, enforce) | same state, true effects declared | false | false | **AGREE restored** — with the footprint covering the true effects, the implemented gate rejects exactly what the faithful instantiation rejects |

**Reconciliation conclusion (terminology fixed by the Round-2 audit, §Q.2).** On every state whose declared footprint covers the true effects (or whose hidden effects' obligations happen to hold — D3b), the implemented gate decides **exactly** as the signature-faithful instantiation of the original placeholders; the only reachable divergence class is effect incompleteness, which `wfCheck` (policy `enforce`) blocks from ever reaching the gate (D4/D7). The implemented semantics is therefore a **signature-faithful realization with mechanically checked ground agreement over the covered states** — **not** a refinement/simulation theorem: finite ground agreement (G1–G7, X1, X2) is the weakest tier of the three-tier result structure (§Q.2), and the fully quantified agreement statement is stated but NOT YET MECHANIZED. Earlier drafts of this report called this a "refinement"; that wording is superseded.

### F.4 The full lineage-length safety theorem: hand proof, machine-checked steps, precise blocker

The theorem targeted by the handoff (§20/§21) is:

```
InitialSafe_P(σ0) ∧ SecurityClosed(P)
---------------------------------------
∀n. Safe(P, σ_n)      hence   Reach_committed(A) ⊆ Safe(P)
```

**Hand induction (meta-theorem).**
- **Base.** `InitialSafe_P`: σ₀ is initialized to a state satisfying Safe(IA ∧ IB ∧ IAB) — in the minimal model, x_A + x_B ≤ 10 with each ≤ 10 (evaluated, not assumed; A4).
- **Step.** Assume `Safe(P, σ_n)`. Any one-step transition σ_n → σ̂ either (i) is admissible and the gate accepts: the accept rule's requires is exactly `allHold(applicable(REG, FD), σ̂)` ∧ authority; under the complete registry for the universe, applicable = {IB, IAB} for a B-footprint write, so IAB holds on σ̂ by evaluation, IA/IB hold because commit sets σ_{n+1} := σ̂ and the untouched component x_A is carried from σ_n by the induction hypothesis — hence `Safe(P, σ_{n+1})` (this is **Claim 4a, PROVED**); or (ii) is inadmissible and cannot commit: the REJECT rule leaves committed unchanged and discards σ̂, so `Safe(P, σ_{n+1}) = Safe(P, σ_n)` (this is **Claim 4b, PROVED**); and by Claim 2 + rule census there is **no third way** for `<committed>` to change apart from initialization.
- **Conclusion.** By induction on the committed lineage length n (each commit appends exactly one record — Claim 3), `∀n. Safe(P, σ_n)`, hence `Reach_committed(A) ⊆ Safe(P)`. ∎

**Mechanization status — what was attempted and exactly where it blocks** (`proofs/induction_full.k`, `proofs/induction_record.k`, `transcripts/audit/induction_attempt.txt`):

| Attempt | Encoding | Result |
|---|---|---|
| [B] full theorem as a `[circularity]` claim over the real Map semantics, committed state fully symbolic, safety observer `chkS` executable only on safe states | Map | **STUCK** — verbatim residual captured: the program stays `PG ~> .K` with `safeMin(M)` unevaluable (recursive `lookupInt` over a constructor-free symbolic Map does not reduce); rule applicability is decided by *evaluation* of requires, not by entailment against the reachability-logic path constraints, so even the observer rule — whose requires is exactly the claim's own premise — cannot fire |
| [C-a]/[C-b] 4a/4b-shape step claims on a **record encoding** of the minimal model's *reachable* state space (key sets are transition-invariant, so every reachable committed state is faithfully a record (x_A, x_B)) | record | **PROVED** (`record-4a`, `record-4b` → `#Top`) — the induction step is machine-checked in a second, fully symbolic-value encoding |
| [C-attempt-1] one cycle + `chk` observer, termination form | record | **STUCK** — verbatim residual `#Not(?YB #Equals W ∧ …)`: kore's destination handling renames the claim's destination variable and loses the linkage to the rule-produced value, even though the same destination shape **without** the observer closes with `#Top` (isolation experiment, same transcript) |
| [C-attempt-2] full theorem as `[circularity]` over the record encoding | record | **STUCK** — same residual class at the first circular reuse |

**Blocker statement (precise).** The induction over lineage length is not expressible "cleanly" in this prover for three stacked reasons, each captured verbatim: (i) with a symbolic Map state, recursive map lookups over update terms do not reduce, so state predicates cannot be evaluated; (ii) reachability-logic side conditions (where the induction hypothesis lives) cannot be consumed as rewrite hypotheses, so a circular claim cannot *use* its own premise when re-applying itself; (iii) kore's destination matching loses rule-produced value linkages under observer/continuation composition (the `?YB` residual), which blocks even the termination-form packaging whose logic is sound. Closing the packaging requires one of: ghost-state invariant maintenance (invariant-as-data, with its own soundness obligation), quantified frame reasoning beyond this backend's reachability+SMT fragment, or a prover upgrade. **The theorem is reported as hand-proved with machine-checked steps — not weakened, not claimed as mechanized.**

---

## G. The phantom-reject defect — a formal-methods lesson (Priority 3)

During bring-up, the phase recorded (worklog, Task 4, verbatim):

> "CRITICAL semantic bug found + fixed: reject rules referenced unbound variable P (cells used _P) -> kore treated P as free existential, making reject fire with a phantom state. Fixed to named P bound to actual prospective. All 13 demos re-validated."

This was treated by the audit as a first-class result, not an implementation footnote.

### G.1 The defect, reconstructed and executable

The verbatim defective rule text from the original bring-up session was not preserved in the surviving transcripts; `proofs/defects/phantom_reject.k` is a **faithful reconstruction** from the recorded description (its header documents this). The reconstruction kompiles under K v7.1.337 and reproduces the recorded behavior exactly.

1. **Original defective rule (reconstruction):**

```k
rule <k> gate => .K ... </k>
     <prospective> _P:Map => .Map </prospective>        // cell matched ANONYMOUSLY
     <registry> R2:Set </registry>
     <footprint-t> _FT2:Set => .Set </footprint-t>
     <footprint-d> FD2:Set => .Set </footprint-d>
     <result> _R2:String => "reject" </result>
  requires notBool allHold(applicable(R2, FD2), P)      // P is bound by NOTHING
```

2. **Corrected rule (as shipped in `SRW3-GATE`):**

```k
rule <k> gate => .K ... </k>
     <prospective> P:Map => .Map </prospective>         // P bound to the ACTUAL state
     <registry> R:Set </registry>
     ...
     <result> _R:String => "reject" </result>
  requires notBool allHold(applicable(R, FD), P)        // evaluated on the real σ̂
```

3. **Exact reason the original was unsound.** `kompile` accepts the defective rule with **only a warning** ("Variable 'P' defined but not used" — verified verbatim in the audit transcript). At rewriting time, `P` is not bound by the rule's pattern, so the backend quantifies it **existentially** in the rule condition: the rule is applicable whenever *some* state `P` violating the applicable obligations exists — which is always. Rejection is therefore *satisfiable with a phantom state*: the gate can "reject" on the basis of a state that is not the state being committed, and never evaluates the real prospective state at all.

### G.2 Demonstration (all verbatim in `transcripts/audit/phantom_defect.txt`, `phantom_defect_search.txt`)

| Demonstration | Corrected gate | Defective gate |
|---|---|---|
| `krun --search`, honest transition (7,3)→(7,2), complete registry | **1 outcome**: `commit`, committed (7,2) — deterministic | **2 outcomes**: `commit` AND a spurious `reject` with committed (7,3) — the phantom path is live on an *honest* transition |
| Claim 2 statement ("violation → reject, committed unchanged") | PROVED (reject decided by evaluating the real σ̂) | "PROVED" — but **vacuously**: the phantom fires regardless of the real state, so the claim no longer evidences gate coverage |
| Claim 4a (accept-side, verbatim copy) | PROVED | **FAILS** (WarnStuckClaimState on the phantom `reject` path) — every accept-side claim (1, 3, 4a) collapses |
| False claim "honest transition → reject" | **correctly FAILS** (no such path exists) | stuck (the false statement sits on a live execution path — see `krun --search` row) |

4. **Why this matters to the proof suite.** Under the defect, the true coverage claim (Claim 2) still "passes" — for the wrong reason — while the accept-side claims fail. A suite that kept only reject-side claims would have looked green while evidencing nothing: "the gate rejects bad transitions" had become satisfiable without the gate ever reading the state. This is exactly the class of error the §23 no-hidden-axiom discipline is designed to expose, and it was caught by the demo self-verification (honest transitions nondeterministically rejecting), not by the prover.

5. **Confirmation that all relevant claims depend on the corrected semantics.** Claims 1–4a/4b and the negative control all import `SRW3-GATE` (the corrected reject rules). Mechanically: re-running the accept-side suite against the defective definition fails (transcript item [4]); re-running the false claim against the corrected definition fails (item [5]); the corrected `krun --search` yields exactly one outcome. Every current proof result therefore stands or falls with the corrected rule — and stands.

6. **Discipline adopted.** (i) Never match a cell anonymously when a `requires` reasons about its content; (ii) treat unbound-variable *warnings* as errors in gate rules; (iii) keep the positive/negative claim pair plus self-verifying demos as permanent regression guards — the defect was visible as nondeterminism in honest demos before it was visible anywhere else.

---

## H. Commitment-boundary audit (Priority 4)

### H.1 What is inherited from KEVM vs introduced by SRW3

Census evidence (`transcripts/audit/boundary_census.txt`): every KEVM source file used by the binding (`evm.md`, `asm.md`, `evm-types.md`, `word.md`, `data.md`, `buf.md`, `gas.md`, `schedule.md`, `serialization.md`, `network.md`, `hashed-locations.md`, `state-utils.md`) is **byte-identical** to the pristine v1.0.921 tarball; the binding introduces **29 rules and 15 syntax declarations** (all `#w3*`/SRW3 driver names) against **778 + 157 inherited rules** (evm.md + asm.md). No EVM opcode-semantics rule is touched.

| Layer | Content | Status |
|---|---|---|
| **A. Actual KEVM/EVM execution** | SSTORE, SLOAD, CALL (+ args/returndata buffering), RETURN, MSTORE, MLOAD, PUSH, STOP under CANCUN; account/storage cells; the assembler | **Inherited, unmodified** (byte-identical sources) |
| **B. SRW3 prospective-state semantics** | `begin` (σ → σ̂); declared/true footprints; `wfCheck` (Γ* ⊆ Γ̂); `evalInv`/`applicable`/`allHold` obligation evaluation **over the prospective state**; at the KEVM layer, `#w3read`/`#w3IOL`/`#w3ILD`/`#w3IOLD` evaluate obligations over real `<accounts>` storage | **Introduced by SRW3** (29 rules), reading through KEVM's own cells without modifying them |
| **C. Modeled commitment/restore semantics** | Abstract layer: gate ACCEPT (the only transition-result rule that updates `<committed>`) / REJECT / REJECT-auth; lineage append; chain head. KEVM layer: `#w3Gate` (commit = re-snapshot storages + lineage append), `#w3RestoreAll`/`#w3RestoreOne` (reject = write storages back from the pre-bundle snapshot), `#w3Snap0` | **Introduced by SRW3 — a MODEL, not a mechanism**: nothing here modifies Ethereum; it demonstrates what a commitment-point mechanism must do |

### H.2 The semantic sequence, rule by rule

```
σ            --#w3Snap0-->            committed snapshot S (threaded in <k> as #w3State(S,…))
σ --KEVM-->  σ̂                        #w3Run(A, OPS) → #w3SetCtx → #loadProgram → #initVM → #execute:
                                      REAL opcodes mutate REAL <account>/<storage> cells (evm.md rules)
σ̂ --SRW3 Gate--> commit(σ̂)            #w3Gate accept: #w3IOL ∧ #w3ILD ∧ #w3IOLD over REAL storage
                                      ⇒ snapshot := post-storage, lineage w3lin(parent=h, tid=n, price) appended
σ̂ --SRW3 Gate--> reject + restore(σ)  #w3Gate reject ⇒ #w3RestoreAll(S) → #w3RestoreOne per account:
                                      <storage> := snapshot (prospective EVM effects discarded)
```

This sequence is **a modeled architecture, not an existing Ethereum protocol capability**. Stock Ethereum commits a transaction's effects atomically at block/state-commitment time with no obligation-evaluation hook between execution and commitment; no rule above exists outside this model.

### H.3 Where the gate can actually sit — the five-level enforcement taxonomy (revised, Round-2 §Q.4)

The Round-2 audit replaces the earlier four-level table with the full five-level taxonomy
and five attributes per level. The earlier statement "only an execution client or protocol
can provide pre-inclusion enforcement" is **superseded**: builder/sequencer-level
enforcement exists in practice (Phylax Credible Layer on Linea — §Q.3) and occupies its
own level with its own trust profile.

| Level | Concrete form | What it can prevent | Who must trust it | Bypassable? | Consensus-critical? | Covers independently developed contracts? |
|---|---|---|---|---|---|---|
| **A. Contract-level** | Obligation logic in a library each contract calls; commit = the app's own state writes, reject = `revert` (Scribble-style instrumentation sits here when woven into the contract) | Violations passing through the gated contract's own entry points | Whoever calls the contract trusts its (audited) code | **Yes** — direct SSTORE by other contracts, delegatecall, upgrades; nothing forces a counterparty to route through the gate | No | **No** — only if every counterparty voluntarily adopts the same gate composition |
| **B. Compiler/toolchain-level** | Emit declared footprint Γ̂ + obligation manifest as deploy-time metadata; instrument obligation checks at compile time | Under-declared effects and missing obligation code for anything compiled by that toolchain | Whoever trusts the compiler + verifies bytecode provenance on-chain | **Yes** — other languages/toolchains, hand-written EVM, bytecode without provenance | No | Partial — only within a homogeneous toolchain ecosystem with provenance checks |
| **C. Builder/sequencer pre-inclusion** | Assertions/policies evaluated during block building (Phylax Credible Layer model); violating txs dropped before inclusion | Any transaction violating registered assertions that is submitted through the enforcing builder/sequencer | Users of that builder/sequencer trust its operator + assertion correctness; **not** consensus | **Yes** — other builders, self-building validators, inclusion paths outside the enforcing set | No (policy, not validity) | **Yes, for its inclusion set** — assertions read cross-contract state without counterparty code changes |
| **D. Execution-client-level** | The client runs the gate in its state-transition loop: pre-state → execute → prospective post-state → evaluate obligations → commit or discard (the modeled `#w3Gate`/`#w3RestoreAll` sequence) | Any transition processed by that client | Node operators running the modified client; users trusting a supermajority of such clients | Only by not using the client — but a client rejecting consensus-valid blocks forks itself (liveness cost) | No unless supermajority adoption (then de facto protocol) | **Yes** — for all transactions it processes |
| **E. Protocol/consensus validity** | The same gate inside the protocol: a block is invalid unless every applicable obligation holds on the post-state; registry committed in protocol data | **Any** violating state from ever finalizing, network-wide | The protocol's social/consensus layer | **No** (within the protocol; a violating state is simply invalid) | **Yes** | **Yes, universally** |

**Finding (theorem-to-level binding).** The compositional safety theorem's assumptions — a single commit path, the gate evaluating every applicable obligation on the prospective state before commitment, reject restoring the committed state — are satisfied **unconditionally and network-wide only at level E**; the theorem is therefore consensus-strength iff the commitment gate is enshrined in protocol validity. At level C the same theorem holds **relative to the enforcing builder/sequencer's inclusion set** (trust assumption: operator + assertion correctness); at level D, relative to the client's processed view. The model (level B/C semantics above) does not require modifying EVM opcode semantics; it requires a **commitment-point hook** — and the honest statement of what is proved (§Q.5) is that the hook exists in the model, not in any deployed protocol.

---

## I. EVM binding uses real EVM semantics — execution-path verification (Priority 5)

The obligations must depend on **actual EVM-derived state**, not injected abstract values. Evidence: command-granularity prefix traces of the stale-price demo (`transcripts/audit/evm_trace_stale.txt`) — each stage runs the full KEVM pipeline for the commands executed so far and extracts real cell contents.

| Stage | Commands executed | Real cell contents observed |
|---|---|---|
| 1 | `#w3Setup #w3Snap0` | all three `<storage>` = `.Map`; snapshot carrier `s = {4097↦.Map, 4098↦.Map, 4099↦.Map}`, `n=0`, `h=-1` |
| 2 | + oracle segment | oracle storage `{0↦100, 1↦1}` — written by **real SSTORE** through evm.md rules |
| 3 | + lending segment | lending storage `{0↦90, 1↦5}` — the program executed a **real CALL** to 4097 (gas 10000, returndata 32 bytes to memory[0..32]) and then SSTOREd the stale constant 90, ignoring the return buffer |
| 4 | + liquidator segment | liq storage `{0↦4, 1↦90}` — a **real CALL to lending**, whose contract code (`PUSH 0; SLOAD; MSTORE; RETURN`) returned lending's slot0 = 90; liq's `MLOAD(0)` read the return buffer and SSTOREd it as priceLineage — the stale price flowed oracle → CALL/RETURN → memory → storage, entirely inside KEVM |
| 5 | `#w3Gate0` | **REJECT + RESTORE**: `#w3IOL()` evaluates `#w3read(lending,0) ==Int #w3read(oracle,0)` = `90 == 100` = false on real storage ⇒ `#w3RestoreAll` writes all three storages back to the snapshot (`.Map`); carrier unchanged (`n=0`, `h=-1`); no lineage |
| **Sensitivity probe** | oracle SSTOREs **90**; lending stores the **CALL-returned value** (`MLOAD` of the return buffer) instead of a constant | **COMMIT**: all three storages agree at 90 (oracle `{0↦90,1↦1}`, lending `{0↦90,1↦5}`, liq `{0↦4,1↦90}`); lineage `w3lin(parent=-1, tid=0, price=90)`; carrier advanced (`n=1`, `h=0`) |

**Reading.** The differential between stage 5 and the probe is the point: the *same* gate, evaluating the *same* obligations over *real* storage, flips from reject to commit precisely when the EVM-derived values make the obligations true — and the committed lineage record's `price` field (90 vs 100) is the value that flowed through real CALL/RETURN/MLOAD/SSTORE execution. Positive and negative examples are therefore traced end-to-end through genuine EVM semantics (`oracle state → CALL → returned price → lending state → liquidator state → IOL/ILD/IOLD → reject + restore`), with no manually injected abstract values anywhere in the gate's inputs.

---

## J. Lineage audit: mechanized structure vs cryptographic authentication (Priority 6)

**What is mechanized** (PROVED BY K — Claims 3, and structurally by the single-commit-path census): lineage is a chain of records `Λ = ⟨ParentCommitment, TransitionId, AuthorizationEvidence, PolicyVersion, ChildCommitment⟩` appended **only** by the gate's accept rule, with `parent` = the current chain head and `child` = `commit(next)`. This mechanizes **lineage structure**: ordering, chaining, one-record-per-commit, and authority-evidence *membership* at record-creation time. What the mechanization intentionally does **not** provide is any cryptographic content: commitments are opaque `commit(Int)` terms (assumption A2), authorization evidence is `auth(AppId)` (assumption A3), and nothing binds record contents to the data they summarize. **Symbolic lineage proves structural ordering properties only; it does not prove provenance.** No claim in this report should be read as implying that the mechanized lineage establishes cryptographic authenticity of parents, data, or evidence.

**What `Verify(parent, data, proof)` would require to be cryptographically meaningful** — four additions, each concrete:

1. **Commitment function.** Replace `commit(Int)` with a real hash — in the EVM context, `keccak256`. Mechanically this requires the K krypto plugin's `Keccak256` hook **and a built libkrypto** (the C library was not built in this environment — currently unexercised, §O); the KEVM layer would then commit `head := keccak256(parent ++ tid ++ inputEvidence ++ policyVersion ++ postStateRoot)` so that a lineage record is a tamper-evident hash chain.
2. **Data binding.** `data` must be the (hash of the) state the record summarizes: bind each record to a **state root** of the prospective post-state (in KEVM terms, the Merklized `<accounts>` storage) so that "the committed state" has a canonical digest inside the record — otherwise the chain orders records but says nothing about which state they certify.
3. **Inclusion proof.** `Verify` needs to check that a claimed (account, slot, value) is actually in the committed state: Merkle-Patricia inclusion proofs against the state root of item 2 — `Verify(parent, data, proof)` = recompute the state root from `proof` and `data` and compare with the root hashed into `parent`.
4. **Authorization evidence.** Replace `auth(AppId)` with a **signature over (parent, tid, data, policyVersion)** verifiable against the actor's public key (secp256k1 is already linked for `kore-exec`; the ecrecover path is unexercised), plus revocation/validity windows if delegation is admitted (CM3/CM5 territory).

With 1–4 in place, lineage becomes an authenticated hash chain anchored in state roots: forgery requires breaking the hash function or stealing a key, rather than violating an evaluated equation. Until then, the honest classification is: **mechanized lineage structure (PROVED BY K); cryptographically authenticated lineage (NOT YET MECHANIZED — requires libkrypto/keccak, state-root binding, MPT proofs, signatures).**

---

## K. Full verification matrix — post-reconciliation re-run (Priority 7)

Every row was re-executed after the reconciliation and audit artifacts were added (`transcripts/audit/full_matrix.txt`); **no previous result changed**. A second full re-run after the Round-2 theorem-boundary audit is recorded in `transcripts/audit/full_matrix_v2.txt` and summarized in §Q.6 — same verdict, zero regression.

| # | Check | Expected | Observed (this re-run) | Verdict |
|---|---|---|---|---|
| 1 | Baseline Python suite (`make test`, canonical) | 15/15 | `Ran 15 tests … OK`, exit 0 | ✓ unchanged |
| 2 | Abstract demo suite (`run_demos.sh`) | 13/13 as-expected | D1–D10, D2b, D3b, D7b all match §E table | ✓ unchanged |
| 3 | Claims 1, 2, 3, 4a, 4b (`kprove`, `SRW3-CLAIMS`) | all PROVED, no vacuity | exit 0, `#Top`, zero `WarnTrivial`/`WarnStuck` | ✓ unchanged |
| 4 | Negative control | correctly FAILS | exit 113, `WarnStuckClaimState` | ✓ unchanged |
| 5 | KEVM positive bundle | COMMIT + lineage | storages `{100,1} {100,5} {4,100}`; `w3lin(parent=-1, tid=0, price=100)`; `n=1`, `h=0` | ✓ unchanged |
| 6 | KEVM stale-price bundle | REJECT + restore | all storages restored to `.Map`; `n=0`, `h=-1`; no lineage | ✓ unchanged |
| 7 | KEVM restore (single-segment `evm_min2`) | REJECT + restore | all storages `.Map` after gate | ✓ unchanged |
| 8 | **NEW** — reconciliation bridge (9 ground claims) | agreements + pinned disagreement | kprove exit 0, `#Top`; G1–G7 agree, X1 pins CM7 divergence, X2 restoration (§F.3) | ✓ PASS |
| 9 | **NEW** — defect demonstrations | corrected vs defective behavior contrast | 1 vs 2 `krun --search` outcomes; 4a collapse under defect; vacuous Claim 2 under defect (§G.2) | ✓ PASS |
| 10 | **NEW** — induction attempts | step proved or blocker documented | `record-4a`/`record-4b` PROVED; full-theorem attempts stuck with verbatim residuals (§F.4) | ✓ PASS |

The reconciliation artifacts are **additive**: no rule in `k/srw3.k` or `k/kevm/srw3-kevm.k` was modified (the bridge, defect, and induction files are new modules in separate files), which is why rows 1–7 are expected to be unchanged — and are confirmed unchanged.

---

## L. Evidence classification and scoped scientific conclusion (Priority 8)

### L.1 Status of every major statement, in the mandated vocabulary

| Statement | Classification |
|---|---|
| Claims 1, 2, 3 (local preservation; gate coverage; lineage append) | **PROVED BY K** |
| Claim 4a (admissible one-step transition preserves safety) | **PROVED BY K** |
| Claim 4b (inadmissible one-step transition cannot commit) | **PROVED BY K** |
| Full theorem `Reach_committed(A) ⊆ Safe(P)` | ~~Hand proof valid; steps PROVED BY K; induction NOT YET MECHANIZED~~ **SUPERSEDED by §R.1: PROVED BY K over the ghost-instrumented semantics (GH-T2/GH-M; faithfulness mechanically certified)** |
| Structural uniqueness of the commit path (apart from initialization) | **PROVED BY K** (Claim 2) + rule census |
| Gate accepts/rejects on evaluated obligations (no assumed predicates) | **PROVED BY K** (§23 discipline; claims evaluate `securityClosedUniv`) |
| Refinement of the original scaffold (signature-faithful `gateOk`/`rootOk` agreement) | **PROVED BY K** on all covered states; divergence class pinned to wfCheck boundary (§F.3) |
| Real SSTORE/CALL/RETURN/MSTORE/MLOAD/PUSH/STOP execution; obligations over real storage; commit/restore on EVM state | **DEMONSTRATED BY KEVM** (stage traces, §I; negative + sensitivity controls) |
| The gate mediates *cross-application composition* over arbitrary contracts | **DEMONSTRATED BY KEVM** at model scale (3 contracts); not a protocol result |
| Commitment/restore as an enforcement mechanism | **Modeled** — DEMONSTRATED BY KEVM inside the semantics; not an Ethereum capability (§H.2) |
| Obligation registry (`edge(InvId, AppSet)`) completeness for a given universe | **ASSUMED** per model (SecurityClosed is *evaluated* on the concrete registry; the theorem's premise, not a consequence) |
| `trueDeps` read-set derivation (A1); opaque commitments (A2); symbolic evidence (A3) | **ASSUMED** (explicit, §E) |
| Commitment-point hook in an execution client / protocol | **REQUIRES PROTOCOL/CLIENT SUPPORT** (§H.3 — concrete modifications per level) |
| Cryptographically authenticated lineage (`Verify(parent, data, proof)`) | **NOT YET MECHANIZED** (§J — keccak/libkrypto, state-root binding, MPT proofs, signatures) |
| Full lineage-length induction in K | **NOT YET MECHANIZED** (§F.4) — **SUPERSEDED by §R.1 (mechanized over the ghost representation)** |
| CM2 aliasing; CM3 aggregate authority limits; CM8 hyperproperties; CM9 liveness | **NOT YET MECHANIZED** (§N scope boundaries) |

### L.2 What the evidence supports — and what it does not

**Supported finding.** SRW3 can be represented as a **commitment-gated composition semantics**: prospective EVM state is evaluated, at a single commitment point, against explicit cross-application obligations (a hypergraph registry + effect-completeness check + authority closure), before becoming committed state; the evaluation is by equations over the actual prospective state; acceptance appends authenticated-structure lineage and rejection restores the prior state. Within the modeled architecture:

```
Closed-composition enforcement  ⇒  requires a commitment-point hook
```

— where the hook is precisely characterized at the five enforcement levels contract / compiler-toolchain / builder-sequencer / execution-client / protocol (§H.3, revised §Q.4). The strongest form of the theorem — validity for arbitrary independently developed contracts, network-wide — matches the trust/validity assumptions of the **protocol/consensus-validity level (E)**; at the builder/sequencer level (C) it holds relative to the enforcing inclusion set, at the execution-client level (D) relative to the client's processed view.

**Explicitly NOT claimed.** Ethereum already supports SRW3 (it does not — §H.2); the modeled gate is a real client/protocol mechanism (it is a semantics); pre-inclusion cross-contract invariant enforcement is new (it is not — deployed systems exist, §Q.3); ~~the full lineage-length theorem is mechanized~~ (at §L-writing time it was hand-proved with machine-checked steps; **as of §R.1 it IS mechanized over the ghost-instrumented semantics, which is exactly how the claim is now scoped**); the scaffold reconciliation is a refinement/simulation theorem (it is a signature-faithful realization with mechanically checked agreement, §Q.2); symbolic lineage establishes cryptographic provenance (it does not — §J); the negative-control-validated prover proves more than its stated fragment. Each ingredient is classical; the phase's specific contribution is the **conjunction** defined in §Q.5, and the audits above are what bound it honestly.

---

## M. Relation to prior art (§27) — REVISED in the Round-2 audit (§Q.3)

**This section is superseded by §Q.3**, which adds current pre-inclusion/runtime
invariant-enforcement systems (in particular the Phylax Credible Layer, deployed on
Linea), distinguishes five enforcement levels, and reframes the novelty question as a
conjunction. The table below is retained for the areas already covered at Phase-0 time;
read it together with §Q.3. **Pre-inclusion cross-contract invariant enforcement itself
is NOT claimed as new.**

| Prior area | What it covers | What SRW3-phase-0 adds (mechanized here) |
|---|---|---|
| Solidity verification (SMTChecker, VerX, Securify, Manticore, Echidna, SmartCheck) | per-contract invariants / temporal specs, pre-deployment | **cross-application obligations as first-class hyperedges** with a closure predicate, checked at a commitment point over composed prospective state |
| Proof-Carrying Code / Proof-Carrying Smart Contracts | evidence carried with code, checked at load | evidence is **state-lineage-linked** (parent/child commitments) and **re-checked per transition against the current composed state**, not once at load |
| Move / Cadence resource semantics | linear resources prevent duplication/loss inside a language | obligations over **storage-level cross-contract dependencies** (no language boundary), incl. three-way (non-pairwise) properties (IOLD; CM6) |
| Capability systems | authority mediation of operations | mediation of **state commitment** plus authority evidence in lineage (reject-auth) |
| Universal Composability | ideal-world composition theorem | executable gate-level analogue with explicit closure premises (SecurityClosed) over a concrete semantics; not a UC theorem |
| Runtime monitoring / firewalling | post-hoc violation detection or mediating wrapper | the **pre-commitment** distinction (§H): the violated state is discarded, not reported — mechanically demonstrated (D1 vs monitoring semantics; D2 shows what dropping one obligation costs) |
| Cross-chain security | bridge-level assumptions | orthogonal; lineage records could anchor cross-chain evidence — future work |

---

## N. Countermodel disposition (§28)

| CM | Statement | Disposition in this phase |
|---|---|---|
| CM1 | local invariants true, interaction invariant false | **Handled by closure assumption** — negative registry demo (D2) commits the violation; with the complete registry it is rejected (D1); InteractionComplete evaluates FALSE on the negative registry, so the theorem's premise is correctly unsatisfiable there — no vacuous proof claimed |
| CM2 | shared-resource aliasing | **Requires extension** (Phase-1): the abstract model's state is (app, slot)-addressed — aliasing across *names* for the same resource needs an explicit aliasing relation on keys; **NOT YET MECHANIZED** |
| CM3 | authority aggregation/delegation exceeds global limit | **Partially handled**: authority-closure membership + reject-auth (D5); *aggregate* limits (sum over delegation chains) need threshold obligations — **NOT YET MECHANIZED** |
| CM4 | source-valid but wrong/stale lineage input | **Handled at the interaction level** (D7b/D8: stale/wrong price lineage rejected via IOL/IOLD over real values); *cryptographic* input-evidence binding is abstraction A3 — **NOT YET MECHANIZED** (§J) |
| CM5 | temporal/revocation ordering | **Structurally handled** (parent = current head; ordering by lineage chain); revocation with validity windows = extension |
| CM6 | three-way interaction not captured by pairwise contracts | **Mechanized** — D10 (pairwise-only registry accepts the bad settlement; `bareEdge` marks the known-but-uncontracted dependency); complete registry rejects (D8/D9) |
| CM7 | hidden effect / dependency omitted from abstraction | **Mechanized** — D3 (trust → violation committed), D4 (enforce → blocked), D7 (undeclared read → blocked); **and now pinned at the reconciliation level**: bridge claim X1 is exactly this divergence (§F.3) |
| CM8 | hyperproperty boundary | **Out of scope** (§29) — not mechanized |
| CM9 | liveness treated as safety | **Out of scope** (§29) — not mechanized |

---

## O. Limitations and threats to validity

1. **Scale of the mechanized model.** The claims are proved over a minimal 2-app (+1 hidden-effect app) universe with concrete registries; the closure premise is *evaluated*, not assumed, but the universe is small; scaling to arbitrary registries requires quantified closure premises (different prover strategy).
2. **The induction is not mechanized.** The full lineage-length theorem is hand-proved with machine-checked steps; the three prover-level blockers are documented verbatim (§F.4). Until closed, the packaging from "4a ∧ 4b ∧ structural uniqueness" to "∀n" rests on the meta-argument.
3. **KEVM scope.** The binding covers SSTORE/SLOAD/CALL/RETURN/MSTORE/MLOAD/PUSH/STOP under CANCUN with `useGas=false`; gas accounting, REVERT-interaction with the gate, CREATE/SELFDESTRUCT, and crypto-precompile dependencies are unexercised. The C krypto library was not built (submodule absence + resource ceiling); keccak-dependent paths are untested — none of the demos needs them.
4. **Commitment-point deployment.** The semantics assumes a hook at state commitment; that hook does not exist in stock Ethereum clients — it is the *finding* (§H), not a defect of the experiments.
5. **Defect reconstruction fidelity.** The phantom-reject demonstration uses a reconstruction from the recorded worklog description (the verbatim original rule text was not preserved); the reconstruction reproduces the recorded behavior exactly, and both the reconstruction's header and the transcript disclose this.
6. **Engine-specific parsing lessons** (recorded for reproducibility): single-letter tokens collide with builtin variables; **syntax-declaration argument names must be lowercase** (uppercase names break the inner parser — re-confirmed during the induction work); `[lemma]`/`[simp]` are not recognized by this K version — trusted simplifications use `[simplification]`; claims must not appear in the `--main-module` closure; `SET.intersection` is not reliably evaluated by the Haskell backend; projection casts `{:>Int}` are opaque to the simplifier; cell-map extension of `<kevm>` regenerates unit symbols.
7. **kore destination-variable handling.** The `?YB` residual (§F.4, [C-attempt-1] + isolation experiment) is a prover-behavior finding, not a logic error — flagged for upstream attention; it blocks a packaging strategy that is logically sound.

---

## P. Next steps and remaining blockers

**Immediate (scientific priority, per audit directives — completed in the two audit rounds):** gateOk/rootOk reconciliation (§F, §Q.2); Claim 4a/4b separation, induction audit and premise-form verification (§F.4, §Q.1); phantom-reject defect lesson (§G); commitment-boundary audit and five-level taxonomy (§H.3, §Q.4); EVM-binding verification (§I); lineage classification (§J); full matrix re-runs (§K, §Q.6); scoped conclusion and prior-art revision (§L, §M, §Q.3, §Q.5).

**Secondary (deferred by directive):**
1. **LLVM-backend retarget** of the KEVM binding (build plugin C deps) for krun speed, and `driver.md` integration for transaction-level execution. Deferred until BOTH audit rounds are consumed; no result depends on it.
2. **Close the induction packaging**: candidate routes are ghost-state invariant maintenance, a prover upgrade for destination-variable handling, or quantified frame reasoning (§F.4). Any route must keep the theorem's statement intact.
3. **Close the generalized-agreement theorem**: mechanize ∀H ∀FD ∀S agreement (§Q.2 tier 3) — requires structural induction over symbolic sets/maps, i.e. a prover capability upgrade, or per-instance expansion (the mechanism used for the tier-2 claims).
4. **Mechanize CM2 (aliasing)** and **CM3 aggregate limits** — both fit the obligation-evaluation architecture; CM8/CM9 need a hyperproperty-level extension decision before any mechanization attempt.
5. **Cryptographic lineage** (§J): build libkrypto → keccak commitments; state-root binding; MPT inclusion proofs; signature-based authorization evidence; then state and prove `Verify(parent, data, proof)` soundness in K.
6. **Declarative registry format**: port the obligation registry to a contract-format source and generate `edge(...)` registries from it (the Γ̂ side), closing the loop with a compiler-layer (Option B) story.
7. **Upstream report**: file the `[lemma]`/`[simp]` attribute findings and the `?YB` destination residual against K v7.1.337 with the verbatim transcripts.

**Remaining blockers (concise list):**
- Full-theorem (∀n safety) mechanization in K — blocked by symbolic-map evaluation, requires-as-hypotheses, and destination-variable residuals (§F.4(i)–(iii)); the ROUND-2 audit confirmed this is a packaging boundary, NOT a premise defect (§Q.1).
- Generalized agreement theorem (∀H ∀FD ∀S) — stated with the explicit coverage predicate wfCoverage (§Q.2); blocked by structural induction over symbolic sets in the reachability+SMT fragment; state-generalized instances ARE mechanized (tier 2).
- Cryptographic lineage — blocked by libkrypto build (resource ceiling) plus the extension work in §J.
- CM2/CM3/CM8/CM9 — blocked by model-extension decisions, not by tooling.
- Protocol-level relevance — requires the commitment-point hook of §H.3 at enforcement level C/D/E; outside this environment's scope by definition; a deployed builder/sequencer-level instantiation (level C) exists commercially (§Q.3) but does not make SRW3's theorem consensus-strength.

---

## Q. Round-2 theorem-boundary audit — verdicts, generalization, prior art, taxonomy, contribution

Mandated by the follow-up audit directive ("Next Formal Audit Instructions"). Scope:
resolve the theorem-level issues BEFORE any Phase-1 design work and BEFORE any LLVM
backend work. Every verdict below is backed by a re-runnable artifact and a verbatim
transcript; the full regression matrix (§Q.6) confirms nothing previously established
changed.

### Q.1 Claims 4a/4b as induction steps — VERDICT: **PROVED** (genuine Safe(P,σ) premises)

**Audit question.** Do 4a/4b use a genuine predecessor-state safety premise
`Safe(P, sigma)` (or an equivalent predicate), or merely an `InitialSafe(...)`
premise whose meaning is restricted to the designated initial state?

**Verdict: PROVED — the premises are genuine induction-step premises.** Evidence, all
machine-checked (`proofs/safe_form_audit.k`, transcript
`transcripts/audit/safe_form_audit.txt`, kprove exit 0, `#Top`, 4/4 claims):

1. **No InitialSafe predicate exists in the mechanized claims.** The symbol
   `InitialSafe` appears nowhere in `SRW3-CLAIMS`; it occurs in `k/srw3.k` only in a
   comment stating that the base constraint is *evaluated, not assumed*. X and Y in
   claims 4a/4b are universally quantified symbolic `Int`s — nothing pins them to
   designated initial values.
2. **SF1 — premise ≡ Safe(P, σ_n).** The inlined predecessor constraint
   `X ≤ 10 ∧ Y ≤ 10 ∧ X + Y ≤ 10` is identically the named safety predicate
   `safeForm({appA↦X, appB↦Y})` — the same predicate the induction observer `chkS`
   uses — for all symbolic X, Y. (SF0 additionally records that IC is vacuous on the
   two-key shape, so the minInvs universe reduces to these three checks.)
3. **SF2 — Accepted(σ_n, τ) is the gate's own accept condition.** 4a's accept-side
   conjuncts `V ≤ 10 ∧ X + V ≤ 10` are identically
   `allHold(applicable(completeRegistry(), {appB}), σ̂)` — the evaluated
   applicable-obligation conjunction of the ACCEPT rule.
4. **SF3 — Rejected(σ_n, τ) is the exact negation.** 4b's disjunction
   `V > 10 ∨ X + V > 10` is identically `¬allHold(...)`, and 4b's right-hand side pins
   `σ_{n+1} = σ_n` (committed unchanged), exactly the mandated step shape:
   `Safe(P,σ_n) ∧ Accepted(σ_n,τ) → Safe(P,σ_{n+1})` and
   `Safe(P,σ_n) ∧ Rejected(σ_n,τ) → σ_{n+1} = σ_n`.
5. The remaining premises (`securityClosedUniv`, authorization) are theorem-level
   system premises (SecurityClosed; root authority), not restrictions of the safety
   predicate to an initial state.
6. Joint-soundness note: 4a and 4b together pin the gate's accept condition exactly —
   if the ACCEPT rule's condition were weakened, 4b would fail (the reject path would
   no longer be the only outcome for violating writes); if strengthened, 4a would fail.
   Neither is exploitable by an inconsistent-claim artifact.

**Scope precision (unchanged from §F.4).** The verdict covers the STEP statements over
the minimal model. The full theorem `∀n. Safe(P, σ_n)` remains **hand-proved with
machine-checked steps, packaging NOT YET MECHANIZED** — the Round-2 audit confirms the
blockers are a *packaging boundary* (symbolic-map evaluation, requires-as-hypotheses,
destination-variable residuals), **not a premise defect**. No theorem statement was
changed by this audit; nothing was silently patched.

### Q.2 Generalizing the scaffold reconciliation — coverage predicate + three tiers

**Audit question.** Can `wfCheck(state) → gateOk_faithful(state) = implementedGate(state)`
be proved as a general property?

**Answer: not in that form — the exact formulation requires an explicit coverage
predicate, and the fully quantified statement is NOT YET MECHANIZED.** wfCheck
(Γ* ⊆ Γ̂, effect completeness) is **necessary but not sufficient** for gate agreement:
a state can have all true effects declared while an obligation on an *untouched*
application is already violated in the inherited state (e.g. a trust-policy commit
left `appC = 11`; a later clean, fully-declared `appB` write passes wfCheck yet the
faithful all-universe check rejects while the applicable-only implemented check
accepts). The precise predicate is:

```
wfCoverage(H, FD, S)  :=  ∀ edge(J, Xs) ∈ H.  ( Xs ∩ FD ≠ ∅  ∨  evalInv(J, S) )
```

("every obligation the declared footprint fails to make applicable is already satisfied
by the state"). Under it, the general theorem is:

```
wfCoverage(H, FD, S) ∧ rootOk(R, appName(Ac), tid)
====================================================
( gateOk(C, S, TR, R, H, M) ∧ rootOk(R, appName(Ac), tid) )  ==  gateAccept(H, FD, Ac, As, S)
```

(sketch: `applicable(H,FD) ⊆ universeObls(H)`; `allHold` over the superset factors into
`allHold` over the subset AND the skipped conjuncts, each made true by wfCoverage; the
authorization conjuncts coincide under the name-coincidence premise).

**Three-tier result structure** (this is the scientific terminology; tier 1 alone must
not be called a refinement theorem):

| Tier | Statement | Status |
|---|---|---|
| 1 — finite ground agreement | G1–G7 agreements + X1 divergence + X2 restoration over demo states (`k/compat/srw3-bridge.k`) | **PROVED BY K** (checked by evaluation, 9/9) |
| 2 — state-generalized agreement on covered instances | G8–G11 (`proofs/generalized_bridge.k`): for complete/{appB}, chainComplete/{lending}, chainComplete/{liq}, and negative/{appB} registries, agreement holds for **all symbolic state values** satisfying the wfCoverage instance (the requires IS the coverage predicate, evaluated) | **PROVED BY K** (4/4, `#Top`; WarnTrivialClaim = checked-by-evaluation with universal quantification over X,V / PR,AU,LP,LD,LT,LL) |
| 3 — fully quantified agreement (∀H ∀FD ∀S) | stated above with wfCoverage | **stated, NOT YET MECHANIZED** — with H, FD, S symbolic, wfCoverage/universeObls/applicable/allHold are recursive functions over constructor-free symbolic aggregates and do not reduce; the identity needs structural induction over symbolic sets, beyond the Haskell backend's reachability+SMT fragment (the same prover boundary as §F.4 attempt [B]) |

**Necessity of the coverage premise (falsification-validated).** Ground witness X3:
an unauthenticated-but-consistent oracle state (oracle auth = 0, all applicable
obligations true) — the implemented gate (footprint {lending}) ACCEPTS, the faithful
instantiation REJECTS; X3 PROVED pins the disagreement. Additionally, symbolic probes
N1/N2 (G8/G9 with the coverage premise dropped) correctly FAIL (kprove exit 1,
WarnStuckClaimState — `transcripts/audit/generalized_bridge_negative.txt`): the premise
is load-bearing, not decorative. (For the complete registry over the naturals, IAB
entails the skipped IA; the integer domain is where N1's counterexample lives — the
chain-registry witness X3 is natural-valued, which is why it is the canonical one.)

**Terminology (mandated, adopted).** The reconciliation result is a **"signature-faithful
realization with mechanically checked ground agreement over the covered states"** —
extended by tier 2 to *state-generalized* agreement on the covered (registry, footprint)
pairs. It is **not** called a general refinement/simulation theorem anywhere in this
report. **Link to the safety theorem:** on the ENFORCE system's reachable states,
wfCoverage holds by the frame argument — a transition writes only keys of apps in
FT ⊆ FD, so every skipped edge's keys are untouched and `evalInv(J, σ̂) = evalInv(J, σ_n)`,
which the induction hypothesis `Safe(P, σ_n)` makes true. That is the precise semantic
bridge between the commitment-gate safety theorem and the gate-agreement theorem; under
policy `trust` the link breaks and X1 is the divergence.

### Q.3 Prior-art boundary — revised (pre-inclusion enforcement is NOT new)

Method: 19 targeted web searches + primary-source reads (docs, whitepaper repo,
product pages), 2026-09-27; raw evidence archived in `tool-results/prior-art/`
(`SUMMARY.md` + JSON captures).

**Mandated correction.** Pre-inclusion cross-contract invariant enforcement **exists in
practice and must not be claimed as SRW3 novelty**. The reference system is the
**Phylax Credible Layer** (primary sources): developers write assertions in Solidity
(`credible-std`) defining "states your protocol should never reach", with triggers on
function calls / storage / balance changes and **no contract modification**; a PhEVM
simulation takes pre/post snapshots and runs the assertions; violating transactions are
**"dropped during block building"**; deployed on **Linea** (site-reported "$2.6M+ in
0x drain attempts stopped"). Enforcement level: builder/sequencer (level C of §Q.4) —
policy enforcement by the asserting network, **not** consensus validity, and bypassable
outside its inclusion set.

| Enforcement class (§Q.4 level) | Systems surveyed | Relation to SRW3 |
|---|---|---|
| Post-hoc monitoring (—) | Forta network (detection bots, alerts after inclusion); HighGuard (cross-chain runtime monitoring) | detects, does not prevent; SRW3's gate is pre-commitment (D1 distinction) |
| Contract-level runtime checks (A) | Solidity `require`/modifier patterns; **Scribble** (Certora) — source-annotated, compile-time-woven runtime assertions | per-contract scope; no cross-application closure; SRW3 hyperedges + gate are a different mechanism |
| Compiler/toolchain (B) | Scribble's instrumentation; SolCMC (CAV 2024) and Solidifier — **static** cross-contract model checking pre-deployment | static or woven; no commitment-point semantics, no lineage, no runtime gate |
| Builder/sequencer pre-inclusion (C) | **Phylax Credible Layer** (Linea); ERC-4337 bundler/paymaster policies (per-UserOp scope) | **same enforcement level as SRW3's modeled gate** — but assertion-per-protocol, no interaction-hypergraph closure calculus, no effect-completeness predicate (Γ* ⊆ Γ̂), no lineage ledger, no mechanized compositional theorem |
| Execution-client (D) | modified-client enforcement (Phylax's integration point on L2 sequencers is the deployed analogue) | SRW3's modeled `#w3Gate` sequence is exactly this shape; nothing deployed on mainnet L1 does it |
| Protocol/consensus validity (E) | enshrined-invariant discussions (EIP/debate level only) | no general cross-contract obligation gate enshrined anywhere as of the search date |
| Adjacent building blocks | ZK coprocessors (Axiom, Brevis, Lagrange — proofs over historical state); Move VM on-chain bytecode verifier (resource safety at VM entry) | evidence/verification substrates, not commitment-gated composition semantics |

**Revised research question (replaces any novelty claim on enforcement).** Not "is
pre-inclusion enforcement new?" — it is not. The question is whether SRW3 contributes
something specific in the **conjunction** of: explicit interaction hypergraph;
closure completeness (interaction/contract/effect/lineage/gate); effect-completeness
(declared-vs-true footprints, wfCheck); commitment-gated composition (separate
committed/prospective state with a single commit path and restore-on-reject); lineage;
mechanized semantics over KEVM; and a compositional safety theorem. **No surveyed
system combines these ingredients**; the closest single systems are Phylax (enforcement
level), Scribble (obligation language), SolCMC (cross-contract semantics, static), and
Move (VM-level enforcement, language-internal properties). This conjunction claim is
scoped to the survey above and its date.

### Q.4 Commitment-boundary taxonomy — revised (summary)

The full five-level taxonomy (A contract / B compiler-toolchain / C builder-sequencer /
D execution-client / E protocol-consensus, each with: what it can prevent, who must
trust it, bypassability, consensus-criticality, independent-contract coverage) is
§H.3. The superseded statement "only an execution client or protocol can provide
pre-inclusion enforcement" is retracted there. **Theorem-to-level binding (the
directive's "most important" clause):** the compositional safety theorem's
assumptions — single commit path, all applicable obligations evaluated on the
prospective state before commitment, restore on reject — are satisfied unconditionally
and network-wide **only at level E**; at level C the theorem holds relative to the
enforcing inclusion set; at level D relative to the client's processed view. The
strongest theorem is therefore tied specifically to level E, and SRW3's demonstrated
semantics is the *shape* of the level-D/E hook, not a deployment claim.

### Q.5 Updated scientific contribution statement

**Supported (scoped) finding.** SRW3 is representable as a **commitment-gated
composition semantics**: prospective EVM state is evaluated at a single commitment
point against explicit cross-application obligations — hypergraph registry,
effect-completeness check, authority closure — before becoming committed state;
acceptance appends structurally authenticated lineage; rejection restores the prior
state. Formal result within the model:

```
Closed-composition enforcement  ⟹  requires a commitment-point hook
```

**Conjunction contribution (replaces ingredient or enforcement novelty claims).** The
phase's contribution is the mechanized combination of: interaction-hypergraph
obligations; closure completeness as an evaluated premise; effect-completeness
(wfCheck); commitment-gated composition; lineage; and the KEVM-grounded execution
layer — together with the compositional safety theorem (step PROVED BY K: 4a ∧ 4b
with genuine Safe(P,σ) premises, §Q.1; full ∀n theorem hand-proved with machine-checked
steps and precise verbatim blockers, §F.4) and the countermodel discipline CM1–CM9.
The reconciliation to the original scaffold is a **signature-faithful realization with
mechanically checked ground + state-generalized agreement under wfCoverage** (§Q.2) —
not a refinement theorem. Pre-inclusion enforcement itself is prior art (§Q.3);
"Ethereum already supports SRW3" remains explicitly **not** claimed (§H.2); the gate
becomes a real mechanism only with a commitment-point hook at enforcement levels
C/D/E (§Q.4), which is REQUIRES CLIENT/PROTOCOL SUPPORT, not a result of this phase.

**Evidence-label discipline (§L.1) is unchanged and now also governs §Q:** all new
mechanized statements (SF0–SF3, G8–G11, X3) are PROVED BY K (checked-by-evaluation
class, universal quantification documented); tier-3 agreement, ∀n packaging,
cryptographic lineage, CM2/CM3/CM8/CM9 remain NOT YET MECHANIZED; deployment claims
remain REQUIRES CLIENT/PROTOCOL SUPPORT.

### Q.6 Regression matrix v2 — nothing changed

Re-run after all Round-2 artifacts (`transcripts/audit/full_matrix_v2.txt`):
Python baseline 15/15 (canonical `make test`); abstract demos 13/13 as-expected;
Claims 1/2/3/4a/4b PROVED (`#Top`, no vacuity); negative control correctly FAILS
(exit 113); reconciliation bridge 9/9 (checked-by-evaluation); phantom-reject audit
reproduced (corrected = deterministic commit; defective = spurious second outcome);
Round-2 artifacts: safe-form 4/4, generalized bridge 5/5, necessity probe correctly
FAILS; KEVM positive = COMMIT with expected snapshot, stale-price = REJECT + full
restore + no lineage, min2 = REJECT + restore. Verbatim verdicts in the transcript;
summary in §K-style table maintained there. **No previously established result
changed.**

---

## R. Theorem-closure pass — the ∀n safety theorem MECHANIZED over the ghost representation

This section records the final Phase-0-D pass. Its mandate: close the theorem
boundary before any Phase-1 design or LLVM work, using the prescribed
invariant-as-data / ghost-state strategy, without weakening any statement and
without introducing unproved axioms. Every claim below was re-run for this
section (`transcripts/audit/ghost_theorem.txt`, `tier3_universal.txt`,
`full_matrix_v3.txt`).

### R.1 Primary objective — full lineage-length safety theorem: **PROVED BY K**

Target (unchanged from the audit instruction):

```
InitialSafe(P, σ₀) ∧ SecurityClosed(P)  →  ∀n. Safe(P, σₙ)
equivalently  Reach_committed(P) ⊆ Safe(P)
```

**Encoding (invariant-as-data / ghost-state).** `proofs/induction_ghost.k` is
constructed by a generator script (`scripts/gen_ghost_artifact.py`): the
baseline semantics (k/srw3.k lines 24–530, modules SRW3-SYNTAX … SRW3-CLAIMS)
is copied **byte-identically** — 507/507 source lines matched in order,
mechanically re-verifiable at any time (`scripts/audit_ghost_faithful.py`) —
and the only edit class is **13 marked live lines** (`//GHOST:` sentinel):
a `<ghost>` certificate cell; a `GW(I,S,prev,v)` pending-write record in the
declared-write rule; certificate transformers `ghostApply`/`ghostUndo` at the
three commitment-point rules; the `Ghost`/`GateRun` sorts and the ghost
function signatures. The real gate decisions (`allHold(applicable(R,FD), P)`)
are kept **verbatim** as the accept/reject splitting conditions — the
certificate is purely additive, and no rule's real-cell behavior changed.

**The prescribed structure, mechanized end-to-end:**

* `GhostMatches(ghost, committed)` — the explicit soundness relation
  (`lookupInt` equalities on the tracked keys). **Not an axiom**: the base
  instance is checked by evaluation (GH-BASE), preservation is proved per
  transition outcome, and the relation is re-checked dynamically at every
  program termination in the strongest theorem form (GH-M).
* **GH-A (accept preservation)**: after an accepted transition,
  `GhostMatches(ghost′, committed′)` — PROVED. The observer `chkM` fires only
  if the certificate matches the committed state AND is certified-safe, so a
  defective certificate transformer would make the claim stick.
* **GH-R (reject preservation)**: a rejected transition preserves the previous
  matching relation (committed state and certificate unchanged) — PROVED.
* **GH-SOUND-I / GH-SOUND-F**: a certified-safe certificate matched to the
  real state implies the real-state safety observer `safeMin` (the
  `GhostMatches → Safe` bridge, in residual-sharing and named-relation forms)
  — PROVED.
* **GATE-AGREE**: the certificate-predicted accept condition equals the real
  gate's evaluated applicable-obligation conjunction on the prospective state
  — PROVED.
* **GH-T2 / GH-M — THE THEOREM**: `[circularity]` claims over
  `chkG`/`chkM`-terminated programs of one-write cycles (sort `GateRun`).
  InitialSafe is the evaluated requires; SecurityClosed is the evaluated
  `securityClosedUniv` premise. The observer executes only on a
  certified-safe certificate, so universal termination proves iff no
  admissible run ever commits an unsafe state (refutation-proof form, as in
  attempts [B]/[C]). The shared `X0/Y0` variables between `<committed>` and
  `<ghost>` bake the GhostMatches shape into the induction. **Both reach
  #Top (exit 0, no vacuity warning).** The unbounded symbolic program tail
  means the proof can only close through the circular reuse — the induction
  is genuinely exercised, not unrolled.
* **GH-T2-NEG (non-vacuity control)**: GH-T2 with the InitialSafe premise
  dropped — correctly FAILS (an initially-unsafe certified value sticks at
  the observer).

| claim | content | verdict |
|---|---|---|
| GH-BASE | GhostMatches base instance (by evaluation) | PROVED |
| GH-A | accept preservation (4a-analogue at certificate layer) | PROVED |
| GH-R | reject preservation (4b-analogue) | PROVED |
| GH-SOUND-I / GH-SOUND-F | certificate → real-state safety bridge | PROVED |
| GATE-AGREE | ghost-predicted condition == real gate condition | PROVED |
| GH-ISO / GH-T1 | non-circular diagnostics (1 and 2 cycles, both branches) | PROVED |
| **GH-T2** | **∀n safety theorem** (`[circularity]`, chkG observer) | **PROVED** |
| **GH-M** | **∀n + GhostMatches re-checked at every termination** | **PROVED** |
| GH-T | minimal-destination probe (see below) | STUCK (documented) |
| GH-T2-NEG | premise-dropped non-vacuity control | FAILS (correctly) |

**Faithfulness of the representation.** Three independent anchors: (i) the
mechanical byte-identity certificate (507/507 in order, delta = 13 marked
lines); (ii) the certificate layer is semantically conservative by
construction — the real gate conditions decide accept/reject verbatim, and
the certificate only observes/records; (iii) GH-A/GH-R/GATE-AGREE/GH-SOUND
are themselves proof obligations that were checked, not assumed. The
superseded attempts [B] (fully symbolic Map) and [C] (record mirror) remain in
the repository as the recorded evidence of *why* this encoding is the one that
closes: [B] requires symbolic Map evaluation, [C] hit the destination-residual
boundary, and the ghost encoding avoids both (concrete-shape committed map
with symbolic values; certificate data instead of map reads; explicit
existential destinations).

**Prover-boundary discovery (recorded for future K users; not a theorem
gap).** A kore implication check fails with a stuck residual when a cell that
CHANGES during the proof is absent from the claim's destination; the SAME
claim with explicit `?`-prefixed existential destination cells over all cells
closes. GH-T (destination mentioning only `<k> .K`) is retained as the
documented probe of exactly this behavior — the same residual class as the
[C] record attempt — and explains why the copied SRW3-CLAIMS claims cannot be
re-run against the instrumented definition (their destinations do not mention
`<ghost>`); on the pristine definition they prove unchanged (matrix [3]).

**Why the theorem is now mechanized rather than "hand-proved".** The
mathematical induction (base: evaluated InitialSafe; step: 4a ∧ 4b) was
already valid. What this pass adds is the machine-checked closure of the
induction itself: the circular claim re-establishes the (preserved) safety of
the certificate at every unrolled tail, and every semantic link in the chain
— GhostMatches base, preservation per outcome, certificate-to-real-state
soundness, gate agreement, encoding faithfulness — is an independently
checked proof obligation. The scope statement is precise: the ∀n theorem is
mechanized over the ghost-instrumented semantics, whose copied rule bodies
are byte-identical to the baseline by mechanical certificate and whose
certificate layer is verified conservative. The residual gap to "the literal
SRW3-GATE module proves the same claim" is a module-identity artifact of the
kore destination behavior documented above, not a mathematical step.

### R.2 Secondary objective — tier-3 universal reconciliation: **STATEMENT FORMALIZED; NOT YET MECHANIZED**

The mandated target statement, with universal quantification over the registry
H, the declared footprint FD and the prospective state S, using the EXACT
audit-established coverage predicate:

```
wfCoverage(H, FD, S) := ∀ edge(J, Xs) ∈ H. ( Xs ∩ FD ≠ ∅  ∨  evalInv(J, S) )

wfCoverage(H, FD, S)  →  gateOk_faithful(H,S) = implementedGate(H,FD,S)
```

`proofs/tier3_universal.k` formalizes the statement as kprove claims **without
weakening** (no coverage conjunct dropped, no quantifier restricted) and
attempts mechanization. Three attempts, all stuck at the same backend
boundary, residuals recorded verbatim (`transcripts/audit/tier3_universal.txt`):

| attempt | quantification | outcome | verbatim boundary |
|---|---|---|---|
| T3-U | ∀H ∀FD ∀S (+ name-coincidence by construction) | STUCK | `memberName(appName(Ac),Rt) ∧ allHold(universeObls(H),S) ==Bool member(Ac,Rt) ∧ allHold(applicable(H,FD),S)` — recursive functions over constructor-free symbolic Sets do not reduce; the identity needs structural induction over symbolic aggregates |
| T3-FD | concrete H, ∀FD ∀S | STUCK | symbolic FD alone already leaves `allHold(applicable(concrete-H, FD), S)` non-reducible (the coverage premise unfolds to concrete conjuncts but the universal Ac/S identity remains) |
| T3-A | authorization lemma alone: `memberName(appName(Ac),As) ==Bool member(Ac,As)` | STUCK | pins the exact boundary: structural induction over a symbolic Set is beyond the Haskell backend's reachability+SMT fragment |

Per the mandate: the classification is exactly **STATEMENT FORMALIZED; NOT YET
MECHANIZED**, and the tier-1 (ground G1–G7/X1/X2) and tier-2 (state-generalized
G8–G11/X3 under `wfCoverage`) results are preserved unchanged (matrix [5], [7b],
[7c]). The bridge terminology remains "signature-faithful realization with
mechanically checked ground agreement over the covered states", extended with
the state-generalized tier — never "refinement theorem".

### R.3 Strengthened scientific boundary — four enforcement levels

The final report distinguishes four levels by ENFORCEMENT PHASE (superseding
the round-2 five-level by-site scheme A–E of §Q.4, which remains in §H.3 as
the deployment-site view; the two are complementary — site × phase):

| level | what it is | what it can prevent | who must trust it | bypassable? | consensus-critical? | guarantees for independently developed contracts? |
|---|---|---|---|---|---|---|
| **A. Detection** | the system observes/identifies an unsafe transition (monitoring, alerts, post-hoc forensics — e.g. Forta-class) | nothing by itself; enables reaction | whoever acts on the detection | yes (detection lag, evasion) | no | only as good as observability of the contracts |
| **B. Operational pre-inclusion prevention** | a builder/sequencer/runtime component rejects the transaction before settlement (e.g. Phylax Credible Layer-class) | unsafe txs *from txs it chooses to process* | the tx submitter / order-flow source | yes (submit elsewhere; builder set fragmentation) | no (liveness/economics, not validity) | yes, relative to the enforcing inclusion set |
| **C. Commitment-point semantic enforcement** | the execution semantics contains an explicit prospective-state → obligation-check → commit/reject boundary (SRW3's modeled mechanism; a client/protocol would realize it) | any state change admitted through the semantics without passing the gate | whoever runs/validates the semantics | no, *within the semantics* (the gate is total over transitions) | depends on where the semantics runs | yes for contracts registered in the hypergraph with complete footprints |
| **D. Consensus/protocol validity** | the validity rule itself makes obligation-violating transitions protocol-invalid (invalid blocks are rejected by consensus) | all violations by all validators | all validators / the protocol's social consensus | no (violation = invalid block) | **yes** | yes, network-wide, for all covered contracts |

**The levels do NOT have identical trust assumptions**, and the strongest
SRW3 safety theorem states exactly which level it assumes:

* The **mechanized theorem (GH-T2/GH-M, §R.1)** is a theorem about **level C**:
  it quantifies over transitions admitted by the semantics' commitment gate.
  Its premises are InitialSafe (evaluated), SecurityClosed (evaluated closure
  conditions over the registry), and the program class (declared-footprint
  one-write cycles). It makes no claim about transactions that never enter
  the gate.
* Relative to **level B**, the same gate gives: every tx in the enforcing
  inclusion set that settles is safe (the inclusion-set-relative reading).
* **Consensus-strength (level D) is NOT a result of this phase**: it requires
  the commitment-point hook to be embedded in a consensus-validity rule, which
  remains REQUIRES CLIENT/PROTOCOL SUPPORT (§H.3/§Q.4).

### R.4 Prior-art position — frozen (unchanged after the freeze check)

The corrected Round-2 position (§Q.3) is retained verbatim and now FROZEN:
pre-inclusion invariant enforcement is NOT novel (Phylax Credible Layer and
peers); cross-contract invariant checking is NOT novel; formal invariant
verification is NOT novel; lineage/hash chains are NOT novel. The candidate
contribution remains the **conjunction**: explicit interaction hypergraph +
closure-completeness condition + effect-completeness requirement +
commitment-gated composition + lineage structure + executable mechanization
over KEVM + compositional safety theorem.

Per the freeze mandate, three targeted searches were run against the
conjunction before freezing (raw evidence:
`tool-results/prior-art/freeze/`, 2026-09-28): guard-contract post-state
assertion patterns (contract-level checks; no hypergraph/closure/lineage/
mechanization), constraint-based speculative execution (database equivalence
checking; no invariant-gated commitment), and declarative safety verifiers
(VerX/DCV-class; static, not commitment-gated). **No surveyed system combines
substantially all seven elements.** Had a close system been found, the claim
would have been narrowed again rather than defended; none was.

### R.5 Phase-0-D completion classification (mandated 17 items)

Evidence labels: PROVED BY K / DEMONSTRATED BY KEVM / ASSUMED /
REQUIRES CLIENT/PROTOCOL SUPPORT / NOT YET MECHANIZED.

| # | item | classification | anchor |
|---|---|---|---|
| 1 | Claims 1–3 (local preservation; gate coverage; lineage append) | **PROVED BY K** | §E; matrix [3] |
| 2 | Claim 4a (admissible step preserves Safe) | **PROVED BY K** | §E, §Q.1; matrix [3] |
| 3 | Claim 4b (inadmissible step cannot commit) | **PROVED BY K** | §E, §Q.1; matrix [3] |
| 4 | full ∀n safety theorem (`InitialSafe ∧ SecurityClosed → ∀n. Safe`) | **PROVED BY K** — mechanized over the ghost-instrumented semantics (GH-T2/GH-M `#Top`; GhostMatches base/preservation/soundness + gate agreement machine-checked; encoding faithfulness mechanically certified 507/507; non-vacuity control fails correctly) | §R.1; matrix [9] |
| 5 | tier-1 reconciliation (ground agreement) | **PROVED BY K** (checked-by-evaluation class) | §F/§Q.2; matrix [5] |
| 6 | tier-2 generalized reconciliation (state-generalized under wfCoverage) | **PROVED BY K** | §Q.2; matrix [7b] |
| 7 | tier-3 universal reconciliation (∀H ∀FD ∀S) | **STATEMENT FORMALIZED; NOT YET MECHANIZED** (symbolic-set induction boundary; statement not weakened) | §R.2; matrix [10] |
| 8 | effect completeness (wfCheck: Γ* ⊆ Γ̂) | **PROVED BY K** (enforced by the semantics; trust-policy divergence pinned to CM7/X1) | §F, §H; matrix [2] |
| 9 | interaction closure (InteractionComplete/ContractComplete) | **PROVED BY K** (evaluated closure; CM1/CM6 countermodels demonstrate necessity) | §E, §N |
| 10 | structural lineage (Λ records; single commit path; head advance) | **PROVED BY K** (Claims 2/3 + rule census) | §E, §J |
| 11 | cryptographic lineage (`Verify(parent, data, proof)`) | **NOT YET MECHANIZED** (keccak, state-root binding, MPT proofs, signatures) | §J |
| 12 | KEVM execution binding (real SSTORE/CALL/RETURN; obligations over real storage; commit/restore) | **DEMONSTRATED BY KEVM** | §I; matrix [8] |
| 13 | commitment-point mechanism (prospective → obligation-check → commit/reject) | **PROVED BY K** (only the gate accept rule updates `<committed>`; Claim 2; now additionally the ∀n theorem rides it) | §E, §R.1 |
| 14 | CM2 (aliasing across storage namespaces) | **NOT YET MECHANIZED** (modeled single namespace) | §N |
| 15 | CM3 (aggregate-authority limits) | **NOT YET MECHANIZED** | §N |
| 16 | CM8 (hyperproperty-level guarantees) | **NOT YET MECHANIZED** | §N |
| 17 | CM9 (liveness) | **NOT YET MECHANIZED** | §N |

plus: commitment-point hook in an execution client / protocol — **REQUIRES
CLIENT/PROTOCOL SUPPORT** (§H.3/§Q.4/§R.3); obligation registries and A1–A3
abstractions — **ASSUMED** per model (explicit, §E).

### R.6 Regression matrix v3 — nothing changed

Re-run after all theorem-closure artifacts
(`transcripts/audit/full_matrix_v3.txt`): [1] Python baseline 15/15 (canonical
`make test`); [2] abstract demos 13/13 as-expected; [3] Claims 1/2/3/4a/4b
PROVED (`#Top`, no vacuity); [4] negative control correctly FAILS (exit 113);
[5] bridge 9/9; [6] phantom-reject audit reproduced; [7] safe-form 4/4,
generalized bridge 5/5, necessity probe correctly FAILS; [8] KEVM positive =
COMMIT `{oracle:{0:100,1:1}, lending:{0:100,1:5}, liq:{0:4,1:100}}` + lineage
price 100; stale-price = REJECT + full restore + no lineage (n=0, h=−1);
minimal = REJECT + restore (n=0, h=−1) — demo `evm_min2.srw3evm` retargeted
from the pre-renaming account 1 to 4097 (w3Oracle) with a changelog note
(`k/kevm/demos/DEMO_NOTES.md`); verdict semantics identical to the round-1
canonical record; `evm_minimal.srw3evm` remains the setup-only smoke demo;
[9] ghost encoding freshly recompiled and re-run: faithfulness certificate
507/507 PASS, all twelve per-claim verdicts identical to the discovery run;
[10] tier-3 attempts reproduced the same three stuck residuals; [11]
prior-art freeze evidence present. **No previously established result
changed.**

### R.7 LLVM decision — resolved

Per the mandate's rule: the full ∀n theorem **is mechanized** (GH-T2/GH-M
reach `#Top`), so this pass's outcome is the first branch: the theorem-closure
result is recorded above as a major Phase-0-D result, and **LLVM backend work
is now UNBLOCKED** as the next phase's first engineering step. The backend
boundaries documented along the way (symbolic-Map evaluation in [B];
destination-value linkage in [C] and GH-T; symbolic-set induction in T3-U/FD/A)
are recorded verbatim so LLVM retargeting can be evaluated against exactly
these packaging limitations. The tier-3 statement remains formalized and
unweakened; if a future backend upgrade mechanizes it, the tier ladder
completes without any change to the statements.
