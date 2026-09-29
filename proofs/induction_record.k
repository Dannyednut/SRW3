// =============================================================================
// proofs/induction_record.k — Attempt [C]
//
// PRIORITY-2 AUDIT ARTIFACT. The SAME full lineage-length safety induction,
// over a record encoding of the minimal model's REACHABLE state space.
//
// Faithfulness of the restriction (minimal model, universe {IA,IB,IAB}):
//   * committed state = record (xa,xb); prospective (pa,pb); begin copies;
//   * the only write is w(appB,0,V) => pb := V; footprint {appB}; wfCheck
//     passes trivially;
//   * gate accept iff the applicable obligations on the prospective record —
//     exactly {IB, IAB} = applicable(completeRegistry(), {appB}) — hold:
//     V <= 10  /\  xa + V <= 10; accept sets (xa,xb) := (xa,V); reject keeps;
//   * key sets are preserved by transitions, so every REACHABLE committed
//     state of the minimal model is faithfully a record (xa,xb); the Map
//     encoding's extra generality (arbitrary key sets) is unreachable.
//
// The theorem is stated in refutation-proof form: every program is a
// nonempty sequence of transition attempts TERMINATED by the observer `chk`,
// whose only rule requires the committed record to be safe. The claim
// "every such program reaches <k> .K </k>" therefore PROVES iff no path ever
// commits an unsafe state: were the gate to accept an unsafe state, chk
// could not fire and the path would stick. The [circularity] reuse of the
// claim at each unrolled tail re-establishes safe(xa,xb) — the induction
// hypothesis over committed lineage length. No ghost state; the end-state
// safety is enforced by chk's rule, not by an unconstrained RHS.
// =============================================================================

module SRW3-RECORD
  imports DOMAINS

  configuration <srw3r>
                  <k> $PGM:TProg </k>
                  <xa> 0 </xa>
                  <xb> 0 </xb>
                  <pa> 0 </pa>
                  <pb> 0 </pb>
                  <result> "" </result>
                </srw3r>

  syntax TauStep ::= "tB" "(" Int ")" | "w2" "(" Int ")" | "g2"
  syntax TProg ::= "chk" | TauStep ":" TProg

  rule <k> (T:TauStep : P2:TProg) => T ~> P2 ... </k>

  // begin: prospective := committed record
  rule <k> tB(V:Int) => w2(V) ... </k>
       <xa> X:Int </xa> <xb> Y:Int </xb>
       <pa> _PA:Int => X </pa> <pb> _PB:Int => Y </pb>

  // w(appB,0,V): pb := V  (footprint {appB}; wfCheck trivially passes)
  rule <k> w2(V:Int) => g2 ... </k> <pb> _P2:Int => V </pb>

  // gate ACCEPT: applicable obligations {IB, IAB} hold on prospective
  rule <k> g2 => .K ... </k>
       <xa> X:Int </xa> <xb> _Y:Int => V:Int </xb>
       <pa> _PA2:Int => 0 </pa> <pb> V:Int => 0 </pb>
       <result> _R:String => "commit" </result>
    requires V <=Int 10 andBool X +Int V <=Int 10

  // gate REJECT: no committed update (the commitment boundary)
  rule <k> g2 => .K ... </k>
       <xa> X:Int </xa> <xb> _YR:Int </xb>
       <pa> _PA3:Int => 0 </pa> <pb> V:Int => 0 </pb>
       <result> _R2:String => "reject" </result>
    requires notBool ( V <=Int 10 andBool X +Int V <=Int 10 )

  // observer: executable ONLY on a safe committed record
  rule <k> chk => .K ... </k>
       <xa> X:Int </xa> <xb> Y:Int </xb>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
endmodule

// --- claims that PROVE (machine-checked induction step on the record encoding)
module SRW3-RECORD-CLAIMS-PROVED
  imports SRW3-RECORD

  claim // [C-a] 4a-shape, record encoding: an admissible transition commits W
        // and the committed record (X,W) satisfies Safe (destination pinned;
        // no observer; all destination values LHS-bound).
    <k> tB(W:Int) => .K </k>
    <xa> X:Int </xa>
    <xb> Y:Int => W:Int </xb>
    <pa> _PA:Int => 0 </pa>
    <pb> _PB:Int => 0 </pb>
    <result> _R:String => "commit" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
             andBool W <=Int 10 andBool X +Int W <=Int 10
    [label(record-4a)]

  claim // [C-b] 4b-shape, record encoding: an inadmissible transition cannot
        // commit; the committed record (X,Y) is unchanged and safe.
    <k> tB(W:Int) => .K </k>
    <xa> X:Int </xa>
    <xb> Y:Int </xb>
    <pa> _PA2:Int => 0 </pa>
    <pb> _PB2:Int => 0 </pb>
    <result> _R2:String => "reject" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
             andBool notBool ( W <=Int 10 andBool X +Int W <=Int 10 )
    [label(record-4b)]
endmodule

// --- full-theorem ATTEMPTS (record encoding) — expected STUCK; verbatim
// --- residuals are recorded in the audit transcript and analyzed in the report
module SRW3-RECORD-CLAIM-ATTEMPT
  imports SRW3-RECORD

  claim // [C-attempt-1] one cycle + chk observer (termination-form step).
        // STUCK: kore destination handling loses the rule-produced value
        // linkage (residual #Not(?YB = W /\ ...) recorded verbatim).
    <k> ( tB(W:Int) : chk ) => .K </k>
    <xa> X:Int </xa>
    <xb> Y:Int => W:Int </xb>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
             andBool W <=Int 10 andBool X +Int W <=Int 10

  claim // [C-attempt-2] FULL theorem as [circularity]: every chk-terminated
        // program from a safe record terminates. STUCK: same destination
        // residual at the first circular reuse.
    <k> P3:TProg => .K </k>
    <xa> X:Int </xa>
    <xb> Y:Int </xb>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
    [circularity]
endmodule
