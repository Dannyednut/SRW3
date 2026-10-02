// =============================================================================
// SRW3 Phase 1D-R1 — canonical-encoding layout probe (K side)
// Pure-function probe over SRW3LIN (no demo configuration import — avoids the
// multiple-<k> conflict). Evaluates LinCanonCore / LinCanonFull / LinCoreHash
// on FIXED record-0 inputs and dumps the canon bytes for byte-alignment with
// the Python independent verifier.
// Record-0 artifacts (lin_true_effects demo trace):
//   Q = {1:{0:30}} (declared), E = {1:{0:30}} (true effects),
//   P = {1:{0:30}, 2:{0:50}} (post), tid=0, HEAD=LinRoot, PV=5, key=DemoKey1.
// =============================================================================

requires "srw3lin.k"

module SRW3LIN-CANON-PROBE
  imports SRW3LIN

  configuration <srw3lincanonprobe>
                  <k> $PGM </k>
                  <canoncoreout> .Bytes </canoncoreout>
                  <corehashout> .Bytes </corehashout>
                  <lithashout> .Bytes </lithashout>
                </srw3lincanonprobe>

  syntax CanonPgm ::= "dumpCanon" | "dumpLit"

  // {1:{0:30}} — the declared writes == true effects of record 0
  syntax Map ::= "LinProbeQ" [function, total]
  rule LinProbeQ => 1 |-> (0 |-> 30)
  // {1:{0:30}, 2:{0:50}} — the post-state
  syntax Map ::= "LinProbeP" [function, total]
  rule LinProbeP => LinSetKV(1 |-> (0 |-> 30), 2, 0, 50)

  rule <k> dumpCanon => .K ... </k>
       <canoncoreout> _:Bytes
          => LinCanonCore(1, LinRoot, 0, LinAppsOfMap(LinProbeQ),
                          LinH(LinCanonKV(LinProbeQ)),
                          LinH(LinCanonKV(LinProbeQ)),
                          LinH(LinCanonKV(LinProbeP)),
                          5, LinAddrOf(LinDemoKey1),
                          LinMakeEvidence(LinDemoKey1, 0,
                                          LinH(LinCanonKV(LinProbeQ)),
                                          LinH(LinCanonKV(LinProbeQ)),
                                          LinH(LinCanonKV(LinProbeP)))) </canoncoreout>
       <corehashout> _:Bytes
          => LinCoreHash(1, LinRoot, 0, LinAppsOfMap(LinProbeQ),
                         LinH(LinCanonKV(LinProbeQ)),
                         LinH(LinCanonKV(LinProbeQ)),
                         LinH(LinCanonKV(LinProbeP)),
                         5, LinAddrOf(LinDemoKey1),
                         LinMakeEvidence(LinDemoKey1, 0,
                                         LinH(LinCanonKV(LinProbeQ)),
                                         LinH(LinCanonKV(LinProbeQ)),
                                         LinH(LinCanonKV(LinProbeP)))) </corehashout>

  rule <k> dumpLit => .K ... </k>
       <lithashout> _:Bytes
          => LinH(LinHex("000000010000000000000000000000000000000000000000000000000000000000000000000000000000000100000001be0de445b3967006f9cdc27cf8e5b235daf93767ec356017bc1c7a81931f978ebe0de445b3967006f9cdc27cf8e5b235daf93767ec356017bc1c7a81931f978e816d2242bd50596b115642ad777711ff5fa4554bd39c2912bf6a84e78c52bd4100000005c2aa6271409c10dee630e79df90c968989ccf2b7000000418eec4a7b4212178c3265285839b486bf951a0832f3e820b17d2eb7a63f67bee975a3c12b7310877a56adba8e3594a1b2826cd4e637d31fbd2da0eab91439a0b701")) </lithashout>

endmodule
