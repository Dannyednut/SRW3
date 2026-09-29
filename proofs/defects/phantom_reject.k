// =============================================================================
// proofs/defects/phantom_reject.k
//
// PRIORITY-3 AUDIT ARTIFACT — the "phantom reject" defect, reconstructed and
// demonstrated mechanically.
//
// HISTORY (verbatim from the phase worklog, Task 4):
//   "CRITICAL semantic bug found + fixed: reject rules referenced unbound
//    variable P (cells used _P) -> kore treated P as free existential, making
//    reject fire with a phantom state. Fixed to named P bound to actual
//    prospective. All 13 demos re-validated."
//
// WHAT IS RECONSTRUCTED HERE
//   The defective reject rule in its historical shape: the <prospective> cell
//   is matched anonymously (_P:Map) while the requires clause references a
//   variable P that no part of the rule pattern binds. kompile v7.1.337
//   accepts this with ONLY a warning ("Variable 'P' defined but not used");
//   at rewriting time the backend quantifies P existentially in the rule
//   condition, so the rule is applicable whenever SOME state violating the
//   applicable obligations exists -- which is always. Rejection is then
//   "satisfiable with a phantom state": the gate can reject on the basis of a
//   state that is not the state being committed.
//
//   The accept rule below is the CORRECTED accept rule (verbatim semantics of
//   SRW3-GATE) so that the accept side is beyond suspicion: every behavioral
//   difference demonstrated here is attributable to the defective reject rule
//   alone.
//
// NOTE ON FIDELITY: the verbatim defective rule text from the original
// bring-up session was not preserved in the surviving transcripts; this file
// is a faithful reconstruction from the recorded worklog description. The
// reconstruction kompiles and reproduces the recorded behavior (see the
// demonstration claims and the transcript).
// =============================================================================

requires "srw3.k"

module SRW3-PHANTOM
  imports SRW3-CLOSURE        // evalInv / applicable / allHold / member -- NO gate rules

  // setup rule copied verbatim from SRW3-GATE (SRW3-GATE is deliberately NOT
  // imported here: only the reject rule below differs from the corrected gate)
  rule <k> useRegistry(K2:RegistryKind) => .K ... </k>
       <registry> _R:Set => pickRegistry(K2) </registry>
       <authorities> _As:Set => SetItem(appA) |Set SetItem(appB) |Set SetItem(appC) |Set SetItem(oracle) |Set SetItem(lending) |Set SetItem(liq) </authorities>

  // wfCheck rules copied verbatim from SRW3-GATE
  rule <k> wfCheck => .K ... </k>
       <footprint-t> FT:Set </footprint-t>
       <footprint-d> FD:Set </footprint-d>
       <policy> enforce </policy>
    requires subset(FT, FD)

  rule <k> wfCheck => .K ... </k>
       <footprint-t> _FT:Set </footprint-t>
       <footprint-d> _FD:Set </footprint-d>
       <policy> trust </policy>

  rule <k> wfCheck ~> _REST:K => .K </k>
       <footprint-t> FT:Set </footprint-t>
       <footprint-d> FD:Set </footprint-d>
       <policy> enforce </policy>
       <result> _R:String => "blocked-effect-incomplete" </result>
       <prospective> _P:Map => .Map </prospective>
    requires notBool subset(FT, FD)

  // accept rule: CORRECTED form (identical to SRW3-GATE)
  rule <k> gate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <committed> _C:Map => P </committed>
       <registry> R:Set </registry>
       <footprint-t> _FT:Set => .Set </footprint-t>
       <footprint-d> FD:Set => .Set </footprint-d>
       <actor> Ac:AppId </actor>
       <authorities> As:Set </authorities>
       <polver> PV:Int </polver>
       <lineage> LN:Map => LN:Map [ N:Int <- lin(CH:Commitment, N:Int, auth(Ac), PV, commit(N:Int)) ] </lineage>
       <lineageNext> N:Int => N +Int 1 </lineageNext>
       <head> CH:Commitment => commit(N:Int) </head>
       <result> _R:String => "commit" </result>
    requires member(Ac, As) andBool allHold(applicable(R, FD), P)

  // ==== THE DEFECT (reconstructed) ============================================
  // <prospective> is matched anonymously; requires references P, which NO
  // pattern binds. kompile: Warning "Variable 'P' defined but not used".
  // Backend: P becomes existentially quantified in the condition => the rule
  // fires whenever some phantom state violates the obligations => always.
  rule <k> gate => .K ... </k>
       <prospective> _P:Map => .Map </prospective>
       <registry> R2:Set </registry>
       <footprint-t> _FT2:Set => .Set </footprint-t>
       <footprint-d> FD2:Set => .Set </footprint-d>
       <result> _R2:String => "reject" </result>
    requires notBool allHold(applicable(R2, FD2), P)
