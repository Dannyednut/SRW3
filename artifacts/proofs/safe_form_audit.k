// =============================================================================
// proofs/safe_form_audit.k — Round-2 theorem-boundary audit, item 1
//
// MACHINE-CHECKED PREMISE-FORM EQUIVALENCES for Claims 4a/4b (SRW3-CLAIMS).
//
// AUDIT QUESTION (verbatim from the instructions):
//   "Determine whether Claim 4a and Claim 4b use a genuine predecessor-state
//    safety premise of the form Safe(P, sigma) or an equivalent predicate,
//    rather than merely an InitialSafe(...) premise whose semantic meaning is
//    restricted to the designated initial state."
//
// FINDING (analytic, confirmed by the claims below):
//   * The requires clauses of 4a/4b contain NO InitialSafe predicate and pin
//     NO initial values: X and Y are universally quantified symbolic Ints.
//     The word "InitialSafe" occurs in srw3.k only in a comment describing
//     that the base constraint is evaluated, not assumed.
//   * The predecessor constraint  X <= 10 /\ Y <= 10 /\ X + Y <= 10  is the
//     evaluated conjunction of the minimal-model obligation universe
//     minInvs() = {IA, IB, IAB, IC} over the committed state
//     {appA |-> X, appB |-> Y} (IC holds vacuously there — SF0 below).
//   * 4a's accept-side conjuncts  V <= 10 /\ X + V <= 10  are exactly the
//     gate's evaluated applicable-obligation conjunction on the prospective
//     state, i.e. the Accepted(sigma_n, tau) premise (SF2).
//   * 4b's disjunction  V > 10 \/ X + V > 10  is exactly the negation of
//     that conjunction, i.e. the Rejected(sigma_n, tau) premise (SF3).
//   * The remaining premises of 4a/4b (securityClosedUniv, authorization)
//     are theorem-level system premises (SecurityClosed / root authority),
//     not restrictions of the safety predicate to an initial state.
//
//   => VERDICT: PROVED. 4a/4b are valid induction steps whose premises are
//      Safe(P, sigma_n) in evaluated form. The full lineage-length theorem
//      remains separately BLOCKED at mechanization (§F.4 blockers) — that is
//      a packaging boundary, NOT a premise defect.
//
// Epistemic status: like the bridge G-claims, these are checked by
// evaluation (WarnTrivialClaim = checked-by-evaluation); the difference from
// a ground decision is UNIVERSAL QUANTIFICATION: X, Y, V range over all
// integers, so each claim is an identity between evaluated formulas.
// =============================================================================

requires "srw3.k"

module SRW3-SAFE-FORM
  imports SRW3-GATE

  // The named safety predicate, verbatim the observer predicate of
  // proofs/induction_full.k (chkS's requires), restated locally so this
  // artifact is self-contained.
  syntax Bool ::= "safeForm" "(" st:Map ")" [function, total]
  rule safeForm(M2:Map)
    => lookupInt(M2, stK(appA, 0)) <=Int 10
       andBool lookupInt(M2, stK(appB, 0)) <=Int 10
       andBool lookupInt(M2, stK(appA, 0)) +Int lookupInt(M2, stK(appB, 0)) <=Int 10
endmodule

module SRW3-SAFE-FORM-CLAIMS
  imports SRW3-SAFE-FORM

  claim // SF0: IC is vacuous on the two-key shape (never-written slot reads 0,
        // mirroring EVM SLOAD semantics) — why the universe reduces to 3 checks
    <k> evalInv(IC, stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int) => true </k>

  claim // SF1: the inlined 4a/4b predecessor constraint IS the named safety
        // predicate, for ALL symbolic X, Y  (premise form = Safe(P, sigma_n))
    <k> safeForm(stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int)
        ==Bool ( X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10 )
        => true </k>

  claim // SF2: 4a's accept-side conjuncts ARE the gate's applicable-obligation
        // conjunction on the prospective state  (= Accepted(sigma_n, tau))
    <k> allHold(applicable(completeRegistry(), SetItem(appB)),
                stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int)
        ==Bool ( V <=Int 10 andBool X +Int V <=Int 10 )
        => true </k>

  claim // SF3: 4b's rejection disjunction IS the exact negation of the gate's
        // accept condition  (= Rejected(sigma_n, tau))
    <k> notBool allHold(applicable(completeRegistry(), SetItem(appB)),
                        stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int)
        ==Bool ( V >Int 10 orBool X +Int V >Int 10 )
        => true </k>
endmodule
