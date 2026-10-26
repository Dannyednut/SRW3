/-
================================================================================
SRW3 PHASE 1U — WORKSTREAM A3: THE FALSITY CONTROLS FOR THE HELPER LEMMAS.
                    (phase1u/audit/lean/c12_helper_neg_controls.lean)

DELIBERATELY FALSE STATEMENTS — this file MUST FAIL TO ELABORATE (lean
exit != 0).  Each theorem is the falsity twin of a helper lemma; if any of
them were accepted, the helper development would be vacuous or unsound and
every 1U rule classification would be rejected.  This is the same
negative-control discipline as the 1T c12_neg_controls.lean file.

Expected: exit 1 (elaboration error on the first false theorem; the error
message of record is the retained transcript).

Run command:
  lean phase1u/audit/lean/c12_helper_neg_controls.lean
Expected: NONZERO exit (the false statements cannot be proved).
================================================================================
-/

inductive PoolCount where
  | zeroP : PoolCount
  | succP : PoolCount → PoolCount

open PoolCount

def countToInt : PoolCount → Int
  | .zeroP   => 0
  | .succP p => countToInt p + 1

theorem c12_nonneg : ∀ p : PoolCount, countToInt p ≥ 0 := by
  intro p
  induction p with
  | zeroP =>
      have h0 : countToInt .zeroP = 0 := rfl
      omega
  | succP p ih =>
      have hstep : countToInt (.succP p) = countToInt p + 1 := rfl
      omega

-- FALSITY TWIN 1: the 1T overgeneralization, stated exactly as the 1T rule
-- read it — countToInt (succP p) >= i for ALL i >= 1.  FALSE: witness
-- p = zeroP, i = 2 gives 1 >= 2.  If Lean accepted this, the corrected-rule
-- audit premise ("the justified statement is the literal threshold") would
-- be wrong.
theorem NEG_c15_generalized : ∀ (p : PoolCount) (i : Int), i ≥ 1 → countToInt (succP p) ≥ i := by
  intro p i hi
  have hstep : countToInt (.succP p) = countToInt p + 1 := rfl
  have hnn : countToInt p ≥ 0 := c12_nonneg p
  omega   -- MUST FAIL: the goal is not derivable (witness zeroP/2)

-- FALSITY TWIN 2: the successor reaches 2 — FALSE for p = zeroP
-- (countToInt (succP zeroP) = 1).
theorem NEG_succ_ge2 : ∀ p : PoolCount, countToInt (succP p) ≥ 2 := by
  intro p
  have hstep : countToInt (.succP p) = countToInt p + 1 := rfl
  have hnn : countToInt p ≥ 0 := c12_nonneg p
  omega   -- MUST FAIL

-- FALSITY TWIN 3: C1.2 with the inequality flipped — countToInt p <= 0 for
-- all p is FALSE (witness succP zeroP: 1 <= 0 fails); guards against a
-- sign-flipped rule body.
theorem NEG_c12_flipped : ∀ p : PoolCount, countToInt p ≤ 0 := by
  intro p
  induction p with
  | zeroP =>
      have h0 : countToInt .zeroP = 0 := rfl
      omega
  | succP p ih =>
      have hstep : countToInt (.succP p) = countToInt p + 1 := rfl
      omega   -- MUST FAIL (ih gives countToInt p >= 0, goal needs <= -1)
