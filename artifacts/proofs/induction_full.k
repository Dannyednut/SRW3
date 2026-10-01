// =============================================================================
// proofs/induction_full.k — Attempt [B] (v2)
//
// PRIORITY-2 AUDIT ARTIFACT. Full lineage-length safety theorem as a
// [circularity] claim over the REAL Map-encoded semantics with a FULLY
// SYMBOLIC committed state.
//
//   Full theorem (target):
//     InitialSafe_P(sigma_0) /\ SecurityClosed(P)
//     --------------------------------------------
//     forall n. Safe(P, sigma_n)        hence Reach_committed(A) ⊆ Safe(P)
//
//   The induction STEP is Claim 4a /\ 4b (proved separately, see SRW3-CLAIMS).
//   This attempt mechanizes the INDUCTION: tB(V) is one full admissible
//   transition cycle (begin; w(appB,0,V); wfCheck; gate); chkS is a safety
//   observer whose ONLY rule requires safeMin(committed); programs are
//   sequences of cycles terminated by chkS (isGateRun). The claim "every such
//   program terminates" PROVES iff no path ever commits an unsafe state —
//   were the gate to accept an unsafe prospective, chkS could not fire.
//   The [circularity] reuse of the claim at each unrolled tail re-establishes
//   safeMin(committed) — the induction hypothesis over committed lineage
//   length.
//
//   EXPECTED RESULT (recorded verbatim in the transcript): the prover gets
//   stuck at the GATE DECISION — with committed state fully symbolic, the
//   accept condition allHold(applicable(completeRegistry, FD), M[KEY <- V])
//   contains lookupInt over a symbolic map-update term; even with the
//   lookup-over-update [simplification] lemmas, lookupInt over the UNWRITTEN
//   part of a symbolic map does not reduce, so neither gate rule can be
//   selected. The induction hypothesis lives in a reachability-logic side
//   condition (requires), which cannot be consumed as a rewrite hypothesis.
//   See induction_record.k [C] for the record encoding where the SAME
//   induction goes through.
// =============================================================================

requires "srw3.k"

module SRW3-INDUCT-STEP
  imports SRW3-GATE

  // one full admissible transition cycle over the REAL semantics
  syntax Srw3Cmd ::= "tB" "(" Int ")" | "chkS"
  rule <k> tB(V:Int) => begin ~> w(appB, 0, V) ~> wfCheck ~> gate ... </k>

  // safety observer: executable ONLY on a safe committed state
  rule <k> chkS => .K ... </k>
       <committed> M:Map </committed>
    requires safeMin(M)

  // program restriction: cycles terminated by the observer
  syntax Bool ::= "isGateRun" "(" Srw3Pgm ")" [function, total]
  rule isGateRun(chkS) => true
  rule isGateRun(tB(V:Int) , REST:Srw3Pgm) => isGateRun(REST)
  rule isGateRun(_) => false [owise]

  // trusted simplification lemmas: lookup of the written slot; lookup past
  // an update to a different slot.
  rule lookupInt(M:Map [KEY:StKey <- V:Int], KEY:StKey) => V [simplification]
  rule lookupInt(M:Map [KEY:StKey <- V:Int], K2:StKey) => lookupInt(M, K2)
    requires K2 =/=K KEY [simplification]

  syntax Bool ::= "safeMin" "(" st:Map ")" [function, total]
  rule safeMin(M2:Map)
    => lookupInt(M2, stK(appA, 0)) <=Int 10
       andBool lookupInt(M2, stK(appB, 0)) <=Int 10
       andBool lookupInt(M2, stK(appA, 0)) +Int lookupInt(M2, stK(appB, 0)) <=Int 10
endmodule

module SRW3-INDUCT-FULL
  imports SRW3-INDUCT-STEP

  claim // [B] Full theorem, Map encoding, fully symbolic committed state
    <k> PG:Srw3Pgm => .K </k>
    <committed> M:Map => ?M2:Map </committed>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> As:Set </authorities>
    requires safeMin(M) andBool member(appB, As) andBool isGateRun(PG)
    [circularity]
endmodule
