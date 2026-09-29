// Negative control: a deliberately FALSE claim — a transition violating IAB
// must NOT be provable to commit. kprove is expected to REFUTE/STUCK on this.
// If kprove "proves" this, the prover configuration is unsound and all
// results above are void.
requires "srw3.k"

module SRW3-NEGCONTROL
  imports SRW3-GATE

  claim // FALSE: gate coverage violation — expecting proof FAILURE
    <k> w(appB, 0, V:Int) ~> gate => .K </k>
    <committed> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int
             => stK(appA, 0) |-> X:Int stK(appB, 0) |-> V:Int </committed>
    <prospective> stK(appA, 0) |-> X:Int stK(appB, 0) |-> Y:Int => .Map </prospective>
    <footprint-t> _FT:Set => .Set </footprint-t>
    <footprint-d> SetItem(appB) => .Set </footprint-d>
    <registry> completeRegistry() </registry>
    <policy> _Pol:Policy </policy>
    <authorities> As:Set </authorities>
    <actor> appB </actor>
    <result> _R:String => "commit" </result>
    requires X +Int V >Int 10 andBool member(appB, As)
endmodule
