# SRW3 Phase 1L — Induction Diagnosis (why the universal theorem is NOT
# MECHANIZED, with the exact blockers)

**Disposition:** the universal reachability-safety theorem
(J-REACHABLE-COMMITTED-SAFE, handoff §2) is **NOT MECHANIZED**.  This
document names the blockers EXACTLY, with probe-level evidence, and states
the strongest theorems that ARE proved.  No result is relabeled; the failed
attempts are retained (`transcripts/k/`).

## 1. Diagnosis of the frozen 1J claim (handoff §5.1)

The frozen `J-REACHABLE-COMMITTED-SAFE` claim instantiates a FIXED
four-command fixture pipeline (`pInitJ ~> pExecJ ~> pGateEvalJ ~>
pCommitJ ~> runNilJ`) over the ground fixtures and requires
`SafeJ(XCatJ, S)` at the source.  Its retained failure log
(356,867 lines) ends with `[Error] Prover: backend terminated because
the configuration cannot be rewritten further`, with 29,357
`WarnFunctionWithoutEvaluators` warnings for the KRYPTO `Keccak256raw`
hook.  Three over-constraint classes (handoff §5.1's questions):

1. **Fixed pipeline, not a universal statement** — the claim quantifies
   over symbolic cells but over a FIXED command sequence; it cannot
   express "arbitrary finite continuation".  The induction structure is
   absent: nothing carries the invariant across an UNBOUNDED number of
   committed blocks.
2. **Undischargable definedness** — the pipeline's mid-execution hash
   equalities (receipt fields vs. recomputed roots — e.g.
   `BytesEq(StateRootJ(XPost0D), jbParentRootOf(XB0))`) put a
   `Keccak256raw` application with a hash-containing argument into a
   position where kore must discharge its definedness (#Ceil); the hs
   backend has no evaluator for the hook and discharges #Ceil ONLY over
   fully-literal arguments (probe-verified, §2 below).  Nested-hash
   canonicals (the evidence identity contains
   `lengthBytes(Keccak256raw(...))` over hash-containing preimages) are
   therefore never dischargable — even over ground data.  This is the
   precise form of the frozen "hs keccak-hook boundary" (1J/1K).
3. **Circularity blocker** — the kore stuck-configuration class inherited
   from the frozen PI7-ALL/R1-ALL/R2-ALL/R3-ALL claims.

## 2. The blocker census (probe-verified)

Minimal probes on the 1L definition (probe files retained in the session
record; the findings are reproduced by the ladder's own claims):

- **B1 — the hash-definedness boundary (the dominant blocker).**  A claim
  whose proof path materializes `Keccak256raw(x)` where `x` is symbolic
  (or contains a hash subterm) fails the final implication check with an
  undischargeable `#Ceil(Keccak256raw(...))`.  Probe: `<jhead> H:Bytes =>
  LinH(H:Bytes) </jhead>` fails with residual
  `#Not(#Ceil(Keccak256raw(H)) ∧ ...)`; the same claim with a LITERAL
  argument proves (the frozen 1J ground-fixture claims all have
  literal-argument hashes).  Total wrappers (a `[function, total]`
  alias with a single unfolding rule, declared in the 1L proof-facing
  module) do NOT rescue destinations — the unification unfolds the
  wrapper and re-materializes the Ceil.  Reflexivity hypotheses in
  `requires` do NOT discharge the Ceil (the SMT treats the equation as an
  uninterpreted atom).  **Every hash EQUALITY remains a claim HYPOTHESIS
  where it is one** — the boundary is about kore's ability to MATERIALIZE
  hash applications, not about any assumed hash property.
- **B2 — the destination-constraint idiom is unusable.**  `requires` is
  evaluated at the SOURCE; a destination-only variable in `requires` is
  an unbound-lookahead term and the claim dies with "configuration cannot
  be rewritten further" (the L-EXP-DESTVAR-POS/NEG experiment pair).
  Therefore a claim of the form "one step preserves the invariant" CANNOT
  constrain its destination invariant through `requires`; the invariant
  must be carried by SHARED cells (frame steps) or EXACT destination
  terms (the accept step) — which is what the ladder does.
- **B3 — the pool-Ceil class.**  The mint/accept rewrites build
  receipts (`JExecReceiptOf`, `jGateReceipt(...)` with `ProtoRootR3` /
  `JCatalogRootJ` / `VerifyLineageG` arguments) into SETS; set
  well-formedness demands the elements' definedness; over symbolic
  arguments the `#Ceil`s are undischargeable (B1's consequences at the
  pool level).  Claims whose SOURCE patterns pin CONCRETE pool shapes
  (`.Set`, `SetItem(R) .Set`) refute the accept/mint unifications
  CONCRETELY and prove — the working convention of the frozen ladder
  (J-FORGED-VERDICT-REJECT) applied systematically in 1L.
- **B4 — the stuck-gate path.**  A `pGateEvalJ` whose mint preconditions
  are unmet matches NO rule (there is deliberately no `[owise]` gate
  rule): the configuration is stuck, and a stuck configuration does not
  match the all-path claim's source pattern `RUN:PProgJI` (the <k> cell
  holds a K-sequence, not a PProgJI term), so the circular re-application
  cannot re-fire and the branch dies.  The handoff §3 item 5 documents
  the stuck case as non-commit ("may be stuck; this is non-commit, not
  an accepting transition"); mechanically it excludes any
  termination-anchored universal claim over programs containing gate
  evaluations.

## 3. Why the [circularity] (forall-n) recipe does not transfer

Phase 1B's forall-n theorems (GH2/GH3/GH4-T2/M, `[circularity]`) proved
`InitialSafe ∧ SecurityClosed → ∀n. Safe(s_n)` over ghost-instrumented
semantics whose invariant was DECIDABLE ARITHMETIC on concrete
fixed-shape cells (`stK(appA,7) |-> X1 ...` with bounds).  The circular
re-application re-checks the claim's source requires at the successor
state; with decidable arithmetic that re-check VERIFIES the invariant.
The J machine's safety core `SafeJ(P, σ)` is a recursive evaluator over a
symbolic Map and a symbolic catalog — on the Haskell backend it is a
STUCK term.  The circular re-application can only ASSUME it
(satisfiability of a stuck true-assertion is trivial), so a closed proof
would be VACUOUS w.r.t. safety.  The paired negative control
(L-NEG-ALLPATH-WEAKSAFEJ — the invariant weakened to the non-safety
conjuncts) was run to detect exactly this: it also fails (the stuck-gate
and hash blockers kill it independently), so the positive claim's failure
cannot be re-interpreted as a sound closure; and had it closed, the
control's failure would have exposed the vacuity.  The 1L ladder therefore
reports the all-path claim as attempted-and-blocked, NOT PROVED-BY-CIRCULARITY.

## 4. The strongest theorems that ARE proved (this phase)

All mechanized over the FROZEN J machine (the reachable rule set is the
frozen machine's — rule-inventory.md), symbolic everywhere the backend
allows:

1. **The initialization base, grounded**: successful `pInitJ` under the
   authorized anchor pins the configuration and the catalog with the
   genesis state unchanged — the frozen 1J claim J-INIT-PINS-AUTHORIZED
   (ground fixture), reproduced PROVED in the fresh re-run; the init
   guard itself computes `SafeJ(P, .Map)` (fail-closed base).
2. **The frame family**: the anchor cell, the pinned configuration, and
   the pinned catalog are untouched by the execution-dispatch step
   (L-INV-ANCHOR-FRAME-EXEC, L-INV-CATALOG-FRAME-EXEC — PROVED).
3. **The pre-init family**: pre-init states have no committed history and
   no receipts; refused initializations and commit attempts change
   nothing (L-INV-PREINIT-INIT-REFUSES, L-INV-PREINIT-COMMIT-REFUSES —
   PROVED).
4. **The refusal family**: the unsupported/bounds refusals write ONLY the
   diagnostic and mint nothing; the dispatch resolves both classes; the
   unauthorized-source class moves no committed cell and mints no receipt
   on EVERY resolution path (L-INV-EXEC-REFUSAL-*,
   L-INV-EXEC-DISPATCH-UNSUPPORTED/BOUNDS, L-INV-EXEC-SOURCE-NOCOMMIT —
   PROVED).
5. **The commit-rejection family**: the freshness ties are CONCRETE — a
   slot-(N-1) receipt cannot commit at slot N; empty post-consumption
   pools refute reuse; a non-"valid-g" computed verdict refuses; a
   prior-slot exec receipt cannot satisfy the accept guard
   (L-INV-COMMIT-REJECT-STALE-SLOT, L-INV-COMMIT-REJECT-REUSED-RECEIPT,
   L-INV-COMMIT-REJECT-FORGED-VERDICT, L-INV-COMMIT-HEAD-STATE-COHERENCE —
   PROVED).
6. **The structural inventory** (rule-inventory.md): exactly one rule
   writes `<jstate>` with a non-shared value (the accepted pCommitJ, and
   it writes exactly `jerPostOf(jgExecOf(R))` — the same term the guard's
   SafeJ conjunct certifies); exactly one rule extends the chain; the
   receipt producers/consumers are closed.

The composition of 1-6 into the universal theorem is a standard
induction argument whose BASE and STEP are (mostly) mechanized but whose
FINAL COMPOSITION over arbitrary finite continuations is NOT mechanized
on the Haskell backend (B1-B4).  Per the phase discipline the theorem
remains **NOT MECHANIZED**; the concrete substitutes (the Python prefix
enumeration, the fresh LLVM T-series byte-identical to the frozen
records) remain DEMONSTRATED evidence, not proof.

## 5. What would close the gap (recorded, not claimed)

- A K backend with a Keccak evaluator or totality axiom for the hash hook
  would remove B1 (the blocker census shows every blocked claim's
  residue is a #Ceil).
- An `[owise]` gate-mint refusal (a separately justified 1J-semantics
  repair commit) would remove B4.
- A backend-level pattern-with-constraint for reachability claims (or a
  proof assistant over a proved abstract transition relation plus a
  simulation theorem — handoff §5.5's alternative) would remove B2/B4's
  expressiveness limits.
