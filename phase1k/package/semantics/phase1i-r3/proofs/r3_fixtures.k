// =============================================================================
// SRW3 Phase 1I-R3 — PROOF FIXTURES (definition module)
//                    (phase1i-r3/proofs/r3_fixtures.k)
//
// K proof modules admit only claims and simplification rules, so the CONCRETE
// canon fixture and the LEGACY WITNESS ORACLE used by the canon claims live
// here, in a plain definition module imported by r3_proofs.k.
//
//   R3FixCfg (+ the five single-field mutations R3FixCfgSchedB / Spec4 /
//   PT2 / GuestX / CfgX): an all-concrete 13-field configuration — every
//   digest field is a LITERAL byte string, so every canon claim over it is
//   decidable on the Haskell backend (no hash hook involved).  The field
//   values are the handoff/pack sample configuration whose canonical
//   preimage is the 349-byte golden vector (vectors/config-root-r3.json;
//   Python reproduces it byte-for-byte).
//
//   LegacyR2ProjectionR3W: the frozen R2/1I preimage shape (0x9C tag, fields
//   1..8, no length prefixes), transcribed verbatim from
//   phase1i-r2/semantics/srw3proto-r2.k §1 ProtoCfgCanonR2 (lines 209-214).
//   Regression witness ONLY (handoff §2: keep the frozen formulas as
//   correspondence points; never reuse the old preimage for the R3 root) —
//   the R3 machine itself never references it.
// =============================================================================

requires "../semantics/srw3proto-r3.k"

module SRW3PROTO-R3-FIXTURES
  imports SRW3PROTO-R3

  syntax ProtoCfgR3 ::= "R3FixCfg" [function, total]
  rule R3FixCfg
    => protoCfgR3( LinHex("636861696e2d31")                    // "chain-1"
                 , 7
                 , LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("666f726b2d41")                      // "fork-A"
                 , LinHex("7363686564756c652d41")              // "schedule-A"
                 , 3
                 , 1
                 , LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572") )

  // the five single-field mutations of the fixture (fields 9..13)
  syntax ProtoCfgR3 ::= "R3FixCfgSchedB" [function, total]
  rule R3FixCfgSchedB
    => protoCfgR3( LinHex("636861696e2d31"), 7
                 , LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("666f726b2d41")
                 , LinHex("7363686564756c652d42")              // "schedule-B"
                 , 3, 1
                 , LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572") )

  syntax ProtoCfgR3 ::= "R3FixCfgSpec4" [function, total]
  rule R3FixCfgSpec4
    => protoCfgR3( LinHex("636861696e2d31"), 7
                 , LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("666f726b2d41")
                 , LinHex("7363686564756c652d41")
                 , 4, 1                                        // spec 3 -> 4
                 , LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572") )

  syntax ProtoCfgR3 ::= "R3FixCfgPT2" [function, total]
  rule R3FixCfgPT2
    => protoCfgR3( LinHex("636861696e2d31"), 7
                 , LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("666f726b2d41")
                 , LinHex("7363686564756c652d41")
                 , 3, 2                                        // proof type 1 -> 2
                 , LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572") )

  syntax ProtoCfgR3 ::= "R3FixCfgGuestX" [function, total]
  rule R3FixCfgGuestX
    => protoCfgR3( LinHex("636861696e2d31"), 7
                 , LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("666f726b2d41")
                 , LinHex("7363686564756c652d41")
                 , 3, 1
                 , LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c64657221")  // + '!'
                 , LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572") )

  syntax ProtoCfgR3 ::= "R3FixCfgCfgX" [function, total]
  rule R3FixCfgCfgX
    => protoCfgR3( LinHex("636861696e2d31"), 7
                 , LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("666f726b2d41")
                 , LinHex("7363686564756c652d41")
                 , 3, 1
                 , LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c64657221") )  // + '!'

  // LEGACY WITNESS ORACLE — the frozen R2/1I preimage shape (0x9C tag,
  // fields 1..8, NO length prefixes), transcribed verbatim from
  // phase1i-r2/semantics/srw3proto-r2.k lines 209-214.  Regression witness
  // ONLY (handoff §2); the R3 machine never references it.
  syntax Bytes ::= LegacyR2ProjectionR3W ( ProtoCfgR3 ) [function, total]
  rule LegacyR2ProjectionR3W(C:ProtoCfgR3)
    => Int2Bytes(1, 156, BE)                      // 0x9C (frozen 1I tag)
       +Bytes qcrChainIdOf(C) +Bytes I2B4(qcrPolicyVOf(C))
       +Bytes qcrPolicyDOf(C) +Bytes qcrAppSetDOf(C) +Bytes qcrGraphDOf(C)
       +Bytes qcrClientCfgDOf(C) +Bytes qcrExecClientDOf(C) +Bytes qcrForkOf(C)

endmodule
