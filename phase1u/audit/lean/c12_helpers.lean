/-
================================================================================
SRW3 PHASE 1U — WORKSTREAM A3: THE EXPLICIT HELPER LEMMAS FOR THE K RULES.
                    (phase1u/audit/lean/c12_helpers.lean)

PURPOSE OF RECORD.  The Phase 1T cross-checker proved exactly one statement
(the C1.2 theorem c12_nonneg); the K derived rules 1U-C12-LEAN-RULE[-SHIFT/
-SHIFT1] and 1U-C1.5-PROVED-RULE were "projections" of that theorem composed
with integer monotonicity discharged INSIDE K by Z3.  The 1U audit requires
the EXACT properties the K rules need to be stated and kernel-checked as
explicit Lean lemmas, so every derived rule has a one-to-one checked source:

    K rule                          Lean lemma (this file)
    ------------------------------  ----------------------------------------
    1U-C12-LEAN-RULE                c12_nonneg      : countToInt p >= 0
    1U-C1.5-PROVED-RULE             c15_succ_ge1    : countToInt (succP p) >= 1
    1U-C12-LEAN-RULE-SHIFT          c12_shift_ge0   : i >= 0 -> countToInt p + i >= 0
    1U-C12-LEAN-RULE-SHIFT1         c12_shift_ge1   : i >= 1 -> countToInt p + i >= 1

The inductive type, the defining equations, and the statement forms are the
1T development verbatim (phase1t/audit/lean/c12_induction.lean); nothing
else is added — no Mathlib, Lean core only.

Trust base (unchanged from the 1T disclosure): the Lean 4.16.0 kernel and
core, and the source-correspondence argument (C-a)..(C-d) of the 1T file.
A kernel-checked Lean theorem is NOT a K kernel check; the correspondence
between each lemma and its K simplification rule remains part of the
disclosed cross-language trust base.

Tool pin: Lean 4.16.0 (commit 128a1e6b0a82, Release); archive
lean-4.16.0-linux.zip sha256
54d6cba24417d97d928cd8dc0b79e74fedcf8ad92ba4b69850b319785b81c80c.

Run command (no Mathlib, Lean core only):
  lean phase1u/audit/lean/c12_helpers.lean
Expected: exit 0, no errors, the four axiom reports printed.
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

-- The defining equations are definitional (`rfl`):
example : countToInt .zeroP = 0 := rfl
example : countToInt (.succP p) = countToInt p + 1 := rfl

-- ===========================================================================
-- LEMMA 1 (for 1U-C12-LEAN-RULE): C1.2 itself — the 1T theorem of record,
-- restated here so this file is self-contained.
-- ===========================================================================
theorem c12_nonneg : ∀ p : PoolCount, countToInt p ≥ 0 := by
  intro p
  induction p with
  | zeroP =>
      have h0 : countToInt .zeroP = 0 := rfl
      omega
  | succP p ih =>
      have hstep : countToInt (.succP p) = countToInt p + 1 := rfl
      omega

-- ===========================================================================
-- LEMMA 2 (for 1U-C1.5-PROVED-RULE): the EXACT-THRESHOLD successor lower
-- bound — the precise statement the corrected rule needs.  The 1T rule
-- generalized this to `countToInt (succP p) >= i` for ALL i >= 1, which is
-- FALSE (witness p = zeroP, i = 2: countToInt (succP zeroP) = 1 < 2); the
-- falsity is machine-checked in c12_helper_neg_controls.lean.
-- ===========================================================================
theorem c15_succ_ge1 : ∀ p : PoolCount, countToInt (succP p) ≥ 1 := by
  intro p
  have hstep : countToInt (.succP p) = countToInt p + 1 := rfl
  have hnn : countToInt p ≥ 0 := c12_nonneg p
  omega

-- ===========================================================================
-- LEMMA 3 (for 1U-C12-LEAN-RULE-SHIFT): C1.2 shifted by a nonnegative
-- integer — the exact content of the SHIFT rule.
-- ===========================================================================
theorem c12_shift_ge0 : ∀ (p : PoolCount) (i : Int), i ≥ 0 → countToInt p + i ≥ 0 := by
  intro p i hi
  have hnn : countToInt p ≥ 0 := c12_nonneg p
  omega

-- ===========================================================================
-- LEMMA 4 (for 1U-C12-LEAN-RULE-SHIFT1): C1.2 shifted by a positive
-- integer reaches 1 — the exact content of the SHIFT1 rule (the unfolded
-- guard shape countToInt(P) +Int 1 >=Int 1).
-- ===========================================================================
theorem c12_shift_ge1 : ∀ (p : PoolCount) (i : Int), i ≥ 1 → countToInt p + i ≥ 1 := by
  intro p i hi
  have hnn : countToInt p ≥ 0 := c12_nonneg p
  omega

-- (C-e): the AXIOM DEPENDENCY REPORTS — printed to stdout at elaboration
-- time and captured in the retained transcript.  Expected: no `sorryAx`.
#print axioms c12_nonneg
#print axioms c15_succ_ge1
#print axioms c12_shift_ge0
#print axioms c12_shift_ge1
