// =============================================================================
// SRW3 PHASE 1P (r2) — THE SELF-ASSUMPTION / PASS-EVAL GUARD-HOLE PROBE
//                    (phase1p/proofs/n_p_neg_self.k)
//
// RECONSTRUCTION r2.  The 1O audit documented the PASS-EVAL guard hole: a
// claim whose goal closes by EVALUATION (no rewriting, no step content)
// proves nothing about dynamics, yet a naive gate counts it green.  This
// probe is that hole, ON PURPOSE, at the tagged layer:
//
//   1P-NEG-SELF-ASSUME — a "universal-looking" Bool claim that reduces to a
//   tautology because the run is the NIL run (absRunFT(aRunNilJ, AX) == AX,
//   so the implication is X impliesBool X).  EXPECTED: rc=0 with
//   WarnTrivialClaim — the runner records it in the PASS-SELF class and the
//   gate treats ANY WarnTrivialClaim on a NEGATIVE control as GREEN, but
//   the report states plainly: this claim is NOT a universal theorem and
//   MUST NOT be cited as one.  Level III only.
// =============================================================================

requires "../semantics/abs-machine-tdr.k"

module P-NEG-SELF
  imports SRW3N-ABS-TDR

  claim // 1P-NEG-SELF-ASSUME (EXPECTED PASS-EVAL + WarnTrivialClaim — the
        // documented hole, reproduced deliberately; NOT a theorem).
    <k> (ABSInvT(AX:AStateT) impliesBool ABSInvT(absRunFT(aRunNilJ, AX:AStateT))) => true </k>
    [label(1P-NEG-SELF-ASSUME)]

endmodule