endmodule

// =============================================================================
// Demonstration claims.
//
// D-FALSE-REJECT : an HONEST transition (all obligations hold on the real
//   prospective state) "results in reject with committed unchanged".
//   False of the intended model. Under the defect, the phantom reject rule
//   fires on every gate step, so this false claim sits on a live execution
//   path (krun shows honest transitions nondeterministically rejecting; the
//   krun transcript records the phantom firing).
//
// D-VIOLATION-REJECT : the (true) gate-coverage claim, Claim 2's statement.
//   Under the defect this still "proves" -- but for the WRONG reason: the
//   phantom rule fires regardless of the real state, so "the gate rejects bad
//   transitions" holds VACUOUSLY, without the gate ever evaluating the real
//   prospective state. This is why the defect is fatal to the proof suite's
//   evidential value even where the claims still pass.
// =============================================================================

module SRW3-PHANTOM-CLAIMS
  imports SRW3-PHANTOM

  claim // D-FALSE-REJECT: honest transition "rejects" -- FALSE of the intended model
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> _Pol:Policy </policy>
    <authorities> As:Set </authorities>
    <actor> appB </actor>
    <result> _R:String => "reject" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool V <=Int 10
             andBool X +Int V <=Int 10 andBool member(appB, As)

  claim // D-VIOLATION-REJECT: Claim 2's statement -- holds VACUOUSLY under the defect
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> _Pol:Policy </policy>
    <authorities> As:Set </authorities>
    <actor> appB </actor>
    <result> _R:String => "reject" </result>
    requires X +Int V >Int 10 andBool member(appB, As)
endmodule

// =============================================================================
// ACCEPT-SIDE COLLAPSE CHECK (run against the DEFECTIVE definition):
// a verbatim copy of the PROVED Claim 4a. Under the corrected gate it is
// PROVED (see kprove_claims_final.txt). Under the defective gate the phantom
// reject path leaves <committed> unchanged with result "reject", so the
// claim's RHS is unreachable on that path -> the accept-side proof suite
// COLLAPSES. This is the mechanical proof that every accept-side claim
// (Claims 1, 3, 4a) depends on the corrected reject rule.
// =============================================================================
module SRW3-PHANTOM-ACCEPT-CLAIM
  imports SRW3-PHANTOM

  claim // verbatim Claim 4a (proved under SRW3-GATE) -- expected to FAIL here
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <authorities> As:Set </authorities>
    <polver> 1 </polver>
    <actor> appB </actor>
    <lineage> LN:Map => LN:Map [ N:Int <- lin(CH:Commitment, N:Int, auth(appB), 1, commit(N:Int)) ] </lineage>
    <lineageNext> N:Int => N +Int 1 </lineageNext>
    <head> CH:Commitment => commit(N:Int) </head>
    <result> _R:String => "commit" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool X +Int Y <=Int 10
             andBool V <=Int 10 andBool X +Int V <=Int 10
             andBool member(appB, As)
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
endmodule

// =============================================================================
// CORRECTED-SIDE CONTROL (run against the CORRECTED definition hs-out):
// the same false "honest -> reject" claim under the corrected gate. Expected:
// correctly FAILS (the only path is accept, whose result is "commit") -- the
// false statement sits on NO execution path of the corrected model.
// =============================================================================
module SRW3-CORR-FALSE-REJECT
  imports SRW3-GATE

  claim // same statement as D-FALSE-REJECT, corrected gate -- expected to FAIL
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> _Pol:Policy </policy>
    <authorities> As:Set </authorities>
    <actor> appB </actor>
    <result> _R:String => "reject" </result>
    requires X <=Int 10 andBool Y <=Int 10 andBool V <=Int 10
             andBool X +Int V <=Int 10 andBool member(appB, As)
endmodule
