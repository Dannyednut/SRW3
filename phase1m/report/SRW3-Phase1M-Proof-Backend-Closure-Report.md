# SRW3 Phase 1M — Proof-Backend Closure: Report

**Branch:** `phase1m-proof-backend-closure` (from `phase1l-universal-induction` @ `0aee3ee`)
**Commits:** Workstream A `a6ca829` (the L-FINDING-1 repair) · Workstream B (the hash redirect) · Workstream C (the gate refusal) · Workstreams D–E (this report)
**Verdict:** the proof-engineering blockers B1 (hash definedness) and B4 (the stuck gate) are **REMOVED AND MEASURED**; the universal reachable-committed-state theorem is **NOT MECHANIZED** — per the execution order's completion gate, **Phase 1M is NOT COMPLETE under its own rule**, and this report is the honest disposition.  Level III only; no consensus-integration claim.

## 0. Executive verdict

Phase 1M was ordered to (1) repair L-FINDING-1, (2) remove the hash-definedness blocker soundly, (3) make gate failure explicit and non-committing, and (4) attempt the genuine universal induction theorem.  All four were executed.  (1)–(3) are complete at the claim level with measured OLD/NEW evidence pairs; (4) retains the failed proofs, names the exact remaining blockers, and reports the strongest theorems that are truly proved: the complete step-partition family over the repaired machine (7/7 PROVED, including the new gate-refusal class), the refusal non-commitment family (3/3 PROVED), and the hash-redirect soundness surface (the vector pins PROVE inside the proof backend).  The composition into the universal theorem is NOT mechanized: the arbitrary-continuation claim and the committed-prefix corollary both FAIL with named, non-definedness residuals.

## 1. Workstream A — the L-FINDING-1 repair (commit a6ca829)

The unauthorized-source dispatch rule's `<jlineage>` pattern omitted the K map tail: the frozen pattern matched ONLY the single-entry lineage map, so every fully-pinned machine was STUCK on the unauthorized-source class (no diagnostic, no receipt, no movement) while the Python mirror emitted the refusal — the cross-layer divergence.  The repair (machine M1) adds the map tail; the refusal now matches any lineage CONTAINING the config pin; requires/RHS unchanged.  Measured: the K ladder 6/6 (the repaired witness, the single-entry continuity, no-committed-movement, two negative controls failing as designed), the LLVM T11-M1 CORRECTED vs the retained frozen stuck T11, the Python mirror cross-check 8/8 — CROSS-LAYER AGREEMENT.

## 2. Workstream B — the total Keccak-256 evaluator and the M2 redirect

**The evaluator** (`keccak256_total.k`, generated): a REAL, DETERMINISTIC, TOTAL Keccak-256 in plain K rules — no hooks, no axioms.  The state is ONE 1600-bit Int (lane i = x+5·y at bits 64i..64i+63); every stage is a fully-literal-indexed pure-Int reduction; totality by construction (the padding rules partition `lengthBytes mod 136` exactly; the absorb rules partition the padded stream at `==0 / ==136 / >136` — the `==136` base rule exists because the LLVM `substrBytes` RAISES on start>end).  Validated 7/7 pinned vectors on BOTH backends (references cross-checked between an independent Python implementation and pycryptodome); a full hash evaluates in ~7.6 s on hs.  The first (Map-keyed) attempt OOM-killed the hs backend and was never vector-validated — preserved as the failed attempt of record; three defect classes were exposed and fixed during validation (the padding zero count; **`^Int` is EXPONENTIATION in K — bitwise XOR is `xorInt`**; the absorb remainder slice that silently dropped every second block).

**The M2 machine** = M1 + exactly five disclosed edits (roundtrip-verified): the redirect equation on the hash PRIMITIVE — `rule Keccak256raw(B:Bytes) => Keccak256T(B)` — tried before the native hook implementation, so EVERY hash caller flows through the evaluator (the builders via `LinH` AND the frozen 1E auth path, which calls the hook directly).

