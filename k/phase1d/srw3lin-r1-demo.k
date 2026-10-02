// =============================================================================
// SRW3 Phase 1D-R1 Part VII — K demonstration: 1 positive + 3 negatives
// (k/phase1d/srw3lin-r1-demo.k)
//
// Scenario mirrors the Python L7 suite exactly:
//   Q = {1:{0:100,1:0}, 2:{0:50,1:1}}            (claimed pre-state)
//   E = {1:{0:25}, 2:{1:7}}                      (true effects)
//   P = Apply(Q,E) = {1:{0:25,1:0}, 2:{0:50,1:7}} (honest post)
//   P1 = P ∪ {2:{9:999}}                          (EXTRA entry — the L7 attack)
//   P2 = {1:{0:25,1:0}}                           (missing composed entries)
//   P3 = {1:{0:25,1:0}, 2:{0:50,1:9}}             (changed value)
// All four records are built by LinBuildRec (every cryptographic field
// genuine, signed with LinDemoKey1): only the post correspondence differs.
//
// Expected: pos=valid; neg1=neg2=neg3=invalid-state-composition.
// =============================================================================

requires "srw3lin-r1.k"

module SRW3LIN-R1-DEMO
  imports SRW3LIN-R1

  configuration <srw3linr1>
                  <k> $PGM </k>
                  <r1result> "" </r1result>
                </srw3linr1>

  syntax R1Pgm ::= "r1suite"

  // scenario artifacts
  syntax Map ::= "R1Q" [function, total]
  rule R1Q => LinSetKV(LinSetKV(LinSetKV(LinKV1(1, 0, 100), 1, 1, 0),
                                2, 0, 50), 2, 1, 1)
  syntax Map ::= "R1E" [function, total]
  rule R1E => LinSetKV(LinSetKV(LinKV1(1, 0, 25), 2, 1, 7), 1, 1, 0)
  // honest post = Apply(Q, E): {1:{0:25,1:0}, 2:{0:50,1:7}}
  syntax Map ::= "R1P" [function, total]
  rule R1P => LinApplyEff(R1Q, R1E)
  // negatives
  syntax Map ::= "R1P1" [function, total]   // extra (2,9):=999
  rule R1P1 => LinSetKV(R1P, 2, 9, 999)
  syntax Map ::= "R1P2" [function, total]   // missing: app 2's entries absent
  rule R1P2 => LinSetKV(LinKV1(1, 0, 25), 1, 1, 0)
  syntax Map ::= "R1P3" [function, total]   // changed: (2,1):=9
  rule R1P3 => LinSetKV(R1P, 2, 1, 9)

  syntax Map ::= "R1Reg" [function, total]
  rule R1Reg => 5 |-> true  6 |-> true
  syntax Set ::= "R1Auth" [function, total]
  rule R1Auth => SetItem(LinAddrOf(LinDemoKey1)) SetItem(LinAddrOf(LinDemoKey2))

  syntax LinCtx ::= "R1CtxOf" "(" Map ")" [function, total]
  rule R1CtxOf(P:Map) => linCtxP(R1Q, R1E, P, R1Reg, R1Auth)

  syntax String ::= R1Case ( Map ) [function, total]
  rule R1Case(P:Map)
    => VerifyLineageP( LinBuildRec(1, LinRoot, R1Q, R1E, P, LinDemoKey1, 5),
                       R1CtxOf(P), 1, LinRoot )

  syntax String ::= "R1SUITE" [function, total]
  rule R1SUITE
    => "pos="   +String R1Case(R1P)
       +String ";neg1=" +String R1Case(R1P1)
       +String ";neg2=" +String R1Case(R1P2)
       +String ";neg3=" +String R1Case(R1P3)

  rule <k> r1suite => .K ... </k>
       <r1result> "" => R1SUITE </r1result>

  syntax Map ::= LinKV1 ( Int , Int , Int ) [function, total]
  rule LinKV1(A:Int, S:Int, V:Int) => A |-> (S |-> V)

endmodule
