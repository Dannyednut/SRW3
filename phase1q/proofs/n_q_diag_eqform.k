// =============================================================================
// SRW3 PHASE 1Q — VACUITY DIAGNOSTIC PROBES for the ==K claim form.
//                    (phase1q/proofs/n_q_diag_eqform.k)
//   D1  a TRUE ==K equality between concrete AStateQE terms (MUST PROVE if
//       the form has content);
//   D2  an OBVIOUSLY FALSE ==K equality (MUST FAIL — if this PROVES, the
//       <k> _ ==K _ </k> claim form is vacuous and every ==K claim needs
//       reclassification);
//   D3  the Bool-form control: <k> false => true </k> (the 1O PASS-EVAL
//       hole probe: if this PROVES, the bare-Bool implication form is
//       vacuous for a false hypothesis).
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine-q.k"

module Q-DIAG-EQFORM-PROOFS
  imports SRW3N-ABS-Q

  claim // D1 (MUST PROVE if the form has content): a true equality.
    <k> ( absStQE(true, true, 0, 0, 0, true, adNone)
        ==K absStQE(true, true, 0, 0, 0, true, adNone)) => true </k>
    [label(1Q-DIAG-EQFORM-TRUE)]

  claim // D2 (MUST FAIL): an obviously false equality.
    <k> ( absStQE(true, true, 0, 0, 0, true, adNone)
        ==K absStQE(true, true, 5, 5, 9, true, adNone)) => true </k>
    [label(1Q-DIAG-EQFORM-FALSE)]

  claim // D3 (the PASS-EVAL hole probe): the bare false hypothesis.
    <k> false => true </k>
    [label(1Q-DIAG-FALSE-HYP)]

endmodule
