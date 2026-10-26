/-
================================================================================
SRW3 PHASE 1T — THE LEAN-ROUTE FALSITY CONTROLS (each MUST FAIL to check)
                    (phase1t/audit/lean/c12_neg_controls.lean)

Expected: `lean c12_neg_controls.lean` EXITS NON-ZERO with elaboration
errors at the marked spots.  A GREEN check (exit 0) on this file would mean
the checker accepts false universals — the fallback route is then rejected
as UNSOUND and C1.2 is NOT upgraded.  The retained transcript records the
exact failure.
================================================================================
-/

inductive PoolCount where
  | zeroP : PoolCount
  | succP : PoolCount → PoolCount

open PoolCount

def countToInt : PoolCount → Int
  | .zeroP   => 0
  | .succP p => countToInt p + 1

-- 1T-LEAN-NEG-GE5 (MUST FAIL): the false universal with threshold 5 —
-- the base case is countToInt(zeroP) = 0 and 0 ≥ 5 is false.
theorem c12_neg_ge5 : ∀ p : PoolCount, countToInt p ≥ 5 := by
  intro p
  induction p with
  | zeroP =>
      have h0 : countToInt .zeroP = 0 := rfl
      omega   -- EXPECTED FAILURE: omega cannot prove 0 ≥ 5
  | succP p ih => omega

-- 1T-LEAN-NEG-ODD (MUST FAIL): the false universal "every interpretation
-- is odd" — zeroP interprets to 0, which is even.
theorem c12_neg_odd : ∀ p : PoolCount, (countToInt p) % 2 = 1 := by
  intro p
  induction p with
  | zeroP =>
      have h0 : countToInt .zeroP = 0 := rfl
      omega   -- EXPECTED FAILURE at the base case
  | succP p ih => omega
