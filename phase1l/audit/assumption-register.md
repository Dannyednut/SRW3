# SRW3 Phase 1L — Assumption Register

Every assumption is EXPLICIT; none is smuggled in through a
caller-supplied Boolean.  The register carries the 1J assumptions forward
UNCHANGED (the frozen model is unchanged) and adds the 1L proof-facing
items.

## Carried forward from the frozen 1J surface (unchanged)

- **A-ANCHOR (explicit external authentication).**  `<janchor>` is filled
  by the explicit authenticated external input `$SRW3JANCHOR`, written by
  NO rule; protocol-root AUTHORITY/governance remains outside the model.
  The universal theorem is conditional on it.
- **A-KECCAK-CR (collision resistance).**  The hash equalities that bind
  receipts/roots/identities are concrete on the LLVM/Python tier (real
  Keccak-256) and collision resistance is ASSUMED, not proved.
- **A-GATE (frozen-gate soundness).**  The verdict is the frozen 21-
  conjunct `VerifyLineageG` result; its soundness is the Phase 1G
  mechanization.  The 1L ladder never overrides it.
- **A-POLICY (the registered finite invariant language).**  `SafeJ` is
  evaluated over the catalog's registered invariant CONTENTS; the
  declared finite typed fragment is the intended policy.
- **A-SOURCE (execution-source/input-side authenticity).**  The declared
  execution source must equal the pinned execution-client identity; trace
  AUTHENTICITY (historical truth) is NOT claimed — the closed-fragment
  theorem establishes DERIVATION + CORRESPONDENCE + COVERAGE for `EVM_F`.
- **A-LEVEL (Level III).**  Model-level reachable-state safety under the
  listed assumptions; no consensus-integration or full-EVM claim; the
  anchor is NOT renamed "protocol-authenticated" (no governance
  mechanism exists in the model).

## Added by the 1L proof work (proof-facing; no machine change)

- **A-DEF (totality of the builders — the definedness assumption).**  The
  proof-facing wrappers in `phase1l/semantics/j_invariant.k` §5 declare
  the hash-rooted builders TOTAL
  (`LinHT`/`ProtoRootR3T`/`JBlockCommitWJ`/`JRecChildWT`/
  `JCatalogRootWT`/`JExecReceiptWT`, each equal to the frozen builder by
  a single defining rule).  Mathematically keccak-256 IS a total
  function; the Haskell backend merely lacks the evaluator (the blocker
  census, induction-diagnosis.md §2 B1).  **The assumption is DEFINEDNESS
  ONLY** — it does NOT assume collision resistance, preimage resistance,
  or any hash EQUALITY; every hash equality remains a claim hypothesis
  where it is one and is concrete on the LLVM/Python tier.
- **A-FRAGMENT (the universal claim's fragment condition).**  The
  all-path claim is conditional on the machine's own totality discipline:
  the pGateEvalJ stuck case (unmet mint preconditions — handoff §3
  item 5, L-A19) is NON-COMMIT by rule exhaustiveness; a
  termination-anchored universal claim additionally requires the stuck
  case to be resolvable (B4, induction-diagnosis.md).
- **A-RERUN (the 1J re-run bound).**  The fresh re-run of the frozen 1J
  kprove ladder reproduced 38/38 PROVED; the 4 retained-class claims were
  re-run bounded by the re-run wrapper's per-claim budget (rc=124); their
  frozen full-run logs remain the authoritative record (the Phase 1K
  disclosure, carried forward).

## Explicit non-assumptions (the negative register)

- SafeJ is NEVER assumed in its own induction step: it enters the ladder
  only through (a) the init guard's computed conjunct (base), (b) the
  accept guard's computed conjunct over EXACTLY the installed post-state
  (step), (c) shared cells (frames).  The negative control
  L-NEG-CONTROL-SAFEJ verifies the dependency.
- No caller-supplied verdict/decision/root/anchor/receipt/policy Boolean
  exists on any command surface (the command language has none; the
  Python introspection check L-A12 verifies).
- No new transition rule, no rewritten frozen rule, no semantic change:
  the 1L definitions are `[function, total]` only (rule-inventory.md).
