/-
================================================================================
SRW3 PHASE 1T — C1.2 STRUCTURAL INDUCTION (Workstream B, FALLBACK ROUTE)
                    (phase1t/audit/lean/c12_induction.lean)

THE STATEMENT OF RECORD (phase1s report §C1.2; the ledger row 1S-C1.2-UNIV,
FAILED-STUCK on K v7.1.337):

    C1.2   forall P : PoolCount, countToInt(P) >=Int 0

THE DEFINITIONS OF RECORD (frozen machine of record
phase1q/semantics/abs-machine-q.k, lines 31-32 and 400-402 — the module
imported transitively by the Phase 1S definition SRW3N-REL-S via
phase1r/semantics/abs-machine-qs.k -> phase1q/semantics/abs-machine-q.k):

    syntax PoolCount ::= "zeroP"          [constructor]   // exactly zero receipts
    syntax PoolCount ::= succP(PoolCount) [constructor]   // exactly one more
                                                          // receipt than _

    syntax Int ::= countToInt ( PoolCount ) [function, total]
    rule countToInt(zeroP)                => 0
    rule countToInt(succP(N:PoolCount))   => countToInt(N) +Int 1

THE EXACT CORRESPONDENCE (the argument that this Lean development proves the
SAME statement C1.2 over the SAME free algebra — check each clause against
the K source above):

  (C-a) CONSTRUCTORS.  The K syntactic category PoolCount is declared with
        EXACTLY two constructors, zeroP/0 and succP/1, both [constructor]-
        tagged; K constructor declarations define a FREE ALGEBRA (no
        equations between constructor terms; the `syntax` block above is the
        entire declaration — no other production targets PoolCount).  The
        Lean `inductive PoolCount` below has exactly the two constructors
        zeroP/0 and succP/1 with the same arities and order; Lean inductive
        types are free algebras (the constructors are injective and
        mutually exclusive — the same term model up to the identity
        renaming).  Therefore the two term languages are isomorphic by the
        unique-interpretation extensionality of free algebras.

  (C-b) THE FUNCTION.  The K function countToInt is defined by EXACTLY two
        equations on the two constructor shapes (no [owise], no overlapping
        patterns, no requires-side conditions on either rule — verified by
        inspection of lines 400-402): the rules are left-linear,
        non-overlapping, and constructor-complete, hence they define
        countToInt as THE UNIQUE total function on the free algebra
        satisfying the two clauses — which is exactly what the Lean
        `def countToInt` pattern match below defines (Lean's equation
        compiler produces the same two defining equations, provable by
        `rfl`, and the match is exhaustive by the completeness checker).

  (C-c) THE PREDICATE.  K `X >=Int 0` is the hooked integer comparison on
        the K builtin Int (arbitrary-precision, wrapping-free: the K
        `>=Int` hook is Z3's arithmetic `>=` over unbounded integers —
        the K frontend maps Int to SMT Int); Lean `Int` is
        arbitrary-precision integer arithmetic and `a ≥ 0` is `0 ≤ a` on
        that type.  Same mathematical predicate `x in Int, x >= 0`.

  (C-d) THE CLAIM.  Under (C-a)+(C-b) the K equation `countToInt(zeroP) = 0`
        is the Lean clause `| .zeroP => 0` and the K equation
        `countToInt(succP(N)) = countToInt(N) +Int 1` is the Lean clause
        `| .succP p => countToInt p + 1` (+Int on K Int is the unbounded
        `+` = Lean `Int.add`).  Under (C-c) the K goal `countToInt(P) >=Int 0`
        for every P is the Lean goal `countToInt p >= 0` for every p.  The
        Lean theorem below is therefore LITERALLY C1.2.

  (C-e) THE PROOF.  The Lean `induction p with` performs the structural
        induction on the free algebra (the same induction principle K's
        term language would require): the base case discharges by the
        defining equation (`rfl` + linear arithmetic) and the step case
        discharges by the defining equation + the induction hypothesis
        `ih : countToInt p >= 0` + linear arithmetic (`omega`).  The proof
        kernel of Lean 4.16.0 checks every inference; `#print axioms` at
        the end records the axiom dependency of the theorem.

  (C-f) TRUST BASE (disclosed, per mission §5): the Lean 4.16.0 kernel and
        core (the checker itself), the correspondence clauses (C-a)..(C-d)
        (a source-inspection argument, retained here verbatim), and the
        pinning of the tool (sha256 of the release archive recorded in the
        Phase 1T report).  This is an INDEPENDENT-CHECKER proof of the C1.2
        statement — NOT a K-native derivation; the K-side consequence is
        disclosed as such in the Phase 1T report (the K prover itself
        remains unable to internalize the induction — the recorded boundary
        stands).

Tool pin: Lean (version 4.16.0, x86_64-unknown-linux-gnu, commit 128a1e6b0a82,
Release); archive lean-4.16.0-linux.zip sha256
54d6cba24417d97d928cd8dc0b79e74fedcf8ad92ba4b69850b319785b81c80c.

Run command (no Mathlib, Lean core only):
  lean phase1t/audit/lean/c12_induction.lean
Expected: exit 0, no errors, the axiom report printed.
================================================================================
-/

-- (C-a): the free algebra of the K PoolCount category, constructor
-- names/arity/order verbatim from abs-machine-q.k lines 31-32.
inductive PoolCount where
  | zeroP : PoolCount                                -- "zeroP"          /0
  | succP : PoolCount → PoolCount                    -- succP(PoolCount) /1

open PoolCount

-- (C-b): the two defining equations of record, verbatim shape
-- (abs-machine-q.k lines 401-402; no owise, no requires).
def countToInt : PoolCount → Int
  | .zeroP   => 0
  | .succP p => countToInt p + 1

-- The defining equations are definitional (`rfl`) — the exact K rewrite
-- clauses, checked by the kernel at elaboration time:
example : countToInt .zeroP = 0 := rfl
example : countToInt (.succP p) = countToInt p + 1 := rfl

-- (C-d)+(C-e): C1.2 — the structural induction that K v7.1.337 could not
-- perform (1S-C1.2-UNIV FAILED-STUCK; 1T probes 1T-C12-UNIV-CIRC and
-- 1T-C12-STEP-NZ-CIRC FAILED-STUCK; the [induction] attribute is rejected
-- by the toolchain).  Base: the defining equation + 0 ≥ 0.  Step: the
-- defining equation + the IH + linear arithmetic.
theorem c12_nonneg : ∀ p : PoolCount, countToInt p ≥ 0 := by
  intro p
  induction p with
  | zeroP =>
      -- base: countToInt(zeroP) = 0 >=Int 0 (the K equation by rfl)
      have h0 : countToInt .zeroP = 0 := rfl
      omega
  | succP p ih =>
      -- step: countToInt(succP p) = countToInt p + 1 (K equation by rfl);
      -- IH ih : countToInt p ≥ 0; omega = the integer-arithmetic closure
      -- (countToInt p ≥ 0 → countToInt p + 1 ≥ 0).
      have hstep : countToInt (.succP p) = countToInt p + 1 := rfl
      omega

-- (C-e): the AXIOM DEPENDENCY REPORT — printed to stdout by the checker
-- at elaboration time and captured in the retained transcript.  Expected:
-- no `sorryAx` (no unproved placeholders); whatever standard logical
-- axioms are listed is recorded verbatim.
#print axioms c12_nonneg