**Measured:**
- The vector pins PROVE inside the proof backend (KB-VEC-ABC, KB-VEC-TWOBLOCK — destination-pinned literals, non-vacuous).
- **The B1 discriminating OLD/NEW pair**: KB-OLD-INIT-BASE (M1, no redirect) FAILS with `#Ceil(Keccak256raw(b"SRW3/ProtoCfg/R3..." +Bytes ...))` — the exact 1L frozen-machine residual class — while KB-INIT-BASE (M2) fails with NO Ceil: the state carries the evaluator's own defined cascade.  **The hash-definedness blocker is gone.**
- KB-INIT-BASE-HEAD PROVES over M2 — the head advance the 1L claim had to omit.
- The negative controls keep failing: totality grants NO hash equality and NO injectivity; the weakened-SafeJ control does not close (the handoff §3 requirements, all enforced).
- The M2 LLVM anchor is BYTE-IDENTICAL to the frozen record `295e0b6d...` — the redirect is semantics-preserving on concrete data end-to-end.
- Disclosed boundaries: the attribute-dropped LLVM kompile of the redirect machine segfaults (heap corruption; gdb backtrace of record; the tiny-definition counter-evidence isolates it; the attribute-PRESENT build is the LLVM tier of record); the M2-hs krun of the full certificate exceeds 50 min (retained); the pool-mint claims grind to their budgets (B5', below).

## 3. Workstream C — the explicit, non-committing gate refusal

**The M3 machine** = M2 + exactly four disclosed edits (roundtrip-verified): `jrefusedGate()` in the JRefuse domain + ONE `[owise]` rule after the two gate-mint rules.  The partition of well-formed gate commands is **exhaustive by construction** (K's `[owise]` semantics) and **non-overlapping** (mechanized as the negative control MC-NEG-REFUSE-ON-MINT, FAILED as required).

**Measured (the MC ladder, GATE GREEN):**
- MC-GATE-REFUSE-NOCOMMIT, MC-GATE-REFUSE-WITNESS-EMPTYPOOL, MC-GATE-REFUSE-WRONGSLOT — all PROVED: on the CONCRETE-refuted mint shapes (the `.Map` tail, the `.Set` empty pool, the decidable wrong-slot command) the refusal fires and every committed cell is framed unchanged.
- **The B4 discriminating OLD/NEW pair (decidable)**: MC-OLD-GATE-COVERAGE-WRONGSLOT over M2 FAILS with "the configuration cannot be rewritten further" — the concretely-refused command is NEVER consumed (the 1L B4 stuck path, concretely witnessed) — while MC-GATE-REFUSE-WRONGSLOT over M3 PROVES: the SAME command is explicitly consumed with only the diagnostic written.  **The stuck-gate blocker is gone.**
- **The cross-layer agreement (10/10)**: the real frozen mirror returns None with NO movement on every unmet-precondition class and mints on the honest class — the machine and the mirror agree on every well-formed gate command class.

## 4. Workstream D — the genuine universal-induction attempt (the MD ladder)

| Element | Claim | Result | Residual |
|---|---|---|---|
| MD2 step: frames | MD-INV-ANCHOR/CATALOG-FRAME-EXEC | PROVED | — |
| MD2 step: pre-init refusals | MD-INV-PREINIT-INIT/COMMIT-REFUSES | PROVED | — |
| MD2 step: exec source-refusal | MD-INV-EXEC-REFUSAL-SOURCE | PROVED | — |
| MD2 step: commit staleness | MD-INV-COMMIT-REJECT-STALE-SLOT | PROVED | — |
| MD2 step: the NEW gate-refusal class | MD-INV-GATE-REFUSAL-PRESERVES | PROVED | — |
| MD1 base | MD-INV-INIT-BASE | FAILED(rc=1) | "cannot be rewritten further" — NO Ceil (B5) |
| MD3 commit step | KB-COMMIT-ACCEPT-POSTSTATE | FAILED(rc=124) | the B5' grind (retained) |
| MD4 arbitrary continuation | MD-INV-ALLPATH-REACHABILITY | FAILED(rc=1) | B5/B2 (retained) |
| MD5 committed prefix | MD-INV-COMMITTED-PREFIX-SAFE | FAILED(rc=1) | B5/B2 (retained) |
| MD6 vacuity control | MD-NEG-CONTROL-SAFEJ | FAILED(rc=124) as required | — |

**The step partition over M3 is complete (7/7): every transition class of the repaired machine preserves the invariant cells or is an explicit, non-committing refusal.**  The composition is not: the base, the arbitrary continuation, and the committed-prefix corollary all fail with named residuals.

## 5. The remaining blockers (exact)

- **B5 (new, narrower)** — the implication check cannot equate stuck-DEFINED hash-class terms across pattern/rule expansion: the M2/M3 residuals carry the evaluator's own cascade on both sides with NO Ceil, yet the condition comparison fails.  A checker-capability boundary, not a definedness boundary.
- **B5' (new)** — the evaluator's symbolic search cost: the mint/commit rewrites expand the cascade (the redirect made expensive what the opaque hook kept cheap); the single-step claims close, the compositions grind to their budgets.
- **B2 (1L, unchanged)** — the destination-constraint idiom is unusable.
- **The circularity/vacuity class (1L, unchanged)** — SafeJ is a stuck term over symbolic maps; a circular closure would be vacuous (the paired controls enforce this).

## 6. The completion gate, applied

"THE PHASE IS COMPLETE ONLY IF THE UNIVERSAL REACHABLE-COMMITTED-STATE THEOREM IS ACTUALLY MECHANIZED AND THE PROOF REPORTS MATCH THE RETAINED LOGS."

MD-INV-ALLPATH-REACHABILITY and MD-INV-COMMITTED-PREFIX-SAFE are NOT PROVED.  **Phase 1M is therefore NOT COMPLETE under its own gate.**  What IS established, at Level III: the two separately justified semantic repairs (L-FINDING-1; the gate refusal), the sound removal of the hash-definedness blocker (no broad axioms; no hash property assumed or derived), the explicit non-committing gate-failure partition, the cross-layer agreement on every refusal class, and the complete step-partition family — with every raw exit code, log, failed attempt, and boundary disclosed in `phase1m/` (the ladders `claims-status-{kb,mc,md}.csv`, the scores, the audits, the provenance).

## 7. Assumptions and non-claims

- External anchor authority; Keccak collision/preimage resistance; execution-source trust — ASSUMED, unchanged.
- The evaluator's correctness beyond the pinned vectors rests on the standard published construction (generator-transcribed, cross-checked against two independent implementations).
- Finite `EVM_F` scope; no full-EVM claim; no consensus-integration claim.
- Concrete demonstrations (LLVM/Python) are DEMONSTRATED, never proofs.
